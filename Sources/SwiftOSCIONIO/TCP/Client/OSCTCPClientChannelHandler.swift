//
//  OSCTCPClientChannelHandler.swift
//  SwiftOSC I/O: SwiftNIO • https://github.com/orchetect/swift-osc-io-nio
//  © 2026 Steffan Andrews • Licensed under MIT License
//

import Foundation
import NIO

/// Internal TCP receiver class so as to not expose  methods as public.
final class OSCTCPClientChannelHandler {
    weak var oscServer: (any _OSCTCPHandlerProtocol & _OSCTCPGeneratesClientNotificationsProtocol)?

    /// Stores an error captured in `errorCaught` for use in `channelInactive`.
    private var pendingError: (any Error)?

    init(oscServer: (any _OSCTCPHandlerProtocol & _OSCTCPGeneratesClientNotificationsProtocol)? = nil) {
        self.oscServer = oscServer
    }
}

extension OSCTCPClientChannelHandler: @unchecked Sendable { } // TODO: unchecked

extension OSCTCPClientChannelHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer

    func channelActive(context: ChannelHandlerContext) {
        // send notification
        oscServer?._generateConnectedNotification()
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var envelope = unwrapInboundIn(data)

        // get byte length of envelope
        let byteLength = envelope.readableBytes
        // read bytes from envelope
        guard let bytes = envelope.readBytes(length: byteLength) else { return /* throw error */ }
        // convert bytes into data
        let data = Data(bytes)

        guard let oscServer else { return }

        let remoteAddress = context.remoteAddress
        let remoteHost = remoteAddress?.ipAddress ?? ""
        let remotePort = remoteAddress?.port ?? 0

        oscServer._handle(receivedData: data, remoteHost: remoteHost, remotePort: remotePort)
    }

    func channelInactive(context: ChannelHandlerContext) {
        let error = pendingError
        pendingError = nil

        oscServer?._generateDisconnectedNotification(error: error)
    }

    func errorCaught(context: ChannelHandlerContext, error: any Error) {
        pendingError = error
        context.close(promise: nil)
    }
}
