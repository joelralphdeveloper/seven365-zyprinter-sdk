import { Zyprint } from 'seven365-zyprinter';

/**
 * Simple test file to demonstrate Zyprint SDK functionality
 * Run this in your Capacitor app to test printer connections
 */

class ZyprintTester {
  private connectedPrinterId: string | null = null;

  async runTests() {
    console.log('🖨️ Starting Zyprint SDK Tests...');

    try {
      // Test 1: Echo functionality
      await this.testEcho();
      
      // Test 2: Printer discovery
      const printers = await this.testDiscovery();
      
      if (printers.length > 0) {
        // Test 3: Connection
        await this.testConnection(printers[0].identifier);
        
        if (this.connectedPrinterId) {
          // Test 4: Status check
          await this.testStatus();
          
          // Test 5: Text printing
          await this.testTextPrint();
          
          // Test 6: Receipt printing
          await this.testReceiptPrint();
          
          // Test 7: Disconnection
          await this.testDisconnection();
        }
      } else {
        console.log('⚠️ No printers found - skipping connection tests');
      }
      
      console.log('✅ All tests completed!');
    } catch (error) {
      console.error('❌ Test failed:', error);
    }
  }

  private async testEcho() {
    console.log('\n1. Testing echo...');
    try {
      const result = await Zyprint.echo({ value: 'Hello Zyprint!' });
      console.log('✅ Echo result:', result.value);
    } catch (error) {
      console.error('❌ Echo failed:', error);
      throw error;
    }
  }

  private async testDiscovery() {
    console.log('\n2. Discovering printers...');
    try {
      const result = await Zyprint.discoverPrinters();
      console.log(`✅ Found ${result.printers.length} printer(s):`);
      
      result.printers.forEach((printer, index) => {
        console.log(`   ${index + 1}. ${printer.model} (${printer.identifier}) - ${printer.status}`);
      });
      
      return result.printers;
    } catch (error) {
      console.error('❌ Discovery failed:', error);
      return [];
    }
  }

  private async testConnection(printerId: string) {
    console.log(`\n3. Connecting to printer: ${printerId}`);
    try {
      const result = await Zyprint.connectToPrinter({ identifier: printerId });
      
      if (result.connected) {
        this.connectedPrinterId = printerId;
        console.log('✅ Connected successfully');
      } else {
        console.log('❌ Connection failed');
      }
    } catch (error) {
      console.error('❌ Connection error:', error);
    }
  }

  private async testStatus() {
    console.log('\n4. Checking printer status...');
    try {
      const status = await Zyprint.getPrinterStatus({ 
        identifier: this.connectedPrinterId! 
      });
      
      console.log('✅ Printer Status:', {
        status: status.status,
        paperStatus: status.paperStatus,
        connected: status.connected
      });
    } catch (error) {
      console.error('❌ Status check failed:', error);
    }
  }

  private async testTextPrint() {
    console.log('\n5. Testing text printing...');
    try {
      const testText = `
Zyprint SDK Test
================
Date: ${new Date().toLocaleDateString()}
Time: ${new Date().toLocaleTimeString()}

This is a test print from the
Seven365 Zyprinter SDK.

Features tested:
✓ Bluetooth/WiFi connection
✓ Text formatting
✓ Line feeds
✓ Paper cutting

Test completed successfully!
`;

      const result = await Zyprint.printText({
        text: testText,
        identifier: this.connectedPrinterId!
      });

      if (result.success) {
        console.log('✅ Text printed successfully');
      } else {
        console.log('❌ Text print failed');
      }
    } catch (error) {
      console.error('❌ Text print error:', error);
    }
  }

  private async testReceiptPrint() {
    console.log('\n6. Testing receipt printing...');
    try {
      const sampleReceipt = {
        header: "Seven365 Test Restaurant\n123 Tech Street\nSingapore 123456\nTel: +65 1234 5678",
        items: [
          { name: "Chicken Rice", price: "$4.50" },
          { name: "Kopi-O", price: "$1.20" },
          { name: "Ice Kacang", price: "$2.80" },
          { name: "Laksa", price: "$5.00" }
        ],
        subtotal: "$13.50",
        tax: "$1.35",
        total: "$14.85",
        footer: "\nThank you for dining with us!\nPlease come again!\n\nPowered by Seven365 POS"
      };

      const result = await Zyprint.printReceipt({
        template: sampleReceipt,
        identifier: this.connectedPrinterId!
      });

      if (result.success) {
        console.log('✅ Receipt printed successfully');
      } else {
        console.log('❌ Receipt print failed');
      }
    } catch (error) {
      console.error('❌ Receipt print error:', error);
    }
  }

  private async testDisconnection() {
    console.log('\n7. Disconnecting from printer...');
    try {
      const result = await Zyprint.disconnectFromPrinter({ 
        identifier: this.connectedPrinterId! 
      });

      if (result.disconnected) {
        console.log('✅ Disconnected successfully');
        this.connectedPrinterId = null;
      } else {
        console.log('❌ Disconnection failed');
      }
    } catch (error) {
      console.error('❌ Disconnection error:', error);
    }
  }
}

// Export for use in your app
export { ZyprintTester };

// Auto-run if this file is imported directly
if (typeof window !== 'undefined') {
  // Add test button to page
  const addTestButton = () => {
    const button = document.createElement('button');
    button.textContent = 'Run Zyprint Tests';
    button.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      z-index: 9999;
      padding: 10px 15px;
      background: #3880ff;
      color: white;
      border: none;
      border-radius: 5px;
      cursor: pointer;
      font-size: 14px;
      box-shadow: 0 2px 10px rgba(0,0,0,0.2);
    `;

    button.addEventListener('click', async () => {
      button.disabled = true;
      button.textContent = 'Running Tests...';
      
      const tester = new ZyprintTester();
      await tester.runTests();
      
      button.disabled = false;
      button.textContent = 'Run Zyprint Tests';
    });

    document.body.appendChild(button);
  };

  // Wait for DOM to be ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', addTestButton);
  } else {
    addTestButton();
  }
}