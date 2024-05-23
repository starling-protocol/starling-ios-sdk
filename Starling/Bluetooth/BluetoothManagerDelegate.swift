//
//  BluetoothManager+Events.swift
//  react-native-starling
//
//  Created by Viktor Strate Kløvedal on 09/10/2023.
//

import Foundation

protocol BluetoothManagerDelegate {
    func advertisingStarted()
    func advertisingFailed(reason: String)
    func deviceConnected(deviceAddress: DeviceAddress)
    func deviceDisconnected(deviceAddress: DeviceAddress)
    func receivedPacket(deviceAddress: DeviceAddress, packet: Data)
}
