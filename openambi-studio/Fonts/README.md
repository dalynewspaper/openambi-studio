# Kode Mono Fonts

This directory should contain the Kode Mono font files.

## Required Font Files

Please add the following font files to this directory:

- `KodeMono-Regular.ttf`
- `KodeMono-Medium.ttf`
- `KodeMono-SemiBold.ttf`
- `KodeMono-Bold.ttf`

## Font Name

The font is registered in `Info.plist` and can be used in SwiftUI with:
```swift
.font(.custom("Kode Mono", size: 40))
```

**Note:** The exact font name may vary depending on the font file. Common variations:
- "Kode Mono"
- "KodeMono-Regular"
- "KodeMono"

If the font doesn't appear, check the font's PostScript name using Font Book on macOS, or use:
```swift
.font(.custom("KodeMono-Regular", size: 40))
```

## Download

Kode Mono can be downloaded from:
- Google Fonts: https://fonts.google.com/specimen/Kode+Mono
- Or your font provider

