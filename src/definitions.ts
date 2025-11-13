export interface ZyprintPlugin {
  echo(options: { value: string }): Promise<{ value: string }>;
  
  // Printer Discovery and Connection
  discoverPrinters(): Promise<{ printers: Array<{ identifier: string; model: string; status: string }> }>;
  connectToPrinter(options: { identifier: string }): Promise<{ connected: boolean }>;
  disconnectFromPrinter(options: { identifier: string }): Promise<{ disconnected: boolean }>;
  
  // Printing Methods
  printText(options: { text: string; identifier: string }): Promise<{ success: boolean }>;
  printReceipt(options: { template: Record<string, any>; identifier: string }): Promise<{ success: boolean }>;
  
  // Printer Status
  getPrinterStatus(options: { identifier: string }): Promise<{ status: string; paperStatus: string; connected: boolean }>;
}
