//
//  StarlingCentral.swift
//  react-native-starling
//
//  Created by Viktor Strate Kløvedal on 09/10/2023.
//

import Foundation
import CoreBluetooth

class StarlingCentral: StarlingPeer {
    let central: CBCentral
    weak var bm: BluetoothManager!
    
    var address: DeviceAddress {
        DeviceAddress(id: central.identifier)
    }
    
    var log: Logger {
        Logger(ctx: .tag("StarlingCentral"), logger: bm.log.logger)
    }
    
    var maxPacketLength: Int { central.maximumUpdateValueLength }
    
    var peripheralManager: CBPeripheralManager? {
        bm?.peripheralManager
    }
    
    init(bm: BluetoothManager, central: CBCentral) {
        self.bm = bm
        self.central = central
    }
    
    func sendPacket(_ packet: Data) {
        bm.peripheralManager.updateValue(packet, for: bm.transferCharacteristic, onSubscribedCentrals: [central])
    }
}
