import { WebPlugin } from '@capacitor/core';

import type { ZyprintPlugin, ZyPrinter } from './definitions';

export class ZyprintWeb extends WebPlugin implements ZyprintPlugin {
  async echo(options: { value: string }): Promise<{ value: string }> {
    console.log('ECHO', options);
    return options;
  }

  async discoverPrinters(): Promise<{ printers: ZyPrinter[] }> {
    console.warn('Zyprint discovery is not available on web platform');
    return { printers: [] };
  }

  async discoverBluetoothPrinters(): Promise<{ printers: ZyPrinter[] }> {
    console.warn('Zyprint Bluetooth discovery is not available on web platform');
    return { printers: [] };
  }

  async discoverWiFiPrinters(_options?: { networkRange?: string }): Promise<{ printers: ZyPrinter[] }> {
    console.warn('Zyprint WiFi discovery is not available on web platform');
    return { printers: [] };
  }

  async discoverUSBPrinters(): Promise<{ printers: ZyPrinter[] }> {
    console.warn('Zyprint USB discovery is not available on web platform');
    return { printers: [] };
  }

  async connectToPrinter(_options: { identifier: string }): Promise<{ connected: boolean }> {
    console.warn('Zyprint connection is not available on web platform');
    return { connected: false };
  }

  async disconnectFromPrinter(_options: { identifier: string }): Promise<{ disconnected: boolean }> {
    console.warn('Zyprint disconnection is not available on web platform');
    return { disconnected: false };
  }

  async printText(_options: { text: string; identifier: string }): Promise<{ success: boolean }> {
    console.warn('Zyprint printing is not available on web platform');
    return { success: false };
  }

  async printReceipt(_options: { template: Record<string, any>; identifier: string }): Promise<{ success: boolean }> {
    console.warn('Zyprint receipt printing is not available on web platform');
    return { success: false };
  }

  async printTestReceipt(_options: { template: Record<string, any>; identifier: string }): Promise<{ success: boolean }> {
    console.warn('[TEST] Zyprint test receipt printing is not available on web platform');
    return { success: false };
  }

  async getPrinterStatus(_options: { identifier: string }): Promise<{ status: string; paperStatus: string; connected: boolean }> {
    console.warn('Zyprint status check is not available on web platform');
    return { status: 'unknown', paperStatus: 'unknown', connected: false };
  }
}
