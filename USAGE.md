# Zyprint SDK Usage Examples

## Basic Setup

```typescript
import { Zyprint } from 'seven365-zyprinter';

// Echo test
const result = await Zyprint.echo({ value: 'Hello Zyprint!' });
console.log(result.value); // 'Hello Zyprint!'
```

## Printer Discovery

```typescript
// Discover available printers
try {
  const result = await Zyprint.discoverPrinters();
  console.log('Found printers:', result.printers);
  
  // Example output:
  // [
  //   {
  //     identifier: "00:11:22:33:44:55",
  //     model: "Zywell Bluetooth Printer",
  //     status: "ready"
  //   },
  //   {
  //     identifier: "192.168.1.100",
  //     model: "Zywell Network Printer", 
  //     status: "ready"
  //   }
  // ]
} catch (error) {
  console.error('Discovery failed:', error);
}
```

## Printer Connection

```typescript
// Connect to a printer
const printerIdentifier = "00:11:22:33:44:55"; // Bluetooth MAC or IP address

try {
  const result = await Zyprint.connectToPrinter({ 
    identifier: printerIdentifier 
  });
  
  if (result.connected) {
    console.log('Successfully connected to printer');
  }
} catch (error) {
  console.error('Connection failed:', error);
}

// Disconnect from printer
try {
  const result = await Zyprint.disconnectFromPrinter({ 
    identifier: printerIdentifier 
  });
  
  if (result.disconnected) {
    console.log('Successfully disconnected from printer');
  }
} catch (error) {
  console.error('Disconnection failed:', error);
}
```

## Text Printing

```typescript
// Print simple text
try {
  const result = await Zyprint.printText({
    text: 'Hello World!\nThis is a test print.',
    identifier: printerIdentifier
  });
  
  if (result.success) {
    console.log('Text printed successfully');
  }
} catch (error) {
  console.error('Print failed:', error);
}
```

## Receipt Printing

```typescript
// Print a formatted receipt
const receiptTemplate = {
  header: "My Restaurant\n123 Main Street\nPhone: (555) 123-4567",
  items: [
    { name: "Burger", price: "$12.99" },
    { name: "Fries", price: "$4.99" },
    { name: "Drink", price: "$2.99" }
  ],
  total: "$20.97",
  footer: "Thank you for your visit!"
};

try {
  const result = await Zyprint.printReceipt({
    template: receiptTemplate,
    identifier: printerIdentifier
  });
  
  if (result.success) {
    console.log('Receipt printed successfully');
  }
} catch (error) {
  console.error('Receipt print failed:', error);
}
```

## Printer Status Check

```typescript
// Check printer status
try {
  const status = await Zyprint.getPrinterStatus({ 
    identifier: printerIdentifier 
  });
  
  console.log('Printer Status:', {
    status: status.status,          // 'ready', 'busy', 'offline', 'paper_out', 'error'
    paperStatus: status.paperStatus, // 'ok', 'low', 'out', 'unknown'
    connected: status.connected      // true/false
  });
} catch (error) {
  console.error('Status check failed:', error);
}
```

## Complete Workflow Example

```typescript
class ZyprintManager {
  private connectedPrinter: string | null = null;

  async initializePrinter(): Promise<boolean> {
    try {
      // 1. Discover printers
      const discovery = await Zyprint.discoverPrinters();
      
      if (discovery.printers.length === 0) {
        throw new Error('No printers found');
      }

      // 2. Connect to first available printer
      const printer = discovery.printers[0];
      const connection = await Zyprint.connectToPrinter({
        identifier: printer.identifier
      });

      if (connection.connected) {
        this.connectedPrinter = printer.identifier;
        console.log(`Connected to: ${printer.model}`);
        return true;
      }

      throw new Error('Failed to connect to printer');
    } catch (error) {
      console.error('Printer initialization failed:', error);
      return false;
    }
  }

  async printOrderReceipt(orderData: any): Promise<boolean> {
    if (!this.connectedPrinter) {
      throw new Error('No printer connected');
    }

    try {
      // Check printer status first
      const status = await Zyprint.getPrinterStatus({
        identifier: this.connectedPrinter
      });

      if (status.status !== 'ready') {
        throw new Error(`Printer not ready: ${status.status}`);
      }

      if (status.paperStatus === 'out') {
        throw new Error('Printer is out of paper');
      }

      // Print the receipt
      const result = await Zyprint.printReceipt({
        template: {
          header: orderData.restaurant.name + '\n' + orderData.restaurant.address,
          items: orderData.items.map(item => ({
            name: item.name,
            price: `$${item.price.toFixed(2)}`
          })),
          total: `$${orderData.total.toFixed(2)}`,
          footer: 'Thank you for your order!'
        },
        identifier: this.connectedPrinter
      });

      return result.success;
    } catch (error) {
      console.error('Failed to print receipt:', error);
      return false;
    }
  }

  async disconnect(): Promise<void> {
    if (this.connectedPrinter) {
      try {
        await Zyprint.disconnectFromPrinter({
          identifier: this.connectedPrinter
        });
        this.connectedPrinter = null;
      } catch (error) {
        console.error('Disconnect failed:', error);
      }
    }
  }
}

// Usage
const printerManager = new ZyprintManager();

// Initialize and use
if (await printerManager.initializePrinter()) {
  const orderData = {
    restaurant: {
      name: "Joe's Diner",
      address: "123 Main St, City, State"
    },
    items: [
      { name: "Cheeseburger", price: 8.99 },
      { name: "French Fries", price: 3.99 },
      { name: "Soda", price: 1.99 }
    ],
    total: 14.97
  };

  const printed = await printerManager.printOrderReceipt(orderData);
  
  if (printed) {
    console.log('Order receipt printed successfully!');
  }
  
  // Clean up
  await printerManager.disconnect();
}
```

## Error Handling

The SDK provides comprehensive error handling:

```typescript
try {
  await Zyprint.connectToPrinter({ identifier: "invalid-id" });
} catch (error) {
  // Possible error messages:
  // - "Printer not found"
  // - "Connection failed"
  // - "Bluetooth not available"
  // - "WiFi connection timeout"
  console.error('Connection error:', error);
}

try {
  await Zyprint.printText({ 
    text: "Hello", 
    identifier: "not-connected" 
  });
} catch (error) {
  // Possible error messages:
  // - "Printer not connected"
  // - "Print failed"
  // - "Paper out"
  // - "Printer busy"
  console.error('Print error:', error);
}
```

## Platform Support

- ✅ iOS (Bluetooth, WiFi)
- ✅ Android (Bluetooth, WiFi)  
- ⚠️ Web (Limited - returns mock responses with warnings)

## Printer Communication Protocols

The SDK supports standard ESC/POS commands for maximum compatibility:
- Text formatting (bold, underline, size)
- Character encoding (UTF-8)
- Paper cutting
- Status monitoring
- Line feeds and spacing

For Zywell-specific features, the SDK can be extended with custom command sequences.