//
//  StarlingConnection.swift
//  react-native-starling
//
//  Created by Viktor Strate Kløvedal on 02/10/2023.
//

import Foundation
import CoreBluetooth
import StarlingProtocol

protocol StarlingPeer {
    var maxPacketLength: Int { get }
    var address: DeviceAddress { get }
    func sendPacket(_ packet: Data)
}

class StarlingConnection {
    var central: StarlingCentral? = nil
    var peripheral: StarlingPeripheral? = nil
    
    let address: DeviceAddress
    
    var log: Logger {
        let logger = (central?.bm ?? peripheral?.bm)?.log.logger ?? StarlingDefaultLogger()
        return Logger(ctx: .tag("StarlingConnection"), logger: logger)
    }
    
    var isEmpty: Bool {
        central == nil && peripheral == nil
    }
    
    init(address: DeviceAddress) {
        self.address = address
    }
    
    @discardableResult
    func with(central: StarlingCentral) -> Self {
        self.central = central
        return self
    }
    
    @discardableResult
    func with(peripheral: StarlingPeripheral) -> Self {
        self.peripheral = peripheral
        return self
    }
    
    @discardableResult
    func withoutCentral() -> Self {
        self.central = nil
        return self
    }
    
    @discardableResult
    func withoutPeripheral() -> Self {
        self.peripheral = nil
        return self
    }
    
    @discardableResult
    func merge(_ other: StarlingConnection) -> Self {
        self.central = other.central ?? self.central
        self.peripheral = other.peripheral ?? self.peripheral
        return self
    }
    
    var maxPacketLength: Int? {
        self.peripheral?.maxPacketLength ?? self.central?.maxPacketLength
    }
    
    func sendPacket(packet: Data) {
        var peer: StarlingPeer! = nil
        if let peripheral = self.peripheral {
            log.i("sending packet (\(packet.count) bytes) to peripheral: \(peripheral.address)")
            peer = peripheral
        } else if let central = self.central {
            log.i("sending packet (\(packet.count) bytes) to central: \(central.address)")
            peer = central
        } else {
            log.e("bad state: tried to send packet to peer without underlying connection")
            return
        }
        
        peer.sendPacket(packet)
    }
}
