import AVFoundation
import Foundation
import CoreAudio

public struct AudioDevice: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let isDefault: Bool
    
    public init(id: String, name: String, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
    }
}

@MainActor
public class DeviceManager: ObservableObject {
    @Published public var availableDevices: [AudioDevice] = []
    @Published public var devicePriorities: [String] = []
    @Published public var preferredDeviceID: String?
    
    private var deviceChangeObserver: NSObjectProtocol?
    
    public init() {
        setupDeviceChangeNotifications()
        updateAvailableDevices()
        loadDevicePriorities()
    }
    
    deinit {
        if let observer = deviceChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupDeviceChangeNotifications() {
        deviceChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateAvailableDevices()
            }
        }
    }
    
    public func updateAvailableDevices() {
        var devices: [AudioDevice] = []
        
        // Get available audio input devices using Core Audio
        var propertySize: UInt32 = 0
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize
        )
        
        guard status == noErr else {
            // Fallback to default device
            let defaultDevice = AudioDevice(id: "default", name: "Default Microphone", isDefault: true)
            availableDevices = [defaultDevice]
            updatePreferredDevice()
            return
        }
        
        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = Array<AudioDeviceID>(repeating: 0, count: deviceCount)
        
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceIDs
        )
        
        guard status == noErr else {
            let defaultDevice = AudioDevice(id: "default", name: "Default Microphone", isDefault: true)
            availableDevices = [defaultDevice]
            updatePreferredDevice()
            return
        }
        
        // Filter for input devices and get their names
        for deviceID in deviceIDs {
            if hasInputStreams(deviceID: deviceID) {
                let name = getDeviceName(deviceID: deviceID)
                let device = AudioDevice(
                    id: String(deviceID),
                    name: name,
                    isDefault: isDefaultDevice(deviceID: deviceID)
                )
                devices.append(device)
            }
        }
        
        // Add system default if no devices found
        if devices.isEmpty {
            let defaultDevice = AudioDevice(id: "default", name: "Default Microphone", isDefault: true)
            devices.append(defaultDevice)
        }
        
        availableDevices = devices
        updatePreferredDevice()
    }
    
    private func hasInputStreams(deviceID: AudioDeviceID) -> Bool {
        var propertySize: UInt32 = 0
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize
        )
        
        guard status == noErr && propertySize > 0 else { return false }
        
        let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        defer { bufferList.deallocate() }
        
        let getStatus = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            bufferList
        )
        
        return getStatus == noErr && bufferList.pointee.mNumberBuffers > 0
    }
    
    private func getDeviceName(deviceID: AudioDeviceID) -> String {
        var propertySize: UInt32 = 0
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var status = AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize
        )
        
        guard status == noErr else { return "Unknown Device" }
        
        var name: CFString?
        status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &name
        )
        
        return status == noErr ? (name as String?) ?? "Unknown Device" : "Unknown Device"
    }
    
    private func isDefaultDevice(deviceID: AudioDeviceID) -> Bool {
        var defaultDeviceID: AudioDeviceID = 0
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &defaultDeviceID
        )
        
        return status == noErr && defaultDeviceID == deviceID
    }
    
    private func updatePreferredDevice() {
        // Find the first available device from priority list
        for deviceID in devicePriorities {
            if availableDevices.contains(where: { $0.id == deviceID }) {
                preferredDeviceID = deviceID
                return
            }
        }
        
        // Fallback to first available device
        preferredDeviceID = availableDevices.first?.id
    }
    
    public func setDevicePriorities(_ priorities: [String]) {
        devicePriorities = priorities
        saveDevicePriorities()
        updatePreferredDevice()
    }
    
    public func moveDevice(from source: IndexSet, to destination: Int) {
        devicePriorities.move(fromOffsets: source, toOffset: destination)
        saveDevicePriorities()
        updatePreferredDevice()
    }
    
    public func addDeviceToPriorities(_ deviceID: String) {
        if !devicePriorities.contains(deviceID) {
            devicePriorities.append(deviceID)
            saveDevicePriorities()
            updatePreferredDevice()
        }
    }
    
    public func removeDeviceFromPriorities(_ deviceID: String) {
        devicePriorities.removeAll { $0 == deviceID }
        saveDevicePriorities()
        updatePreferredDevice()
    }
    
    private func saveDevicePriorities() {
        UserDefaults.standard.set(devicePriorities, forKey: "DevicePriorities")
    }
    
    private func loadDevicePriorities() {
        devicePriorities = UserDefaults.standard.stringArray(forKey: "DevicePriorities") ?? []
        updatePreferredDevice()
    }
    
    public func getDeviceName(for deviceID: String) -> String {
        return availableDevices.first { $0.id == deviceID }?.name ?? "Unknown Device"
    }
}