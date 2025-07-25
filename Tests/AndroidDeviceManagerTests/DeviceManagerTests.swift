import XCTest
@testable import AndroidDeviceManager

final class DeviceManagerTests: XCTestCase {
    func testDeviceManagerInitialization() {
        let deviceManager = DeviceManager()
        XCTAssertNotNil(deviceManager)
    }
}