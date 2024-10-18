//
//  SwitcherApp.swift
//  Switcher
//
//  Created by Bobronium on 05.05.2024.
//

import SwiftUI
import CoreAudio
import Foundation


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
    private var deviceSwitcher: DeviceSwitcher
    private var appState: AppState

    init(appState: AppState) {
        self.deviceSwitcher = DeviceSwitcher()
        self.appState = appState
    }

    func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
        isMonitoring.toggle()
        appState.isMonitoring = isMonitoring
    }

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPlayback()
        }
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    @objc private func checkPlayback() {
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
                    self.deviceSwitcher.switchToBuiltInMic()
                }
                self.previousElapsedTime = elapsedTime
            }
        }
        DispatchQueue.main.async {
            self.appState.currentDevice = self.deviceSwitcher.getCurrentDeviceName()
            self.appState.incrementSwitchCount()
        }
    }
}


class DeviceSwitcher {
    var currentInputDeviceID: AudioDeviceID?
    var builtInInputDeviceID: AudioDeviceID?

    init() {
        // Initialize with the default and built-in mic device IDs
        self.currentInputDeviceID = getCurrentInputDevice()
        self.builtInInputDeviceID = getBuiltInInputDeviceID()
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

    func setCurrentInputDevice(to deviceID: AudioDeviceID) {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        let propertySize = UInt32(MemoryLayout.size(ofValue: deviceID))
        var mutableDeviceID = deviceID
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            propertySize,
            &mutableDeviceID)

        if status != noErr {
            print("Error setting the default input device.")
        }
    }

    func getBuiltInInputDeviceID() -> AudioDeviceID {
        var size = UInt32(0)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        // Get the number of devices
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size)
        let deviceCount = Int(size) / MemoryLayout<AudioDeviceID>.size

        // Allocate memory for the array of AudioDeviceIDs
        var audioDevices = [AudioDeviceID](repeating: 0, count: deviceCount)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &audioDevices)

        for device in audioDevices {
            var transportType: UInt32 = 0
            var propertySize = UInt32(MemoryLayout<UInt32>.size)
            var transportTypeAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyTransportType,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)

            // Get the transport type of the device
            AudioObjectGetPropertyData(device, &transportTypeAddr, 0, nil, &propertySize, &transportType)

            if transportType == kAudioDeviceTransportTypeBuiltIn {
                return device
            }
        }

        return kAudioObjectUnknown
    }

    /// Switch to the built-in microphone.
    func switchToBuiltInMic() {
        self.currentInputDeviceID = getCurrentInputDevice()
        if let builtInMicID = self.builtInInputDeviceID {
            setCurrentInputDevice(to: builtInMicID)
            print("Switched to built-in microphone.")
        }
    }

    /// Restore the default input device.
    func restoreDefaultInputDevice() {
        if let defaultDeviceID = self.currentInputDeviceID {
            setCurrentInputDevice(to: defaultDeviceID)
            print("Restored default input device.")
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Monitoring", isOn: Binding(
                get: { self.appState.isMonitoring },
                set: { _ in self.playbackDetector.toggleMonitoring() }
            ))

            Text("Current Device: \(appState.currentDevice)")
            Text("Switch Count: \(appState.switchCount)")
        }
        .padding()
        .frame(width: 200)
    }
}

@main
struct SwitcherApp: App {
    @StateObject private var appState = AppState()
    private var playbackDetector: PlaybackDetector

    init() {
        let appState = AppState()
        self._appState = StateObject(wrappedValue: appState)
        self.playbackDetector = PlaybackDetector(appState: appState)
        playbackDetector.toggleMonitoring() // Start monitoring on app start
    }

    var body: some Scene {
        MenuBarExtra("Switcher", systemImage: "mic") {
            MenuBarView(appState: appState, playbackDetector: playbackDetector)
        }
    }
}
