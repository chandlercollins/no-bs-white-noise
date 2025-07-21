import SwiftUI
import AVFoundation

/// Entry point for the Simple White Noise application
@main
struct WhiteNoiseApp: App {
    init() {
        // Configure audio session for exclusive background playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
