//
//  SmokeTests.swift
//  No-BS White Noise Tests
//
//  Launch-compliance smoke tests. These run hosted in the app, so
//  Bundle.main is the app bundle — letting us assert on the built product.
//

import XCTest
@testable import No_BS_White_Noise

final class SmokeTests: XCTestCase {

    // MARK: - Model invariants

    func testSoundTypesAreComplete() {
        XCTAssertEqual(SoundType.allCases.count, 5)
        XCTAssertEqual(
            SoundType.allCases.map(\.rawValue),
            ["white", "brown", "fire", "rain", "birds"]
        )
        // Display names are non-empty and unique
        let names = SoundType.allCases.map(\.displayName)
        XCTAssertEqual(Set(names).count, names.count)
        XCTAssertFalse(names.contains(where: \.isEmpty))
    }

    func testThemeModesAreComplete() {
        XCTAssertEqual(ThemeMode.allCases.count, 2)
        XCTAssertEqual(ThemeMode.light.iconName, "sun.max.fill")
        XCTAssertEqual(ThemeMode.dark.iconName, "moon.fill")
    }

    // MARK: - Built-bundle compliance (App Store readiness)

    func testPrivacyManifestIsBundled() {
        XCTAssertNotNil(
            Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"),
            "PrivacyInfo.xcprivacy must ship in the app bundle"
        )
    }

    func testExportComplianceFlagIsSet() {
        let value = Bundle.main.object(forInfoDictionaryKey: "ITSAppUsesNonExemptEncryption") as? Bool
        XCTAssertEqual(value, false, "ITSAppUsesNonExemptEncryption must be false")
    }

    func testBackgroundAudioModeIsDeclared() {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        XCTAssertEqual(modes, ["audio"], "Background audio must be declared")
    }

    func testAllSoundFilesAreBundled() {
        for file in ["fire", "rain", "birdsounds"] {
            XCTAssertNotNil(
                Bundle.main.path(forResource: file, ofType: "mp3"),
                "\(file).mp3 must ship in the app bundle"
            )
        }
    }

    func testNowPlayingArtworkIsBundled() {
        XCTAssertNotNil(UIImage(named: "logo"), "logo.png powers Now Playing artwork")
    }

    func testVersionIsSane() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        XCTAssertNotNil(version)
        XCTAssertTrue(version!.hasPrefix("2."), "Marketing version should be 2.x, got \(version!)")
    }
}
