import Foundation
import Capacitor

/**
 * Zyprint plugin for iOS
 * Capacitor iOS Plugin Development Guide: https://capacitorjs.com/docs/plugins/ios
 */
@objc(ZyprintPlugin)
public class ZyprintPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "ZyprintPlugin"
    public let jsName = "Zyprint"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "echo", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "discoverPrinters", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "connectToPrinter", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "disconnectFromPrinter", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "printText", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "printReceipt", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getPrinterStatus", returnType: CAPPluginReturnPromise)
    ]
    
    private var implementation = Zyprint()
    
    @objc func echo(_ call: CAPPluginCall) {
        let value = call.getString("value") ?? ""
        let result = implementation.echo(value)
        call.resolve([
            "value": result
        ])
    }
    
    @objc func discoverPrinters(_ call: CAPPluginCall) {
        implementation.discoverPrinters { printers in
            let printersData = printers.map { printer in
                return [
                    "identifier": printer.identifier,
                    "model": printer.model,
                    "status": printer.status
                ]
            }
            
            call.resolve([
                "printers": printersData
            ])
        }
    }
    
    @objc func connectToPrinter(_ call: CAPPluginCall) {
        guard let identifier = call.getString("identifier") else {
            call.reject("Missing identifier parameter")
            return
        }
        
        implementation.connectToPrinter(identifier: identifier) { success, error in
            if success {
                call.resolve([
                    "connected": true
                ])
            } else {
                call.reject(error ?? "Connection failed")
            }
        }
    }
    
    @objc func disconnectFromPrinter(_ call: CAPPluginCall) {
        guard let identifier = call.getString("identifier") else {
            call.reject("Missing identifier parameter")
            return
        }
        
        implementation.disconnectFromPrinter(identifier: identifier) { success in
            call.resolve([
                "disconnected": success
            ])
        }
    }
    
    @objc func printText(_ call: CAPPluginCall) {
        guard let text = call.getString("text"),
              let identifier = call.getString("identifier") else {
            call.reject("Missing required parameters")
            return
        }
        
        implementation.printText(text, identifier: identifier) { success, error in
            if success {
                call.resolve([
                    "success": true
                ])
            } else {
                call.reject(error ?? "Print failed")
            }
        }
    }
    
    @objc func printReceipt(_ call: CAPPluginCall) {
        guard let template = call.getObject("template"),
              let identifier = call.getString("identifier") else {
            call.reject("Missing required parameters")
            return
        }
        
        implementation.printReceipt(template, identifier: identifier) { success, error in
            if success {
                call.resolve([
                    "success": true
                ])
            } else {
                call.reject(error ?? "Print failed")
            }
        }
    }
    
    @objc func getPrinterStatus(_ call: CAPPluginCall) {
        guard let identifier = call.getString("identifier") else {
            call.reject("Missing identifier parameter")
            return
        }
        
        implementation.getPrinterStatus(identifier: identifier) { status, paperStatus, connected in
            call.resolve([
                "status": status,
                "paperStatus": paperStatus,
                "connected": connected
            ])
        }
    }
}
