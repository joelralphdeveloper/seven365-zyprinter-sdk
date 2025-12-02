package com.mycompany.plugins.example;

import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothSocket;
import android.content.Context;
import android.util.Log;
import android.os.Handler;
import android.os.Looper;

import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;

import java.io.IOException;
import java.io.OutputStream;
import java.net.Socket;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

public class Zyprint {

    private static final String TAG = "Zyprint";
    private Map<String, PrinterConnection> connectedPrinters = new HashMap<>();
    private Handler mainHandler = new Handler(Looper.getMainLooper());

    // Callback interfaces
    public interface PrinterDiscoveryCallback {
        void onPrintersFound(JSArray printers);
        void onError(String error);
    }

    public interface ConnectionCallback {
        void onConnected();
        void onError(String error);
    }

    public interface DisconnectionCallback {
        void onDisconnected();
        void onError(String error);
    }

    public interface PrintCallback {
        void onSuccess();
        void onError(String error);
    }

    public interface StatusCallback {
        void onStatus(String status, String paperStatus, boolean connected);
        void onError(String error);
    }

    public String echo(String value) {
        Log.i(TAG, "Echo: " + value);
        return value;
    }

    public void discoverPrinters(PrinterDiscoveryCallback callback) {
        new Thread(() -> {
            try {
                JSArray printers = new JSArray();
                
                // Discover Bluetooth printers
                BluetoothAdapter bluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
                if (bluetoothAdapter != null && bluetoothAdapter.isEnabled()) {
                    Set<BluetoothDevice> pairedDevices = bluetoothAdapter.getBondedDevices();
                    
                    for (BluetoothDevice device : pairedDevices) {
                        // Filter for printer devices (you may need to adjust this based on Zywell printer naming)
                        if (device.getName() != null && 
                            (device.getName().toLowerCase().contains("zywell") ||
                             device.getName().toLowerCase().contains("zyprint") ||
                             device.getName().toLowerCase().contains("printer"))) {
                            
                            JSObject printer = new JSObject();
                            printer.put("identifier", device.getAddress());
                            printer.put("model", device.getName());
                            printer.put("status", device.getBondState() == BluetoothDevice.BOND_BONDED ? "ready" : "offline");
                            printers.put(printer);
                        }
                    }
                }
                
                mainHandler.post(() -> callback.onPrintersFound(printers));
                
            } catch (Exception e) {
                Log.e(TAG, "Error discovering printers", e);
                mainHandler.post(() -> callback.onError("Discovery failed: " + e.getMessage()));
            }
        }).start();
    }

    public void connectToPrinter(String identifier, ConnectionCallback callback) {
        new Thread(() -> {
            try {
                PrinterConnection connection = new PrinterConnection();
                
                // Try to connect via Bluetooth
                BluetoothAdapter bluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
                if (bluetoothAdapter != null) {
                    BluetoothDevice device = bluetoothAdapter.getRemoteDevice(identifier);
                    
                    if (connection.connectBluetooth(device)) {
                        connectedPrinters.put(identifier, connection);
                        mainHandler.post(callback::onConnected);
                        return;
                    }
                }
                
                // If Bluetooth fails, try WiFi (if identifier is an IP address)
                if (identifier.matches("\\d+\\.\\d+\\.\\d+\\.\\d+")) {
                    if (connection.connectWiFi(identifier, 9100)) {
                        connectedPrinters.put(identifier, connection);
                        mainHandler.post(callback::onConnected);
                        return;
                    }
                }
                
                mainHandler.post(() -> callback.onError("Connection failed"));
                
            } catch (Exception e) {
                Log.e(TAG, "Error connecting to printer", e);
                mainHandler.post(() -> callback.onError("Connection failed: " + e.getMessage()));
            }
        }).start();
    }

    public void disconnectFromPrinter(String identifier, DisconnectionCallback callback) {
        PrinterConnection connection = connectedPrinters.get(identifier);
        if (connection != null) {
            connection.disconnect();
            connectedPrinters.remove(identifier);
            callback.onDisconnected();
        } else {
            callback.onError("Printer not connected");
        }
    }

    public void printText(String text, String identifier, PrintCallback callback) {
        PrinterConnection connection = connectedPrinters.get(identifier);
        if (connection == null) {
            callback.onError("Printer not connected");
            return;
        }

        new Thread(() -> {
            try {
                byte[] data = formatTextForPrinter(text);
                if (connection.sendData(data)) {
                    mainHandler.post(callback::onSuccess);
                } else {
                    mainHandler.post(() -> callback.onError("Print failed"));
                }
            } catch (Exception e) {
                Log.e(TAG, "Error printing text", e);
                mainHandler.post(() -> callback.onError("Print failed: " + e.getMessage()));
            }
        }).start();
    }

    public void printReceipt(JSObject template, String identifier, PrintCallback callback) {
        PrinterConnection connection = connectedPrinters.get(identifier);
        if (connection == null) {
            callback.onError("Printer not connected");
            return;
        }

        new Thread(() -> {
            try {
                byte[] data = formatReceiptForPrinter(template);
                if (connection.sendData(data)) {
                    mainHandler.post(callback::onSuccess);
                } else {
                    mainHandler.post(() -> callback.onError("Print failed"));
                }
            } catch (Exception e) {
                Log.e(TAG, "Error printing receipt", e);
                mainHandler.post(() -> callback.onError("Print failed: " + e.getMessage()));
            }
        }).start();
    }

    public void getPrinterStatus(String identifier, StatusCallback callback) {
        PrinterConnection connection = connectedPrinters.get(identifier);
        if (connection == null) {
            callback.onStatus("offline", "unknown", false);
            return;
        }

        new Thread(() -> {
            try {
                // Send status command (this would be specific to Zywell protocol)
                byte[] statusCommand = {0x10, 0x04, 0x01}; // Example status command
                
                if (connection.sendData(statusCommand)) {
                    // In a real implementation, you'd read the response and parse it
                    mainHandler.post(() -> callback.onStatus("ready", "ok", true));
                } else {
                    mainHandler.post(() -> callback.onStatus("error", "unknown", true));
                }
            } catch (Exception e) {
                Log.e(TAG, "Error getting printer status", e);
                mainHandler.post(() -> callback.onError("Status check failed: " + e.getMessage()));
            }
        }).start();
    }

    private byte[] formatTextForPrinter(String text) {
        try {
            // ESC/POS commands for text printing
            byte[] initPrinter = {0x1B, 0x40}; // ESC @
            byte[] textBytes = text.getBytes("UTF-8");
            byte[] lineFeed = {0x0A, 0x0A, 0x0A}; // Line feeds
            byte[] cutPaper = {0x1D, 0x56, 0x41, 0x10}; // Cut command
            
            byte[] result = new byte[initPrinter.length + textBytes.length + lineFeed.length + cutPaper.length];
            int offset = 0;
            
            System.arraycopy(initPrinter, 0, result, offset, initPrinter.length);
            offset += initPrinter.length;
            
            System.arraycopy(textBytes, 0, result, offset, textBytes.length);
            offset += textBytes.length;
            
            System.arraycopy(lineFeed, 0, result, offset, lineFeed.length);
            offset += lineFeed.length;
            
            System.arraycopy(cutPaper, 0, result, offset, cutPaper.length);
            
            return result;
        } catch (Exception e) {
            Log.e(TAG, "Error formatting text", e);
            return new byte[0];
        }
    }

    private byte[] formatReceiptForPrinter(JSObject template) {
        try {
            StringBuilder receiptText = new StringBuilder();
            
            // Initialize printer
            receiptText.append("\u001B@"); // ESC @
            
            // Center align
            receiptText.append("\u001B\u0061\u0001"); // ESC a 1
            
            // Header
            if (template.has("header")) {
                // Get header size from formatting
                byte sizeCode = 0x00; // Default: normal
                if (template.has("formatting")) {
                    JSObject formatting = template.getJSObject("formatting");
                    if (formatting != null && formatting.has("headerSize")) {
                        sizeCode = mapHeaderSizeToCode(formatting.get("headerSize"));
                    }
                }
                
                // Set font size (GS ! n)
                receiptText.append((char) 0x1D).append((char) 0x21).append((char) sizeCode);
                
                receiptText.append(template.getString("header")).append("\n\n");
                
                // Reset to normal size
                receiptText.append((char) 0x1D).append((char) 0x21).append((char) 0x00);
            }
            
            // Left align for items
            receiptText.append("\u001B\u0061\u0000"); // ESC a 0
            
            // Items
            if (template.has("items")) {
                // Get item formatting
                byte itemSizeCode = 0x00;
                boolean itemBold = false;
                if (template.has("formatting")) {
                    JSObject formatting = template.getJSObject("formatting");
                    if (formatting != null) {
                        if (formatting.has("itemSize")) {
                            itemSizeCode = mapHeaderSizeToCode(formatting.get("itemSize"));
                        }
                        itemBold = formatting.optBoolean("itemBold", false);
                    }
                }
                
                // Apply item formatting
                if (itemBold) {
                    receiptText.append((char) 0x1B).append((char) 0x45).append((char) 0x01); // Bold on
                }
                if (itemSizeCode != 0x00) {
                    receiptText.append((char) 0x1D).append((char) 0x21).append((char) itemSizeCode); // Set size
                }
                
                JSArray items = template.getJSArray("items");
                for (int i = 0; i < items.length(); i++) {
                    JSObject item = items.getJSObject(i);
                    String name = item.optString("name", "");
                    String price = item.optString("price", "");
                    receiptText.append(name).append("\t").append(price).append("\n");
                }
                
                // Reset item formatting
                if (itemSizeCode != 0x00) {
                    receiptText.append((char) 0x1D).append((char) 0x21).append((char) 0x00); // Normal size
                }
                if (itemBold) {
                    receiptText.append((char) 0x1B).append((char) 0x45).append((char) 0x00); // Bold off
                }
            }
            
            // Total
            if (template.has("total")) {
                // Get total formatting
                byte totalSizeCode = 0x00;
                boolean totalBold = false;
                if (template.has("formatting")) {
                    JSObject formatting = template.getJSObject("formatting");
                    if (formatting != null) {
                        if (formatting.has("totalSize")) {
                            totalSizeCode = mapHeaderSizeToCode(formatting.get("totalSize"));
                        }
                        totalBold = formatting.optBoolean("totalBold", false);
                    }
                }
                
                // Apply total formatting
                if (totalBold) {
                    receiptText.append((char) 0x1B).append((char) 0x45).append((char) 0x01); // Bold on
                }
                if (totalSizeCode != 0x00) {
                    receiptText.append((char) 0x1D).append((char) 0x21).append((char) totalSizeCode); // Set size
                }
                
                receiptText.append("\nTotal: ").append(template.getString("total")).append("\n");
                
                // Reset total formatting
                if (totalSizeCode != 0x00) {
                    receiptText.append((char) 0x1D).append((char) 0x21).append((char) 0x00); // Normal size
                }
                if (totalBold) {
                    receiptText.append((char) 0x1B).append((char) 0x45).append((char) 0x00); // Bold off
                }
            }
            
            // Footer
            if (template.has("footer")) {
                // Get footer formatting
                byte footerSizeCode = 0x00;
                if (template.has("formatting")) {
                    JSObject formatting = template.getJSObject("formatting");
                    if (formatting != null && formatting.has("footerSize")) {
                        footerSizeCode = mapHeaderSizeToCode(formatting.get("footerSize"));
                    }
                }
                
                // Apply footer formatting
                if (footerSizeCode != 0x00) {
                    receiptText.append((char) 0x1D).append((char) 0x21).append((char) footerSizeCode); // Set size
                }
                
                receiptText.append(template.getString("footer")).append("\n");
                
                // Reset footer formatting
                if (footerSizeCode != 0x00) {
                    receiptText.append((char) 0x1D).append((char) 0x21).append((char) 0x00); // Normal size
                }
            }
            
            // Line feeds and cut
            receiptText.append("\n\n\n");
            receiptText.append("\u001D\u0056\u0041\u0010"); // Cut command
            
            return receiptText.toString().getBytes("UTF-8");
        } catch (Exception e) {
            Log.e(TAG, "Error formatting receipt", e);
            return new byte[0];
        }
    }

    private byte mapHeaderSizeToCode(Object size) {
        if (size instanceof Integer) {
            int sizeInt = (Integer) size;
            switch (sizeInt) {
                case 1: return 0x00;
                case 2: return 0x11;
                case 3: return 0x22;
                case 4: return 0x33;
                default: return 0x00;
            }
        } else if (size instanceof String) {
            String sizeStr = (String) size;
            switch (sizeStr) {
                case "normal": return 0x00;
                case "large": return 0x11;
                case "xlarge": return 0x22;
                default: return 0x00;
            }
        }
        return 0x00;
    }

    private static class PrinterConnection {
        private BluetoothSocket bluetoothSocket;
        private Socket wifiSocket;
        private OutputStream outputStream;

        public boolean connectBluetooth(BluetoothDevice device) {
            try {
                // UUID for printer service (this might need to be specific to Zywell)
                UUID uuid = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB");
                bluetoothSocket = device.createRfcommSocketToServiceRecord(uuid);
                bluetoothSocket.connect();
                outputStream = bluetoothSocket.getOutputStream();
                return true;
            } catch (Exception e) {
                Log.e(TAG, "Bluetooth connection failed", e);
                return false;
            }
        }

        public boolean connectWiFi(String ipAddress, int port) {
            try {
                wifiSocket = new Socket(ipAddress, port);
                outputStream = wifiSocket.getOutputStream();
                return true;
            } catch (Exception e) {
                Log.e(TAG, "WiFi connection failed", e);
                return false;
            }
        }

        public boolean sendData(byte[] data) {
            try {
                if (outputStream != null) {
                    outputStream.write(data);
                    outputStream.flush();
                    return true;
                }
            } catch (IOException e) {
                Log.e(TAG, "Error sending data", e);
            }
            return false;
        }

        public void disconnect() {
            try {
                if (outputStream != null) {
                    outputStream.close();
                }
                if (bluetoothSocket != null) {
                    bluetoothSocket.close();
                }
                if (wifiSocket != null) {
                    wifiSocket.close();
                }
            } catch (IOException e) {
                Log.e(TAG, "Error disconnecting", e);
            }
        }
    }
}
