import UIKit
import AVFoundation
import CoreHaptics

/// Timing configuration (seconds)
struct TimingConfig {
    let longPulse: Double
    let shortPulse: Double
    let interPulsePause: Double
    let separatorPause: Double
}

/// Default timing constants in seconds
enum HapticTiming {
    static let `default` = TimingConfig(
        longPulse: 0.250,
        shortPulse: 0.100,
        interPulsePause: 0.070,
        separatorPause: 0.400
    )
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
    
    private var engine: CHHapticEngine?
    private var supportsHaptics: Bool = false
    
    private var isVibrating = false
    private var audioEngine: AVAudioEngine?
    private var tonePlayer: AVAudioPlayerNode?
    
    private init() {
        // Setup CoreHaptics if available
        let capabilities = CHHapticEngine.capabilitiesForHardware()
        supportsHaptics = capabilities.supportsHaptics
        if supportsHaptics {
            do {
                engine = try CHHapticEngine()
                try engine?.start()
            } catch {
                supportsHaptics = false
            }
        }
    }
    
    /// Check if currently vibrating
    var isBusy: Bool { isVibrating }
    
/// Vibrate the given time with configurable tally base and optional audio
    func vibrateTime(hour: Int,
                     minute: Int,
                     tallyBase: Int = 5,
                     audioEnabled: Bool = false,
                     timing: TimingConfig = HapticTiming.default,
                     includeMinute: Bool = true,
                     completion: @escaping () -> Void) {
        guard !isVibrating else { return }
        
        isVibrating = true
        
// Build sequence (hour always, minutes optional)
        var sequence: [HapticEvent] = []
        
        if hour > 0 {
            sequence.append(contentsOf: buildNumberSequence(hour, tallyBase: tallyBase, timing: timing))
        }
        
        if includeMinute && minute > 0 {
            // Add separator if we had hours
            if !sequence.isEmpty {
                sequence.append(.pause(timing.separatorPause))
            }
            sequence.append(contentsOf: buildNumberSequence(minute, tallyBase: tallyBase, timing: timing))
        }
        
        // Handle 00:00 case
        if sequence.isEmpty {
            isVibrating = false
            completion()
            return
        }
        
        // Execute on background thread
DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.executeSequence(sequence, audioEnabled: audioEnabled, timing: timing)
            
            DispatchQueue.main.async {
                self?.isVibrating = false
                completion()
            }
        }
    }
    
    /// Build haptic sequence for a number using tally system
private func buildNumberSequence(_ n: Int, tallyBase: Int, timing: TimingConfig) -> [HapticEvent] {
        var events: [HapticEvent] = []
        let longs = n / tallyBase
        let shorts = n % tallyBase
        
        // Add LONG pulses (heavy)
        for i in 0..<longs {
if i > 0 {
                events.append(.pause(timing.interPulsePause))
            }
            events.append(.heavy)
            events.append(.pause(timing.longPulse))
        }
        
        // Add SHORT pulses (light)
        for i in 0..<shorts {
if !events.isEmpty {
                events.append(.pause(timing.interPulsePause))
            }
            events.append(.light)
            events.append(.pause(timing.shortPulse))
        }
        
        return events
    }
    
    /// Execute haptic sequence with optional audio
private func executeSequence(_ sequence: [HapticEvent], audioEnabled: Bool, timing: TimingConfig) {
        for event in sequence {
            switch event {
case .heavy:
                if supportsHaptics {
                    // Stronger perceived buzz via repeated transients
                    playHapticRumble(duration: timing.longPulse, intensity: 1.0, sharpness: 0.2)
                } else {
                    // Fallback to system vibrate
                    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                    Thread.sleep(forTimeInterval: timing.longPulse)
                }
                if audioEnabled {
                    playTone(frequency: BeepFrequency.longTone, duration: timing.longPulse)
                }
case .light:
                if supportsHaptics {
                    playHapticTransient(intensity: 0.6, sharpness: 0.6)
                    Thread.sleep(forTimeInterval: timing.shortPulse)
                } else {
                    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                    Thread.sleep(forTimeInterval: timing.shortPulse)
                }
                if audioEnabled {
                    playTone(frequency: BeepFrequency.shortTone, duration: timing.shortPulse)
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
    
    /// Play CoreHaptics "rumble" by chaining transients over the duration
    private func playHapticRumble(duration: Double, intensity: Float = 1.0, sharpness: Float = 0.2) {
        guard supportsHaptics, duration > 0 else { return }
        let step: Double = 0.05 // 50ms transients to feel continuous
        var events: [CHHapticEvent] = []
        var t: Double = 0
        let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        while t < duration {
            events.append(CHHapticEvent(eventType: .hapticTransient,
                                        parameters: [intensityParam, sharpnessParam],
                                        relativeTime: t))
            t += step
        }
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try engine?.start()
            try player?.start(atTime: 0)
        } catch { /* ignore */ }
    }

    /// Play CoreHaptics continuous pattern (kept for future tuning)
    private func playHapticContinuous(duration: Double, intensity: Float, sharpness: Float) {
        guard supportsHaptics, duration > 0 else { return }
        let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensityParam, sharpnessParam], relativeTime: 0, duration: duration)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try engine?.start()
            try player?.start(atTime: 0)
        } catch { /* ignore */ }
    }
    
    /// Play CoreHaptics transient tap
    private func playHapticTransient(intensity: Float, sharpness: Float) {
        guard supportsHaptics else { return }
        let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensityParam, sharpnessParam], relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try engine?.start()
            try player?.start(atTime: 0)
        } catch { /* ignore */ }
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
