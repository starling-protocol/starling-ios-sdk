//
//  BluetoothManager.swift
//  Starling
//
//  Created by Viktor Strate Kløvedal on 06/12/2023.
//

import Foundation
import CoreBluetooth

class BluetoothManager: NSObject {
    var centralManager: CBCentralManager!
    var peripheralManager: CBPeripheralManager!
    
    let serviceUUID: CBUUID
    let characteristicUUID: CBUUID
    
    let eventQueue: DispatchQueue
    let delegate: BluetoothManagerDelegate
    let log: Logger
    
    var connections = ConnectionsTable()
    
    var connectingPeripherals: Set<CBPeripheral> = Set()
    var configuringPeripherals: Set<StarlingPeripheral> = Set()
    
    var transferCharacteristic: CBMutableCharacteristic {
        CBMutableCharacteristic(type: characteristicUUID,
                                properties: [.notify, .writeWithoutResponse],
                                value: nil,
                                permissions: [.readable, .writeable])
    }
    
    init(starling: StarlingManager, serviceUUID: UUID, characteristicUUID: UUID) {
        self.eventQueue = starling.eventQueue
        self.delegate = starling
        self.log = Logger(ctx: .tag("BluetoothManager"), logger: starling.log.logger)
        self.serviceUUID = CBUUID(nsuuid: serviceUUID)
        self.characteristicUUID = CBUUID(nsuuid: characteristicUUID)
        
        super.init()
        
        self.centralManager = CBCentralManager(delegate: self, queue: starling.eventQueue, options: [
            CBCentralManagerOptionShowPowerAlertKey: true,
            // Opt in to state restoration to attempt reconnecting old peripherals
            //CBCentralManagerOptionRestoreIdentifierKey: "3e43c60d-9a0e-460b-8530-c2025468a5c4"
        ])
        
        self.peripheralManager = CBPeripheralManager(delegate: self, queue: starling.eventQueue, options: [
            CBPeripheralManagerOptionShowPowerAlertKey: true,
        ])
        
        if self.peripheralManager.state == .poweredOn {
            log.d("peripheral manager already powered on, starting advertising")
            peripheralStartAdvertising()
        }
        if self.centralManager.state == .poweredOn {
            log.d("central manager already powered on, starting scanning")
            centralStartScanning()
        }
        
        let peripherals = centralManager.retrieveConnectedPeripherals(withServices: [self.serviceUUID])
        for peripheral in peripherals {
            log.d("attempting to reconnect to old peripheral \(peripheral)")
            self.connectingPeripherals.insert(peripheral)
            self.centralManager.connect(peripheral)
        }
    }
    
    func stopAdvertising() {
        for connection in connections {
            self.delegate.deviceDisconnected(deviceAddress: connection.address)
        }
        
        peripheralManager.stopAdvertising()
        peripheralManager.removeAllServices()
        
        centralManager.stopScan()
        
        for peripheral in connectingPeripherals {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        
        for connection in connections {
            connection.peripheral?.disconnect()
        }
        
        connections.removeAll()
        
        log.d("bluetooth manager stopped")
    }
    
    func sendPacket(address: DeviceAddress, packet: Data) throws {
        guard let connection = connections[address] else {
            log.e("attempted to send a packet to an unknown recipient: \(address)")
            throw StarlingDevice.DeviceError.unknownDevice(address: address)
        }
        
        connection.sendPacket(packet: packet)
    }
    
    func centralConnected(_ central: StarlingCentral) {
        log.d("central connected \(central.address)")
        
        connections.add(central: central)
        if connections[central.address]?.peripheral == nil {
            delegate.deviceConnected(deviceAddress: central.address)
        }
    }
    
    func centralDisconnected(_ central: CBCentral) {
        let address = DeviceAddress(id: central.identifier)
        if connections[address] == nil {
            return
        }
        
        log.d("central disconnected \(address)")
        connections.removeCentral(address: address)
        
        if let peripheral = connections[address]?.peripheral {
            log.d("disconnecting associated peripheral...")
            connections.removePeripheral(address: address)
            peripheral.disconnect()
        }
        
        self.delegate.deviceDisconnected(deviceAddress: address)
    }
    
    func peripheralConnected(_ peripheral: StarlingPeripheral) {
        log.d("peripheral connected \(peripheral.address)")
        connections.add(peripheral: peripheral)
        if connections[peripheral.address]?.central == nil {
            self.delegate.deviceConnected(deviceAddress: peripheral.address)
        }
    }
    
    func peripheralDisconnected(address: DeviceAddress) {
        if connections[address] == nil {
            return
        }
        
        log.d("peripheral disconnected \(address)")
        connections.removePeripheral(address: address)
        if connections[address]?.central == nil {
            self.delegate.deviceDisconnected(deviceAddress: address)
        }
    }
}
