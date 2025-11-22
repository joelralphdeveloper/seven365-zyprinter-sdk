//
//  ZywellSDK.swift
//  Seven365Zyprinter
//
//  Swift wrapper for the Zywell Objective-C SDK
//

import Foundation
import CoreBluetooth

@objc public class ZywellSDK: NSObject {
    
    private var bleManager: POSBLEManager?
    private var wifiManagers: [String: POSWIFIManager] = [:]
    private var discoveredPeripherals: [CBPeripheral] = []
    private var peripheralRSSIs: [NSNumber] = []
    
    public override init() {
        super.init()
    }
    
    // MARK: - Echo Test
    
    @objc public func echo(_ value: String) -> String {
        return value
    }
    
    // MARK: - Printer Discovery
    
    @objc public func discoverPrinters(completion: @escaping ([[String: Any]], String?) -> Void) {
        // Discover both Bluetooth and WiFi printers
        var allPrinters: [[String: Any]] = []
        let group = DispatchGroup()
        
        // Discover Bluetooth
        group.enter()
        discoverBluetoothPrinters { btPrinters, error in
            if error == nil {
                allPrinters.append(contentsOf: btPrinters)
            }
            group.leave()
        }
        
        // Discover WiFi
        group.enter()
        discoverWiFiPrinters(networkRange: nil) { wifiPrinters, error in
            if error == nil {
                allPrinters.append(contentsOf: wifiPrinters)
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion(allPrinters, nil)
        }
    }
    
    @objc public func discoverBluetoothPrinters(completion: @escaping ([[String: Any]], String?) -> Void) {
        bleManager = POSBLEManager.sharedInstance()
        bleManager?.delegate = self
        
        // Store completion for delegate callback
        self.discoveryCompletion = completion
        
        // Start scanning
        bleManager?.poSstartScan()
        
        // Auto-stop after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.bleManager?.poSstopScan()
            
            guard let printers = self?.discoveredPeripherals,
                  let rssis = self?.peripheralRSSIs else {
                completion([], nil)
                return
            }
            
            var printerList: [[String: Any]] = []
            for (index, peripheral) in printers.enumerated() {
                let rssi = rssis.count > index ? rssis[index].intValue : 0
                
                printerList.append([
                    "identifier": peripheral.identifier.uuidString,
                    "model": peripheral.name ?? "Unknown Printer",
                    "status": "ready",
                    "connectionType": "bluetooth",
                    "rssi": rssi
                ])
            }
            
            completion(printerList, nil)
        }
    }
    
    @objc public func discoverWiFiPrinters(networkRange: String?, completion: @escaping ([[String: Any]], String?) -> Void) {
        // For WiFi discovery, we would need to implement network scanning
        // This is a placeholder - WiFi printers typically need manual IP entry
        // or use mDNS/Bonjour discovery which requires additional implementation
        
        // Return empty for now - users will connect via IP address
        completion([], nil)
    }
    
    // MARK: - Connection Management
    
    @objc public func connectToPrinter(identifier: String, completion: @escaping (Bool, String?) -> Void) {
        // Check if it's a Bluetooth connection (UUID format)
        if let uuid = UUID(uuidString: identifier) {
            connectBluetoothPrinter(uuid: uuid, completion: completion)
        } else {
            // Assume it's an IP address for WiFi
            connectWiFiPrinter(ipAddress: identifier, completion: completion)
        }
    }
    
    private func connectBluetoothPrinter(uuid: UUID, completion: @escaping (Bool, String?) -> Void) {
        if bleManager == nil {
            bleManager = POSBLEManager.sharedInstance()
            bleManager?.delegate = self
        }
        
        guard let manager = bleManager else {
            completion(false, "Failed to initialize BLE manager")
            return
        }
        
        // Find the peripheral
        guard let peripheral = discoveredPeripherals.first(where: { $0.identifier == uuid }) else {
            completion(false, "Printer not found")
            return
        }
        
        self.connectionCompletion = completion
        manager.poSconnectDevice(peripheral)
    }
    
    private func connectWiFiPrinter(ipAddress: String, completion: @escaping (Bool, String?) -> Void) {
        let port: UInt16 = 9100 // Standard printer port
        
        let wifiManager = POSWIFIManager()
        wifiManager.delegate = self
        wifiManagers[ipAddress] = wifiManager
        
        self.connectionCompletion = completion
        
        wifiManager.posConnect(withHost: ipAddress, port: port) { [weak self] isConnected in
            completion(isConnected, isConnected ? nil : "Connection failed")
        }
    }
    
    @objc public func disconnectFromPrinter(identifier: String, completion: @escaping (Bool, String?) -> Void) {
        // Check if it's WiFi connection
        if let wifiManager = wifiManagers[identifier] {
            wifiManager.posDisConnect()
            wifiManagers.removeValue(forKey: identifier)
            completion(true, nil)
        } else {
            // Bluetooth disconnection
            bleManager?.poSdisconnectRootPeripheral()
            completion(true, nil)
        }
    }
    
    // MARK: - Printing Methods
    
    @objc public func printText(text: String, identifier: String, completion: @escaping (Bool, String?) -> Void) {
        guard let data = formatTextForPrinter(text: text) else {
            completion(false, "Failed to format text")
            return
        }
        
        sendDataToPrinter(data: data, identifier: identifier, completion: completion)
    }
    
    @objc public func printReceipt(template: [String: Any], identifier: String, completion: @escaping (Bool, String?) -> Void) {
        guard let data = formatReceiptForPrinter(template: template) else {
            completion(false, "Failed to format receipt")
            return
        }
        
        sendDataToPrinter(data: data, identifier: identifier, completion: completion)
    }
    
    private func sendDataToPrinter(data: Data, identifier: String, completion: @escaping (Bool, String?) -> Void) {
        // Check if WiFi connection
        if let wifiManager = wifiManagers[identifier] {
            self.printCompletion = completion
            wifiManager.posWriteCommand(with: data)
        } else {
            // Bluetooth connection
            self.printCompletion = completion
            bleManager?.posWriteCommand(with: data)
        }
    }
    
    // MARK: - Printer Status
    
    @objc public func getPrinterStatus(identifier: String, completion: @escaping (String, String, Bool, String?) -> Void) {
        // Send status request command
        let statusCommand = Data([0x10, 0x04, 0x01]) // DLE EOT n
        
        if let wifiManager = wifiManagers[identifier] {
            if wifiManager.isConnected {
                completion("ready", "ok", true, nil)
            } else {
                completion("offline", "unknown", false, nil)
            }
        } else if let bleManager = bleManager, bleManager.connectOK {
            completion("ready", "ok", true, nil)
        } else {
            completion("offline", "unknown", false, nil)
        }
    }
    
    // MARK: - Data Formatting
    
    private func formatTextForPrinter(text: String) -> Data? {
        var printData = Data()
        
        // Initialize printer (ESC @)
        printData.append(Data([0x1B, 0x40]))
        
        // Add text
        if let textData = text.data(using: .utf8) {
            printData.append(textData)
        }
        
        // Line feeds
        printData.append(Data([0x0A, 0x0A, 0x0A]))
        
        // Cut paper (GS V m)
        printData.append(Data([0x1D, 0x56, 0x41, 0x10]))
        
        return printData
    }
    
    private func formatReceiptForPrinter(template: [String: Any]) -> Data? {
        var printData = Data()
        
        // Initialize printer
        printData.append(Data([0x1B, 0x40]))
        
        // Center align (ESC a 1)
        printData.append(Data([0x1B, 0x61, 0x01]))
        
        // Header
        if let header = template["header"] as? String,
           let headerData = (header + "\n\n").data(using: .utf8) {
            printData.append(headerData)
        }
        
        // Left align (ESC a 0)
        printData.append(Data([0x1B, 0x61, 0x00]))
        
        // Items
        if let items = template["items"] as? [[String: Any]] {
            for item in items {
                if let name = item["name"] as? String,
                   let price = item["price"] as? String {
                    let line = String(format: "%@\t%@\n", name, price)
                    if let lineData = line.data(using: .utf8) {
                        printData.append(lineData)
                    }
                }
            }
        }
        
        // Total
        if let total = template["total"] as? String,
           let totalData = ("\nTotal: " + total + "\n").data(using: .utf8) {
            printData.append(totalData)
        }
        
        // Footer
        if let footer = template["footer"] as? String,
           let footerData = (footer + "\n").data(using: .utf8) {
            printData.append(footerData)
        }
        
        // Line feeds
        printData.append(Data([0x0A, 0x0A, 0x0A]))
        
        // Cut paper
        printData.append(Data([0x1D, 0x56, 0x41, 0x10]))
        
        return printData
    }
    
    // MARK: - Callback Storage
    
    private var discoveryCompletion: (([[String: Any]], String?) -> Void)?
    private var connectionCompletion: ((Bool, String?) -> Void)?
    private var printCompletion: ((Bool, String?) -> Void)?
}

// MARK: - POSBLEManagerDelegate

extension ZywellSDK: POSBLEManagerDelegate {
    
    public func poSdidUpdatePeripheralList(_ peripherals: [Any]!, rssiList: [Any]!) {
        guard let peripherals = peripherals as? [CBPeripheral],
              let rssis = rssiList as? [NSNumber] else { return }
        
        self.discoveredPeripherals = peripherals
        self.peripheralRSSIs = rssis
    }
    
    public func poSdidConnect(_ peripheral: CBPeripheral!) {
        connectionCompletion?(true, nil)
        connectionCompletion = nil
    }
    
    public func poSdidFail(toConnect peripheral: CBPeripheral!, error: Error!) {
        let errorMsg = error?.localizedDescription ?? "Connection failed"
        connectionCompletion?(false, errorMsg)
        connectionCompletion = nil
    }
    
    public func poSdidDisconnectPeripheral(_ peripheral: CBPeripheral!, isAutoDisconnect: Bool) {
        // Handle disconnection
    }
    
    public func poSdidWriteValue(for character: CBCharacteristic!, error: Error!) {
        if let error = error {
            printCompletion?(false, error.localizedDescription)
        } else {
            printCompletion?(true, nil)
        }
        printCompletion = nil
    }
}

// MARK: - POSWIFIManagerDelegate

extension ZywellSDK: POSWIFIManagerDelegate {
    
    public func poswifiManager(_ manager: POSWIFIManager!, didConnectedToHost host: String!, port: UInt16) {
        connectionCompletion?(true, nil)
        connectionCompletion = nil
    }
    
    public func poswifiManager(_ manager: POSWIFIManager, willDisconnectWithError error: Error?) {
        // Handle disconnection warning
    }
    
    public func poswifiManager(_ manager: POSWIFIManager!, didWriteDataWithTag tag: Int) {
        printCompletion?(true, nil)
        printCompletion = nil
    }
    
    public func poswifiManager(_ manager: POSWIFIManager, didRead data: Data, tag: Int) {
        // Handle data reading if needed
    }
    
    public func poswifiManagerDidDisconnected(_ manager: POSWIFIManager!) {
        // Handle disconnection
    }
}
