# Terminal Resizing & Font Support Analysis

**Date:** 2025-10-06
**Status:** 🔍 Issues Found - Needs Attention

---

## Issue 1: Terminal Resizing Logic ⚠️

### Current Implementation Analysis

**File:** `OmriiOS/Views/TerminalSessionView.swift`

**Code Flow:**
```swift
// 1. GeometryReader calculates available space
GeometryReader { geometry in
    let adjustedSize = CGSize(
        width: geometry.size.width - 8,
        height: geometry.size.height - 8
    )

    // 2. Pass size to UIViewRepresentable
    iOSTerminalView(manager: manager, size: adjustedSize)
}

// 3. UIViewRepresentable sets frame explicitly
func makeUIView(context: Context) -> TerminalView {
    terminalView.frame = CGRect(origin: .zero, size: size)  // ⚠️ EXPLICIT FRAME
    terminalView.autoresizingMask = [.flexibleWidth, .flexibleHeight]  // ⚠️ CONFLICT?
}

// 4. updateUIView updates frame on size changes
func updateUIView(_ uiView: TerminalView, context: Context) {
    if uiView.frame.size != size {
        uiView.frame = CGRect(origin: .zero, size: size)
        resizeTerminal(uiView, to: size)
    }
}
```

### Potential Issue

**Problem:** Mixing explicit frame setting with `autoresizingMask`

The `autoresizingMask` property is designed for automatic resizing based on superview changes, but we're also manually setting the frame in both `makeUIView` and `updateUIView`. This creates two sources of truth:

1. **SwiftUI's GeometryReader** → calculates size → passes to UIViewRepresentable
2. **UIKit's autoresizingMask** → tries to auto-resize based on superview

**Why iPad Might Have Issues:**
- iPad has different size classes (regular/regular vs compact/regular)
- Multitasking/Split View creates dynamic size changes
- Autoresizing mask might conflict with manual frame updates
- GeometryReader might not trigger `updateUIView` on every size change

### Testing Needed

Test scenarios:
- [ ] iPad portrait → landscape rotation
- [ ] iPad Split View (1/3, 1/2, 2/3 layouts)
- [ ] iPad Slide Over
- [ ] iPad Stage Manager resizing
- [ ] iPhone rotation (verify still works)

### Recommended Fix (If Issue Confirmed)

**Option A: Remove autoresizingMask (RECOMMENDED)**
```swift
func makeUIView(context: Context) -> TerminalView {
    let terminalView = manager.terminalView
    terminalView.frame = CGRect(origin: .zero, size: size)
    // REMOVE: terminalView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    // Rely solely on SwiftUI's updateUIView for resizing
}
```

**Option B: Use SwiftUI's `.frame()` modifier instead**
```swift
iOSTerminalView(manager: manager, size: adjustedSize)
    .frame(width: adjustedSize.width, height: adjustedSize.height)
    .padding(4)
```

---

## Issue 2: Font Support for Starship/Zsh ⚠️⚠️⚠️

### Current Implementation

**File:** `OmriiOS/Views/TerminalSessionView.swift:286`

```swift
terminalView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
```

### The Problem: No Powerline Glyph Support

**System Monospace Font Does NOT Include:**
- ❌ Powerline glyphs (separators, arrows)
- ❌ Nerd Font icons (git branch, folder icons, etc.)
- ❌ Special symbols used by Starship
- ❌ Dev icons, file type icons

**What Happens with Starship/Zsh Powerline:**
- User sees **boxes (□)** or **question marks (?)** instead of icons
- Powerline arrows show as broken characters
- Git branch symbol displays incorrectly
- Overall prompt looks broken

**Example - What User Sees:**
```
# Expected (with Nerd Font):
 ~/project  main

# Actual (with system font):
□ ~/project □ main □
```

### SwiftTerm Font Capabilities

From research, SwiftTerm **DOES** support:
- ✅ Custom fonts via `font` property
- ✅ Unicode rendering (emoji, combining characters)
- ✅ Font variants (bold, italic, bold+italic)
- ✅ Nerd Fonts with powerline glyphs

**The library supports it - we're just not using it!**

### Starship Fallback Mode

Starship **does** have a no-nerd-font preset:
```toml
# Starship config - plain mode (no icons)
[character]
success_symbol = "[>](bold green)"
error_symbol = "[>](bold red)"

[git_branch]
symbol = "branch "
```

But this requires **user configuration** on remote machine.

### Solutions

#### Option 1: Bundle a Nerd Font (RECOMMENDED for UX)

**Benefits:**
- ✅ Works out of the box
- ✅ Starship/powerline "just works"
- ✅ Professional terminal experience
- ✅ Consistent across all users

**Implementation:**
```swift
// 1. Add font to bundle (e.g., JetBrainsMono Nerd Font)
// 2. Register in Info.plist
// 3. Use in terminal:

if let nerdFont = UIFont(name: "JetBrainsMonoNerdFont-Regular", size: 14) {
    terminalView.font = nerdFont
} else {
    terminalView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
}
```

**Popular Nerd Fonts for Terminals:**
- **JetBrains Mono Nerd Font** (recommended - excellent readability)
- **Fira Code Nerd Font** (with ligatures)
- **Hack Nerd Font** (classic terminal font)
- **Cascadia Code Nerd Font** (Microsoft's terminal font)

**File Size:** ~2-3MB per font variant (Regular, Bold, Italic, BoldItalic)

#### Option 2: Document Limitation

Add to app description/docs:
- "Note: Powerline glyphs and Nerd Font icons are not currently supported. Use starship's plain preset for best results."

**User workaround on remote machine:**
```bash
# ~/.config/starship.toml
format = """
[...plain symbols...]
"""
```

#### Option 3: Allow Custom Font Selection (Future)

Let users install fonts via iOS font management:
```swift
// Font picker in Settings
struct FontPicker: View {
    @State private var selectedFont: String = "System Monospace"
    let availableFonts = UIFont.familyNames.filter { /* monospace only */ }
}
```

---

## Best Practices Recommendations

### For Resizing (Priority: HIGH)

**1. Remove autoresizingMask Conflict**
```swift
func makeUIView(context: Context) -> TerminalView {
    let terminalView = manager.terminalView
    terminalView.frame = CGRect(origin: .zero, size: size)
    // REMOVED: autoresizingMask - rely on SwiftUI layout

    resizeTerminal(terminalView, to: size)
    manager.displayWelcomeMessage()

    DispatchQueue.main.async {
        _ = terminalView.becomeFirstResponder()
    }

    return terminalView
}
```

**2. Add Debug Logging (Temporary)**
```swift
func updateUIView(_ uiView: TerminalView, context: Context) {
    if uiView.frame.size != size {
        print("🔄 Terminal resize: \(uiView.frame.size) → \(size)")
        uiView.frame = CGRect(origin: .zero, size: size)
        resizeTerminal(uiView, to: size)
    }
}
```

**3. Test on iPad Simulator**
```bash
# Open iPad Pro 12.9" simulator
xcrun simctl list devices | grep "iPad Pro"

# Test rotation, split view, slide over
```

### For Font Support (Priority: MEDIUM)

**Recommended: Bundle JetBrains Mono Nerd Font**

**Why JetBrains Mono:**
- ✅ Excellent readability at small sizes
- ✅ Clear distinction between similar characters (0/O, 1/l/I)
- ✅ Professional appearance
- ✅ Free and open source (OFL license)
- ✅ Active maintenance
- ✅ Complete Nerd Font glyph coverage

**Steps:**
1. Download JetBrains Mono Nerd Font from https://www.nerdfonts.com/
2. Add .ttf files to Xcode project (Fonts group)
3. Update Info.plist:
```xml
<key>UIAppFonts</key>
<array>
    <string>Fonts/JetBrainsMonoNerdFont-Regular.ttf</string>
    <string>Fonts/JetBrainsMonoNerdFont-Bold.ttf</string>
    <string>Fonts/JetBrainsMonoNerdFont-Italic.ttf</string>
    <string>Fonts/JetBrainsMonoNerdFont-BoldItalic.ttf</string>
</array>
```
4. Use in terminal:
```swift
terminalView.font = UIFont(name: "JetBrainsMonoNerdFont-Regular", size: 14)
    ?? UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
```

**Bundle Size Impact:** ~10-12MB total (4 font files)

---

## Summary

### Issues Found

1. **⚠️ Potential iPad Resizing Issue**
   - Conflicting autoresizingMask + manual frame updates
   - Needs testing on iPad with Split View/multitasking
   - Simple fix: remove autoresizingMask

2. **⚠️⚠️⚠️ No Powerline/Starship Support (CONFIRMED)**
   - System monospace font lacks Nerd Font glyphs
   - Starship and powerline prompts show broken characters
   - Users see boxes instead of icons
   - **This IS a problem** for users with modern shell setups

### Recommended Actions

**Immediate (Resizing):**
1. Remove `autoresizingMask` line to eliminate conflict
2. Add temporary debug logging to monitor size changes
3. Test on iPad simulator (Pro 12.9", rotation, Split View)
4. Verify terminal resizes properly in all scenarios

**Short-term (Font Support):**
1. Bundle JetBrains Mono Nerd Font (~10MB)
2. Update font initialization to use Nerd Font
3. Add fallback to system font if bundle missing
4. Test with remote machine using starship

**Alternative (Documentation):**
1. Document font limitation in app description
2. Provide user instructions for starship plain mode
3. Add to FAQ/known limitations

---

## Testing Script

### iPad Resizing Test
```swift
// Add to TerminalSessionView for debugging
.onReceive(NotificationCenter.default.publisher(
    for: UIDevice.orientationDidChangeNotification
)) { _ in
    print("📱 Device orientation changed")
}

// Monitor size changes
func updateUIView(_ uiView: TerminalView, context: Context) {
    let oldSize = uiView.frame.size
    if oldSize != size {
        print("""
        🔄 Terminal Resize Event:
           Old: \(Int(oldSize.width))x\(Int(oldSize.height))
           New: \(Int(size.width))x\(Int(size.height))
           Cols/Rows: \(Int(size.width / charWidth))x\(Int(size.height / charHeight))
        """)
        uiView.frame = CGRect(origin: .zero, size: size)
        resizeTerminal(uiView, to: size)
    }
}
```

### Starship Test
```bash
# On remote machine
curl -sS https://starship.rs/install.sh | sh
echo 'eval "$(starship init zsh)"' >> ~/.zshrc

# Test with current app (will show broken icons)
# Then test again after bundling Nerd Font
```

---

## Conclusion

**Resizing:** Likely issue with autoresizingMask conflict. Simple one-line fix.

**Font Support:** Confirmed limitation. System font doesn't support powerline glyphs. Recommend bundling JetBrains Mono Nerd Font for complete terminal experience.

Both issues have straightforward solutions following iOS best practices.
