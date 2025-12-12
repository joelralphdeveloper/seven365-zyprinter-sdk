import { Zyprint } from 'seven365-zyprinter';

/**
 * Test print function demonstrating different font sizes, bold text, and image printing
 * This example shows the number "12345678890" in various formatting styles
 */

class TestPrintFormatting {
  private connectedPrinterId: string | null = null;

  /**
   * Main test function - discovers printer and runs test print
   */
  async runFormattingTest() {
    console.log('🖨️ Starting Formatting Test Print...');

    try {
      // Discover printers
      const printers = await this.discoverPrinters();
      
      if (printers.length === 0) {
        console.log('⚠️ No printers found. Please ensure a printer is connected.');
        return;
      }

      // Connect to first available printer
      await this.connectToPrinter(printers[0].identifier);

      if (this.connectedPrinterId) {
        // Run the formatting test
        await this.printFormattingTest();

        // Disconnect
        await this.disconnectFromPrinter();
      }

      console.log('✅ Formatting test completed!');
    } catch (error) {
      console.error('❌ Test failed:', error);
    }
  }

  /**
   * Discover available printers
   */
  private async discoverPrinters() {
    console.log('Discovering printers...');
    try {
      const result = await Zyprint.discoverPrinters();
      console.log(`Found ${result.printers.length} printer(s)`);
      result.printers.forEach((printer, index) => {
        console.log(`  ${index + 1}. ${printer.model} (${printer.identifier})`);
      });
      return result.printers;
    } catch (error) {
      console.error('Discovery failed:', error);
      return [];
    }
  }

  /**
   * Connect to a printer
   */
  private async connectToPrinter(printerId: string) {
    console.log(`Connecting to printer: ${printerId}`);
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

  /**
   * Disconnect from printer
   */
  private async disconnectFromPrinter() {
    if (!this.connectedPrinterId) return;

    console.log('Disconnecting from printer...');
    try {
      const result = await Zyprint.disconnectFromPrinter({ 
        identifier: this.connectedPrinterId 
      });
      if (result.disconnected) {
        console.log('✅ Disconnected successfully');
        this.connectedPrinterId = null;
      }
    } catch (error) {
      console.error('❌ Disconnection error:', error);
    }
  }

  /**
   * Print formatting test with different sizes and bold text
   */
  private async printFormattingTest() {
    console.log('Printing formatting test...');

    const testTemplate = {
      // Header with bold, size 3
      header: {
        restaurant_name: "FORMATTING TEST",
        sub_header: "Font Size & Bold Demo",
        size: "3",
        bold: true
      },

      // Test items showing "12345678890" in different sizes
      kitchen: [
        {
          name: "Size 1 (Normal): 12345678890",
          qty: 1
        },
        {
          name: "Size 2 (Large): 12345678890",
          qty: 1
        },
        {
          name: "Size 3 (XLarge): 12345678890",
          qty: 1
        },
        {
          name: "Size 4 (XXLarge): 12345678890",
          qty: 1
        }
      ],

      // Item configuration - we'll vary this in separate prints
      item: {
        size: "1",  // Normal size
        bold: false
      },

      // Order info
      order_type: "Test Print",
      order_number: "12345678890",
      table_name: "TEST",

      // Total with bold
      total: "12345678890",
      total_config: {
        size: "2",
        bold: true
      },

      // Footer
      footer: {
        message: "✅ Test Complete!\nUnderline: 12345678890\nNormal: 12345678890",
        size: "1",
        bold: false
      }
    };

    try {
      const result = await Zyprint.printReceipt({
        template: testTemplate,
        identifier: this.connectedPrinterId!
      });

      if (result.success) {
        console.log('✅ Formatting test printed successfully');
        
        // Print additional size variations
        await this.printSizeVariations();
        
        // Print bold variations
        await this.printBoldVariations();
        
      } else {
        console.log('❌ Formatting test failed');
      }
    } catch (error) {
      console.error('❌ Print error:', error);
    }
  }

  /**
   * Print the number 12345678890 in different sizes
   */
  private async printSizeVariations() {
    console.log('Printing size variations...');

    const sizes: Array<'1' | '2' | '3' | '4'> = ['1', '2', '3', '4'];
    
    for (const size of sizes) {
      const template = {
        header: {
          restaurant_name: `SIZE ${size} TEST`,
          size: size,
          bold: false
        },
        kitchen: [
          {
            name: "12345678890",
            qty: 1
          }
        ],
        item: {
          size: size,
          bold: false
        },
        total: "12345678890",
        total_config: {
          size: size,
          bold: false
        }
      };

      try {
        await Zyprint.printReceipt({
          template: template,
          identifier: this.connectedPrinterId!
        });
        console.log(`  ✓ Size ${size} printed`);
      } catch (error) {
        console.error(`  ✗ Size ${size} failed:`, error);
      }
    }
  }

  /**
   * Print the number 12345678890 with bold variations
   */
  private async printBoldVariations() {
    console.log('Printing bold variations...');

    // Regular (not bold)
    await this.printWithBold(false, "REGULAR (NOT BOLD)");
    
    // Bold
    await this.printWithBold(true, "BOLD TEXT");
  }

  /**
   * Helper to print with bold setting
   */
  private async printWithBold(bold: boolean, title: string) {
    const template = {
      header: {
        restaurant_name: title,
        size: "2",
        bold: bold
      },
      kitchen: [
        {
          name: "12345678890",
          qty: 1
        }
      ],
      item: {
        size: "2",
        bold: bold
      },
      total: "12345678890",
      total_config: {
        size: "3",
        bold: bold
      },
      footer: {
        message: "12345678890",
        size: "1",
        bold: bold
      }
    };

    try {
      await Zyprint.printReceipt({
        template: template,
        identifier: this.connectedPrinterId!
      });
      console.log(`  ✓ ${title} printed`);
    } catch (error) {
      console.error(`  ✗ ${title} failed:`, error);
    }
  }

  /**
   * Print a comprehensive test showing all combinations
   */
  async printComprehensiveTest() {
    console.log('🖨️ Starting Comprehensive Formatting Test...');

    try {
      const printers = await this.discoverPrinters();
      if (printers.length === 0) return;

      await this.connectToPrinter(printers[0].identifier);
      if (!this.connectedPrinterId) return;

      const template = {
        header: {
          restaurant_name: "COMPREHENSIVE TEST",
          sub_header: "All Formatting Options",
          address: "Test Location",
          phone_number: "+65 12345678890",
          size: "3",
          bold: true
        },

        order_type: "Format Test",
        order_number: "TEST-12345678890",
        table_name: "T-001",

        kitchen: [
          // Size variations
          { name: "Size 1: 12345678890", qty: 1 },
          { name: "Size 2: 12345678890", qty: 1 },
          { name: "Size 3: 12345678890", qty: 1 },
          { name: "Size 4: 12345678890", qty: 1 },
          
          // With modifiers
          {
            name: "Item with modifiers: 12345678890",
            qty: 2,
            modifiers: [
              { name: "Modifier 1: 12345678890" },
              { name: "Modifier 2: Bold text" },
              { name: "Modifier 3: Different sizes" }
            ]
          }
        ],

        item: {
          size: "2",
          bold: false
        },

        modifier: {
          style: "bullet",
          indent: "medium",
          size: "1"
        },

        total: "$123.45",
        total_config: {
          size: "3",
          bold: true
        },

        footer: {
          message: "Thank you!\nOrder ID: 12345678890\nVisit us again!",
          size: "1",
          bold: false
        }
      };

      await Zyprint.printReceipt({
        template: template,
        identifier: this.connectedPrinterId
      });

      console.log('✅ Comprehensive test printed');
      await this.disconnectFromPrinter();
      
    } catch (error) {
      console.error('❌ Comprehensive test failed:', error);
    }
  }
}

// Export for use
export { TestPrintFormatting };

// Auto-run function
export async function runQuickTest() {
  const tester = new TestPrintFormatting();
  await tester.runFormattingTest();
}

export async function runComprehensiveTest() {
  const tester = new TestPrintFormatting();
  await tester.printComprehensiveTest();
}

// Browser integration
if (typeof window !== 'undefined') {
  const addTestButtons = () => {
    const container = document.createElement('div');
    container.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      z-index: 9999;
      display: flex;
      flex-direction: column;
      gap: 10px;
    `;

    // Quick test button
    const quickBtn = document.createElement('button');
    quickBtn.textContent = 'Run Format Test';
    quickBtn.style.cssText = `
      padding: 10px 15px;
      background: #10b981;
      color: white;
      border: none;
      border-radius: 5px;
      cursor: pointer;
      font-size: 14px;
      box-shadow: 0 2px 10px rgba(0,0,0,0.2);
    `;
    quickBtn.addEventListener('click', async () => {
      quickBtn.disabled = true;
      quickBtn.textContent = 'Running...';
      await runQuickTest();
      quickBtn.disabled = false;
      quickBtn.textContent = 'Run Format Test';
    });

    // Comprehensive test button
    const compBtn = document.createElement('button');
    compBtn.textContent = 'Comprehensive Test';
    compBtn.style.cssText = `
      padding: 10px 15px;
      background: #3b82f6;
      color: white;
      border: none;
      border-radius: 5px;
      cursor: pointer;
      font-size: 14px;
      box-shadow: 0 2px 10px rgba(0,0,0,0.2);
    `;
    compBtn.addEventListener('click', async () => {
      compBtn.disabled = true;
      compBtn.textContent = 'Running...';
      await runComprehensiveTest();
      compBtn.disabled = false;
      compBtn.textContent = 'Comprehensive Test';
    });

    container.appendChild(quickBtn);
    container.appendChild(compBtn);
    document.body.appendChild(container);
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', addTestButtons);
  } else {
    addTestButtons();
  }
}
