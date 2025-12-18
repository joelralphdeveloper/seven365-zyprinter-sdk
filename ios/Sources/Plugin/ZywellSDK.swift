//
//  ZywellSDK.swift
//  Seven365Zyprinter
//
//  Swift wrapper for the Zywell Objective-C SDK
//

import Foundation
import CoreBluetooth
import Network
import ExternalAccessory


@objc public class ZywellSDK: NSObject {
    
    // MARK: - Printer Configuration
    
    /// Default printer width in characters (for 80mm thermal paper)
    /// Common widths: 32 chars (58mm paper), 48 chars (80mm paper)
    private let printerWidth: Int = 48
    
    /// Default separator character (can be overridden per-template)
    private let defaultSeparatorChar: String = "-"
    
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
    
    @objc public func discoverUSBPrinters(completion: @escaping ([[String: Any]], String?) -> Void) {
        // Query External Accessory framework for connected accessories
        let accessoryManager = EAAccessoryManager.shared()
        let connectedAccessories = accessoryManager.connectedAccessories
        
        var usbPrinters: [[String: Any]] = []
        
        // Filter for printer accessories
        // Note: This requires the app to declare supported accessory protocols in Info.plist
        // under the key "UISupportedExternalAccessoryProtocols"
        for accessory in connectedAccessories {
            // Check if the accessory might be a printer
            // Common printer protocol strings include manufacturer-specific identifiers
            let isPotentialPrinter = accessory.protocolStrings.contains { protocolString in
                protocolString.lowercased().contains("printer") ||
                protocolString.lowercased().contains("print") ||
                protocolString.lowercased().contains("pos")
            }
            
            if isPotentialPrinter || !accessory.protocolStrings.isEmpty {
                usbPrinters.append([
                    "identifier": String(accessory.connectionID),
                    "model": "\(accessory.manufacturer) \(accessory.name)",
                    "status": accessory.isConnected ? "ready" : "offline",
                    "connectionType": "usb",
                    "manufacturer": accessory.manufacturer,
                    "modelNumber": accessory.modelNumber,
                    "serialNumber": accessory.serialNumber,
                    "firmwareRevision": accessory.firmwareRevision,
                    "hardwareRevision": accessory.hardwareRevision,
                    "protocols": accessory.protocolStrings
                ])
            }
        }
        
        // Log information about USB discovery
        if usbPrinters.isEmpty {
            print("ZywellSDK: No USB accessories found. Note: iOS requires MFi-certified accessories with declared protocol strings in Info.plist")
        } else {
            print("ZywellSDK: Found \(usbPrinters.count) potential USB printer(s)")
        }
        
        completion(usbPrinters, nil)
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
    
    // MARK: - Test Print Method (Isolated from Production)
    
    /**
     * Dedicated test print method - isolates test functionality from production code
     * This method wraps printReceipt with additional logging and test-specific handling
     * Use this for test prints to avoid affecting production printer setup
     */
    @objc public func printTestReceipt(template: [String: Any], identifier: String, completion: @escaping (Bool, String?) -> Void) {
        print("ZywellSDK [TEST]: Test print request received")
        print("ZywellSDK [TEST]: Template: \(template)")
        print("ZywellSDK [TEST]: Printer ID: \(identifier)")
        
        guard let data = formatReceiptForPrinter(template: template) else {
            print("ZywellSDK [TEST]: Failed to format test receipt")
            completion(false, "Failed to format test receipt")
            return
        }
        
        print("ZywellSDK [TEST]: Sending test print data to printer...")
        sendDataToPrinter(data: data, identifier: identifier) { success, error in
            if success {
                print("ZywellSDK [TEST]: ✅ Test print completed successfully")
            } else {
                print("ZywellSDK [TEST]: ❌ Test print failed: \(error ?? "unknown error")")
            }
            completion(success, error)
        }
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
        
        // Get separator character from template (dynamic) or use default
        let separatorChar = getString(template["separator"]) ?? defaultSeparatorChar
        
        // Initialize printer
        printData.append(Data([0x1B, 0x40]))
        
        // Center align (ESC a 1)
        printData.append(Data([0x1B, 0x61, 0x01]))
        
        // ========== HEADER SECTION (NEW STRUCTURE) ==========
        if let header = template["header"] as? [String: Any] {
            // Get header formatting
            var sizeCode: UInt8 = 0x00
            var headerBold = false
            
            if let size = header["size"] {
                sizeCode = mapHeaderSizeToCode(size)
            }
            if let bold = header["bold"] as? Bool {
                headerBold = bold
            }
            
            // Apply bold if needed
            if headerBold {
                printData.append(Data([0x1B, 0x45, 0x01])) // Bold on
            }
            
            // Set font size
            if sizeCode != 0x00 {
                printData.append(Data([0x1D, 0x21, sizeCode]))
            }
            
            // Restaurant name
            if let restaurantName = getString(header["restaurant_name"]),
               let nameData = (restaurantName + "\n").data(using: .utf8) {
                printData.append(nameData)
            }
            
            // Sub header
            if let subHeader = getString(header["sub_header"]),
               !subHeader.isEmpty,
               let subData = (subHeader + "\n").data(using: .utf8) {
                printData.append(subData)
            }
            
            // GST number
            if let gstNumber = getString(header["gst_number"]),
               !gstNumber.isEmpty,
               let gstData = ("GST number: \(gstNumber)\n").data(using: .utf8) {
                printData.append(gstData)
            }
            
            // Reset header formatting
            if sizeCode != 0x00 {
                printData.append(Data([0x1D, 0x21, 0x00])) // Normal size
            }
            if headerBold {
                printData.append(Data([0x1B, 0x45, 0x00])) // Bold off
            }
        }
        
        // Left align for separator (ESC a 0)
        printData.append(Data([0x1B, 0x61, 0x00]))
        
        // Separator (normal font size)
        if let separatorData = generateSeparator(withChar: separatorChar).data(using: .utf8) {
            printData.append(separatorData)
        }
        
        // ========== ORDER INFO SECTION ==========
        // Center align for order info (ESC a 1)
        printData.append(Data([0x1B, 0x61, 0x01]))
        
        // Template type (e.g., "Kitchen Tickets") - customizable formatting
        if let orderType = getString(template["order_type"]) {
            // Get order_type formatting from order_type_config object
            var orderTypeSizeCode: UInt8 = 0x00  // Default to normal size
            var orderTypeBold = false  // Default to not bold
            
            if let orderTypeConfig = template["order_type_config"] as? [String: Any] {
                if let size = orderTypeConfig["size"] {
                    orderTypeSizeCode = mapHeaderSizeToCode(size)
                }
                if let bold = orderTypeConfig["bold"] as? Bool {
                    orderTypeBold = bold
                }
            }
            
            // Apply order_type formatting
            if orderTypeBold {
                printData.append(Data([0x1B, 0x45, 0x01]))  // Bold on
            }
            if orderTypeSizeCode != 0x00 {
                printData.append(Data([0x1D, 0x21, orderTypeSizeCode]))  // Set size
            }
            
            // Print order type
            if let orderTypeData = (orderType + "\n").data(using: .utf8) {
                printData.append(orderTypeData)
            }
            
            // Reset order_type formatting
            if orderTypeSizeCode != 0x00 {
                printData.append(Data([0x1D, 0x21, 0x00]))  // Normal size
            }
            if orderTypeBold {
                printData.append(Data([0x1B, 0x45, 0x00]))  // Bold off
            }
        }
        
        // Table and order number - Read formatting from order_info or use defaults
        var orderInfoSizeCode: UInt8 = 0x11  // Default to 2x (large)
        var orderInfoBold = true  // Default to bold
        
        if let orderInfo = template["order_info"] as? [String: Any] {
            if let size = orderInfo["size"] {
                orderInfoSizeCode = mapHeaderSizeToCode(size)
            }
            if let bold = orderInfo["bold"] as? Bool {
                orderInfoBold = bold
            }
        }
        
        // Apply order info formatting
        if orderInfoBold {
            printData.append(Data([0x1B, 0x45, 0x01]))  // Bold on
        }
        if orderInfoSizeCode != 0x00 {
            printData.append(Data([0x1D, 0x21, orderInfoSizeCode]))  // Set size from config
        }
        
        var orderInfoLine = ""
        if let tableName = getString(template["table_name"]) {
            orderInfoLine += tableName
        }
        if let orderNumber = getString(template["order_number"]) {
            if !orderInfoLine.isEmpty {
                orderInfoLine += " | "
            }
            orderInfoLine += orderNumber
        }
        if !orderInfoLine.isEmpty,
           let orderInfoData = (orderInfoLine + "\n").data(using: .utf8) {
            printData.append(orderInfoData)
        }
        
        // Reset formatting back to normal
        if orderInfoSizeCode != 0x00 {
            printData.append(Data([0x1D, 0x21, 0x00]))  // Normal size
        }
        if orderInfoBold {
            printData.append(Data([0x1B, 0x45, 0x00]))  // Bold off
        }
        
        // Left align for items section (ESC a 0)
        printData.append(Data([0x1B, 0x61, 0x00]))
        
        // Separator for items section (normal font size)
        if let separatorData = generateSeparator(withChar: separatorChar).data(using: .utf8) {
            printData.append(separatorData)
        }
        
        // ========== ITEMS SECTION (NEW STRUCTURE) ==========
        if let kitchen = template["kitchen"] as? [[String: Any]] {
            // Get item formatting from item object
            var itemSizeCode: UInt8 = 0x11  // Default to 2x (large) for better readability
            var itemBold = false
            
            if let item = template["item"] as? [String: Any] {
                if let size = item["size"] {
                    itemSizeCode = mapHeaderSizeToCode(size)
                }
                if let bold = item["bold"] as? Bool {
                    itemBold = bold
                }
            }
            
            // Apply item formatting
            if itemBold {
                printData.append(Data([0x1B, 0x45, 0x01])) // Bold on
            }
            // Always send size command to ensure items are at configured size
            printData.append(Data([0x1D, 0x21, itemSizeCode])) // Set size (even if 0x00 for normal)
            
            // Get modifier formatting from modifier object
            var modifierStyle = "bullet"  // default
            var modifierSizeCode: UInt8 = 0x00
            var modifierIndent = "  "  // default: medium
            var modifierBold = false  // NEW: bold support for modifiers
            
            if let modifier = template["modifier"] as? [String: Any] {
                if let style = getString(modifier["style"]) {
                    modifierStyle = style
                }
                if let size = modifier["size"] {
                    modifierSizeCode = mapHeaderSizeToCode(size)
                }
                if let indent = getString(modifier["indent"]) {
                    switch indent.lowercased() {
                    case "small": modifierIndent = " "
                    case "medium": modifierIndent = "  "
                    case "large": modifierIndent = "    "
                    default: modifierIndent = "  "
                    }
                }
                if let bold = modifier["bold"] as? Bool {
                    modifierBold = bold
                }
            }
            
            for item in kitchen {
                var itemName = ""
                var quantity = "1"
                
                // Get item name
                if let name = getString(item["name"]) {
                    itemName = name
                } else if let menu = item["menu"] as? [String: Any],
                   let name = getString(menu["name"]) {
                    itemName = name
                }
                
                // Get quantity
                if let qty = item["qty"] {
                    quantity = "x\(getString(qty) ?? "1")"
                } else if let qty = item["quantity"] {
                    quantity = "x\(getString(qty) ?? "1")"
                }
                
                // Print main item line
                let line = String(format: "%@ %@\n", itemName, quantity)
                if let lineData = line.data(using: .utf8) {
                    printData.append(lineData)
                }
                
                // Print modifiers
                if let modifiers = item["modifiers"] as? [[String: Any]] {
                    // Apply modifier formatting (size and bold)
                    if modifierSizeCode != 0x00 {
                        printData.append(Data([0x1D, 0x21, modifierSizeCode]))
                    }
                    if modifierBold {
                        printData.append(Data([0x1B, 0x45, 0x01])) // Bold on
                    }
                    
                    for mod in modifiers {
                        if let modName = getString(mod["name"]) {
                            var prefix = ""
                            
                            // Determine prefix based on style
                            // Note: Using ASCII-compatible characters only
                            // Unicode characters like • and → display as garbled text on thermal printers
                            switch modifierStyle.lowercased() {
                            case "dash":
                                prefix = "-"
                            case "bullet":
                                prefix = "*"  // ASCII asterisk instead of Unicode bullet
                            case "arrow":
                                prefix = ">"  // ASCII greater-than instead of Unicode arrow
                            default:
                                prefix = "-"  // Default to dash for best compatibility
                            }
                            
                            // Build modifier line
                            let modLine = "\(modifierIndent)\(prefix) \(modName)\n"
                            
                            if let modData = modLine.data(using: .utf8) {
                                printData.append(modData)
                            }
                        }
                    }
                    
                    // Reset modifier formatting (size and bold)
                    if modifierBold {
                        printData.append(Data([0x1B, 0x45, 0x00])) // Bold off
                    }
                    if modifierSizeCode != 0x00 {
                        printData.append(Data([0x1D, 0x21, itemSizeCode])) // Reset to item size, not 0x00
                    }
                }
            }
            
            // Reset item formatting
            printData.append(Data([0x1D, 0x21, 0x00])) // Always reset to normal size
            if itemBold {
                printData.append(Data([0x1B, 0x45, 0x00])) // Bold off
            }
            
        }
        
        // ========== TOTAL SECTION ==========
        // Separator before total (normal font size)
        if let separatorData = generateSeparator(withChar: separatorChar).data(using: .utf8) {
            printData.append(separatorData)
        }
        
        // Subtotal, Discount, GST
        if let subtotal = getString(template["subtotal"]) {
            if let data = ("SUBTOTAL\t\t\t$\(subtotal)\n").data(using: .utf8) {
                printData.append(data)
            }
        }
        
        if let discount = getString(template["discount"]) {
            if let discountDouble = Double(discount), discountDouble > 0 {
                if let data = ("SAFRA Members\t\t\t-$\(discount)\n").data(using: .utf8) {
                    printData.append(data)
                }
            }
        }
        
        if let gst = getString(template["gst"]) {
            if let data = ("9% (Incl.) GST\t\t\t$\(gst)\n").data(using: .utf8) {
                printData.append(data)
            }
        }
        
        // ========== TOTAL SECTION (NEW STRUCTURE) ==========
        if let total = getString(template["total"]) {
            // Separator (may need to account for total font size)
            if let separatorData = generateSeparator(withChar: separatorChar).data(using: .utf8) {
                printData.append(separatorData)
            }
            
            // Get total formatting from total_config object
            var totalSizeCode: UInt8 = 0x00
            var totalBold = false
            
            if let totalConfig = template["total_config"] as? [String: Any] {
                if let size = totalConfig["size"] {
                    totalSizeCode = mapHeaderSizeToCode(size)
                }
                if let bold = totalConfig["bold"] as? Bool {
                    totalBold = bold
                }
            }
            
            // Apply total formatting
            if totalBold {
                printData.append(Data([0x1B, 0x45, 0x01])) // Bold on
            }
            if totalSizeCode != 0x00 {
                printData.append(Data([0x1D, 0x21, totalSizeCode])) // Set size
            }
            
            if let totalData = ("TOTAL\t\t\t$\(total)\n").data(using: .utf8) {
                printData.append(totalData)
            }
            
            // Reset total formatting
            if totalSizeCode != 0x00 {
                printData.append(Data([0x1D, 0x21, 0x00])) // Normal size
            }
            if totalBold {
                printData.append(Data([0x1B, 0x45, 0x00])) // Bold off
            }
        }
        
        // Payment method (with separator only if payment method exists)
        if let paymentMethod = getString(template["paymentMethod"]) {
            // Separator before payment
            if let separatorData = generateSeparator(withChar: separatorChar).data(using: .utf8) {
                printData.append(separatorData)
            }
            
            if let paymentData = ("PAYMENT BY:\(paymentMethod)\t\(getString(template["total"]) ?? "")\n").data(using: .utf8) {
                printData.append(paymentData)
            }
        }
        
        // Single separator before footer
        if let separatorData = generateSeparator(withChar: separatorChar).data(using: .utf8) {
            printData.append(separatorData)
        }
        
        
        // ========== FOOTER SECTION (NEW STRUCTURE) ==========
        // Center align for footer
        printData.append(Data([0x1B, 0x61, 0x01]))
        
        if let footer = template["footer"] as? [String: Any] {
            // Get footer formatting
            var footerSizeCode: UInt8 = 0x00
            var footerBold = false
            
            if let size = footer["size"] {
                footerSizeCode = mapHeaderSizeToCode(size)
            }
            if let bold = footer["bold"] as? Bool {
                footerBold = bold
            }
            
            // Apply footer formatting
            if footerBold {
                printData.append(Data([0x1B, 0x45, 0x01])) // Bold on
            }
            if footerSizeCode != 0x00 {
                printData.append(Data([0x1D, 0x21, footerSizeCode])) // Set size
            }
            
            // Footer message
            if let message = getString(footer["message"]),
               !message.isEmpty,
               let messageData = (message + "\n").data(using: .utf8) {
                printData.append(messageData)
            }
            
            // Reset footer formatting before timestamp
            if footerSizeCode != 0x00 {
                printData.append(Data([0x1D, 0x21, 0x00])) // Normal size
            }
            if footerBold {
                printData.append(Data([0x1B, 0x45, 0x00])) // Bold off
            }
            
            // Print timestamp
            let dateFormat = getString(footer["date_format"]) ?? "YYYY-MM-DD"
            let timeFormat = getString(footer["time_format"]) ?? "24H"
            let timestamp = formatTimestamp(dateFormat: dateFormat, timeFormat: timeFormat)
            if let timestampData = (timestamp + "\n").data(using: .utf8) {
                printData.append(timestampData)
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
        var resultCode: UInt8 = 0x00
        
        if let sizeInt = size as? Int {
            switch sizeInt {
            case 1: resultCode = 0x00
            case 2: resultCode = 0x11
            case 3: resultCode = 0x22
            case 4: resultCode = 0x33
            default: resultCode = 0x00
            }
            print("ZywellSDK: Mapped size Int(\(sizeInt)) → 0x\(String(format: "%02X", resultCode))")
        } else if let sizeStr = size as? String {
            switch sizeStr.lowercased() {
            case "normal", "1": resultCode = 0x00
            case "large", "2": resultCode = 0x11
            case "xlarge", "3": resultCode = 0x22
            case "4": resultCode = 0x33
            default: resultCode = 0x00
            }
            print("ZywellSDK: Mapped size String(\"\(sizeStr)\") → 0x\(String(format: "%02X", resultCode))")
        } else if let sizeNum = size as? NSNumber {
             switch sizeNum.intValue {
             case 1: resultCode = 0x00
             case 2: resultCode = 0x11
             case 3: resultCode = 0x22
             case 4: resultCode = 0x33
             default: resultCode = 0x00
             }
             print("ZywellSDK: Mapped size NSNumber(\(sizeNum.intValue)) → 0x\(String(format: "%02X", resultCode))")
        } else {
            print("ZywellSDK: Unknown size type: \(type(of: size)), defaulting to 0x00")
        }
        
        return resultCode
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
    
    /**
     * Formats the current timestamp based on date and time format preferences
     * - Parameters:
     *   - dateFormat: Format string like "YYYY-MM-DD", "DD-MM-YYYY", "MM-DD-YYYY"
     *   - timeFormat: "12H" or "24H"
     * - Returns: Formatted timestamp string
     */
    private func formatTimestamp(dateFormat: String, timeFormat: String) -> String {
        let now = Date()
        let calendar = Calendar.current
        
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        let day = calendar.component(.day, from: now)
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let second = calendar.component(.second, from: now)
        
        // Format date
        var formattedDate: String
        switch dateFormat {
        case "DD-MM-YYYY", "DD/MM/YYYY":
            formattedDate = String(format: "%02d-%02d-%04d", day, month, year)
        case "MM-DD-YYYY", "MM/DD/YYYY":
            formattedDate = String(format: "%02d-%02d-%04d", month, day, year)
        default: // "YYYY-MM-DD"
            formattedDate = String(format: "%04d-%02d-%02d", year, month, day)
        }
        
        // Format time
        var formattedTime: String
        if timeFormat == "12H" {
            let hour12 = hour % 12 == 0 ? 12 : hour % 12
            let ampm = hour >= 12 ? "PM" : "AM"
            formattedTime = String(format: "%d:%02d:%02d %@", hour12, minute, second, ampm)
        } else { // 24H
            formattedTime = String(format: "%02d:%02d:%02d", hour, minute, second)
        }
        
        return "\(formattedDate) \(formattedTime)"
    }
    
    /**
     * Generates a separator line based on current printer width and font magnification
     * - Parameter sizeCode: The current font size code (0x00, 0x11, 0x22, 0x33)
     * - Returns: A separator string with appropriate width
     *
     * Font magnification affects character width:
     * - 0x00 (normal): 1x width
     * - 0x11 (2x2): 2x width (half as many characters fit)
     * - 0x22 (3x3): 3x width (one-third as many characters fit)
     * - 0x33 (4x4): 4x width (one-quarter as many characters fit)
     */
    private func generateSeparator(forSizeCode sizeCode: UInt8 = 0x00, withChar separatorChar: String? = nil) -> String {
        // Calculate width divisor based on font magnification
        let widthMultiplier: Int
        switch sizeCode {
        case 0x11: widthMultiplier = 2  // 2x width
        case 0x22: widthMultiplier = 3  // 3x width
        case 0x33: widthMultiplier = 4  // 4x width
        default: widthMultiplier = 1     // Normal width
        }
        
        // Calculate actual character count that fits on the line
        let effectiveWidth = printerWidth / widthMultiplier
        
        // Use provided separator character or fall back to default
        let charToUse = separatorChar ?? defaultSeparatorChar
        
        // Generate separator string
        return String(repeating: charToUse, count: effectiveWidth) + "\n"
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
