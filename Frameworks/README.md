# Zywell Framework Directory

This directory should contain the Zywell printer SDK framework.

## Required Framework

You need to download and place the Zywell printer SDK here:

- Framework name: `ZywellPrinter.xcframework` (or similar)
- Source: Zywell developer portal or SDK download
- Format: .xcframework or .framework

## Installation Steps

1. Download the Zywell printer SDK from their official source
2. Extract the framework file
3. Copy it to this Frameworks/ directory
4. Update the podspec to reference it

## Example Structure
```
Frameworks/
├── ZywellPrinter.xcframework/
│   ├── Info.plist
│   ├── ios-arm64/
│   └── ios-x86_64-simulator/
```

## Podspec Configuration
Once you have the framework, update `Seven365Zyprinter.podspec`:

```ruby
s.vendored_frameworks = 'Frameworks/ZywellPrinter.xcframework'
```