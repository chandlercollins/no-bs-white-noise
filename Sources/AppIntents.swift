//
//  AppIntents.swift
//  No-BS White Noise
//
//  Siri integration for voice control
//

import AppIntents
import Foundation

/// App Intent for playing specific sound types via Siri
@available(iOS 16.0, *)
struct PlaySoundIntent: AppIntent {
    static var title: LocalizedStringResource = "Play Sound"
    static var description = IntentDescription("Play a specific white noise sound")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Sound Type")
    var soundType: SoundTypeEntity

    func perform() async throws -> some IntentResult {
        // Post notification to play the sound
        NotificationCenter.default.post(
            name: NSNotification.Name("PlaySoundFromSiri"),
            object: nil,
            userInfo: ["soundType": soundType.rawValue]
        )

        return .result()
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Play \(\.$soundType)")
    }
}

/// Entity representing sound types for Siri
@available(iOS 16.0, *)
struct SoundTypeEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Sound"
    static var defaultQuery = SoundTypeQuery()

    var id: String
    var rawValue: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(rawValue)")
    }

    static let whiteNoise = SoundTypeEntity(id: "white", rawValue: "White Noise")
    static let brownNoise = SoundTypeEntity(id: "brown", rawValue: "Brown Noise")
    static let fire = SoundTypeEntity(id: "fire", rawValue: "Fire")
    static let rain = SoundTypeEntity(id: "rain", rawValue: "Rain")
    static let birds = SoundTypeEntity(id: "birds", rawValue: "Birds")
}

/// Query for available sound types
@available(iOS 16.0, *)
struct SoundTypeQuery: EntityQuery {
    func entities(for identifiers: [SoundTypeEntity.ID]) async throws -> [SoundTypeEntity] {
        let allSounds = [
            SoundTypeEntity.whiteNoise,
            SoundTypeEntity.brownNoise,
            SoundTypeEntity.fire,
            SoundTypeEntity.rain,
            SoundTypeEntity.birds
        ]
        return allSounds.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [SoundTypeEntity] {
        [
            .whiteNoise,
            .brownNoise,
            .fire,
            .rain,
            .birds
        ]
    }
}

/// App Shortcuts for common voice commands
@available(iOS 16.0, *)
struct WhiteNoiseShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlaySoundIntent(),
            phrases: [
                "Play \(\.$soundType) in \(.applicationName)",
                "Start \(\.$soundType) in \(.applicationName)",
                "Play \(\.$soundType) on \(.applicationName)"
            ],
            shortTitle: "Play Sound",
            systemImageName: "speaker.wave.2.fill"
        )
    }
}
