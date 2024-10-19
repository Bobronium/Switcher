//
//  SwitcherApp.swift
//  Switcher
//
//  Created by Bobronium on 05.05.2024.
//

import SwiftUI
import CoreAudio
import Foundation
import ServiceManagement

class AppState: ObservableObject {
    @Published var isMonitoring: Bool = false
    @Published var currentDevice: String = "Unknown"
    @Published var switchCount: Int = UserDefaults.standard.integer(forKey: "switchCount")

    func incrementSwitchCount() {
        switchCount += 1
        UserDefaults.standard.set(switchCount, forKey: "switchCount")
    }
}

class PlaybackDetector: ObservableObject {
    private var previousElapsedTime: TimeInterval = -1
    @Published var isMonitoring = false
    private var timer: Timer?
    var deviceSwitcher: DeviceSwitcher
    private var appState: AppState

    init(appState: AppState) {
        self.deviceSwitcher = DeviceSwitcher()
        self.appState = appState
    }

    func toggleMonitoring() {
        if !isMonitoring {
            startMonitoring()
        }
        isMonitoring.toggle()
        appState.isMonitoring = isMonitoring
    }

    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPlayback()
        }
        if deviceSwitcher.switchToBuiltInMic() {
            DispatchQueue.main.async {
                self.appState.incrementSwitchCount()
            }
        }
    }

    @objc private func checkPlayback() {
        if !isMonitoring {
            return
        }
        let bundleURL = NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
        guard let bundle = CFBundleCreate(kCFAllocatorDefault, bundleURL) else { return }

        guard let MRMediaRemoteGetNowPlayingInfoPointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) else { return }
        typealias MRMediaRemoteGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping ([String: Any]?) -> Void) -> Void
        let MRMediaRemoteGetNowPlayingInfo = unsafeBitCast(MRMediaRemoteGetNowPlayingInfoPointer, to: MRMediaRemoteGetNowPlayingInfoFunction.self)

        // Fetch the now playing info
        MRMediaRemoteGetNowPlayingInfo(DispatchQueue.main) { [weak self] (info) in
            guard let self = self, let info = info else { return }
            if let elapsedTime = info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? TimeInterval {
                if self.previousElapsedTime != -1 && self.previousElapsedTime != elapsedTime {
                    if self.deviceSwitcher.switchToBuiltInMic() {
                        DispatchQueue.main.async {
                            self.appState.incrementSwitchCount()
                        }
                    }
                }
                self.previousElapsedTime = elapsedTime
            }
        }
    }
}

class DeviceSwitcher {
    var currentInputDeviceID: AudioDeviceID?
    var builtInInputDeviceID: AudioDeviceID?
    var preferredInputDeviceID: AudioDeviceID? // Track the preferred device, even if unavailable

    init() {
        self.currentInputDeviceID = getCurrentInputDevice()
        self.builtInInputDeviceID = getBuiltInInputDeviceID()
        self.preferredInputDeviceID = builtInInputDeviceID // Default to built-in mic if no preference
    }

    /// Set the preferred input device (user-selected)
    func setPreferredInputDevice(to deviceID: AudioDeviceID) {
        self.preferredInputDeviceID = deviceID
    }

    /// Retrieves the current input device ID.
    func getCurrentInputDevice() -> AudioDeviceID {
        var defaultDeviceID = AudioObjectID(kAudioObjectUnknown)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var propertySize = UInt32(MemoryLayout.size(ofValue: defaultDeviceID))

        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &defaultDeviceID
        )

        return defaultDeviceID
    }

    /// Set the system's default input device to the given device ID
    func setCurrentInputDevice(to deviceID: AudioDeviceID) {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var mutableDeviceID = deviceID
        let propertySize = UInt32(MemoryLayout.size(ofValue: mutableDeviceID))

        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            propertySize,
            &mutableDeviceID
        )

        if status != noErr {
            print("Error setting the default input device.")
        } else {
            print("Successfully set the input device to ID \(deviceID)")
        }
    }

    /// Get the list of available input devices
    func getAvailableInputDevices() -> [(id: AudioDeviceID, name: String)] {
        var size = UInt32(0)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal, // Get all devices first
            mElement: kAudioObjectPropertyElementMain)

        // Get the number of devices
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size)
        let deviceCount = Int(size) / MemoryLayout<AudioDeviceID>.size
        var audioDevices = [AudioDeviceID](repeating: 0, count: deviceCount)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &audioDevices)

        var availableInputDevices: [(id: AudioDeviceID, name: String)] = []

        for device in audioDevices {
            var inputStreamCount: UInt32 = 0
            var propertySize = UInt32(MemoryLayout<UInt32>.size)
            var inputScopeAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams, // Check for input streams
                mScope: kAudioObjectPropertyScopeInput, // Input scope
                mElement: kAudioObjectPropertyElementMain)

            // Check if the device has input streams
            let status = AudioObjectGetPropertyData(device, &inputScopeAddress, 0, nil, &propertySize, &inputStreamCount)

            if status == noErr && inputStreamCount > 0 { // If the device supports input
                var name: CFString = "" as CFString
                var namePropertySize = UInt32(MemoryLayout<CFString>.size)
                var namePropertyAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyDeviceNameCFString,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain)

                // Use `withUnsafeMutablePointer` to safely fetch the device name
                let nameStatus = withUnsafeMutablePointer(to: &name) { namePtr in
                    namePtr.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<CFString>.size) {
                        AudioObjectGetPropertyData(device, &namePropertyAddress, 0, nil, &namePropertySize, $0)
                    }
                }

                if nameStatus == noErr {
                    availableInputDevices.append((id: device, name: name as String))
                }
            }
        }

        return availableInputDevices
    }

    /// Check if the preferred device is still available
    func isPreferredDeviceAvailable() -> Bool {
        guard let preferredDeviceID = preferredInputDeviceID else {
            return false
        }
        let availableDevices = getAvailableInputDevices()
        return availableDevices.contains { $0.id == preferredDeviceID }
    }

    /// Switch to the preferred microphone, if available. If not, fallback to the built-in mic.
    func switchToPreferredDevice() -> Bool {
        guard let preferredDeviceID = self.preferredInputDeviceID else {
            return false
        }

        // Check if the preferred device is available
        if isPreferredDeviceAvailable() {
            let currentMicID = getCurrentInputDevice()
            if preferredDeviceID != currentMicID {
                setCurrentInputDevice(to: preferredDeviceID)
                print("Switched to preferred input device with ID \(preferredDeviceID).")
                return true
            }
        } else {
            // Preferred device is not available, fallback to built-in mic
            print("Preferred device unavailable, switching to built-in mic.")
            if switchToBuiltInMic() {
                return true
            }
        }
        return false
    }

    /// Fallback to built-in microphone.
    func switchToBuiltInMic() -> Bool {
        guard let builtInMicID = self.builtInInputDeviceID ?? getBuiltInInputDeviceID() else {
            return false
        }

        let currentMicID = getCurrentInputDevice()
        if builtInMicID != currentMicID {
            setCurrentInputDevice(to: builtInMicID)
            print("Switched to built-in microphone.")
            return true
        }

        return false
    }

    // Helper to retrieve the built-in microphone device ID
    func getBuiltInInputDeviceID() -> Optional<AudioDeviceID> {
        var size = UInt32(0)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size)
        let deviceCount = Int(size) / MemoryLayout<AudioDeviceID>.size
        var audioDevices = [AudioDeviceID](repeating: 0, count: deviceCount)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &audioDevices)

        for device in audioDevices {
            var transportType: UInt32 = 0
            var propertySize = UInt32(MemoryLayout<UInt32>.size)
            var transportTypeAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyTransportType,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)

            AudioObjectGetPropertyData(device, &transportTypeAddr, 0, nil, &propertySize, &transportType)

            if transportType == kAudioDeviceTransportTypeBuiltIn {
                return device
            }
        }

        return nil
    }
    func getCurrentDeviceName() -> String {
        let deviceID = getCurrentInputDevice()
        var name: CFString = "" as CFString
        var propertySize = UInt32(MemoryLayout<CFString>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &name)
        return name as String
    }
}

struct MenuBarView: View {
    @ObservedObject var appState: AppState
    var playbackDetector: PlaybackDetector
    @State private var selectedDeviceID: AudioDeviceID?
    @State private var availableDevices: [(id: AudioDeviceID, name: String)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Enable", isOn: Binding(
                get: { self.appState.isMonitoring },
                set: { _ in self.playbackDetector.toggleMonitoring() }
            ))
// For some weird reason it doesn't work as intended. Checkbox doesnt' appear.
//            Toggle("Launch at Login", isOn: Binding(
//                get: { SMAppService.mainApp.status == .enabled },
//                set: { newValue in
//                    if newValue {
//                        enableLaunchAtLogin()
//                    } else {
//                        disableLaunchAtLogin()
//                    }
//                }
//            ))
            Text("Saved your ears for \(appState.switchCount) times!")
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 200)
    }
}

func enableLaunchAtLogin() {
    do {
        try SMAppService.mainApp.register()
        print("Successfully enabled launch at login")
    } catch {
        print("Failed to enable launch at login: \(error.localizedDescription)")
    }
}

func disableLaunchAtLogin() {
    do {
        try SMAppService.mainApp.unregister()
        print("Successfully disabled launch at login")
    } catch {
        print("Failed to disable launch at login: \(error.localizedDescription)")
    }

    // for some weird reason, app still remains in Login Items, despite the call above should get rid of it.
    // this should do the trick:
    let process = Process()
    process.launchPath = "/usr/bin/env"
    process.arguments = ["osascript", "-e", "tell application \"System Events\" to delete login item \"Switcher\""]
    process.launch()
    process.waitUntilExit()
}

@main
struct SwitcherApp: App {
    @StateObject private var appState = AppState()
    private var playbackDetector: PlaybackDetector

    init() {
        let appState = AppState()
        self._appState = StateObject(wrappedValue: appState)
        self.playbackDetector = PlaybackDetector(appState: appState)
        playbackDetector.toggleMonitoring()
    }

    var body: some Scene {
        MenuBarExtra("Switcher", systemImage: "mic") {
            MenuBarView(appState: appState, playbackDetector: playbackDetector)
        }
    }
}
