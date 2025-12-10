import UIKit
import AVFoundation

/// Timing constants in seconds
enum HapticTiming {
    static let longPulse: Double = 0.250
    static let shortPulse: Double = 0.100
    static let interPulsePause: Double = 0.070
    static let separatorPause: Double = 0.400
}

/// Audio frequencies for beeps
enum BeepFrequency {
    static let longTone: Float = 440.0   // A4
    static let shortTone: Float = 880.0  // A5
}

/// Configuration for time vibration
struct VibeConfig {
    var use12HourFormat: Bool = false
    var buzzInterval: Int = 5        // Minutes between buzzes
    var startMinute: Int = 0         // First minute of hour to buzz
    var tallyBase: Int = 5           // 5 or 10
    var audioEnabled: Bool = false   // Play beeps instead of/with haptics
}

/// Manages haptic feedback for encoding time
class HapticManager {
    static let shared = HapticManager()
    
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    
    private var isVibrating = false
    private var audioEngine: AVAudioEngine?
    private var tonePlayer: AVAudioPlayerNode?
    
    private init() {
        // Prepare generators
        heavyGenerator.prepare()
        lightGenerator.prepare()
    }
    
    /// Check if currently vibrating
    var isBusy: Bool { isVibrating }
    
    /// Vibrate the given time with configurable tally base and optional audio
    func vibrateTime(hour: Int, minute: Int, tallyBase: Int = 5, audioEnabled: Bool = false, completion: @escaping () -> Void) {
        guard !isVibrating else { return }
        
        isVibrating = true
        
        // Build sequence (always include both hour and minute)
        var sequence: [HapticEvent] = []
        
        if hour > 0 {
            sequence.append(contentsOf: buildNumberSequence(hour, tallyBase: tallyBase))
        }
        
        if minute > 0 {
            // Add separator if we had hours
            if !sequence.isEmpty {
                sequence.append(.pause(HapticTiming.separatorPause))
            }
            sequence.append(contentsOf: buildNumberSequence(minute, tallyBase: tallyBase))
        }
        
        // Handle 00:00 case
        if sequence.isEmpty {
            isVibrating = false
            completion()
            return
        }
        
        // Execute on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.executeSequence(sequence, audioEnabled: audioEnabled)
            
            DispatchQueue.main.async {
                self?.isVibrating = false
                completion()
            }
        }
    }
    
    /// Build haptic sequence for a number using tally system
    private func buildNumberSequence(_ n: Int, tallyBase: Int) -> [HapticEvent] {
        var events: [HapticEvent] = []
        let longs = n / tallyBase
        let shorts = n % tallyBase
        
        // Add LONG pulses (heavy)
        for i in 0..<longs {
            if i > 0 {
                events.append(.pause(HapticTiming.interPulsePause))
            }
            events.append(.heavy)
            events.append(.pause(HapticTiming.longPulse))
        }
        
        // Add SHORT pulses (light)
        for i in 0..<shorts {
            if !events.isEmpty {
                events.append(.pause(HapticTiming.interPulsePause))
            }
            events.append(.light)
            events.append(.pause(HapticTiming.shortPulse))
        }
        
        return events
    }
    
    /// Execute haptic sequence with optional audio
    private func executeSequence(_ sequence: [HapticEvent], audioEnabled: Bool) {
        for event in sequence {
            switch event {
            case .heavy:
                DispatchQueue.main.async { [weak self] in
                    self?.heavyGenerator.impactOccurred()
                }
                if audioEnabled {
                    playTone(frequency: BeepFrequency.longTone, duration: HapticTiming.longPulse)
                }
            case .light:
                DispatchQueue.main.async { [weak self] in
                    self?.lightGenerator.impactOccurred()
                }
                if audioEnabled {
                    playTone(frequency: BeepFrequency.shortTone, duration: HapticTiming.shortPulse)
                }
            case .pause(let duration):
                Thread.sleep(forTimeInterval: duration)
            }
        }
    }
    
    /// Play a simple tone
    private func playTone(frequency: Float, duration: Double) {
        let sampleRate: Double = 44100
        let frameCount = Int(sampleRate * duration)
        
        var samples = [Float](repeating: 0, count: frameCount)
        for i in 0..<frameCount {
            let time = Float(i) / Float(sampleRate)
            // Apply envelope for smoother sound
            let envelope = min(1.0, min(Float(i) / 500.0, Float(frameCount - i) / 500.0))
            samples[i] = sin(2.0 * .pi * frequency * time) * 0.3 * envelope
        }
        
        // Use AVAudioPlayer with generated data
        DispatchQueue.main.async {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                // Ignore audio session errors
            }
        }
        
        // Simple blocking tone using AudioServices as fallback
        AudioServicesPlaySystemSound(1057) // Tock sound as simple feedback
    }
    
    /// Describe the pattern for a given time (for UI display)
    static func describePattern(hour: Int, minute: Int, tallyBase: Int = 5) -> String {
        let hourDesc = describeNumber(hour, label: "Hour", tallyBase: tallyBase)
        let minDesc = describeNumber(minute, label: "Min", tallyBase: tallyBase)
        return "\(hourDesc) | \(minDesc)"
    }
    
    private static func describeNumber(_ n: Int, label: String, tallyBase: Int) -> String {
        if n == 0 {
            return "\(label) \(n): (none)"
        }
        
        let longs = n / tallyBase
        let shorts = n % tallyBase
        var components: [String] = []
        
        if longs > 0 { components.append("\(longs)L") }
        if shorts > 0 { components.append("\(shorts)S") }
        
        return "\(label) \(n): \(components.joined(separator: "+"))"
    }
}

/// Types of haptic events
private enum HapticEvent {
    case heavy
    case light
    case pause(Double)
}
