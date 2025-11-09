//
//  BluetoothManager.swift
//  otgi
//
//  Created by jwjbadger on 10/10/25.
//

import CoreBluetooth
import Foundation
import SwiftUI

enum BLEDecodeError: Error {
    case invalidLength
}

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate,
    CBPeripheralDelegate
{
    private var centralManager: CBCentralManager!
    private var otgiPeripheral: CBPeripheral!
    
    @Published var bluetoothEnabled = false
    @Published var estimatedTripFuelUsage: Double? = nil
    @Published var connected = false
    @Published var error: Error? = nil
    @Published var runcount: UInt64? = nil
    
    @AppStorage("storedRuncount") public var storedRuncount = 0
    @AppStorage("tankUsage") public var storedTankUsage: Double = 0.0
    @AppStorage("tripUsage") public var storedTripUsage: Double = 0.0

    override init() {
        super.init()
        print("Initializing bluetooth...")
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
        
        if self.storedTripUsage > 0.0 && self.estimatedTripFuelUsage == nil {
            // I see no way for estimatedTripFuelUsage NOT to be nil at this point
            self.estimatedTripFuelUsage = self.storedTripUsage
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            self.bluetoothEnabled = true
            print("Bluetooth is ON")
            self.centralManager.scanForPeripherals(withServices: [
                CBUUID(string: "2CBC6002-370F-577A-9286-81E04F368400")
            ])

        default:
            self.bluetoothEnabled = false
            print("Bluetooth not available: \(central.state.rawValue)")
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        if peripheral.name == "OTGI" {  // there has to be a better way to identify this
            self.centralManager.stopScan()
            self.centralManager.connect(peripheral)
            self.otgiPeripheral = peripheral  // Is there a better way to keep this state?
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        print("Successfully connected to: \(peripheral)")
        self.connected = true
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: (any Error)?
    ) {
        self.connected = false
        self.otgiPeripheral = nil
        self.centralManager.scanForPeripherals(withServices: [
            CBUUID(string: "2CBC6002-370F-577A-9286-81E04F368400")
        ])

        // We can't be sure that we should save our trip fuel until we encounter the next trip
}

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: (any Error)?
    ) {
        if error != nil {
            print("wuh woh: \(error!)")
            self.error = error
            return
        }

        if peripheral.services?.count ?? 0 != 1 {
            print(
                "Wrong number of services (\(peripheral.services?.count ?? 0)... Firmware has been updated or we're attempting to connect to the wrong device"
            )
            return
        }

        peripheral.discoverCharacteristics(
            nil,
            for: peripheral.services!.first!
        )
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: (any Error)?
    ) {
        if error != nil {
            print("Failed to discover characteristics: \(error!)")
            self.error = error
        }

        if service.characteristics?.count ?? 0 != 2 {
            print(
                "Wrong number of characteristics (\(service.characteristics?.count ?? 0)... Firmware has been updated or we're attempting to connect to the wrong device"
            )
            return
        }

        peripheral.readValue(
            for: service.characteristics!.filter {
                $0.uuid
                    == CBUUID(string: "ED0CDAA9-FC55-C2C1-93A0-61B6E1F36720")
            }.first!
        )
        peripheral.setNotifyValue(
            true,
            for: service.characteristics!.filter {
                $0.uuid
                    == CBUUID(string: "56C46FEF-9039-0803-A71F-EEBCC8650E43")
            }.first!
        )
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        if error != nil {
            print("Error in updating value for characteristic: \(error!)")
            self.error = error
            return
        }

        if characteristic.uuid
            == CBUUID(string: "ED0CDAA9-FC55-C2C1-93A0-61B6E1F36720")
        {
            print(characteristic.value!)
            self.runcount = characteristic.value!.withUnsafeBytes {
                rawBufferPointer -> UInt64 in
                return rawBufferPointer.load(as: UInt64.self)
            }
            
            if self.runcount! > self.storedRuncount {
                // Save previous run
                self.storedTankUsage += self.estimatedTripFuelUsage ?? self.storedTripUsage
                self.storedTripUsage = 0.0
                self.storedRuncount = Int(self.runcount!)
            }
            
            // Otherwise, we just reconnected and are good with our previously stored data
            
            return
        }

        do {
            if characteristic.value!.count != 8 {
                throw BLEDecodeError.invalidLength
            }

            self.estimatedTripFuelUsage = characteristic.value!.withUnsafeBytes {
                rawBufferPointer -> Double in
                let raw = rawBufferPointer.load(as: UInt64.self)
                let bitPattern = UInt64(littleEndian: raw)
                return Double(bitPattern: bitPattern)
            }
        } catch {
            print("Appears that we have had an error: \(error)")
            self.error = error
        }
    }
    
    public func save() {
        if let tripUsage = self.estimatedTripFuelUsage {
            self.storedTripUsage = tripUsage
        }
    }
}
