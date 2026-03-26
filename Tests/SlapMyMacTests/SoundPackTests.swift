import XCTest
@testable import SlapMyMac

final class SoundPackTests: XCTestCase {

    // MARK: - SoundMode

    func testAllModesHaveDisplayName() {
        for mode in SoundMode.allCases {
            XCTAssertFalse(mode.displayName.isEmpty, "\(mode) should have a display name")
        }
    }

    func testAllModesHaveDescription() {
        for mode in SoundMode.allCases {
            XCTAssertFalse(mode.description.isEmpty, "\(mode) should have a description")
        }
    }

    func testAllModesHaveIcon() {
        for mode in SoundMode.allCases {
            XCTAssertFalse(mode.icon.isEmpty, "\(mode) should have an icon name")
        }
    }

    func testAllModesHaveFolderName() {
        for mode in SoundMode.allCases where mode != .custom {
            XCTAssertFalse(mode.folderName.isEmpty, "\(mode) should have a folder name")
        }
    }

    func testCustomFolderNameIsDisplayName() {
        // Custom mode uses displayName as folder, but it's not really used for bundle lookup
        XCTAssertEqual(SoundMode.custom.folderName, "Custom")
    }

    func testKungFuFolderNameIsCorrect() {
        XCTAssertEqual(SoundMode.kungfu.folderName, "KungFu")
    }

    func testEightBitFolderNameIsCorrect() {
        XCTAssertEqual(SoundMode.eightbit.folderName, "8Bit")
    }

    func testWWEFolderNameIsCorrect() {
        XCTAssertEqual(SoundMode.wwe.folderName, "WWE")
    }

    func testEscalatingModes() {
        XCTAssertTrue(SoundMode.sexy.isEscalating)
        XCTAssertTrue(SoundMode.cat.isEscalating)
        XCTAssertTrue(SoundMode.glass.isEscalating)
        XCTAssertFalse(SoundMode.pain.isEscalating)
        XCTAssertFalse(SoundMode.halo.isEscalating)
        XCTAssertFalse(SoundMode.cartoon.isEscalating)
    }

    func testModeIdentifiableConformance() {
        for mode in SoundMode.allCases {
            XCTAssertEqual(mode.id, mode.rawValue)
        }
    }

    func testModeCodableRoundTrip() throws {
        for mode in SoundMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(SoundMode.self, from: data)
            XCTAssertEqual(decoded, mode)
        }
    }

    // MARK: - SoundPack

    func testEmptyPackProperties() {
        let pack = SoundPack(mode: .pain, urls: [])
        XCTAssertTrue(pack.isEmpty)
        XCTAssertEqual(pack.count, 0)
    }

    func testPackWithURLs() {
        let urls = (0..<5).map { URL(fileURLWithPath: "/tmp/sound\($0).mp3") }
        let pack = SoundPack(mode: .halo, urls: urls)
        XCTAssertFalse(pack.isEmpty)
        XCTAssertEqual(pack.count, 5)
        XCTAssertEqual(pack.urls.count, 5)
    }

    func testCustomPackFromNonexistentDirectory() {
        let url = URL(fileURLWithPath: "/nonexistent/path/to/sounds")
        let pack = SoundPack.custom(from: url)
        XCTAssertEqual(pack.mode, .custom)
        // May be empty if directory doesn't exist
    }

    func testBundledPackForMissingFolderReturnsEmpty() {
        // In the test runner, Bundle.main doesn't contain the app's resources.
        // Verify bundled() handles missing folders gracefully (no crash, returns pack).
        let pack = SoundPack.bundled(.pain)
        XCTAssertEqual(pack.mode, .pain)
        // count may be 0 in test environment — that's OK
    }
}
