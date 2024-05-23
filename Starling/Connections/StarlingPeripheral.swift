//
//  StarlingPeripheral.swift
//  react-native-starling
//
//  Created by Viktor Strate Kløvedal on 27/09/2023.
//

import Foundation
import CoreBluetooth

protocol StarlingPeripheralDelegate {
    func didConnect(_ peripheral: StarlingPeripheral)
    func didDisconnect(_ peripheral: StarlingPeripheral)
}

class StarlingPeripheral: NSObject, StarlingPeer {
    let peripheral: CBPeripheral
    weak var bm: BluetoothManager!
    
    var log: Logger {
        Logger(ctx: .tag("StarlingPeripheral"), logger: bm.log.logger)
    }
    
    public var delegate: StarlingPeripheralDelegate? = nil
    var transferCharacteristic: CBCharacteristic? = nil
    
    var centralManager: CBCentralManager? {
        bm?.centralManager
    }
    
    var address: DeviceAddress {
        DeviceAddress(id: peripheral.identifier)
    }
    
    var maxPacketLength: Int { peripheral.maximumWriteValueLength(for: .withoutResponse) }
    
    init(bm: BluetoothManager, peripheral: CBPeripheral) {
        self.bm = bm
        self.peripheral = peripheral
        
        super.init()
        
        peripheral.delegate = self
    }
    
    func discover() {
        peripheral.discoverServices([bm.serviceUUID])
    }
    
    func disconnect() {
        log.i("disconnecting peripheral \(address)")
        
        if let charac = transferCharacteristic {
            peripheral.setNotifyValue(false, for: charac)
        }
        
        centralManager?.cancelPeripheralConnection(peripheral)
        delegate?.didDisconnect(self)
    }
    
    func sendPacket(_ packet: Data) {
        let maxBytes = peripheral.maximumWriteValueLength(for: .withoutResponse)
        precondition(packet.count <= maxBytes)
        
        guard let transferCharacteristic = transferCharacteristic else {
            log.e("failed to send message to peripheral, transferCharacteristic was nil")
            return
        }
        
        peripheral.writeValue(packet, for: transferCharacteristic, type: .withoutResponse)
    }
}

extension StarlingPeripheral: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        log.d("peripheral didModifyServices")
        
        let invalidatedService = invalidatedServices.first(where: { $0.uuid == bm.serviceUUID })
        
        if invalidatedService != nil {
            log.d("peripheral service is invalidated - rediscovering services")
            self.transferCharacteristic = nil
            self.discover()
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        log.d("peripheral didDiscoverServices")
        
        if let error = error {
            log.e("error discovering services for peripheral: \(error.localizedDescription)")
            disconnect()
            return
        }
        
        guard let service = peripheral.services?.first(where: { $0.uuid == bm.serviceUUID }) else {
            log.e("peripheral did not have our service")
            disconnect()
            return
        }
        
        peripheral.discoverCharacteristics([bm.characteristicUUID], for: service)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        log.d("peripheral didDiscoverCharacteristicsFor service")
        
        if let error = error {
            log.e("error discovering characteristics for peripheral: \(error.localizedDescription)")
            return
        }
        
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == bm.characteristicUUID }) else {
            log.w("peripheral did not have our characteristic")
            return
        }
        
        log.d("transfer characteristic found, enabling notifications")
        self.transferCharacteristic = characteristic
        peripheral.setNotifyValue(true, for: characteristic)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            log.e("notification error: \(error.localizedDescription)")
            disconnect()
            return
        }
        
        if characteristic.uuid == bm.characteristicUUID {
            log.d("characteristic is notifying: \(characteristic.isNotifying)")
            self.transferCharacteristic = characteristic
            
            if characteristic.isNotifying {
                delegate?.didConnect(self)
            } else {
                disconnect()
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            log.e("error discovering characteristics: \(error.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else {
            log.e("failed to read value of characteristic")
            return
        }
        
        log.i("received \(data.count) bytes from peripheral")
        bm.delegate.receivedPacket(deviceAddress: address, packet: data)
    }
}
