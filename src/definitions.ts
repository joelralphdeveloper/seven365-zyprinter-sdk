// Enhanced printer interface with connection type details
export interface ZyPrinter {
  identifier: string;
  model: string;
  status: string;
  connectionType: 'bluetooth' | 'wifi' | 'usb';
  ipAddress?: string;
  port?: number;
  rssi?: number;
}

export interface ReceiptFormatting {
  headerSize?: 'normal' | 'large' | 'xlarge' | 1 | 2 | 3 | 4;
  itemSize?: 'normal' | 'large' | 'xlarge' | 1 | 2 | 3 | 4;
  itemBold?: boolean;
  totalSize?: 'normal' | 'large' | 'xlarge' | 1 | 2 | 3 | 4;
  totalBold?: boolean;
  footerSize?: 'normal' | 'large' | 'xlarge' | 1 | 2 | 3 | 4;
}

export interface ReceiptTemplate {
  header?: string;
  items?: Array<{ name: string; price: string }>;
  total?: string;
  footer?: string;
  formatting?: ReceiptFormatting;
}

export interface ZyprintPlugin {
  echo(options: { value: string }): Promise<{ value: string }>;
  
  // Enhanced Printer Discovery Methods
  discoverPrinters(): Promise<{ printers: ZyPrinter[] }>;
  discoverBluetoothPrinters(): Promise<{ printers: ZyPrinter[] }>;
  discoverWiFiPrinters(options?: { networkRange?: string }): Promise<{ printers: ZyPrinter[] }>;
  
  // Connection Management
  connectToPrinter(options: { identifier: string }): Promise<{ connected: boolean }>;
  disconnectFromPrinter(options: { identifier: string }): Promise<{ disconnected: boolean }>;
  
  // Printing Methods
  printText(options: { text: string; identifier: string }): Promise<{ success: boolean }>;
  printReceipt(options: { template: ReceiptTemplate; identifier: string }): Promise<{ success: boolean }>;
  
  // Printer Status
  getPrinterStatus(options: { identifier: string }): Promise<{ status: string; paperStatus: string; connected: boolean }>;
}
