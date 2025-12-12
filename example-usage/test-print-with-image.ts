import { Zyprint } from 'seven365-zyprinter';

/**
 * Advanced test print with image support
 * Demonstrates printing images on thermal receipt printers
 */

class TestPrintWithImage {
  private connectedPrinterId: string | null = null;

  /**
   * Print a receipt with an image/logo
   * Note: This requires image to be converted to ESC/POS bitmap format
   */
  async printReceiptWithLogo() {
    console.log('🖨️ Starting Receipt Print with Logo...');

    try {
      const printers = await Zyprint.discoverPrinters();
      if (printers.length === 0) {
        console.log('⚠️ No printers found');
        return;
      }

      const result = await Zyprint.connectToPrinter({ 
        identifier: printers[0].identifier 
      });
      
      if (!result.connected) {
        console.log('❌ Connection failed');
        return;
      }

      this.connectedPrinterId = printers[0].identifier;

      // Option 1: Print ASCII Art Logo
      await this.printWithASCIILogo();

      // Option 2: Print large bold text as "logo"
      await this.printWithTextLogo();

      // Disconnect
      await Zyprint.disconnectFromPrinter({ 
        identifier: this.connectedPrinterId 
      });

      console.log('✅ Receipt with logo printed!');
    } catch (error) {
      console.error('❌ Print failed:', error);
    }
  }

  /**
   * Print receipt with ASCII art logo
   */
  private async printWithASCIILogo() {
    const asciiLogo = `
   _____ ________      ________ _   _ ____   __   ____  
  / ____|  ____\\ \\    / /  ____| \\ | |___ \\ / /  | ___| 
 | (___ | |__   \\ \\  / /| |__  |  \\| | __) / /_  |___ \\ 
  \\___ \\|  __|   \\ \\/ / |  __| | . \` ||__ < '_ \\  ___) |
  ____) | |____   \\  /  | |____| |\\  |___) | (_) ||____/ 
 |_____/|______|   \\/   |______|_| \\_|____/ \\___/ |_____/
    `;

    const template = {
      header: {
        restaurant_name: asciiLogo,
        sub_header: "Receipt #12345678890",
        size: "1",
        bold: false
      },
      kitchen: [
        { name: "Order Number: 12345678890", qty: 1 }
      ],
      total: "$123.45",
      footer: {
        message: "Thank you for your order!",
        size: "1",
        bold: false
      }
    };

    await Zyprint.printReceipt({
      template: template,
      identifier: this.connectedPrinterId!
    });

    console.log('  ✓ ASCII logo receipt printed');
  }

  /**
   * Print receipt with large text logo
   */
  private async printWithTextLogo() {
    const template = {
      header: {
        restaurant_name: "SEVEN365",
        sub_header: "Premium Restaurant",
        address: "123 Main Street",
        phone_number: "Tel: 12345678890",
        size: "4",  // Largest size for logo effect
        bold: true
      },
      order_type: "DINE-IN",
      order_number: "12345678890",
      table_name: "Table 5",
      kitchen: [
        {
          name: "Chicken Rice",
          qty: 2,
          modifiers: [
            { name: "Extra Sauce" },
            { name: "No Cucumber" }
          ]
        },
        {
          name: "Ice Lemon Tea",
          qty: 2
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
      total: "$25.80",
      total_config: {
        size: "3",
        bold: true
      },
      footer: {
        message: "Thank you!\nOrder #12345678890\nPlease come again!",
        size: "1",
        bold: false
      }
    };

    await Zyprint.printReceipt({
      template: template,
      identifier: this.connectedPrinterId!
    });

    console.log('  ✓ Text logo receipt printed');
  }

  /**
   * Print a QR code (if printer supports it)
   * This is a placeholder - would need ESC/POS QR code commands
   */
  async printQRCode(data: string) {
    console.log('📱 QR Code printing (future feature)');
    console.log(`   Data: ${data}`);
    
    // Note: Implementation would require:
    // 1. ESC/POS QR code commands (GS ( k)
    // 2. Printer support verification
    // 3. Custom print command method in SDK
    
    // Example ESC/POS QR code command structure (for reference):
    // [0x1D, 0x28, 0x6B, ...] - Store QR code data
    // [0x1D, 0x28, 0x6B, ...] - Print QR code
  }

  /**
   * Print barcode (if printer supports it)
   */
  async printBarcode(code: string) {
    console.log('📊 Barcode printing (future feature)');
    console.log(`   Code: ${code}`);
    
    // Note: Implementation would require:
    // 1. ESC/POS barcode commands (GS k)
    // 2. Barcode type selection
    // 3. Custom print command method in SDK
  }
}

/**
 * Example: Print the number 12345678890 as a barcode
 */
export async function printNumberAsBarcode(number: string = "12345678890") {
  console.log(`Will print barcode for: ${number}`);
  // Implementation pending barcode support in SDK
}

/**
 * Example: Print the number 12345678890 as a QR code
 */
export async function printNumberAsQRCode(number: string = "12345678890") {
  console.log(`Will print QR code for: ${number}`);
  // Implementation pending QR code support in SDK
}

// Export main class
export { TestPrintWithImage };

// Quick run function
export async function runImageTest() {
  const tester = new TestPrintWithImage();
  await tester.printReceiptWithLogo();
}

// Browser integration
if (typeof window !== 'undefined') {
  const addImageTestButton = () => {
    const button = document.createElement('button');
    button.textContent = '🖼️ Print with Logo';
    button.style.cssText = `
      position: fixed;
      bottom: 20px;
      right: 20px;
      z-index: 9999;
      padding: 12px 20px;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      border: none;
      border-radius: 8px;
      cursor: pointer;
      font-size: 14px;
      font-weight: 600;
      box-shadow: 0 4px 15px rgba(0,0,0,0.3);
      transition: transform 0.2s;
    `;

    button.addEventListener('mouseover', () => {
      button.style.transform = 'scale(1.05)';
    });

    button.addEventListener('mouseout', () => {
      button.style.transform = 'scale(1)';
    });

    button.addEventListener('click', async () => {
      button.disabled = true;
      button.textContent = '⏳ Printing...';
      
      try {
        await runImageTest();
        button.textContent = '✅ Printed!';
        setTimeout(() => {
          button.textContent = '🖼️ Print with Logo';
          button.disabled = false;
        }, 2000);
      } catch (error) {
        button.textContent = '❌ Failed';
        setTimeout(() => {
          button.textContent = '🖼️ Print with Logo';
          button.disabled = false;
        }, 2000);
      }
    });

    document.body.appendChild(button);
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', addImageTestButton);
  } else {
    addImageTestButton();
  }
}
