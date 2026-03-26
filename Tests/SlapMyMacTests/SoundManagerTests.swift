import XCTest
import AVFoundation
@testable import SlapMyMac

final class SoundManagerTests: XCTestCase {

    func testPreloadHandlesEmptyPack() {
        let manager = SoundManager()
        let pack = SoundPack(mode: .pain, urls: [])
        manager.preload(pack)
        // No crash = pass
    }

    func testPlayWithNonexistentFileDoesNotCrash() {
        let manager = SoundManager()
        let fakeURL = URL(fileURLWithPath: "/nonexistent/sound.mp3")
        // Should handle gracefully, not crash
        manager.play(url: fakeURL)
    }

    func testStopAllOnEmptyManagerDoesNotCrash() {
        let manager = SoundManager()
        manager.stopAll()
    }

    func testPreloadWithFakeURLsDoesNotCrash() {
        let manager = SoundManager()
        let urls = (0..<5).map { URL(fileURLWithPath: "/tmp/fake\($0).mp3") }
        let pack = SoundPack(mode: .pain, urls: urls)
        manager.preload(pack)
        // Preloading non-existent files should not crash
    }
}
