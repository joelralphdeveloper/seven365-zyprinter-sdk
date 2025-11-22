//
//  ZyprintPlugin.swift
//  Seven365Zyprinter
//
//  Capacitor plugin for Zywell thermal printer integration
//

import Foundation
import Capacitor

@objc(ZyprintPlugin)
public class ZyprintPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "ZyprintPlugin"
    public let jsName = "Zyprint"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "echo", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "discoverPrinters", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "discoverBluetoothPrinters", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "discoverWiFiPrinters", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "connectToPrinter", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "disconnectFromPrinter", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "printText", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "printReceipt", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getPrinterStatus", returnType: CAPPluginReturnPromise)
    ]
    
    private let implementation = ZywellSDK()
    
    @objc func echo(_ call: CAPPluginCall) {
        let value = call.getString("value") ?? ""
        call.resolve([
            "value": implementation.echo(value)
        ])
    }
    
    @objc func discoverPrinters(_ call: CAPPluginCall) {
        implementation.discoverPrinters { printers, error in
            if let error = error {
                call.reject(error)
            } else {
                call.resolve([
                    "printers": printers
                ])
            }
        }
    }
    
    @objc func discoverBluetoothPrinters(_ call: CAPPluginCall) {
        implementation.discoverBluetoothPrinters { printers, error in
            if let error = error {
                call.reject(error)
            } else {
                call.resolve([
                    "printers": printers
                ])
            }
        }
    }
    
    @objc func discoverWiFiPrinters(_ call: CAPPluginCall) {
        let networkRange = call.getString("networkRange")
        implementation.discoverWiFiPrinters(networkRange: networkRange) { printers, error in
            if let error = error {
                call.reject(error)
            } else {
                call.resolve([
                    "printers": printers
                ])
            }
        }
    }
    
    @objc func connectToPrinter(_ call: CAPPluginCall) {
        guard let identifier = call.getString("identifier") else {
            call.reject("Missing identifier parameter")
            return
        }
        
        implementation.connectToPrinter(identifier: identifier) { success, error in
            if let error = error {
                call.reject(error)
            } else {
                call.resolve([
                    "connected": success
                ])
            }
        }
    }
    
    @objc func disconnectFromPrinter(_ call: CAPPluginCall) {
        guard let identifier = call.getString("identifier") else {
            call.reject("Missing identifier parameter")
            return
        }
        
        implementation.disconnectFromPrinter(identifier: identifier) { success, error in
            if let error = error {
                call.reject(error)
            } else {
                call.resolve([
                    "disconnected": success
                ])
            }
        }
    }
    
    @objc func printText(_ call: CAPPluginCall) {
        guard let text = call.getString("text"),
              let identifier = call.getString("identifier") else {
            call.reject("Missing required parameters")
            return
        }
        
        implementation.printText(text: text, identifier: identifier) { success, error in
            if let error = error {
                call.reject(error)
            } else {
                call.resolve([
                    "success": success
                ])
            }
        }
    }
    
    @objc func printReceipt(_ call: CAPPluginCall) {
        guard let template = call.getObject("template"),
              let identifier = call.getString("identifier") else {
            call.reject("Missing required parameters")
            return
        }
        
        implementation.printReceipt(template: template, identifier: identifier) { success, error in
            if let error = error {
                call.reject(error)
            } else {
                call.resolve([
                    "success": success
                ])
            }
        }
    }
    
    @objc func getPrinterStatus(_ call: CAPPluginCall) {
        guard let identifier = call.getString("identifier") else {
            call.reject("Missing identifier parameter")
            return
        }
        
        implementation.getPrinterStatus(identifier: identifier) { status, paperStatus, connected, error in
            if let error = error {
                call.reject(error)
            } else {
                call.resolve([
                    "status": status,
                    "paperStatus": paperStatus,
                    "connected": connected
                ])
            }
        }
    }
}
