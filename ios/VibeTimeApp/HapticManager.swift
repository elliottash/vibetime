import UIKit

/// Timing constants in seconds
enum HapticTiming {
    static let longPulse: Double = 0.250
    static let shortPulse: Double = 0.100
    static let interPulsePause: Double = 0.070
    static let separatorPause: Double = 0.400
}

/// Configuration for time vibration
struct VibeConfig {
    var use12HourFormat: Bool = false
    var includeHours: Bool = true
    var includeMinutes: Bool = true
}

/// Manages haptic feedback for encoding time
class HapticManager {
    static let shared = HapticManager()
    
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    
    private var isVibrating = false
    
    private init() {
        // Prepare generators
        heavyGenerator.prepare()
        lightGenerator.prepare()
    }
    
    /// Check if currently vibrating
    var isBusy: Bool { isVibrating }
    
    /// Vibrate the given time
    func vibrateTime(hour: Int, minute: Int, config: VibeConfig, completion: @escaping () -> Void) {
        guard !isVibrating else { return }
        guard config.includeHours || config.includeMinutes else {
            completion()
            return
        }
        
        isVibrating = true
        
        // Convert hour for 12-hour format
        var h = hour
        if config.use12HourFormat {
            if h == 0 {
                h = 12
            } else if h > 12 {
                h -= 12
            }
        }
        
        // Build sequence
        var sequence: [HapticEvent] = []
        
        if config.includeHours && h > 0 {
            sequence.append(contentsOf: buildNumberSequence(h))
        }
        
        if config.includeMinutes && minute > 0 {
            // Add separator if we had hours
            if !sequence.isEmpty {
                sequence.append(.pause(HapticTiming.separatorPause))
            }
            sequence.append(contentsOf: buildNumberSequence(minute))
        }
        
        // Execute on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.executeSequence(sequence)
            
            DispatchQueue.main.async {
                self?.isVibrating = false
                completion()
            }
        }
    }
    
    /// Build haptic sequence for a number using tally system
    private func buildNumberSequence(_ n: Int) -> [HapticEvent] {
        var events: [HapticEvent] = []
        let longs = n / 5
        let shorts = n % 5
        
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
    
    /// Execute haptic sequence
    private func executeSequence(_ sequence: [HapticEvent]) {
        for event in sequence {
            switch event {
            case .heavy:
                DispatchQueue.main.async { [weak self] in
                    self?.heavyGenerator.impactOccurred()
                }
            case .light:
                DispatchQueue.main.async { [weak self] in
                    self?.lightGenerator.impactOccurred()
                }
            case .pause(let duration):
                Thread.sleep(forTimeInterval: duration)
            }
        }
    }
    
    /// Describe the pattern for a given time (for UI display)
    static func describePattern(hour: Int, minute: Int, config: VibeConfig) -> String {
        var h = hour
        if config.use12HourFormat {
            if h == 0 { h = 12 }
            else if h > 12 { h -= 12 }
        }
        
        var parts: [String] = []
        
        if config.includeHours {
            let desc = describeNumber(h, label: "Hour")
            parts.append(desc)
        }
        
        if config.includeMinutes {
            let desc = describeNumber(minute, label: "Min")
            parts.append(desc)
        }
        
        return parts.joined(separator: " | ")
    }
    
    private static func describeNumber(_ n: Int, label: String) -> String {
        if n == 0 {
            return "\(label) \(n): (none)"
        }
        
        let longs = n / 5
        let shorts = n % 5
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
