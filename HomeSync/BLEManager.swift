//
//  BLEManager.swift
//  HomeSync
//
//  Created by Samarth Bhate on 23/03/26.
//


import SwiftUI
import Combine
import Foundation
import CoreBluetooth

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    var centralManager: CBCentralManager!
    
    @Published var receiveBuffer = ""
    
    @Published var peripherals: [CBPeripheral] = [] {
        didSet {
            
        }
    }
    @Published var connectedPeripheral: CBPeripheral?
    
    @Published var finishedScan = true {
        didSet {
            print("b")
        }
    }
    
    @Published var received: Data?
    
    var targetCharacteristic: CBCharacteristic?
    
    // Door sensor variables
    @Published var doorUltrasonicCM: Double? = nil
    @Published var doorMotionDetected: Bool? = nil
    // Temperature sensor variables
    @Published var temperatureDegrees: Double? = nil
    @Published var humidityPercent: Double? = nil
    // Single-value Boolean (flag for 0 or 1)
    @Published var singleBinaryFlag: Bool? = nil
    
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Scan
    func startScan() {
        finishedScan = false
        peripherals.removeAll()
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        
        // End the scan after a short window so the UI can accurately reflect scan progress.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self else { return }
            self.centralManager.stopScan()
            self.finishedScan = true
        }
    }
    
    // MARK: - Connect
    func connect(peripheral: CBPeripheral) {
        centralManager.stopScan()
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        guard let peripheral = connectedPeripheral else {
            print("Cannot disconnect: No device connected")
            return
        }
        centralManager.cancelPeripheralConnection(peripheral)
        self.connectedPeripheral = nil
    }
    
    // MARK: - Send Data
    func send(data: String) {
        print(data)
        guard let characteristic = targetCharacteristic,
              let peripheral = connectedPeripheral else { return }
        
        let dataToSend = Data(data.utf8)
        peripheral.writeValue(dataToSend, for: characteristic, type: .withResponse)
        
    }
    
    
    // MARK: - Central Delegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("Bluetooth ON")
        } else {
            print("Bluetooth not available")
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        
        if !peripherals.contains(peripheral) {
            peripherals.append(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        
        connectedPeripheral = peripheral
        peripheral.delegate = self
        
        peripheral.discoverServices(nil)
    }
    
    // MARK: - Peripheral Delegate
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        
        peripheral.services?.forEach { service in
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        
        service.characteristics?.forEach { characteristic in
            
            print("Found characteristic: \(characteristic.uuid)")
            
            // Example: HM-10 uses FFE1
            if characteristic.uuid.uuidString == "FFE1" {
                targetCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard error == nil, let data = characteristic.value else { return }
        received = data
        decodeAndUpdate(with: data)
    }
    
    func decodeAndUpdate(with data: Data) {
        guard let string = String(data: data, encoding: .ascii)?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        let parts = string.split(separator: ";").map { String($0) }
        if parts.count == 3, let type = parts.first {
            if type == "0" {
                // Door: 0;distance;motion
                if let dist = Double(parts[1]), let motion = Bool(parts[2]) {
                    doorUltrasonicCM = dist
                    doorMotionDetected = motion
                }
            } else if type == "1" {
                // Temp: 1;temp;humidity
                if let temp = Double(parts[1]), let hum = Double(parts[2]) {
                    temperatureDegrees = temp
                    humidityPercent = hum
                }
            }
        } else if parts.count == 1 {
            if parts[0] == "0" {
                singleBinaryFlag = false
            } else if parts[0] == "1" {
                singleBinaryFlag = true
            }
        }
    }
}

// bool extension because FRICK YOU

private extension Bool {
    init?(_ value: String) {
        switch value.lowercased() {
        case "true", "1": self = true
        case "false", "0": self = false
        default: return nil
        }
    }
}
