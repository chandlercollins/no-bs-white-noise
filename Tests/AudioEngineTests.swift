//
//  AudioEngineTests.swift
//  No-BS White Noise Tests
//
//  State-transition tests for AudioEngine. These avoid paths that start
//  real audio; playback itself is covered by manual QA.
//

import XCTest
@testable import No_BS_White_Noise

@MainActor
final class AudioEngineTests: XCTestCase {

    // Tests run hosted in the app, sharing its UserDefaults —
    // snapshot and restore anything we touch so we never pollute app state.
    private var savedSound: String?
    private var savedVolume: Double?

    override func setUp() {
        super.setUp()
        savedSound = UserDefaults.standard.string(forKey: "selectedSound")
        savedVolume = UserDefaults.standard.object(forKey: "masterVolume") as? Double
    }

    override func tearDown() {
        let defaults = UserDefaults.standard
        if let savedSound { defaults.set(savedSound, forKey: "selectedSound") }
        else { defaults.removeObject(forKey: "selectedSound") }
        if let savedVolume { defaults.set(savedVolume, forKey: "masterVolume") }
        else { defaults.removeObject(forKey: "masterVolume") }
        super.tearDown()
    }

    func testSleepTimerArmAndCancel() {
        let engine = AudioEngine()

        engine.setSleepTimer(30)
        XCTAssertEqual(engine.sleepTimerMinutes, 30)
        XCTAssertNotNil(engine.sleepTimerEndDate)
        // End date ≈ now + 30 min
        let expected = Date().addingTimeInterval(30 * 60)
        XCTAssertEqual(engine.sleepTimerEndDate!.timeIntervalSince1970,
                       expected.timeIntervalSince1970, accuracy: 5)

        engine.setSleepTimer(nil)
        XCTAssertNil(engine.sleepTimerMinutes)
        XCTAssertNil(engine.sleepTimerEndDate)
    }

    func testSleepTimerRearmReplaces() {
        let engine = AudioEngine()
        engine.setSleepTimer(15)
        engine.setSleepTimer(90)
        XCTAssertEqual(engine.sleepTimerMinutes, 90)
        engine.cancelSleepTimer()
        XCTAssertNil(engine.sleepTimerMinutes)
    }

    func testSleepTimerOptionsMatchProduct() {
        XCTAssertEqual(AudioEngine.sleepTimerOptions, [15, 30, 45, 60, 90, 120])
    }

    func testSelectSoundPersistsAndUpdatesState() {
        let engine = AudioEngine()
        engine.selectSound(.fire)
        XCTAssertEqual(engine.selectedSound, .fire)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "selectedSound"), "fire")
        XCTAssertFalse(engine.isPlaying, "selectSound while stopped must not start audio")
    }

    func testCycleWrapsBothDirections() {
        let engine = AudioEngine()
        engine.selectSound(.birds) // last
        engine.cycleToNextSound()
        XCTAssertEqual(engine.selectedSound, .white) // wraps to first

        engine.selectSound(.white) // first
        engine.cycleToPreviousSound()
        XCTAssertEqual(engine.selectedSound, .birds) // wraps to last
    }

    func testMasterVolumePersists() {
        let engine = AudioEngine()
        engine.masterVolume = 0.42
        XCTAssertEqual(UserDefaults.standard.double(forKey: "masterVolume"), 0.42, accuracy: 0.001)
        XCTAssertEqual(AudioEngine().masterVolume, 0.42, accuracy: 0.001,
                       "a fresh engine must read the persisted volume")
    }

    func testMP3BaseGainsMatchRMSTuning() {
        XCTAssertEqual(AudioEngine.mp3BaseVolume(for: .fire), 0.60, accuracy: 0.001)
        XCTAssertEqual(AudioEngine.mp3BaseVolume(for: .rain), 0.45, accuracy: 0.001)
        XCTAssertEqual(AudioEngine.mp3BaseVolume(for: .birds), 1.0, accuracy: 0.001)
    }
}
