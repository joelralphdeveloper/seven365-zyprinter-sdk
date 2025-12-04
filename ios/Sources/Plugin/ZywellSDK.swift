//
//  ZywellSDK.swift
//  Seven365Zyprinter
//
//  Swift wrapper for the Zywell Objective-C SDK
//

import Foundation
import CoreBluetooth
import Network


@objc public class ZywellSDK: NSObject {
    
    private var bleManager: POSBLEManager?
    private var wifiManagers: [String: POSWIFIManager] = [:]
    private var discoveredPeripherals: [CBPeripheral] = []
    private var peripheralRSSIs: [NSNumber] = []
    
    public override init() {
        super.init()
    }
    
    deinit {
        bleManager?.delegate = nil
        for (_, manager) in wifiManagers {
            manager.delegate = nil
        }
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
        
        // Bluetooth discovery disabled
        // group.enter()
        // discoverBluetoothPrinters { btPrinters, error in
        //     if error == nil {
        //         allPrinters.append(contentsOf: btPrinters)
        //     }
        //     group.leave()
        // }
        
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
        // Bluetooth discovery disabled
        completion([], nil)
    }
    
    @objc public func discoverWiFiPrinters(networkRange: String?, completion: @escaping ([[String: Any]], String?) -> Void) {
        guard let ipAddress = getWiFiAddress() else {
            completion([], "Could not determine device IP address")
            return
        }
        
        let prefix = ipAddress.components(separatedBy: ".").dropLast().joined(separator: ".") + "."
        scanSubnet(prefix: prefix, completion: completion)
    }
    
    private func scanSubnet(prefix: String, completion: @escaping ([[String: Any]], String?) -> Void) {
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "com.seven365.printer.scan", attributes: .concurrent)
        var foundPrinters: [[String: Any]] = []
        let lock = NSLock()
        
        // Scan range 1-254
        for i in 1...254 {
            let host = "\(prefix)\(i)"
            group.enter()
            
            queue.async {
                self.checkPort(host: host, port: 9100, timeout: 0.5) { isOpen in
                    if isOpen {
                        lock.lock()
                        foundPrinters.append([
                            "identifier": host,
                            "model": "WiFi Printer (\(host))",
                            "status": "ready",
                            "connectionType": "wifi",
                            "ip": host
                        ])
                        lock.unlock()
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            completion(foundPrinters, nil)
        }
    }
    
    private func checkPort(host: String, port: UInt16, timeout: TimeInterval, completion: @escaping (Bool) -> Void) {
        let hostEndpoint = NWEndpoint.Host(host)
        let portEndpoint = NWEndpoint.Port(integerLiteral: port)
        
        let connection = NWConnection(host: hostEndpoint, port: portEndpoint, using: .tcp)
        
        var hasCompleted = false
        
        connection.stateUpdateHandler = { state in
            if hasCompleted { return }
            
            switch state {
            case .ready:
                hasCompleted = true
                connection.cancel()
                completion(true)
            case .failed(_), .cancelled:
                hasCompleted = true
                connection.cancel()
                completion(false)
            default:
                break
            }
        }
        
        connection.start(queue: .global())
        
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
            if !hasCompleted {
                hasCompleted = true
                connection.cancel()
                completion(false)
            }
        }
    }
    
    // Helper to get IP address
    private func getWiFiAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                guard let interface = ptr?.pointee else { continue }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                
                if addrFamily == UInt8(AF_INET) { // IPv4 only
                    let name = String(cString: interface.ifa_name)
                    if name == "en0" { // WiFi interface
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                    &hostname, socklen_t(hostname.count),
                                    nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address
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
            DispatchQueue.main.async {
                completion(isConnected, isConnected ? nil : "Connection failed")
            }
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
        print("ZywellSDK: Received template: \(template)")
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
        if let header = getString(template["header"]),
           let headerData = (header + "\n\n").data(using: .utf8) {
            
            // Get header size from formatting options
            var sizeCode: UInt8 = 0x00 // Default: normal
            if let formatting = template["formatting"] as? [String: Any],
               let headerSize = formatting["headerSize"] {
                sizeCode = mapHeaderSizeToCode(headerSize)
            }
            print("ZywellSDK: Header size code: \(sizeCode)")
            
            // Set font size (GS ! n)
            printData.append(Data([0x1D, 0x21, sizeCode]))
            
            printData.append(headerData)
            
            // Reset to normal size (GS ! 0)
            printData.append(Data([0x1D, 0x21, 0x00]))
        }
        
        // Left align (ESC a 0)
        printData.append(Data([0x1B, 0x61, 0x00]))
        
        // Items
        if let kitchen = template["kitchen"] as? [[String: Any]] {
            // Get item formatting
            var itemSizeCode: UInt8 = 0x00
            var itemBold = false
            if let formatting = template["formatting"] as? [String: Any] {
                if let itemSize = formatting["itemSize"] {
                    itemSizeCode = mapHeaderSizeToCode(itemSize)
                }
                itemBold = getBool(formatting["itemBold"])
            }
            
            // Apply item formatting
            if itemBold {
                printData.append(Data([0x1B, 0x45, 0x01])) // Bold on
            }
            if itemSizeCode != 0x00 {
                printData.append(Data([0x1D, 0x21, itemSizeCode])) // Set size
            }
            
            for item in kitchen {
                var itemName = ""
                var itemPrice = ""
                
                // Get name from menu object
                if let menu = item["menu"] as? [String: Any],
                   let name = getString(menu["name"]) {
                    itemName = name
                }
                
                // Add quantity
                if let qty = item["quantity"] {
                    itemName += " x\(getString(qty) ?? "1")"
                }
                
                // Format price
                if let price = item["total_price"] {
                    if let priceDouble = Double(getString(price) ?? "0") {
                        itemPrice = String(format: "$%.2f", priceDouble)
                    } else {
                        itemPrice = "$" + (getString(price) ?? "0.00")
                    }
                }
                
                // Print main item
                let line = String(format: "%@\t%@\n", itemName, itemPrice)
                if let lineData = line.data(using: .utf8) {
                    printData.append(lineData)
                }
                
                // Print modifiers
                if let modifiers = item["modifiers"] as? [[String: Any]] {
                    for mod in modifiers {
                        if let modName = getString(mod["name"]) {
                            var modLine = "  + \(modName)"
                            
                            // Only show price if > 0
                            if let modPrice = mod["price"],
                               let priceDouble = Double(getString(modPrice) ?? "0"),
                               priceDouble > 0 {
                                modLine += String(format: "\t$%.2f", priceDouble)
                            }
                            modLine += "\n"
                            
                            if let modData = modLine.data(using: .utf8) {
                                printData.append(modData)
                            }
                        }
                    }
                }
            }
            
            // Reset item formatting
            if itemSizeCode != 0x00 {
                printData.append(Data([0x1D, 0x21, 0x00])) // Normal size
            }
            if itemBold {
                printData.append(Data([0x1B, 0x45, 0x00])) // Bold off
            }
            
        } else if let items = template["items"] as? [[String: Any]] {
            // Get item formatting
            var itemSizeCode: UInt8 = 0x00
            var itemBold = false
            if let formatting = template["formatting"] as? [String: Any] {
                if let itemSize = formatting["itemSize"] {
                    itemSizeCode = mapHeaderSizeToCode(itemSize)
                }
                itemBold = getBool(formatting["itemBold"])
            }
            print("ZywellSDK: Item bold: \(itemBold)")
            
            // Apply item formatting
            if itemBold {
                printData.append(Data([0x1B, 0x45, 0x01])) // Bold on (ESC E 1)
            }
            if itemSizeCode != 0x00 {
                printData.append(Data([0x1D, 0x21, itemSizeCode])) // Set size
            }
            
            for item in items {
                if let name = getString(item["name"]),
                   let price = getString(item["price"]) {
                    let line = String(format: "%@\t%@\n", name, price)
                    if let lineData = line.data(using: .utf8) {
                        printData.append(lineData)
                    }
                }
            }
            
            // Reset item formatting
            if itemSizeCode != 0x00 {
                printData.append(Data([0x1D, 0x21, 0x00])) // Normal size
            }
            if itemBold {
                printData.append(Data([0x1B, 0x45, 0x00])) // Bold off (ESC E 0)
            }
        }
        
        // Total
        if let total = getString(template["total"]),
           let totalData = ("\nTotal: " + total + "\n").data(using: .utf8) {
            // Get total formatting
            var totalSizeCode: UInt8 = 0x00
            var totalBold = false
            if let formatting = template["formatting"] as? [String: Any] {
                if let totalSize = formatting["totalSize"] {
                    totalSizeCode = mapHeaderSizeToCode(totalSize)
                }
                totalBold = getBool(formatting["totalBold"])
            }
            print("ZywellSDK: Total size code: \(totalSizeCode)")
            print("ZywellSDK: Total bold: \(totalBold)")
            
            // Apply total formatting
            if totalBold {
                printData.append(Data([0x1B, 0x45, 0x01])) // Bold on
            }
            if totalSizeCode != 0x00 {
                printData.append(Data([0x1D, 0x21, totalSizeCode])) // Set size
            }
            
            printData.append(totalData)
            
            // Reset total formatting
            if totalSizeCode != 0x00 {
                printData.append(Data([0x1D, 0x21, 0x00])) // Normal size
            }
            if totalBold {
                printData.append(Data([0x1B, 0x45, 0x00])) // Bold off
            }
        }
        
        // Footer
        if let footer = getString(template["footer"]),
           let footerData = (footer + "\n").data(using: .utf8) {
            // Get footer formatting
            var footerSizeCode: UInt8 = 0x00
            if let formatting = template["formatting"] as? [String: Any],
               let footerSize = formatting["footerSize"] {
                footerSizeCode = mapHeaderSizeToCode(footerSize)
            }
            
            // Apply footer formatting
            if footerSizeCode != 0x00 {
                printData.append(Data([0x1D, 0x21, footerSizeCode])) // Set size
            }
            
            printData.append(footerData)
            
            // Reset footer formatting
            if footerSizeCode != 0x00 {
                printData.append(Data([0x1D, 0x21, 0x00])) // Normal size
            }
        }
        
        // Line feeds
        printData.append(Data([0x0A, 0x0A, 0x0A]))
        
        // Cut paper
        printData.append(Data([0x1D, 0x56, 0x41, 0x10]))
        
        return printData
    }
    
    // MARK: - Helper Functions
    
    private func mapHeaderSizeToCode(_ size: Any) -> UInt8 {
        if let sizeInt = size as? Int {
            switch sizeInt {
            case 1: return 0x00
            case 2: return 0x11
            case 3: return 0x22
            case 4: return 0x33
            default: return 0x00
            }
        } else if let sizeStr = size as? String {
            switch sizeStr.lowercased() {
            case "normal", "1": return 0x00
            case "large", "2": return 0x11
            case "xlarge", "3": return 0x22
            case "4": return 0x33
            default: return 0x00
            }
        } else if let sizeNum = size as? NSNumber {
             switch sizeNum.intValue {
             case 1: return 0x00
             case 2: return 0x11
             case 3: return 0x22
             case 4: return 0x33
             default: return 0x00
             }
        }
        return 0x00
    }
    
    private func getBool(_ value: Any?) -> Bool {
        guard let value = value else { return false }
        if let boolVal = value as? Bool { return boolVal }
        if let strVal = value as? String {
            return ["true", "yes", "1"].contains(strVal.lowercased())
        }
        if let numVal = value as? NSNumber {
            return numVal.boolValue
        }
        return false
    }

    private func getString(_ value: Any?) -> String? {
        guard let value = value else { return nil }
        if let strVal = value as? String { return strVal }
        if let numVal = value as? NSNumber { return numVal.stringValue }
        return String(describing: value)
    }
    
    // MARK: - Callback Storage
    
    private var discoveryCompletion: (([[String: Any]], String?) -> Void)?
    private var connectionCompletion: ((Bool, String?) -> Void)?
    private var printCompletion: ((Bool, String?) -> Void)?
}

// MARK: - POSBLEManagerDelegate
extension ZywellSDK: POSBLEManagerDelegate {
    
    // Method 1: Already had

    @objc public func poSdidUpdatePeripheralList(_ peripherals: [Any]?, rssiList: [Any]?) {
        guard let peripherals = peripherals as? [CBPeripheral],
              let rssis = rssiList as? [NSNumber] else { return }
        
        self.discoveredPeripherals = peripherals
        self.peripheralRSSIs = rssis
    }
    
    
    // Method 2: Already had
     @objc public func poSdidConnect(_ peripheral: CBPeripheral?) {
        guard let peripheral = peripheral else { return }
        DispatchQueue.main.async { [weak self] in
            self?.connectionCompletion?(true, nil)
            self?.connectionCompletion = nil
        }
    }
    
    // Method 3: Already had
    @objc public func poSdidFail(toConnect peripheral: CBPeripheral?, error: Error?) {
        let errorMsg = error?.localizedDescription ?? "Connection failed"
        DispatchQueue.main.async { [weak self] in
            self?.connectionCompletion?(false, errorMsg)
            self?.connectionCompletion = nil
        }
    }
    
    // Method 4: Already had
    @objc public func poSdidDisconnectPeripheral(_ peripheral: CBPeripheral?, isAutoDisconnect: Bool) {
        // Handle disconnection
        if let peripheral = peripheral {
            print("Disconnected from: \(peripheral.name ?? "Unknown")")
        }
    }
    
    // Method 5: Fixed based on error
    @objc public func poSdidWriteValue(for character: CBCharacteristic?, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            if let error = error {
                self?.printCompletion?(false, error.localizedDescription)
            } else {
                self?.printCompletion?(true, nil)
            }
            self?.printCompletion = nil
        }
    }
    
    // ADD THESE COMMONLY REQUIRED METHODS:
    
    // Method 6: Bluetooth state updates - VERY COMMONLY REQUIRED
    @objc public func poScentralManagerDidUpdateState(_ central: Any?) {
        if let central = central as? CBCentralManager {
            print("Bluetooth state: \(central.state.rawValue)")
        }
    }
    
    // Method 7: Did discover services
    @objc public func poSdidDiscoverServices(_ peripheral: CBPeripheral!) {
        // Handle service discovery
    }
    
    // Method 8: Did discover characteristics
    @objc public func poSdidDiscoverCharacteristics(for service: CBService!, error: Error!) {
        // Handle characteristic discovery
    }
    
    // Method 9: Did update value for characteristic
    @objc public func poSdidUpdateValue(for characteristic: CBCharacteristic!, error: Error!) {
        // Handle updated values
    }
    
    // Method 10: Did update notification state
    @objc public func poSdidUpdateNotificationState(for characteristic: CBCharacteristic!, error: Error!) {
        // Handle notification state changes
    }
}

// MARK: - POSWIFIManagerDelegate

extension ZywellSDK: POSWIFIManagerDelegate {
    
    @objc(POSWIFIManager:didConnectedToHost:port:)
    public func poswifiManager(_ manager: POSWIFIManager!, didConnectedToHost host: String!, port: UInt16) {
        DispatchQueue.main.async { [weak self] in
            self?.connectionCompletion?(true, nil)
            self?.connectionCompletion = nil
        }
    }
    
    @objc(POSWIFIManager:willDisconnectWithError:)
    public func poswifiManager(_ manager: POSWIFIManager, willDisconnectWithError error: Error?) {
        // Handle disconnection warning
    }
    
    @objc(POSWIFIManager:didWriteDataWithTag:)
    public func poswifiManager(_ manager: POSWIFIManager!, didWriteDataWithTag tag: Int) {
        DispatchQueue.main.async { [weak self] in
            self?.printCompletion?(true, nil)
            self?.printCompletion = nil
        }
    }
    
    @objc(POSWIFIManager:didReadData:tag:)
    public func poswifiManager(_ manager: POSWIFIManager, didRead data: Data, tag: Int) {
        // Handle data reading if needed
    }
    
    @objc(POSWIFIManagerDidDisconnected:)
    public func poswifiManagerDidDisconnected(_ manager: POSWIFIManager!) {
        // Handle disconnection
    }
}
