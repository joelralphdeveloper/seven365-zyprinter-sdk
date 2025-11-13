import Foundation
import Network
import ExternalAccessory

// MARK: - Printer Models
public struct ZyPrinter {
    public let identifier: String
    public let model: String
    public let status: String
    public let connectionType: ZyConnectionType
    public let ipAddress: String?
    public let port: Int?
    
    public init(identifier: String, model: String, status: String, connectionType: ZyConnectionType, ipAddress: String? = nil, port: Int? = nil) {
        self.identifier = identifier
        self.model = model
        self.status = status
        self.connectionType = connectionType
        self.ipAddress = ipAddress
        self.port = port
    }
}

public enum ZyConnectionType: String, CaseIterable {
    case wifi = "wifi"
    case bluetooth = "bluetooth"
    case usb = "usb"
}

public enum ZyPrinterStatus: String {
    case ready = "ready"
    case busy = "busy"
    case offline = "offline"
    case paperOut = "paper_out"
    case error = "error"
}

public enum ZyPaperStatus: String {
    case ok = "ok"
    case low = "low"
    case out = "out"
    case unknown = "unknown"
}

// MARK: - Main Zyprint Class
@objc public class Zyprint: NSObject {
    
    // MARK: - Properties
    private var discoveredPrinters: [ZyPrinter] = []
    private var connectedPrinters: [String: ZyPrinterConnection] = [:]
    private var networkBrowser: NWBrowser?
    private let discoveryQueue = DispatchQueue(label: "zyprint.discovery", qos: .utility)
    
    // MARK: - Public Methods
    
    @objc public func echo(_ value: String) -> String {
        print("Zyprint Echo: \(value)")
        return value
    }
    
    // MARK: - Printer Discovery
    
    public func discoverPrinters(completion: @escaping ([ZyPrinter]) -> Void) {
        discoveryQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.discoveredPrinters.removeAll()
            
            // Discover WiFi/Network printers
            self.discoverNetworkPrinters { networkPrinters in
                self.discoveredPrinters.append(contentsOf: networkPrinters)
                
                // Discover Bluetooth printers
                self.discoverBluetoothPrinters { bluetoothPrinters in
                    self.discoveredPrinters.append(contentsOf: bluetoothPrinters)
                    
                    DispatchQueue.main.async {
                        completion(self.discoveredPrinters)
                    }
                }
            }
        }
    }
    
    private func discoverNetworkPrinters(completion: @escaping ([ZyPrinter]) -> Void) {
        var networkPrinters: [ZyPrinter] = []
        
        // Create network browser for Zywell printers (assuming they use Bonjour/mDNS)
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        networkBrowser = NWBrowser(for: .bonjour(type: "_zyprint._tcp", domain: nil), using: parameters)
        
        networkBrowser?.browseResultsChangedHandler = { results, changes in
            for result in results {
                if case .service(name: let name, type: _, domain: _, interface: _) = result.endpoint {
                    let printer = ZyPrinter(
                        identifier: name,
                        model: "Zywell Network Printer",
                        status: ZyPrinterStatus.ready.rawValue,
                        connectionType: .wifi
                    )
                    networkPrinters.append(printer)
                }
            }
        }
        
        networkBrowser?.start(queue: discoveryQueue)
        
        // Give some time for discovery
        DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
            self.networkBrowser?.cancel()
            completion(networkPrinters)
        }
    }
    
    private func discoverBluetoothPrinters(completion: @escaping ([ZyPrinter]) -> Void) {
        var bluetoothPrinters: [ZyPrinter] = []
        
        // Check for MFi accessories (if Zywell printers support MFi)
        let accessories = EAAccessoryManager.shared().connectedAccessories
        
        for accessory in accessories {
            // Filter for Zywell/printer accessories
            if accessory.manufacturer.lowercased().contains("zywell") ||
               accessory.name.lowercased().contains("zyprint") ||
               accessory.protocolStrings.contains("com.zywell.printer") {
                
                let printer = ZyPrinter(
                    identifier: accessory.serialNumber,
                    model: accessory.modelNumber.isEmpty ? "Zywell Bluetooth Printer" : accessory.modelNumber,
                    status: accessory.isConnected ? ZyPrinterStatus.ready.rawValue : ZyPrinterStatus.offline.rawValue,
                    connectionType: .bluetooth
                )
                bluetoothPrinters.append(printer)
            }
        }
        
        completion(bluetoothPrinters)
    }
    
    // MARK: - Printer Connection
    
    public func connectToPrinter(identifier: String, completion: @escaping (Bool, String?) -> Void) {
        guard let printer = discoveredPrinters.first(where: { $0.identifier == identifier }) else {
            completion(false, "Printer not found")
            return
        }
        
        let connection = ZyPrinterConnection(printer: printer)
        
        connection.connect { [weak self] success, error in
            if success {
                self?.connectedPrinters[identifier] = connection
                completion(true, nil)
            } else {
                completion(false, error?.localizedDescription ?? "Connection failed")
            }
        }
    }
    
    public func disconnectFromPrinter(identifier: String, completion: @escaping (Bool) -> Void) {
        guard let connection = connectedPrinters[identifier] else {
            completion(false)
            return
        }
        
        connection.disconnect { [weak self] success in
            if success {
                self?.connectedPrinters.removeValue(forKey: identifier)
            }
            completion(success)
        }
    }
    
    // MARK: - Printing Methods
    
    public func printText(_ text: String, identifier: String, completion: @escaping (Bool, String?) -> Void) {
        guard let connection = connectedPrinters[identifier] else {
            completion(false, "Printer not connected")
            return
        }
        
        connection.printText(text) { success, error in
            completion(success, error?.localizedDescription)
        }
    }
    
    public func printReceipt(_ template: [String: Any], identifier: String, completion: @escaping (Bool, String?) -> Void) {
        guard let connection = connectedPrinters[identifier] else {
            completion(false, "Printer not connected")
            return
        }
        
        connection.printReceipt(template) { success, error in
            completion(success, error?.localizedDescription)
        }
    }
    
    // MARK: - Status Methods
    
    public func getPrinterStatus(identifier: String, completion: @escaping (String, String, Bool) -> Void) {
        guard let connection = connectedPrinters[identifier] else {
            completion(ZyPrinterStatus.offline.rawValue, ZyPaperStatus.unknown.rawValue, false)
            return
        }
        
        connection.getStatus { status, paperStatus in
            completion(status.rawValue, paperStatus.rawValue, true)
        }
    }
}

// MARK: - Printer Connection Class
private class ZyPrinterConnection {
    let printer: ZyPrinter
    private var tcpConnection: NWConnection?
    private var accessorySession: EASession?
    
    init(printer: ZyPrinter) {
        self.printer = printer
    }
    
    func connect(completion: @escaping (Bool, Error?) -> Void) {
        switch printer.connectionType {
        case .wifi:
            connectTCP(completion: completion)
        case .bluetooth:
            connectBluetooth(completion: completion)
        case .usb:
            // USB connections typically handled differently on iOS
            completion(false, NSError(domain: "ZyprintError", code: -1, userInfo: [NSLocalizedDescriptionKey: "USB connections not supported on iOS"]))
        }
    }
    
    private func connectTCP(completion: @escaping (Bool, Error?) -> Void) {
        guard let ipAddress = printer.ipAddress else {
            completion(false, NSError(domain: "ZyprintError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No IP address provided"]))
            return
        }
        
        let port = NWEndpoint.Port(rawValue: UInt16(printer.port ?? 9100))!
        let host = NWEndpoint.Host(ipAddress)
        
        tcpConnection = NWConnection(host: host, port: port, using: .tcp)
        
        tcpConnection?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                completion(true, nil)
            case .failed(let error):
                completion(false, error)
            case .cancelled:
                completion(false, NSError(domain: "ZyprintError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Connection cancelled"]))
            default:
                break
            }
        }
        
        tcpConnection?.start(queue: .global())
    }
    
    private func connectBluetooth(completion: @escaping (Bool, Error?) -> Void) {
        // Find the accessory
        let accessories = EAAccessoryManager.shared().connectedAccessories
        guard let accessory = accessories.first(where: { $0.serialNumber == printer.identifier }) else {
            completion(false, NSError(domain: "ZyprintError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Bluetooth accessory not found"]))
            return
        }
        
        // Create session (assuming "com.zywell.printer" protocol)
        accessorySession = EASession(accessory: accessory, forProtocol: "com.zywell.printer")
        
        if accessorySession != nil {
            accessorySession?.inputStream?.open()
            accessorySession?.outputStream?.open()
            completion(true, nil)
        } else {
            completion(false, NSError(domain: "ZyprintError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create accessory session"]))
        }
    }
    
    func disconnect(completion: @escaping (Bool) -> Void) {
        if let tcpConnection = tcpConnection {
            tcpConnection.cancel()
            self.tcpConnection = nil
        }
        
        if let session = accessorySession {
            session.inputStream?.close()
            session.outputStream?.close()
            accessorySession = nil
        }
        
        completion(true)
    }
    
    func printText(_ text: String, completion: @escaping (Bool, Error?) -> Void) {
        // Convert text to printer-specific format (ESC/POS, etc.)
        let printData = formatTextForPrinter(text)
        
        sendData(printData) { success, error in
            completion(success, error)
        }
    }
    
    func printReceipt(_ template: [String: Any], completion: @escaping (Bool, Error?) -> Void) {
        // Format receipt template into printer commands
        let printData = formatReceiptForPrinter(template)
        
        sendData(printData) { success, error in
            completion(success, error)
        }
    }
    
    private func sendData(_ data: Data, completion: @escaping (Bool, Error?) -> Void) {
        if let tcpConnection = tcpConnection {
            tcpConnection.send(content: data, completion: .contentProcessed { error in
                completion(error == nil, error)
            })
        } else if let session = accessorySession, let outputStream = session.outputStream {
            let bytesWritten = data.withUnsafeBytes { bytes in
                outputStream.write(bytes.bindMemory(to: UInt8.self).baseAddress!, maxLength: data.count)
            }
            completion(bytesWritten > 0, nil)
        } else {
            completion(false, NSError(domain: "ZyprintError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No active connection"]))
        }
    }
    
    func getStatus(completion: @escaping (ZyPrinterStatus, ZyPaperStatus) -> Void) {
        // Send status command to printer and parse response
        // This is printer-specific and would need actual command protocol
        let statusCommand = Data([0x10, 0x04, 0x01]) // Example status command
        
        sendData(statusCommand) { success, error in
            if success {
                // Parse status response (this would be specific to Zywell protocol)
                completion(.ready, .ok)
            } else {
                completion(.error, .unknown)
            }
        }
    }
    
    // MARK: - Formatting Methods
    
    private func formatTextForPrinter(_ text: String) -> Data {
        // Convert text to printer format (ESC/POS commands, etc.)
        var printData = Data()
        
        // Initialize printer
        printData.append(Data([0x1B, 0x40])) // ESC @
        
        // Add text
        if let textData = text.data(using: .utf8) {
            printData.append(textData)
        }
        
        // Add line feed and cut
        printData.append(Data([0x0A, 0x0A, 0x0A])) // Line feeds
        printData.append(Data([0x1D, 0x56, 0x41, 0x10])) // Cut command
        
        return printData
    }
    
    private func formatReceiptForPrinter(_ template: [String: Any]) -> Data {
        var printData = Data()
        
        // Initialize printer
        printData.append(Data([0x1B, 0x40])) // ESC @
        
        // Center align
        printData.append(Data([0x1B, 0x61, 0x01])) // ESC a 1
        
        // Process template data
        if let header = template["header"] as? String {
            if let headerData = header.data(using: .utf8) {
                printData.append(headerData)
                printData.append(Data([0x0A, 0x0A])) // Line feeds
            }
        }
        
        // Left align for items
        printData.append(Data([0x1B, 0x61, 0x00])) // ESC a 0
        
        if let items = template["items"] as? [[String: Any]] {
            for item in items {
                if let name = item["name"] as? String,
                   let price = item["price"] as? String {
                    let line = "\(name)\t\(price)\n"
                    if let lineData = line.data(using: .utf8) {
                        printData.append(lineData)
                    }
                }
            }
        }
        
        // Add total
        if let total = template["total"] as? String {
            let totalLine = "Total: \(total)\n"
            if let totalData = totalLine.data(using: .utf8) {
                printData.append(Data([0x0A])) // Line feed
                printData.append(totalData)
            }
        }
        
        // Cut paper
        printData.append(Data([0x0A, 0x0A, 0x0A])) // Line feeds
        printData.append(Data([0x1D, 0x56, 0x41, 0x10])) // Cut command
        
        return printData
    }
}
