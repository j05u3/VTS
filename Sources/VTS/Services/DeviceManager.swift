import AVFoundation
import Foundation

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
    
    private func updateAvailableDevices() {
        // For now, create a mock default device until we implement proper device enumeration
        let defaultDevice = AudioDevice(id: "default", name: "Default Microphone", isDefault: true)
        availableDevices = [defaultDevice]
        updatePreferredDevice()
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