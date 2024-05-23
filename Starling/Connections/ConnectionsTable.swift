//
//  ConnectionsTable.swift
//  react-native-starling
//
//  Created by Viktor Strate Kløvedal on 02/10/2023.
//

import Foundation
import CoreBluetooth

class ConnectionsTable {
    private var connections: [DeviceAddress: StarlingConnection] = [:]
    
    subscript(_ address: DeviceAddress) -> StarlingConnection? {
        return connections[address]
    }
    
    func removeAll() {
        connections = [:]
    }
    
    func add(peripheral: StarlingPeripheral) {
        let address = peripheral.address
        connections[address] = connections[address, default: StarlingConnection(address: address)].with(peripheral: peripheral)
    }
    
    func add(central: StarlingCentral) {
        let address = central.address
        connections[address] = connections[address, default: StarlingConnection(address: address)].with(central: central)
    }
    
    func removePeripheral(address: DeviceAddress) {
        let empty = connections[address]?.withoutPeripheral().isEmpty
        if empty == true { connections.removeValue(forKey: address) }
    }
    
    func removeCentral(address: DeviceAddress) {
        let empty = connections[address]?.withoutCentral().isEmpty
        if empty == true { connections.removeValue(forKey: address) }
    }
    
    func insert(connection other: StarlingConnection) {
        let address = other.address
        connections[address] = connections[address, default: StarlingConnection(address: address)].merge(other)
    }
}

extension ConnectionsTable: Sequence {
    typealias Iterator = Dictionary<DeviceAddress, StarlingConnection>.Values.Iterator
    
    func makeIterator() -> Iterator {
        return self.connections.values.makeIterator()
    }
}
