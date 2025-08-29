//
//  AppDelegate.swift
//  Dictly
//
//  Created by beneric.studio
//  Copyright © 2025 beneric.studio. All rights reserved.
//

import AVFoundation
import Cocoa
import Combine  // Needed for Timer

@MainActor  // Make AppDelegate a MainActor class
@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var audioManager: AudioManager!  // This will also be main actor isolated
    private var pasteManager: PasteManager!  // Keep a reference to PasteManager
    private var transformationService: TransformationService?
    private var settingsWindowController: SettingsWindowController?

    // Status bar icons
    private let defaultIcon = "waveform"
    private let recordingIcon = "person.wave.2.fill"  // Person speaking (distinct from system mic icon)
    private let processingIcon = "hourglass"  // Processing/transcription state
    private let transformationIcon = "brain.head.profile"  // AI transformation state

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize services with API key from settings
        initializeServices()

        setupStatusItem()
        setupPermissions()

        // Run without a dock icon
        NSApp.setActivationPolicy(.accessory)

        // Listen for API and provider changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApiKeyChange),
            name: .apiKeyChanged,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProviderChange),
            name: .transcriptionApiChanged,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTransformProviderChange),
            name: .transformationApiChanged,
            object: nil
        )
    }

    private func initializeServices() {
        // Initialize transcription services
        let transcriptionProvider = Settings.shared.transcriptionProvider
        let transcriptionApiKey = Settings.shared.apiKey(for: transcriptionProvider)

        // Initialize transformation services
        let transformProvider = Settings.shared.transformationProvider
        // Use the API key associated with the selected *transformation* provider
        let transformApiKey = Settings.shared.apiKey(for: transformProvider)

        var transcriptionService: TranscriptionService? = nil
        
        // Initialize transcription service
        if let transcriptionApiKey = transcriptionApiKey, !transcriptionApiKey.isEmpty {
            print(
                "Found API key: initializing \(transcriptionProvider.rawValue) transcription services"
            )

            switch transcriptionProvider {
            case .groq:
                transcriptionService = GroqTranscriptionService(apiKey: transcriptionApiKey)
            case .groqTranslations:
                transcriptionService = GroqTranscriptionService(
                    apiKey: transcriptionApiKey,
                    translation: true
                )
            case .openai:
                transcriptionService = OpenAITranscriptionService(apiKey: transcriptionApiKey)
            }
        } else {
            print(
                "No API key found for \(transcriptionProvider.rawValue), transcription services will not be initialized."
            )
        }

        // Initialize transformation service
        if let transformApiKey = transformApiKey, !transformApiKey.isEmpty {
            print(
                "Found API key: initializing \(transformProvider.rawValue) transformation services")

            switch transformProvider {
            case .groq:
                transformationService = GroqTransformationService(apiKey: transformApiKey)
            case .openai:
                transformationService = OpenAITransformationService(apiKey: transformApiKey)
            }
        } else {
            print(
                "No API key found for \(transformProvider.rawValue), transformation services will not be initialized."
            )
            transformationService = nil
        }

        // Initialize PasteManager and pass services + delegate
        pasteManager = PasteManager(
            transformationService: transformationService,
            delegate: self  // Set AppDelegate as the delegate
        )

        // Initialize AudioManager, passing transcription service and paste manager
        // NOTE: This assumes AudioManager's init is updated to accept PasteManager
        //       or that AudioManager internally uses a shared PasteManager instance.
        //       PasteManager directly, its init signature must change.
        // Update: Passing the pasteManager instance now.
        audioManager = AudioManager(
            transcriptionService: transcriptionService,
            pasteManager: pasteManager  // Pass the instance with the delegate
        )
        audioManager.delegate = self
    }

    @objc private func handleApiKeyChange(_ notification: Notification) {
        print("API key changed, reinitializing services")
        initializeServices()
    }

    @objc private func handleProviderChange(_ notification: Notification) {
        print("Transcription provider changed, reinitializing services")
        initializeServices()
    }

    @objc private func handleTransformProviderChange(_ notification: Notification) {
        print("Transformation provider changed, reinitializing services")
        initializeServices()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Use standard macOS template icon for idle state (adapts to dark/light mode automatically)
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Dictly")
            button.toolTip = "Dictly"
        }

        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(
            NSMenuItem(
                title: "Check Permissions", action: #selector(checkPermissions), keyEquivalent: "p")
        )
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc private func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }

        settingsWindowController?.window?.center()
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupPermissions() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if !granted {
                self.showPermissionAlert(for: "Microphone")
            }
        }

        // Also check accessibility permissions
        let options =
            [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false] as CFDictionary
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
        if !accessibilityEnabled {
            self.showPermissionAlert(for: "Accessibility")
        }
        // as Groq transcription uses the API and only microphone access is required locally.
    }

    @objc private func checkPermissions() {
        let alert = NSAlert()
        alert.messageText = "Checking Permissions"
        alert.informativeText =
            "Dictly needs microphone and accessibility permissions to function properly."

        let micStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.audio) == .authorized
        let accessibilityStatus = AXIsProcessTrustedWithOptions(nil as CFDictionary?)

        if micStatus && accessibilityStatus {
            alert.messageText = "All Permissions Granted"
            alert.informativeText = "Dictly has all required permissions."
        } else {
            alert.messageText = "Missing Permissions"
            alert.informativeText = """
                Dictly requires the following permissions:

                Microphone: \(micStatus ? "✅ Granted" : "❌ Missing")
                Accessibility: \(accessibilityStatus ? "✅ Granted" : "❌ Missing")

                Please grant the missing permissions in System Settings.
                """

            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")

            if alert.runModal() == .alertFirstButtonReturn {
                openSystemSettings()
            }
            return
        }

        alert.runModal()
    }

    private func createTintedImage(from image: NSImage?, color: NSColor) -> NSImage? {
        guard let image = image else { return nil }
        
        let tintedImage = NSImage(size: image.size)
        tintedImage.lockFocus()
        
        // Draw the original image
        image.draw(in: NSRect(origin: .zero, size: image.size))
        
        // Apply color tint
        color.set()
        NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
        
        tintedImage.unlockFocus()
        tintedImage.isTemplate = false
        
        return tintedImage
    }
    
    private func openSystemSettings() {
        // For Microphone
        if let micURL = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        {
            NSWorkspace.shared.open(micURL)
        }

        // For Accessibility
        if let accessibilityURL = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        {
            NSWorkspace.shared.open(accessibilityURL)
        }
    }

    private func showPermissionAlert(for permission: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "\(permission) Access Required"
            alert.informativeText =
                "Please enable \(permission) access in System Settings to use Dictly."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")

            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:")!)
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Remove notification observers
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - AudioManagerDelegate

extension AppDelegate: AudioManagerDelegate {
    // Since AppDelegate is @MainActor, these methods are already on the main actor.
    func audioManagerDidStartRecording() {
        // Use person speaking icon to avoid duplicating macOS system microphone indicator
        // macOS automatically shows orange microphone indicator in Control Center when recording
        let image = NSImage(systemSymbolName: recordingIcon, accessibilityDescription: "Dictating")
        image?.isTemplate = false
        let tintedImage = createTintedImage(from: image, color: NSColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 1.0)) // brandBlue
        self.statusItem.button?.image = tintedImage
    }

    func audioManagerDidStopRecording() {
        // Return to standard macOS template icon
        self.statusItem.button?.image = NSImage(systemSymbolName: defaultIcon, accessibilityDescription: "Dictly")
    }

    func audioManagerWillStartNetworkProcessing() {
        print(
            "Delegate: audioManagerWillStartNetworkProcessing - Setting icon to \(processingIcon)")
        // Set processing icon with brand color
        let image = NSImage(systemSymbolName: processingIcon, accessibilityDescription: "Processing")
        image?.isTemplate = false
        let tintedImage = createTintedImage(from: image, color: NSColor(red: 90/255, green: 200/255, blue: 250/255, alpha: 1.0)) // brandTeal
        self.statusItem.button?.image = tintedImage
    }

    func audioManager(didReceiveError error: Error) {
        // Return to standard macOS template icon on error
        self.statusItem.button?.image = NSImage(systemSymbolName: defaultIcon, accessibilityDescription: "Dictly")

        // For better UX, use non-intrusive error handling instead of modal alerts
        let errorMessage: String
        if let localizedError = error as? LocalizedError,
            let errorDescription = localizedError.errorDescription
        {
            errorMessage = errorDescription
        } else {
            errorMessage = error.localizedDescription
        }
        
        // Only show modal alerts for critical errors that require immediate attention
        if let audioError = error as? AudioManagerError {
            switch audioError {
            case .microphoneAccessDenied:
                // This is critical - user needs to grant permission
                showCriticalAlert(title: "Microphone Access Required", message: errorMessage)
            case .transcriptionServiceMissing:
                // This is critical - app won't work without service
                showCriticalAlert(title: "Service Configuration Required", message: errorMessage)
            default:
                // For recording failures, conversion errors, etc., use non-intrusive feedback
                showNonIntrusiveError(message: errorMessage)
            }
        } else {
            // For other errors, use non-intrusive feedback
            showNonIntrusiveError(message: errorMessage)
        }
    }
    
    private func showCriticalAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showNonIntrusiveError(message: String) {
        // Use macOS notification center for non-intrusive feedback
        let notification = NSUserNotification()
        notification.title = "Dictly"
        notification.informativeText = message
        notification.soundName = nil // Silent notification to avoid interruption
        NSUserNotificationCenter.default.deliver(notification)
        
        // Also briefly change status bar icon to indicate error, then revert
        let errorImage = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Error")
        errorImage?.isTemplate = false
        let tintedErrorImage = createTintedImage(from: errorImage, color: NSColor(red: 255/255, green: 149/255, blue: 0/255, alpha: 1.0)) // brandOrange for warning
        self.statusItem.button?.image = tintedErrorImage
        
        // Revert to normal icon after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.statusItem.button?.image = NSImage(systemSymbolName: self.defaultIcon, accessibilityDescription: "Dictly")
        }
    }
}

// MARK: - PasteManagerDelegate

extension AppDelegate: PasteManagerDelegate {
    func pasteManagerWillStartProcessing() {
        // No longer setting icon here, AudioManagerDelegate handles start
        print("Delegate: pasteManagerWillStartProcessing - (Icon setting moved)")
    }

    func pasteManagerWillStartTransformation() {
        print("Delegate: pasteManagerWillStartTransformation - Setting icon to \(transformationIcon)")
        // Set transformation icon with brand purple for AI processing
        let image = NSImage(systemSymbolName: transformationIcon, accessibilityDescription: "AI Processing")
        image?.isTemplate = false
        let tintedImage = createTintedImage(from: image, color: NSColor(red: 175/255, green: 82/255, blue: 222/255, alpha: 1.0)) // brandPurple
        self.statusItem.button?.image = tintedImage
    }

    func pasteManagerDidFinishProcessing() {
        print("Delegate: pasteManagerDidFinishProcessing - Setting icon to \(defaultIcon)")
        // Set back to default icon with success color
        let image = NSImage(systemSymbolName: defaultIcon, accessibilityDescription: "Dictly")
        image?.isTemplate = false
        let tintedImage = createTintedImage(from: image, color: NSColor(red: 0/255, green: 212/255, blue: 170/255, alpha: 1.0)) // brandMint for success
        self.statusItem.button?.image = tintedImage
        
        // Reset to normal template icon after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.statusItem.button?.image = NSImage(systemSymbolName: self.defaultIcon, accessibilityDescription: "Dictly")
        }
    }
}
