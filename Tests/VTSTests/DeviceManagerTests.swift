import XCTest
@testable import VTS

@MainActor
final class DeviceManagerTests: XCTestCase {
    var deviceManager: DeviceManager!
    
    override func setUp() async throws {
        deviceManager = DeviceManager()
    }
    
    override func tearDown() async throws {
        deviceManager = nil
    }
    
    func testInitialState() {
        // Then
        XCTAssertNotNil(deviceManager.availableDevices)
        XCTAssertNotNil(deviceManager.devicePriorities)
    }
    
    func testSetDevicePriorities() {
        // Given
        let priorities = ["device1", "device2", "device3"]
        
        // When
        deviceManager.setDevicePriorities(priorities)
        
        // Then
        XCTAssertEqual(deviceManager.devicePriorities, priorities)
    }
    
    func testMoveDevice() {
        // Given
        deviceManager.setDevicePriorities(["device1", "device2", "device3"])
        
        // When
        deviceManager.moveDevice(from: IndexSet([0]), to: 2)
        
        // Then
        XCTAssertEqual(deviceManager.devicePriorities, ["device2", "device1", "device3"])
    }
    
    func testAddDeviceToPriorities() {
        // Given
        deviceManager.setDevicePriorities(["device1", "device2"])
        
        // When
        deviceManager.addDeviceToPriorities("device3")
        
        // Then
        XCTAssertEqual(deviceManager.devicePriorities, ["device1", "device2", "device3"])
    }
    
    func testAddExistingDeviceToPriorities() {
        // Given
        deviceManager.setDevicePriorities(["device1", "device2"])
        
        // When
        deviceManager.addDeviceToPriorities("device1")
        
        // Then
        XCTAssertEqual(deviceManager.devicePriorities, ["device1", "device2"])
    }
    
    func testRemoveDeviceFromPriorities() {
        // Given
        deviceManager.setDevicePriorities(["device1", "device2", "device3"])
        
        // When
        deviceManager.removeDeviceFromPriorities("device2")
        
        // Then
        XCTAssertEqual(deviceManager.devicePriorities, ["device1", "device3"])
    }
    
    func testGetDeviceNameForUnknownDevice() {
        // When
        let name = deviceManager.getDeviceName(for: "unknown-device")
        
        // Then
        XCTAssertEqual(name, "Unknown Device")
    }
}