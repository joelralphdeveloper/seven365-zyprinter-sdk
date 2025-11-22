# seven365-zyprinter

plugin for integration of zyprinter

## Install

```bash
npm install seven365-zyprinter
npx cap sync
```

## API

<docgen-index>

* [`echo(...)`](#echo)
* [`discoverPrinters()`](#discoverprinters)
* [`discoverBluetoothPrinters()`](#discoverbluetoothprinters)
* [`discoverWiFiPrinters(...)`](#discoverwifiprinters)
* [`connectToPrinter(...)`](#connecttoprinter)
* [`disconnectFromPrinter(...)`](#disconnectfromprinter)
* [`printText(...)`](#printtext)
* [`printReceipt(...)`](#printreceipt)
* [`getPrinterStatus(...)`](#getprinterstatus)
* [Interfaces](#interfaces)
* [Type Aliases](#type-aliases)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

### echo(...)

```typescript
echo(options: { value: string; }) => Promise<{ value: string; }>
```

| Param         | Type                            |
| ------------- | ------------------------------- |
| **`options`** | <code>{ value: string; }</code> |

**Returns:** <code>Promise&lt;{ value: string; }&gt;</code>

--------------------


### discoverPrinters()

```typescript
discoverPrinters() => Promise<{ printers: ZyPrinter[]; }>
```

**Returns:** <code>Promise&lt;{ printers: ZyPrinter[]; }&gt;</code>

--------------------


### discoverBluetoothPrinters()

```typescript
discoverBluetoothPrinters() => Promise<{ printers: ZyPrinter[]; }>
```

**Returns:** <code>Promise&lt;{ printers: ZyPrinter[]; }&gt;</code>

--------------------


### discoverWiFiPrinters(...)

```typescript
discoverWiFiPrinters(options?: { networkRange?: string | undefined; } | undefined) => Promise<{ printers: ZyPrinter[]; }>
```

| Param         | Type                                    |
| ------------- | --------------------------------------- |
| **`options`** | <code>{ networkRange?: string; }</code> |

**Returns:** <code>Promise&lt;{ printers: ZyPrinter[]; }&gt;</code>

--------------------


### connectToPrinter(...)

```typescript
connectToPrinter(options: { identifier: string; }) => Promise<{ connected: boolean; }>
```

| Param         | Type                                 |
| ------------- | ------------------------------------ |
| **`options`** | <code>{ identifier: string; }</code> |

**Returns:** <code>Promise&lt;{ connected: boolean; }&gt;</code>

--------------------


### disconnectFromPrinter(...)

```typescript
disconnectFromPrinter(options: { identifier: string; }) => Promise<{ disconnected: boolean; }>
```

| Param         | Type                                 |
| ------------- | ------------------------------------ |
| **`options`** | <code>{ identifier: string; }</code> |

**Returns:** <code>Promise&lt;{ disconnected: boolean; }&gt;</code>

--------------------


### printText(...)

```typescript
printText(options: { text: string; identifier: string; }) => Promise<{ success: boolean; }>
```

| Param         | Type                                               |
| ------------- | -------------------------------------------------- |
| **`options`** | <code>{ text: string; identifier: string; }</code> |

**Returns:** <code>Promise&lt;{ success: boolean; }&gt;</code>

--------------------


### printReceipt(...)

```typescript
printReceipt(options: { template: Record<string, any>; identifier: string; }) => Promise<{ success: boolean; }>
```

| Param         | Type                                                                                            |
| ------------- | ----------------------------------------------------------------------------------------------- |
| **`options`** | <code>{ template: <a href="#record">Record</a>&lt;string, any&gt;; identifier: string; }</code> |

**Returns:** <code>Promise&lt;{ success: boolean; }&gt;</code>

--------------------


### getPrinterStatus(...)

```typescript
getPrinterStatus(options: { identifier: string; }) => Promise<{ status: string; paperStatus: string; connected: boolean; }>
```

| Param         | Type                                 |
| ------------- | ------------------------------------ |
| **`options`** | <code>{ identifier: string; }</code> |

**Returns:** <code>Promise&lt;{ status: string; paperStatus: string; connected: boolean; }&gt;</code>

--------------------


### Interfaces


#### ZyPrinter

| Prop                 | Type                                        |
| -------------------- | ------------------------------------------- |
| **`identifier`**     | <code>string</code>                         |
| **`model`**          | <code>string</code>                         |
| **`status`**         | <code>string</code>                         |
| **`connectionType`** | <code>'bluetooth' \| 'wifi' \| 'usb'</code> |
| **`ipAddress`**      | <code>string</code>                         |
| **`port`**           | <code>number</code>                         |
| **`rssi`**           | <code>number</code>                         |


### Type Aliases


#### Record

Construct a type with a set of properties K of type T

<code>{ [P in K]: T; }</code>

</docgen-api>
# seven365-zyprinter-sdk
