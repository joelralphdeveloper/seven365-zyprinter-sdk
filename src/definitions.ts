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
  printReceipt(options: { template: Record<string, any>; identifier: string }): Promise<{ success: boolean }>;
  
  // Printer Status
  getPrinterStatus(options: { identifier: string }): Promise<{ status: string; paperStatus: string; connected: boolean }>;
}
