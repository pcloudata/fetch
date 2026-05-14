# Fetch

Fetch is a native SwiftUI iOS app exploring a liquid glass interface concept with animated color fields, translucent material panels, tactile controls, and a floating glass dock.

## Requirements

- Xcode 16.4 or newer
- iOS 17.0 or newer deployment target

## Run Locally

Open `Fetch.xcodeproj` in Xcode, select the `Fetch` scheme, choose an iPhone simulator, and press Run.

Command-line build:

```sh
xcodebuild -project Fetch.xcodeproj -scheme Fetch -sdk iphonesimulator -derivedDataPath ./DerivedData CODE_SIGNING_ALLOWED=NO build
```

## Project Structure

- `Fetch/FetchApp.swift`: app entry point
- `Fetch/ContentView.swift`: main SwiftUI screen and interactions
- `Fetch/GlassComponents.swift`: reusable liquid glass visual components

## Notes

Generated build output is intentionally ignored through `.gitignore`, including `DerivedData/`, simulator artifacts, and local Xcode user state.
