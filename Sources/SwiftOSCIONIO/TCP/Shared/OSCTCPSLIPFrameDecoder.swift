//
//  OSCTCPSLIPFrameDecoder.swift
//  SwiftOSC I/O: SwiftNIO • https://github.com/orchetect/swift-osc-io-nio
//  © 2026 Steffan Andrews • Licensed under MIT License
//

import Foundation
import NIOCore
import SwiftOSCCore

final class OSCTCPSLIPFrameDecoder: ByteToMessageDecoder {
    typealias InboundOut = ByteBuffer

    func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        // SLIP has no upfront size declaration, must scan forward to find closing END byte
        guard let endIndex = buffer.withUnsafeReadableBytes({ bytes -> Int? in
            var start = 0
            // find if there is leading 0xC0
            let leadingDelimiterPresent = (bytes.first == TCPSLIPCoding.Byte.end.rawValue)
            // if there is a leading END byte, skip to avoid misidentifying empty frame
            if !bytes.isEmpty, leadingDelimiterPresent {
                start = 1
            }

            // drop bytes before start
            let framedBytes = bytes[start...]
            // search for closing END byte, if none found then need more data
            guard let end = framedBytes.firstIndex(of: TCPSLIPCoding.Byte.end.rawValue) else { return nil }

            return end + 1 // include the end byte
        }) else {
            return .needMoreData
        }
        // advance the reader index past the frame and return as ByteBuffer
        guard let frame = buffer.readSlice(length: endIndex) else { return .needMoreData }
        let envelope = wrapInboundOut(frame)

        context.fireChannelRead(envelope)
        return .continue
    }
}
