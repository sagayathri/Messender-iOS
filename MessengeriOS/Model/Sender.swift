//
//  Sender.swift
//  MessengeriOS
//

import Foundation
import MessageKit

@available(*, deprecated, message: "`Sender` has been replaced with the `SenderType` protocol in 3.0.0")
public struct Sender: SenderType {

    // MARK: - Properties
    /// The unique String identifier for the sender.
    ///
    /// Note: This value must be unique across all senders.
    public let senderId: String

    @available(*, deprecated, renamed: "senderId", message: "`id` has been renamed `senderId` as defined in the `SenderType` protocol")
    public var id: String {
        return senderId
    }

    /// The display name of a sender.
    public let displayName: String

    // MARK: - Intializers
    public init(senderId: String, displayName: String) {
        self.senderId = senderId
        self.displayName = displayName
    }

    @available(*, deprecated, message: "`id` has been renamed `senderId` as defined in the `SenderType` protocol")
    public init(id: String, displayName: String) {
        self.init(senderId: id, displayName: displayName)
    }
}
