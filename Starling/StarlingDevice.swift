//
//  StarlingDevice.swift
//  Starling
//
//  Created by Viktor Strate Kløvedal on 06/12/2023.
//

import Foundation
import StarlingProtocol

class StarlingDevice: NSObject, ProtoMobileDeviceProtocol {
    weak var starling: StarlingManager!
    
    enum DeviceError: Error {
        case invalidDeviceAddress(address: String?),
            bluetoothManagerWasNil,
             unknownDevice(address: DeviceAddress)
    }
    
    var log: Logger {
        return Logger(ctx: .tag("StarlingDevice"), logger: starling.log.logger)
    }
    
    func log(_ message: String?) {
        starling.log.logger.log(priority: .info, ctx: .proto, message: message!)
    }
    
    fileprivate func bm() throws -> BluetoothManager {
        guard let bm = self.starling.bluetoothManager else {
            throw DeviceError.bluetoothManagerWasNil
        }
        return bm
    }
    
    func maxPacketSize(_ addr: String?, ret0_ returnPtr: UnsafeMutablePointer<Int>?) throws {
        guard let addr = addr, let addrUUID = UUID(uuidString: addr) else {
            log.w("max packet size error: invalid device address \(addr ?? "<nil>")")
            throw DeviceError.invalidDeviceAddress(address: addr)
        }
        
        let address = DeviceAddress(id: addrUUID)
        guard let maxPacketSize = try self.bm().connections[address]?.maxPacketLength else {
            log.w("max packet size error: unknown device \(address)")
            throw DeviceError.unknownDevice(address: address)
        }
        
        returnPtr!.pointee = maxPacketSize
    }
    
    func messageDelivered(_ messageID: Int64) {
        let messageID = MessageID(id: messageID)
        log.d("message delivered \(messageID)")
        self.starling.delegate.messageDelivered(messageID: messageID)
    }
    
    func processMessage(_ session: Int64, message: Data?) {
        let session = Session(id: session)
        log.d("process message \(session)")
        self.starling.delegate.messageReceived(session: session, message: message!)
    }
    
    func sendPacket(_ addr: String?, packet: Data?) {
        guard let addr = addr, let uuid = UUID(uuidString: addr) else {
            log.e("failed to cast address to UUID in sendPacket")
            return
        }
        
        guard let bm = self.starling.bluetoothManager else {
            log.e("failed to send packet since BluetoothManager was nil")
            return
        }
        
        let address = DeviceAddress(id: uuid)
        guard let connection = bm.connections[address] else {
            log.e("address not found when sending packet: \(address)")
            return
        }
        
        connection.sendPacket(packet: packet!)
    }
    
    func sessionBroken(_ session: Int64) {
        let session = Session(id: session)
        log.d("session broken \(session)")
        self.starling.delegate.sessionBroken(session: session)
    }
    
    func sessionEstablished(_ session: Int64, contact: String?, address: String?) {
        let session = Session(id: session)
        let contact = Contact(id: contact!)
        let address = DeviceAddress(id: UUID(uuidString: address!)!)
        
        log.d("session established \(contact)")
        self.starling.delegate.sessionEstablished(session: session, contact: contact, address: address)
    }
    
    func sessionRequested(_ session: Int64, contact: String?) -> Data? {
        let contact = Contact(id: contact!)
        let session = Session(id: session)
        log.d("session requested \(contact)")
        return self.starling.delegate.sessionRequested(session: session, contact: contact)
    }
    
    func syncStateChanged(_ contact: String?, stateUpdate: Data?) {
        let contact = Contact(id: contact!)
        log.d("sync state changed \(contact)")
        
        if let stateUpdate = stateUpdate {
            starling.delegate.syncStateChanged(contact: contact, change: .stateUpdated(newState: stateUpdate))
        } else {
            starling.delegate.syncStateChanged(contact: contact, change: .contactDeleted)
        }
        
        do {
            if let stateUpdate = stateUpdate {
                try SyncPersistence.storeContactState(contact: contact, state: stateUpdate)
            } else {
                try SyncPersistence.deleteContactState(contact: contact)
            }
        } catch let error {
            log.e("failed to persist state update for \(contact): \(error)")
        }
    }
}
