//
//  SyncPersistence.swift
//  Starling
//
//  Created by Viktor Strate Kløvedal on 04/03/2024.
//

import Foundation

enum SyncPersistence {
    static func syncDirectory() throws -> URL {
        let syncDir = try FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("sync")
        
        if !FileManager.default.fileExists(atPath: syncDir.relativePath) {
            try FileManager.default.createDirectory(at: syncDir, withIntermediateDirectories: false)
        }
        
        return syncDir
    }
    
    static func contactSyncFile(_ contact: Contact) throws -> URL {
        return try syncDirectory().appendingPathComponent(contact.id)
    }
    
    static func storeContactState(contact: Contact, state: Data) throws {
        try state.write(to: try contactSyncFile(contact),
                        options: .completeFileProtectionUntilFirstUserAuthentication)
        print("successfully persisted state update for \(contact): \(state.count) bytes")
    }
    
    static func deleteContactState(contact: Contact) throws {
        try FileManager.default.removeItem(at: try contactSyncFile(contact))
        print("successfully persisted state update for \(contact): deleted")
    }
    
    static func deleteAllContactStates() throws {
        let contactFiles = try FileManager.default
            .contentsOfDirectory(at: syncDirectory(), includingPropertiesForKeys: nil)
        
        for file in contactFiles {
            let contact = Contact(id: file.lastPathComponent)
            try deleteContactState(contact: contact)
        }
        
        print("deleted all persisted states: \(contactFiles.count) contacts")
    }
    
    static func loadContactState(contact: Contact) throws -> Data {
        let state = try Data(contentsOf: try contactSyncFile(contact))
        print("loaded persisted state for \(contact): \(state.count) bytes")
        
        return state
    }
    
    static func loadAllContactStates() throws -> [Contact: Data] {
        
        let contactFiles = try FileManager.default
            .contentsOfDirectory(at: syncDirectory(), includingPropertiesForKeys: nil)
        
        var states = [Contact: Data]()
        for file in contactFiles {
            let contact = Contact(id: file.lastPathComponent)
            states[contact] = try loadContactState(contact: contact)
        }
        
        print("loaded all persisted states: \(states.count) contacts")
        
        return states
    }
}
