//
//  StarlingDelegate.swift
//  Starling
//
//  Created by Viktor Strate Kløvedal on 06/12/2023.
//

import Foundation

public protocol StarlingDelegate {
    func advertisingStarted()
    func advertisingEnded(reason: String?)
    func deviceConnected(deviceAddress: DeviceAddress)
    func deviceDisconnected(deviceAddress: DeviceAddress)
    func messageReceived(session: Session, message: Data)
    
    func messageDelivered(messageID: MessageID)
    func sessionBroken(session: Session)
    func sessionEstablished(session: Session, contact: Contact, address: DeviceAddress)
    func sessionRequested(session: Session, contact: Contact) -> Data?
    
    func syncStateChanged(contact: Contact, change: StarlingStateChange)
}

public enum StarlingStateChange {
    case contactDeleted, stateUpdated(newState: Data)
}
