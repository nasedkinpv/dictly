# Hack Nerd Font Implementation Guide

**Date:** 2025-10-06
**Goal:** Add Hack Nerd Font to iOS app for full powerline/starship support with Settings UI

---

## Why Hack Nerd Font? ✅

**Hack Nerd Font is an excellent choice:**
- ✅ **Designed for coding/terminals** - optimized for small sizes
- ✅ **Excellent character distinction** - clear 0/O, 1/l/I differences
- ✅ **Complete glyph coverage** - all powerline + Nerd Font icons
- ✅ **Free & open source** - MIT License
- ✅ **Wide usage** - popular in VS Code, terminals, IDEs
- ✅ **Good readability** - even at 12-14pt sizes
- ✅ **Active maintenance** - regularly updated

**Comparison with JetBrains Mono:**
- Hack: More compact, classic terminal feel
- JetBrains Mono: More spacious, modern look
- Both are excellent - Hack is great choice!

---

## Font Files Needed

### Required Font Variants

For iOS, you need **4 font files** (TTF format):

1. **HackNerdFont-Regular.ttf** - Normal text
2. **HackNerdFont-Bold.ttf** - Bold text
3. **HackNerdFont-Italic.ttf** - Italic text (comments, etc.)
4. **HackNerdFont-BoldItalic.ttf** - Bold + Italic

**File Format:**
- ✅ **TTF (TrueType Font)** - RECOMMENDED for iOS
- ✅ OTF (OpenType Font) - Also works, but TTF preferred

**File Size:** ~2-3MB per file = ~10MB total

### Where to Download

**Option 1: Official Nerd Fonts GitHub (RECOMMENDED)**
```bash
# Direct download URLs:
https://github.com/ryanoasis/nerd-fonts/releases/latest

# Look for: Hack.zip
# Contains all variants + documentation
```

**Option 2: Nerd Fonts Website**
```
https://www.nerdfonts.com/font-downloads
Search: "Hack"
Download: Hack.zip
```

**What's in the ZIP:**
```
Hack/
├── HackNerdFont-Regular.ttf          ← Need this
├── HackNerdFont-Bold.ttf             ← Need this
├── HackNerdFont-Italic.ttf           ← Need this
├── HackNerdFont-BoldItalic.ttf       ← Need this
├── HackNerdFontMono-Regular.ttf      ← Optional (fixed width variant)
├── HackNerdFontPropo-Regular.ttf     ← Skip (proportional variant)
└── LICENSE.md                         ← Keep for attribution
```

**Which variant to use:**
- Use **HackNerdFont** (not Mono, not Propo)
- "Mono" variant = fixed-width only (no icon spacing)
- Standard variant = better icon rendering

---

## Implementation Steps

### Step 1: Add Font Files to Xcode

1. **Create Fonts directory:**
   ```
   OmriiOS/
   └── Resources/
       └── Fonts/
           ├── HackNerdFont-Regular.ttf
           ├── HackNerdFont-Bold.ttf
           ├── HackNerdFont-Italic.ttf
           └── HackNerdFont-BoldItalic.ttf
   ```

2. **Add to Xcode:**
   - Drag font files into Xcode project
   - ✅ Check "Copy items if needed"
   - ✅ Select target: **OmriiOS**
   - ✅ Add to folder: `OmriiOS/Resources/Fonts`

3. **Verify in Build Phases:**
   - Open OmriiOS target
   - Go to "Build Phases" → "Copy Bundle Resources"
   - Verify all 4 .ttf files are listed

### Step 2: Register Fonts in Info.plist

**File:** `OmriiOS/Info.plist`

Add **UIAppFonts** key with font filenames:

```xml
<key>UIAppFonts</key>
<array>
    <string>Fonts/HackNerdFont-Regular.ttf</string>
    <string>Fonts/HackNerdFont-Bold.ttf</string>
    <string>Fonts/HackNerdFont-Italic.ttf</string>
    <string>Fonts/HackNerdFont-BoldItalic.ttf</string>
</array>
```

**Or if using Xcode UI:**
1. Open Info.plist in Xcode
2. Add new row: "Fonts provided by application" (key: UIAppFonts)
3. Type: Array
4. Add 4 string items with font filenames

### Step 3: Update Terminal Font

**File:** `OmriiOS/Views/TerminalSessionView.swift`

```swift
init(connection: SSHConnection) {
    self.connection = connection
    self.terminalView = TerminalView()

    // Configure terminal appearance to match iOS system theme
    // Try to use Hack Nerd Font, fallback to system monospace
    if let hackFont = UIFont(name: "HackNerdFont-Regular", size: 14) {
        terminalView.font = hackFont
        print("✅ Using Hack Nerd Font")
    } else {
        terminalView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        print("⚠️ Hack Nerd Font not found, using system font")
    }

    terminalView.nativeForegroundColor = .label
    terminalView.nativeBackgroundColor = .systemBackground

    // Set delegate to receive keyboard input and terminal events
    terminalView.terminalDelegate = self

    // Don't feed message yet - wait until terminal is properly sized
}
```

### Step 4: Add Font Selection to Settings

**Create new file:** `Shared/Models/TerminalFont.swift`

```swift
//
//  TerminalFont.swift
//  Omri
//
//  Terminal font configuration
//

import Foundation

enum TerminalFont: String, CaseIterable {
    case hackNerd = "Hack Nerd Font"
    case system = "System Monospace"

    var fontName: String? {
        switch self {
        case .hackNerd:
            return "HackNerdFont-Regular"
        case .system:
            return nil // Uses system monospace
        }
    }

    var displayName: String {
        self.rawValue
    }

    var supportsIcons: Bool {
        switch self {
        case .hackNerd:
            return true
        case .system:
            return false
        }
    }

    var description: String {
        switch self {
        case .hackNerd:
            return "Powerline glyphs and icons supported"
        case .system:
            return "No icon support (boxes may appear)"
        }
    }
}
```

**Update:** `Shared/Models/Settings.swift`

```swift
// Add new property
@UserDefault(key: "terminalFont", defaultValue: TerminalFont.hackNerd.rawValue)
var terminalFontRaw: String

var terminalFont: TerminalFont {
    get { TerminalFont(rawValue: terminalFontRaw) ?? .hackNerd }
    set { terminalFontRaw = newValue.rawValue }
}
```

**Create:** `Shared/UI/Settings/TerminalSettingsContent.swift`

```swift
//
//  TerminalSettingsContent.swift
//  Omri
//
//  Terminal appearance settings
//

import SwiftUI

struct TerminalSettingsContent: View {
    @ObservedObject var settings: Settings

    var body: some View {
        VStack(spacing: 20) {
            SettingsGroup("Appearance") {
                VStack(spacing: 16) {
                    SettingRow(label: "Font") {
                        Picker("Terminal Font", selection: $settings.terminalFontRaw) {
                            ForEach(TerminalFont.allCases, id: \.rawValue) { font in
                                Text(font.displayName).tag(font.rawValue)
                            }
                        }
                        #if os(macOS)
                        .pickerStyle(.menu)
                        .frame(width: 180, alignment: .trailing)
                        #else
                        .pickerStyle(.navigationLink)
                        #endif
                    }

                    if let currentFont = TerminalFont(rawValue: settings.terminalFontRaw) {
                        InformationBanner(
                            text: currentFont.description,
                            icon: currentFont.supportsIcons ? "checkmark.circle.fill" : "info.circle.fill",
                            color: currentFont.supportsIcons ? Color("BrandMint") : Color("BrandOrange")
                        )
                    }
                }
            }

            SettingsGroup("Preview") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Terminal Font Preview")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    fontPreview
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
        }
    }

    @ViewBuilder
    private var fontPreview: some View {
        let font = TerminalFont(rawValue: settings.terminalFontRaw) ?? .hackNerd

        #if os(iOS)
        let uiFont: UIFont
        if let fontName = font.fontName,
           let customFont = UIFont(name: fontName, size: 14) {
            uiFont = customFont
        } else {
            uiFont = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        }

        VStack(alignment: .leading, spacing: 4) {
            Text("user@server:~/project$ ls -la")
                .font(Font(uiFont))
            Text(" README.md  src/  main.swift")
                .font(Font(uiFont))

            if font.supportsIcons {
                Text("  ~/project  main  ")
                    .font(Font(uiFont))
                    .padding(.top, 4)
            }
        }
        #else
        // macOS preview
        Text("Preview coming soon")
            .font(.system(.caption, design: .monospaced))
        #endif
    }
}
```

**Update:** `OmriiOS/Views/SettingsView.swift`

Add new tab for Terminal settings:

```swift
// Add after General tab, before About
NavigationStack {
    ScrollView {
        TerminalSettingsContent(settings: settings)
            .padding()
    }
    .navigationTitle("Terminal")
    .navigationBarTitleDisplayMode(.large)
}
.tabItem {
    Label("Terminal", systemImage: "terminal.fill")
}
```

### Step 5: Update Terminal Manager to Use Settings

**File:** `OmriiOS/Views/TerminalSessionView.swift`

```swift
init(connection: SSHConnection) {
    self.connection = connection
    self.terminalView = TerminalView()

    // Configure terminal appearance to match iOS system theme
    let terminalFont = Settings.shared.terminalFont

    if let fontName = terminalFont.fontName,
       let customFont = UIFont(name: fontName, size: 14) {
        terminalView.font = customFont
        print("✅ Using \(terminalFont.displayName)")
    } else {
        terminalView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        print("ℹ️ Using system monospace font")
    }

    terminalView.nativeForegroundColor = .label
    terminalView.nativeBackgroundColor = .systemBackground

    // Set delegate to receive keyboard input and terminal events
    terminalView.terminalDelegate = self
}
```

---

## Verification Steps

### 1. Verify Font Installation

Add debug code to check available fonts:

```swift
// Temporary debug code
func listAvailableFonts() {
    let fontFamilies = UIFont.familyNames.sorted()

    for family in fontFamilies {
        print("Font Family: \(family)")
        let fonts = UIFont.fontNames(forFamilyName: family)
        for font in fonts {
            print("  - \(font)")
        }
    }
}

// Call in viewDidLoad or onAppear
listAvailableFonts()

// Look for output:
// Font Family: Hack Nerd Font
//   - HackNerdFont-Regular
//   - HackNerdFont-Bold
//   - HackNerdFont-Italic
//   - HackNerdFont-BoldItalic
```

### 2. Test Font Rendering

```swift
// Test font loads correctly
if let testFont = UIFont(name: "HackNerdFont-Regular", size: 14) {
    print("✅ Hack Nerd Font loaded: \(testFont.fontName)")
} else {
    print("❌ Hack Nerd Font NOT FOUND - check Info.plist")
}
```

### 3. Test with Starship

On remote machine:

```bash
# Install starship
curl -sS https://starship.rs/install.sh | sh

# Configure zsh
echo 'eval "$(starship init zsh)"' >> ~/.zshrc

# Reconnect and verify icons show correctly
```

---

## Common Issues & Solutions

### Issue: Font not found

**Symptom:** `UIFont(name:)` returns nil

**Solutions:**
1. ✅ Check font files are in "Copy Bundle Resources"
2. ✅ Verify Info.plist has correct UIAppFonts entries
3. ✅ Clean build folder (Product → Clean Build Folder)
4. ✅ Verify font filename matches exactly (case-sensitive)
5. ✅ Use font family name, not file name:
   ```swift
   // ❌ Wrong: UIFont(name: "Hack Nerd Font", ...)
   // ✅ Right: UIFont(name: "HackNerdFont-Regular", ...)
   ```

### Issue: Icons still show as boxes

**Symptom:** Powerline glyphs render as □

**Solutions:**
1. ✅ Verify using **HackNerdFont** not **HackNerdFontMono**
2. ✅ Check terminal is using the font:
   ```swift
   print("Current font: \(terminalView.font.fontName)")
   ```
3. ✅ Verify starship is using icons in config
4. ✅ Test with simple powerline character:
   ```bash
   echo "\ue0b0"  # Should show right arrow
   ```

### Issue: Bold/Italic not working

**Symptom:** All text looks the same weight

**Solutions:**
1. ✅ Verify all 4 font variants are in bundle
2. ✅ SwiftTerm should automatically use variants
3. ✅ Check all fonts are in Info.plist

---

## File Structure After Implementation

```
OmriiOS/
├── Info.plist                         # Updated with UIAppFonts
├── Resources/
│   └── Fonts/
│       ├── HackNerdFont-Regular.ttf
│       ├── HackNerdFont-Bold.ttf
│       ├── HackNerdFont-Italic.ttf
│       └── HackNerdFont-BoldItalic.ttf
└── Views/
    ├── SettingsView.swift             # Added Terminal tab
    └── TerminalSessionView.swift      # Updated to use Settings font

Shared/
├── Models/
│   ├── Settings.swift                 # Added terminalFont property
│   └── TerminalFont.swift             # NEW: Font enum
└── UI/
    └── Settings/
        └── TerminalSettingsContent.swift  # NEW: Terminal settings UI
```

---

## App Size Impact

**Before:** ~15MB (example)
**After:** ~25MB (+10MB for fonts)

**Breakdown:**
- HackNerdFont-Regular.ttf: ~2.8MB
- HackNerdFont-Bold.ttf: ~2.7MB
- HackNerdFont-Italic.ttf: ~2.8MB
- HackNerdFont-BoldItalic.ttf: ~2.7MB
- **Total:** ~11MB

**Worth it?** YES
- Enables full starship/powerline support
- Professional terminal experience
- No user configuration needed
- Industry standard for terminal apps

---

## Testing Checklist

After implementation:

- [ ] Build succeeds with zero warnings
- [ ] Font family appears in debug log
- [ ] UIFont(name:) successfully loads font
- [ ] Terminal displays in Hack Nerd Font
- [ ] Settings UI shows font picker
- [ ] Font selection persists after app restart
- [ ] Powerline arrows render correctly
- [ ] Starship icons display properly
- [ ] Git branch symbol shows correctly
- [ ] Bold text appears bold
- [ ] Italic text appears italic
- [ ] Font preview in settings works

---

## License & Attribution

**Hack Nerd Font License:** MIT License

**Attribution** (add to app About screen):

```
Hack Nerd Font
Copyright (c) 2018, Ryan L McIntyre
MIT License
https://github.com/ryanoasis/nerd-fonts
```

---

## Summary

**Answers to your questions:**

1. ✅ **Can we use Hack Nerd Font?** YES - excellent choice!
2. ✅ **Can it be in GUI settings?** YES - font picker in Settings tab
3. ✅ **Which formats needed?** TTF format, 4 variants (Regular, Bold, Italic, BoldItalic)

**Implementation:**
- Download Hack.zip from nerdfonts.com
- Add 4 TTF files to Xcode
- Register in Info.plist
- Update terminal to use font
- Add Settings UI for font selection
- Total size: ~11MB added to app

**Result:** Full powerline/starship support with user-configurable fonts!
