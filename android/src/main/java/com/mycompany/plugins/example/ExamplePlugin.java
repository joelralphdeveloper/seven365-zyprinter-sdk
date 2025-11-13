package com.mycompany.plugins.example;

import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "Zyprint")
public class ZyprintPlugin extends Plugin {

    private Zyprint implementation = new Zyprint();

    @PluginMethod
    public void echo(PluginCall call) {
        String value = call.getString("value");

        JSObject ret = new JSObject();
        ret.put("value", implementation.echo(value));
        call.resolve(ret);
    }

    @PluginMethod
    public void discoverPrinters(PluginCall call) {
        implementation.discoverPrinters(new Zyprint.PrinterDiscoveryCallback() {
            @Override
            public void onPrintersFound(JSArray printers) {
                JSObject ret = new JSObject();
                ret.put("printers", printers);
                call.resolve(ret);
            }

            @Override
            public void onError(String error) {
                call.reject(error);
            }
        });
    }

    @PluginMethod
    public void connectToPrinter(PluginCall call) {
        String identifier = call.getString("identifier");
        if (identifier == null) {
            call.reject("Missing identifier parameter");
            return;
        }

        implementation.connectToPrinter(identifier, new Zyprint.ConnectionCallback() {
            @Override
            public void onConnected() {
                JSObject ret = new JSObject();
                ret.put("connected", true);
                call.resolve(ret);
            }

            @Override
            public void onError(String error) {
                call.reject(error);
            }
        });
    }

    @PluginMethod
    public void disconnectFromPrinter(PluginCall call) {
        String identifier = call.getString("identifier");
        if (identifier == null) {
            call.reject("Missing identifier parameter");
            return;
        }

        implementation.disconnectFromPrinter(identifier, new Zyprint.DisconnectionCallback() {
            @Override
            public void onDisconnected() {
                JSObject ret = new JSObject();
                ret.put("disconnected", true);
                call.resolve(ret);
            }

            @Override
            public void onError(String error) {
                call.reject(error);
            }
        });
    }

    @PluginMethod
    public void printText(PluginCall call) {
        String text = call.getString("text");
        String identifier = call.getString("identifier");
        
        if (text == null || identifier == null) {
            call.reject("Missing required parameters");
            return;
        }

        implementation.printText(text, identifier, new Zyprint.PrintCallback() {
            @Override
            public void onSuccess() {
                JSObject ret = new JSObject();
                ret.put("success", true);
                call.resolve(ret);
            }

            @Override
            public void onError(String error) {
                call.reject(error);
            }
        });
    }

    @PluginMethod
    public void printReceipt(PluginCall call) {
        JSObject template = call.getObject("template");
        String identifier = call.getString("identifier");
        
        if (template == null || identifier == null) {
            call.reject("Missing required parameters");
            return;
        }

        implementation.printReceipt(template, identifier, new Zyprint.PrintCallback() {
            @Override
            public void onSuccess() {
                JSObject ret = new JSObject();
                ret.put("success", true);
                call.resolve(ret);
            }

            @Override
            public void onError(String error) {
                call.reject(error);
            }
        });
    }

    @PluginMethod
    public void getPrinterStatus(PluginCall call) {
        String identifier = call.getString("identifier");
        if (identifier == null) {
            call.reject("Missing identifier parameter");
            return;
        }

        implementation.getPrinterStatus(identifier, new Zyprint.StatusCallback() {
            @Override
            public void onStatus(String status, String paperStatus, boolean connected) {
                JSObject ret = new JSObject();
                ret.put("status", status);
                ret.put("paperStatus", paperStatus);
                ret.put("connected", connected);
                call.resolve(ret);
            }

            @Override
            public void onError(String error) {
                call.reject(error);
            }
        });
    }
}
