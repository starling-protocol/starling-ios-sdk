//
//  ProtocolTypes.swift
//  Starling
//
//  Created by Viktor Strate Kløvedal on 06/12/2023.
//

import Foundation

public struct DeviceAddress: Identifiable, Hashable {
    public let id: UUID
    
    var stringValue: String { id.uuidString }
    
    public init(id: UUID) {
        self.id = id
    }
}

public struct Contact: Identifiable, Hashable {
    public let id: String
    
    public init(id: String) {
        self.id = id
    }
}

public struct Session: Identifiable, Hashable {
    public let id: Int64
    
    public init(id: Int64) {
        self.id = id
    }
}

public struct MessageID: Identifiable, Hashable {
    public let id: Int64
    
    public init(id: Int64) {
        self.id = id
    }
}
