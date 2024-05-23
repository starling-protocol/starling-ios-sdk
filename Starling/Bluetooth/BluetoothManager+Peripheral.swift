//
//  BluetoothManager+Peripheral.swift
//  react-native-starling
//
//  Created by Viktor Strate Kløvedal on 20/09/2023.
//

import Foundation
import CoreBluetooth

extension BluetoothManager {    
    func peripheralStartAdvertising() {
        if peripheralManager.state != .poweredOn {
            log.w("attempted to start peripheral advertisment without Bluetooth being ready")
            return
        }
        
        
        let transferService = CBMutableService(type: serviceUUID, primary: true)
        transferService.characteristics = [transferCharacteristic]
        
        peripheralManager.add(transferService)
        
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID]
        ])
        
        self.delegate.advertisingStarted()
    }
}

extension BluetoothManager: CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        log.d("Peripheral manager did update state: \(peripheral.state)")
        
        let fail = { (reason: String) in
            self.log.d("CBPeripheralManager state fail: \(reason)")
            self.eventQueue.asyncAfter(deadline: .now().advanced(by: .milliseconds(100)), execute: DispatchWorkItem(block: {
                if peripheral.state != .poweredOn {
                    self.delegate.advertisingFailed(reason: reason)
                } else {
                    self.log.d("Skipped fail CBPeripheralManager is now powered on")
                }
            }))
        }
        
        switch peripheral.state {
        case .poweredOn:
            log.d("- CBPeripheralManager is powered on")
            if !peripheralManager.isAdvertising {
                peripheralStartAdvertising()
            }
        case .poweredOff:
            fail("bluetooth turned off")
        case .resetting:
            fail("bluetooth resetting")
        case .unauthorized:
            fail("bluetooth unauthorized")
        case .unknown:
            fail("bluetooth unknown state")
        case .unsupported:
            fail("bluetooth not supported")
        @unknown default:
            fail("bluetooth unknown error")
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            log.e("didStartAdvertising error: \(error.localizedDescription)")
            return
        }
        
        log.d("PeripheralManager didStartAdvertising")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didOpen channel: CBL2CAPChannel?, error: Error?) {
        if let error = error {
            log.e("peripheralManager.didOpen: \(error.localizedDescription)")
            return
        }
        
        log.d("peripheral opened a L2CAP channel to central")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        log.d("device subscribed to characteristic: \(central.identifier)")
        
        self.centralConnected(StarlingCentral(bm: self, central: central))
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        log.d("device unsubscribed from characteristic: \(central.identifier)")
        self.centralDisconnected(central)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        log.d("peripheralManager didReceiveWrite")
        
        for request in requests {
            guard let data = request.value else {
                log.e("failed to read value of characteristic")
                return
            }
            
            log.i("received \(data.count) bytes from central")
            let address = DeviceAddress(id: request.central.identifier)
            self.delegate.receivedPacket(deviceAddress: address, packet: data)
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        log.i("peripheral did receive read")
        fatalError("NOT IMPLEMENTED YET")
    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        log.d("peripheral is ready to update subscribers")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        log.d("service added to peripheral manager: error is \(error?.localizedDescription ?? "nil")")
    }
}
