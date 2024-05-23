//
//  BluetoothManager+Central.swift
//  react-native-starling
//
//  Created by Viktor Strate Kløvedal on 20/09/2023.
//

import Foundation
import CoreBluetooth

extension BluetoothManager {
    func centralStartScanning() {
        if centralManager.state != .poweredOn {
            log.w("attempted to start central scanner without Bluetooth being ready")
            return
        }
        
        centralManager.scanForPeripherals(withServices: [self.serviceUUID],
                                           options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        log.d("central manager did update state: \(central.state)")
        
        let fail = { (reason: String) in
            self.log.d("CBCentralManager state fail: \(reason)")
            self.eventQueue.asyncAfter(deadline: .now().advanced(by: .milliseconds(100)), execute: DispatchWorkItem(block: {
                if central.state != .poweredOn {
                    self.delegate.advertisingFailed(reason: reason)
                } else {
                    self.log.d("Skipped fail CBCentralManager is now powered on")
                }
            }))
        }
        
        switch central.state {
        case .poweredOn:
            log.d("- CBCentralManager is powered on")
            if !centralManager.isScanning {
                self.centralStartScanning()
            }
            
            // Connect to restored peripherals
            for peripheral in connectingPeripherals {
                central.connect(peripheral, options: nil)
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
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log.d("peripheral device connected to our central: \(peripheral.identifier)")
        
        connectingPeripherals.remove(peripheral)
        
        let starlingPeripheral = StarlingPeripheral(bm: self, peripheral: peripheral)
        starlingPeripheral.delegate = self
        configuringPeripherals.insert(starlingPeripheral)
        
        starlingPeripheral.discover()
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        log.d("central failed to connect to peripheral device: \(peripheral.identifier)")
        connectingPeripherals.remove(peripheral)
        peripheralDisconnected(address: DeviceAddress(id: peripheral.identifier))
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        log.d("peripheral device disconnected from our central: \(peripheral.identifier)")
        peripheralDisconnected(address: DeviceAddress(id: peripheral.identifier))
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, timestamp: CFAbsoluteTime, isReconnecting: Bool, error: Error?) {
        log.d("peripheral device disconnected from our central: \(peripheral.identifier)")
        peripheralDisconnected(address: DeviceAddress(id: peripheral.identifier))
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        let address = DeviceAddress(id: peripheral.identifier)
        
        if self.connections[address]?.peripheral != nil {
            return
        }
        
        if connectingPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            return
        }
        
        if configuringPeripherals.contains(where: { $0.address.id == peripheral.identifier }) {
            return
        }
        
        log.d("central discovered a new peripheral device: \(address)")
        connectingPeripherals.insert(peripheral)
        
        central.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        log.d("central will restore state")
        
        let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []
        log.d("will attempt to restore \(peripherals.count) old peripheral")
        
        for peripheral in peripherals {
            connectingPeripherals.insert(peripheral)
            
            // If not powered on, central will attempt to connect when state changes
            if central.state == .poweredOn {
                central.connect(peripheral, options: nil)
            }
        }
    }
}

// Handle peripherals that are conencted but not yet configured
extension BluetoothManager: StarlingPeripheralDelegate {
    func didConnect(_ peripheral: StarlingPeripheral) {
        log.d("didConnect starling peripheral")
        configuringPeripherals.remove(peripheral)
        peripheralConnected(peripheral)
    }
    
    func didDisconnect(_ peripheral: StarlingPeripheral) {
        log.d("didDisconnect starling peripheral")
        peripheral.delegate = nil
        configuringPeripherals.remove(peripheral)
        peripheralDisconnected(address: peripheral.address)
    }
}
