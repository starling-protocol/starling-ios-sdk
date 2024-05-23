//
//  ContactsContainer.swift
//  Starling
//
//  Created by Viktor Strate Kløvedal on 27/02/2024.
//

import Foundation
import CryptoKit
import StarlingProtocol

struct SharedSecret: Equatable {
    let secret: Data
    
    var contact: Contact {
        let hash = secret.withUnsafeBytes { secretData in
            CryptoKit.SHA256.hash(data: secretData)
        }
        
        let hashData = hash.withUnsafeBytes { hashData in
            Data(bytes: hashData.baseAddress!, count: hashData.count)
        }
        
        
        return Contact(id: hashData.urlSafeBase64())
    }
}

class ContactsContainer: NSObject, ProtoMobileContactsContainerProtocol {
    
    let log: Logger
    
    init(logger: StarlingLogger) {
        self.log = Logger(ctx: .tag("contacts-container"), logger: logger)
    }
    
    enum ContactsContainerError: Error {
        case unknownContact, linkSessionCastError, existingGroup
    }
    
    func allGroups() -> String {
        do {
            let groups = try KeychainContactStore.allSecrets(type: .group)
                .map { $0.contact.id }
                .joined(separator: ";")
            
            log.d("All groups: \(groups)")
            return groups
        } catch let error {
            log.e("Failed to get all group secrets: \(error)")
            return ""
        }
    }
    
    func allLinks() -> String {
        do {
            let links = try KeychainContactStore.allSecrets(type: .link)
                .map { $0.contact.id }
                .joined(separator: ";")
            
            log.d("All links: \(links)")
            return links
        } catch let error {
            log.e("Failed to get all link secrets: \(error)")
            return ""
        }
    }
    
    func contactSecret(_ contact: String?) throws -> Data {
        let contact = Contact(id: contact!)

        if let sharedSecret = try KeychainContactStore.loadSecret(contact) {
            return sharedSecret.secret
        }
        
        log.e("cannot get contact secret of unknown contact: \(contact)")
        throw ContactsContainerError.unknownContact
    }
    
    func deleteContact(_ contact: String?) {
        let contact = Contact(id: contact!)
        
        do {
            try KeychainContactStore.deleteSecret(contact)
        } catch let error {
            log.e("failed to delete secret: \(error)")
        }
    }
    
    func joinGroup(_ groupSecret: Data?, error: NSErrorPointer) -> String {
        let groupSecret = SharedSecret(secret: groupSecret!)
        let contact = groupSecret.contact
        
        do {
            if try KeychainContactStore.loadSecret(contact) != nil {
                log.e("failed to join group, it already exists")
                error?.pointee = ContactsContainerError.existingGroup as NSError
                return ""
            }
        } catch let err {
            log.e("failed to check if group already exists: \(err)")
            error?.pointee = err as NSError
            return ""
        }
        
        do {
            try KeychainContactStore.storeSecret(groupSecret, type: .group)
        } catch let err {
            log.e("failed to store group secret: \(err)")
            error?.pointee = err as NSError
            return ""
        }
        
        return contact.id
    }
    
    func newLink(_ linkSecret: Data?, error: NSErrorPointer) -> String {
        let linkSecret = SharedSecret(secret: linkSecret!)
        let contact = linkSecret.contact
        
        do {
            try KeychainContactStore.storeSecret(linkSecret, type: .link)
        } catch let err {
            log.e("failed to store link secret: \(err)")
            error?.pointee = err as NSError
            return ""
        }
        
        return contact.id
    }
}

enum KeychainContactStore {
    
    enum KeychainError: Error {
        case unhandledError(status: OSStatus, msg: String), unexpectedSecretData
        
        static func newUnhandledError(status: OSStatus) -> Self {
            let errorMsg = SecCopyErrorMessageString(status, nil) as String?
            return .unhandledError(status: status, msg: errorMsg ?? "no message")
        }
    }
    
    enum ContactType: String, CaseIterable {
        case link = "starling-link", group = "starling-group"
    }
    
    static func storeSecret(_ secret: SharedSecret, type: ContactType) throws {        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecAttrAccount as String: secret.contact.id,
            kSecAttrService as String: type.rawValue,
            kSecValueData as String: secret.secret
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.newUnhandledError(status: status) }
    }
    
    static func loadSecret(_ contact: Contact) throws -> SharedSecret? {
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrAccount as String: contact.id,
            //kSecAttrService as String: type.rawValue,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status != errSecItemNotFound else {
            return nil
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.newUnhandledError(status: status)
        }
        
        guard let existingItem = item as? [String : Any],
              let secretData = existingItem[kSecValueData as String] as? Data
        else {
            throw KeychainError.unexpectedSecretData
        }
        
        return SharedSecret(secret: secretData)
    }
    
    static func allSecrets(type: ContactType) throws -> [SharedSecret] {
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecAttrService as String: type.rawValue,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status != errSecItemNotFound else {
            return []
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.newUnhandledError(status: status)
        }
        
        guard let existingItems = item as? [[String : Any]] else {
            throw KeychainError.unexpectedSecretData
        }
        
        let secretData: [SharedSecret] = existingItems
            .compactMap { item in item[kSecValueData as String] as? Data }
            .map(SharedSecret.init(secret:))
        
        return secretData
    }
    
    static func deleteSecret(_ contact: Contact) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecAttrAccount as String: contact.id,
            //kSecMatchLimit as String: kSecMatchLimitOne,
            //kSecAttrService as String: type.rawValue,
            //kSecReturnAttributes as String: true,
            //kSecReturnData as String: true
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.newUnhandledError(status: status)
        }
    }
    
    static func deleteAllSecrets() throws {
        for type in ContactType.allCases {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
                kSecAttrService as String: type.rawValue,
            ]
            
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw KeychainError.newUnhandledError(status: status)
            }
        }
    }
}
