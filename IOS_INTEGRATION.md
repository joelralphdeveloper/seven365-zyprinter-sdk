# Zywell SDK iOS Integration Guide

## Overview

This Capacitor plugin now integrates the official Zywell Objective-C SDK for iOS thermal printer support. The integration provides native Bluetooth and WiFi connectivity for receipt and label printing.

## Architecture

### Files Structure

```
ios/Sources/
├── Plugin/
│   ├── ZyprintPlugin.swift              # Capacitor plugin bridge
│   ├── ZywellSDK.swift                  # Swift wrapper for Zywell SDK
│   └── ZyprintPlugin-Bridging-Header.h  # Objective-C bridging header
└── sources/                              # Zywell Objective-C SDK
    ├── POSSDK.h                         # Main SDK header
    ├── POSBLEManager.h/m                # Bluetooth manager
    ├── POSWIFIManager.h/m               # WiFi manager
    ├── PosCommand.h/m                   # ESC/POS commands
    ├── TscCommand.h/m                   # TSC label commands
    ├── ImageTranster.h/m                # Image processing
    └── GCD/                             # Network layer
        ├── GCDAsyncSocket.h/m           # TCP socket
        └── PrinterManager.h/m           # Printer management
```

### Integration Flow

```
TypeScript (definitions.ts)
    ↓
Capacitor Bridge (ZyprintPlugin.swift)
    ↓
Swift Wrapper (ZywellSDK.swift)
    ↓
Objective-C SDK (POSBLEManager/POSWIFIManager)
    ↓
Zywell Printer Hardware
```

## Setup Instructions

### 1. Build the Plugin

```bash
cd /Users/joelralph/365-project/seven365-zyprinter
npm run build
```

### 2. Install in Your App

```bash
# In your Capacitor app directory
npm install file:../seven365-zyprinter
npx cap sync ios
```

### 3. Configure Info.plist

Add these permissions to your iOS app's `Info.plist`:

```xml
<!-- Bluetooth Permission -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to connect to thermal printers</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth to discover and connect to printers</string>

<!-- Local Network Permission (for WiFi printers) -->
<key>NSLocalNetworkUsageDescription</key>
<string>This app uses local network to discover WiFi printers</string>

<key>NSBonjourServices</key>
<array>
    <string>_printer._tcp</string>
    <string>_ipp._tcp</string>
</array>
```

### 4. Required iOS Frameworks

The following frameworks are automatically included via podspec:
- `CoreBluetooth.framework` - Bluetooth connectivity
- `SystemConfiguration.framework` - Network information
- `CFNetwork.framework` - Network services

## Usage Examples

### Basic Bluetooth Printing

```typescript
import { Zyprint } from 'seven365-zyprinter';

async function printToBluetooth() {
  try {
    // Discover Bluetooth printers
    const { printers } = await Zyprint.discoverBluetoothPrinters();
    console.log('Found printers:', printers);
    
    if (printers.length > 0) {
      const printer = printers[0];
      
      // Connect
      await Zyprint.connectToPrinter({ 
        identifier: printer.identifier 
      });
      
      // Print receipt
      await Zyprint.printReceipt({
        template: {
          header: "My Store\n123 Main St",
          items: [
            { name: "Coffee", price: "$3.50" },
            { name: "Muffin", price: "$2.50" }
          ],
          total: "$6.00",
          footer: "Thank you!"
        },
        identifier: printer.identifier
      });
      
      // Disconnect
      await Zyprint.disconnectFromPrinter({ 
        identifier: printer.identifier 
      });
    }
  } catch (error) {
    console.error('Printing failed:', error);
  }
}
```

### WiFi Printer Connection

```typescript
async function printToWiFi() {
  try {
    // Connect directly to IP address
    const ipAddress = "192.168.1.100";
    
    await Zyprint.connectToPrinter({ 
      identifier: ipAddress 
    });
    
    // Print text
    await Zyprint.printText({
      text: "Hello from WiFi printer!",
      identifier: ipAddress
    });
    
    // Disconnect
    await Zyprint.disconnectFromPrinter({ 
      identifier: ipAddress 
    });
  } catch (error) {
    console.error('WiFi printing failed:', error);
  }
}
```

### Check Printer Status

```typescript
async function checkPrinterStatus(identifier: string) {
  try {
    const status = await Zyprint.getPrinterStatus({ 
      identifier 
    });
    
    console.log('Status:', status.status);          // 'ready', 'offline', etc.
    console.log('Paper:', status.paperStatus);      // 'ok', 'low', 'out'
    console.log('Connected:', status.connected);    // true/false
  } catch (error) {
    console.error('Status check failed:', error);
  }
}
```

## SDK Features

### Bluetooth (POSBLEManager)

- ✅ Automatic device discovery
- ✅ Connection management
- ✅ RSSI signal strength monitoring
- ✅ Auto-reconnection support
- ✅ Delegate-based callbacks

### WiFi (POSWIFIManager)

- ✅ TCP/IP socket connection
- ✅ Multiple concurrent connections
- ✅ Standard port 9100 support
- ✅ Data streaming
- ✅ Connection status monitoring

### Commands Support

#### ESC/POS Commands (PosCommand)
- Text formatting (bold, underline, size)
- Alignment (left, center, right)
- Character encoding (UTF-8, etc.)
- Barcode printing (1D)
- QR code printing
- Image/bitmap printing
- Paper cutting
- Cash drawer control

#### TSC Commands (TscCommand)
- Label size configuration
- Gap detection
- Text printing
- Barcode/QR codes
- Graphics and images
- Print speed/density control

## Troubleshooting

### Build Errors

If you encounter build errors:

1. **Clean build folder**:
   ```bash
   cd ios && xcodebuild clean
   ```

2. **Re-sync Capacitor**:
   ```bash
   npx cap sync ios
   ```

3. **Check bridging header**: Ensure `ZyprintPlugin-Bridging-Header.h` is properly referenced in your Xcode project settings.

### Runtime Issues

**Bluetooth not discovering printers:**
- Check Bluetooth permissions in Info.plist
- Ensure Bluetooth is enabled on device
- Verify printer is in pairing mode

**WiFi connection fails:**
- Confirm IP address is correct
- Check printer is on same network
- Verify port 9100 is open
- Test with ping command

**Print output garbled:**
- Check character encoding (default is UTF-8)
- Verify printer supports ESC/POS commands
- Ensure correct printer model

## Advanced Configuration

### Custom Port for WiFi

The default port is 9100. To use a different port, you can modify `ZywellSDK.swift`:

```swift
private func connectWiFiPrinter(ipAddress: String, completion: @escaping (Bool, String?) -> Void) {
    let port: UInt16 = 9100 // Change this to your custom port
    // ... rest of code
}
```

### Batch Printing Mode

The Zywell SDK supports batch mode for sending multiple commands:

```swift
bleManager?.possetCommandMode(true) // Enable batch mode
// Send multiple commands
bleManager?.possendCommandBuffer()   // Send all at once
```

### Custom ESC/POS Commands

You can use the `PosCommand` class directly for advanced formatting:

```swift
import PosCommand

let initData = PosCommand.initializePrinter()
let boldData = PosCommand.selectOrCancleBoldModel(1)
let textData = "Bold Text".data(using: .utf8)
// Combine and send
```

## Support

For issues with:
- **Zywell SDK**: Contact Zywell support or check their documentation
- **Capacitor Plugin**: Create an issue in the repository
- **Integration**: Refer to this guide or IMPLEMENTATION_GUIDE.md

## License

MIT License - See LICENSE file for details
