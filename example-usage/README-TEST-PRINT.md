# Test Print Formatting Examples

This example demonstrates how to use the Zyprint SDK to print the number **12345678890** with different font sizes, bold text, and images.

## Files

- `test-print-formatting.ts` - Main test print implementation with various formatting examples

## Features Demonstrated

### 1. Different Font Sizes

The test prints "12345678890" in 4 different sizes:

- **Size 1**: Normal (standard receipt text)
- **Size 2**: Large (approximately 2x normal)
- **Size 3**: XLarge (approximately 3x normal)
- **Size 4**: XXLarge (approximately 4x normal)

### 2. Bold Text

Shows the number both in regular and bold formatting:

- Regular weight
- **Bold weight**

### 3. Various Sections

Tests formatting in different receipt sections:

- **Header** - Restaurant name, sub-header, address
- **Items** - Kitchen items with different sizes
- **Modifiers** - Item add-ons with bullet points
- **Total** - Bold, large total amounts
- **Footer** - Thank you messages

## Usage

### Quick Test

Run a quick formatting test:

```typescript
import { runQuickTest } from './example-usage/test-print-formatting';

// Run the test
await runQuickTest();
```

### Comprehensive Test

Run a comprehensive test showing all formatting options:

```typescript
import { runComprehensiveTest } from './example-usage/test-print-formatting';

// Run comprehensive test
await runComprehensiveTest();
```

### Custom Usage

Use the class directly for more control:

```typescript
import { TestPrintFormatting } from './example-usage/test-print-formatting';

const tester = new TestPrintFormatting();

// Run standard test
await tester.runFormattingTest();

// Or run comprehensive test
await tester.printComprehensiveTest();
```

## In Browser

When loaded in a browser, the script automatically adds two test buttons:

- **Run Format Test** (green) - Quick formatting test
- **Comprehensive Test** (blue) - Full test with all options

## Expected Output

The test will print multiple receipts showing:

1. **Main Formatting Test**
   - Title in Size 3, Bold
   - Four lines showing sizes 1-4
   - Order number "12345678890"
   - Bold total

2. **Individual Size Tests**
   - Four separate receipts, one for each size
   - Each showing "12345678890"

3. **Bold Variation Tests**
   - Regular text version
   - Bold text version

4. **Comprehensive Test** (if run)
   - All sections formatted
   - Multiple items with modifiers
   - Complete receipt layout

## Customization

### Change the Test Number

Edit the templates in `test-print-formatting.ts` and replace "12345678890" with your desired number or text.

### Modify Font Sizes

Change the `size` parameter in the template sections:

- `"1"` - Normal
- `"2"` - Large
- `"3"` - XLarge
- `"4"` - XXLarge

### Add Bold

Set `bold: true` in any section:

```typescript
header: {
  restaurant_name: "MY TEXT",
  size: "2",
  bold: true  // Makes it bold
}
```

## Image Printing

> **Note**: The current SDK version focuses on ESC/POS text commands. Image printing can be added by:

### For Image Support

1. Convert image to monochrome bitmap
2. Use ESC/POS image printing commands
3. Example ESC/POS image command structure:

```typescript
// Image printing would use commands like:
// GS v 0 - Print raster bit image
// ESC * - Select bit image mode

// This would require additional implementation in ZywellSDK.swift
// to handle image data conversion and transmission
```

### Recommended Approach for Images

If you need to print images with the current SDK:

1. **Convert to ASCII Art**: For simple logos, convert to ASCII characters
2. **Use Text-Based Logos**: Print logo text in large, bold fonts
3. **QR Codes**: Use ESC/POS QR code commands (supported on many printers)

Example ASCII logo:

```typescript
const logo = `
 ███████ ███████ ██    ██ ███████ ███    ██ ██████   ██████  ███████ 
 ██      ██      ██    ██ ██      ████   ██      ██ ██       ██      
 ███████ █████   ██    ██ █████   ██ ██  ██  █████  ███████  ███████ 
      ██ ██       ██  ██  ██      ██  ██ ██      ██ ██    ██      ██ 
 ███████ ███████   ████   ███████ ██   ████ ██████   ██████  ███████
`;
```

## Troubleshooting

### No Printer Found

Make sure:

- Printer is powered on
- Bluetooth/WiFi is enabled
- Printer is paired (for Bluetooth)
- Printer is on same network (for WiFi)

### Print Not Working

Check:

- Printer has paper
- Connection is established
- Check console logs for errors

### Formatting Not Showing

Different printers support different ESC/POS commands. Some older printers may not support:

- All font sizes
- Bold text
- Advanced formatting

Test with the standard sizes (1-2) first if you experience issues.

## Next Steps

- Integrate into your app
- Customize receipt layout
- Add your branding
- Test with your printer model
- Implement image printing (if needed)

## Support

For issues or questions:

- Check the main README.md
- Review USAGE.md for detailed API docs
- Open an issue on GitHub
