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

export type TSize = '1' | '2' | '3' | '4' | 'normal' | 'large' | 'xlarge';
export type TModifierStyle = 'standard' | 'minimal' | 'bullet' | 'arrow' | 'detailed';
export type TModifierIndent = 'small' | 'medium' | 'large';

export interface HeaderConfig {
  restaurant_name?: string;
  sub_header?: string;
  prefix?: string;
  gst_number?: string;
  address?: string;
  phone_number?: string;
  size?: TSize;
  bold?: boolean;
}

export interface ItemConfig {
  size?: TSize;
  bold?: boolean;
}

export interface ModifierConfig {
  style?: TModifierStyle;
  indent?: TModifierIndent;
  size?: TSize;
}

export interface TotalConfig {
  size?: TSize;
  bold?: boolean;
}

export interface FooterConfig {
  message?: string;
  date_format?: string;
  time_format?: string;
  size?: TSize;
  bold?: boolean;
}

export interface KitchenItem {
  // Simple format (edit.vue)
  qty?: number;
  name?: string;
  
  // Complex format (zyprint-test.vue - from API/backend)
  menu?: {
    _id?: string;
    name: string;
    price?: string;
    categoryName?: string;
    printer?: string;
  };
  quantity?: number;
  price?: number;
  total_price?: number;
  
  // Shared properties
  modifiers?: Array<{ 
    modifier?: string;
    name: string; 
    qty?: number;
    quantity?: number;
    price?: number;
  }>;
}

export interface ReceiptTemplate {
  header?: HeaderConfig;
  kitchen?: KitchenItem[];
  items?: Array<{ name: string; price: string }>; // Legacy support
  total?: string;
  order_type?: string;
  table_name?: string;
  order_number?: string;
  footer?: FooterConfig;
  item?: ItemConfig;
  total_config?: TotalConfig;
  modifier?: ModifierConfig;
}

export interface ZyprintPlugin {
  echo(options: { value: string }): Promise<{ value: string }>;
  
  // Enhanced Printer Discovery Methods
  discoverPrinters(): Promise<{ printers: ZyPrinter[] }>;
  discoverBluetoothPrinters(): Promise<{ printers: ZyPrinter[] }>;
  discoverWiFiPrinters(options?: { networkRange?: string }): Promise<{ printers: ZyPrinter[] }>;
  discoverUSBPrinters(): Promise<{ printers: ZyPrinter[] }>;
  
  // Connection Management
  connectToPrinter(options: { identifier: string }): Promise<{ connected: boolean }>;
  disconnectFromPrinter(options: { identifier: string }): Promise<{ disconnected: boolean }>;
  
  // Printing Methods
  printText(options: { text: string; identifier: string }): Promise<{ success: boolean }>;
  printReceipt(options: { template: ReceiptTemplate; identifier: string }): Promise<{ success: boolean }>;
  
  // Printer Status
  getPrinterStatus(options: { identifier: string }): Promise<{ status: string; paperStatus: string; connected: boolean }>;
}
