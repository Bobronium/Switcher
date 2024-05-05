//
//  SwitcherApp.swift
//  Switcher
//
//  Created by Bobronium on 05.05.2024.
//

import SwiftUI
import CoreAudio
import Foundation

// Assume CFBundleRef and function types are set up here as in your original snippet

class PlaybackDetector: ObservableObject {
    private var previousElapsedTime: TimeInterval = -1
    @Published var isMonitoring = false
    private var timer: Timer?
    private var deviceSwitcher: DeviceSwitcher
    
    init () {
        self.deviceSwitcher = DeviceSwitcher()
    }
    
    func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
        isMonitoring.toggle()
    }

    private func startMonitoring() {
        // Setup timer to periodically check playback status
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
}

@main
struct MyApp: App {
    private let playbackDetector = PlaybackDetector()

    init() {
        playbackDetector.toggleMonitoring() // Start monitoring on app start
    }

    var body: some Scene {
        Settings {
            EmptyView() // Provide an empty view, as no UI is required
        }
    }
}   
