//
//  Starling.swift
//  Starling
//
//  Created by Viktor Strate Kløvedal on 06/12/2023.
//

import Foundation
import StarlingProtocol

public struct StarlingOptions {
    public let enableSync: Bool
    
    public init(enableSync: Bool) {
        self.enableSync = enableSync
    }
    
    var protoOptions: ProtoMobileProtocolOptions {
        let opt = ProtoMobileProtocolOptions()
        opt.enableSync = enableSync
        
        return opt
    }
}

public class StarlingManager {
    let options: StarlingOptions
    var proto: ProtoMobileProtocol! = nil
    let device: StarlingDevice
    
    public var delegate: StarlingDelegate
    
    let log: Logger
    
    var eventQueue: DispatchQueue
    var bluetoothManager: BluetoothManager? = nil
    
    var linkingSession: ProtoMobileLinkingSession? = nil
    
    public init(options: StarlingOptions,
                eventQueue: DispatchQueue = DispatchQueue.main,
                delegate: StarlingDelegate,
                logger: StarlingLogger = StarlingDefaultLogger()
    ) {
        /*do {
            try SyncPersistence.deleteAllContactStates()
            try KeychainContactStore.deleteAllSecrets()
        } catch let KeychainContactStore.KeychainError.unhandledError(_, msg) {
            print("FAILED TO DELETE CONTACTS KEYCHAIN ERROR: \(msg)")
        } catch let error {
            print("FAILED TO DELETE CONTACTS: \(error.localizedDescription)")
        }*/
        
        self.options = options
        self.eventQueue = eventQueue
        self.delegate = delegate
        
        self.log = Logger(ctx: .tag("StarlingManager"), logger: logger)
        
        self.device = StarlingDevice()
        self.device.starling = self
        
        let contactsContainer = ContactsContainer(logger: logger)
        self.proto = ProtoMobileNewProtocol(device, contactsContainer, options.protoOptions)!
    }
    
    deinit {
        self.proto.deinitCleanup()
    }
    
    public func loadPersistedState() {
        do {
            let contactStates = try SyncPersistence.loadAllContactStates()
            
            log.i("Loading \(contactStates.count) contact states")
            
            for (contact, state) in contactStates {
                try self.proto.syncLoadState(contact.id, state: state)
            }
        } catch let error {
            log.e("Failed to load contact states: \(error)")
        }
        
        self.proto.loadPersistedState()
    }
    
    public func deletePersistedState() {
        do {
            try SyncPersistence.deleteAllContactStates()
            try KeychainContactStore.deleteAllSecrets()
        } catch let error {
            log.e("Failed to delete contact states: \(error)")
        }
    }
    
    public func startAdvertising(serviceUUID: UUID, characteristicUUID: UUID) {
        log.i("starting advertising")
        self.bluetoothManager = BluetoothManager(starling: self, serviceUUID: serviceUUID, characteristicUUID: characteristicUUID)
    }
    
    public func stopAdvertising() {
        log.i("stopping advertising")
        self.bluetoothManager?.stopAdvertising()
        self.bluetoothManager = nil
        self.delegate.advertisingEnded(reason: "stopped")
    }
    
    enum ProtoError: Error {
        case syncDisabled
    }
    
    enum LinkingError: Error {
        case noSession, malformedURL
    }
    
    public func startLinkSession() throws -> URL {
        log.i("starting linking session")
        let session = try self.proto.linkingStart()
        linkingSession = session
        
        let share = session.getShare()!.urlSafeBase64()
        
        return URL(string: "starling://\(share)")!
    }
    
    public func connectLinkSession(url: String) throws -> Contact {
        log.i("connect to link session: \(url)")
        
        guard let url = URL(string: url), let base64 = url.host else {
            throw LinkingError.malformedURL
        }
        
        guard let session = linkingSession else {
            throw LinkingError.noSession
        }
        
        guard let remoteKey = Data(urlSafeBase64String: base64) else {
            throw LinkingError.malformedURL
        }
        
        var error: NSError? = nil
        let contactID = proto.linkingCreate(session, remoteKey: remoteKey, error: &error)
        
        if let error = error {
            throw error
        }
        
        return Contact(id: contactID)
    }
    
    public func deleteContact(_ contact: Contact) {
        proto.deleteContact(contact.id)
    }
    
    public func sendMessage(session: Session, message: Data) -> MessageID {
        log.i("send message")
        var msgID: Int64 = 0
        try! proto.sendMessage(session.id, message: message, ret0_: &msgID)
        return MessageID(id: msgID)
    }
    
    public func newGroup() throws -> Contact {
        var error: NSError? = nil
        let contact = proto.newGroup(&error)
        
        if let error = error {
            throw error
        }
        
        return Contact(id: contact)
    }
    
    public func joinGroup(groupSecret: Data) throws -> Contact {
        var error: NSError? = nil
        let contact = proto.joinGroup(groupSecret, error: &error)
        return Contact(id: contact)
    }
    
    public func groupContact(fromSecret secret: Data) -> Contact {
        return SharedSecret(secret: secret).contact
    }
    
    public func syncAddMessage(contact: Contact, message: Data, attachedContact: Contact? = nil) throws {
        precondition(options.enableSync, "Synchronization not enabled for StarlingManager")
        log.i("sync add message \(contact)")
        try proto.syncAddMessage(contact.id, message: message, attachedContact: attachedContact?.id ?? "")
    }
    
    public func broadcastRouteRequest() {
        proto.broadcastRouteRequest()
    }
}

extension StarlingManager: BluetoothManagerDelegate {
    func advertisingStarted() {
        log.i("advertising started")
        self.delegate.advertisingStarted()
    }
    
    func advertisingFailed(reason: String) {
        log.w("advertising failed: \(reason)")
        self.bluetoothManager?.stopAdvertising()
        self.bluetoothManager = nil
        self.delegate.advertisingEnded(reason: reason)
    }
    
    func deviceConnected(deviceAddress: DeviceAddress) {
        log.i("device connected \(deviceAddress)")
        proto.onConnection(deviceAddress.stringValue)
        self.delegate.deviceConnected(deviceAddress: deviceAddress)
    }
    
    func deviceDisconnected(deviceAddress: DeviceAddress) {
        log.i("device disconnected \(deviceAddress)")
        proto.onDisconnection(deviceAddress.stringValue)
        self.delegate.deviceDisconnected(deviceAddress: deviceAddress)
    }
    
    func receivedPacket(deviceAddress: DeviceAddress, packet: Data) {
        log.i("received packet \(deviceAddress)")
        self.proto.receivePacket(deviceAddress.stringValue, packet: packet)
    }
}
