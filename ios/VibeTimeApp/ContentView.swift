import SwiftUI

struct ContentView: View {
    @State private var currentTime = Date()
    @State private var isVibrating = false
    @State private var statusMessage = ""
    
    // Settings
    @State private var use12HourFormat = false
    @State private var buzzInterval = 5
    @State private var startMinute = 0
    @State private var audioEnabled = false
    @State private var tallyBase = 5
    
    // Pattern display for test buttons
    @State private var patternDescription = "Tap a time to see pattern"
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Title
                Text("⏱ VibeTime")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.91, green: 0.27, blue: 0.38))
                
                // Clock display
                Text(timeString)
                    .font(.system(size: 50, weight: .light, design: .monospaced))
                    .foregroundColor(.primary)
                    .onReceive(timer) { _ in
                        currentTime = Date()
                        checkScheduledBuzz()
                    }
                
                // Countdown to next buzz
                Text("Next buzz in \(countdownString)")
                    .font(.title3)
                    .foregroundColor(Color(red: 0.91, green: 0.27, blue: 0.38))
                
                // Main button
                Button(action: vibrateCurrentTime) {
                    Text("Feel Current Time")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 20)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.91, green: 0.27, blue: 0.38), Color(red: 0.06, green: 0.2, blue: 0.38)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(50)
                        .shadow(color: Color(red: 0.91, green: 0.27, blue: 0.38).opacity(0.4), radius: 10, x: 0, y: 4)
                }
                .disabled(isVibrating)
                .opacity(isVibrating ? 0.6 : 1)
                
                // Status
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundColor(Color(red: 0.91, green: 0.27, blue: 0.38))
                    .frame(height: 20)
                
                // Settings section
                VStack(alignment: .leading, spacing: 0) {
                    Text("SETTINGS")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 10)
                    
                    SettingRow(title: "12-hour format", isOn: $use12HourFormat)
                    Divider()
                    NumberSettingRow(title: "Buzz interval (min)", value: $buzzInterval, range: 1...60)
                    Divider()
                    NumberSettingRow(title: "Start minute", value: $startMinute, range: 0...59)
                    Divider()
                    SettingRow(title: "Audible beeps", isOn: $audioEnabled)
                    Divider()
                    TallyBaseRow(title: "Tally base", value: $tallyBase)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(15)
                
                // Test times section
                VStack(alignment: .leading, spacing: 10) {
                    Text("TEST TIMES")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 10) {
                        TestTimeButton(hour: 0, minute: 0, action: testTime)
                        TestTimeButton(hour: 8, minute: 5, action: testTime)
                        TestTimeButton(hour: 14, minute: 37, action: testTime)
                        TestTimeButton(hour: 23, minute: 59, action: testTime)
                    }
                    
                    Text(patternDescription)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(15)
                
                // Help section
                VStack(alignment: .leading, spacing: 8) {
                    Text("How it works")
                        .font(.headline)
                    
                    Text("Time is encoded as vibrations:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("**LONG (250ms)** = \(tallyBase) units")
                        .font(.subheadline)
                    
                    Text("**SHORT (100ms)** = 1 unit")
                        .font(.subheadline)
                    
                    Text("Example: 14 = \(14 / tallyBase) LONG + \(14 % tallyBase) SHORT")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(15)
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
    
    var timeString: String {
        let calendar = Calendar.current
        var hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)
        let second = calendar.component(.second, from: currentTime)
        
        var suffix = ""
        if use12HourFormat {
            suffix = hour >= 12 ? " PM" : " AM"
            if hour == 0 { hour = 12 }
            else if hour > 12 { hour -= 12 }
        }
        
        return String(format: "%02d:%02d:%02d%@", hour, minute, second, suffix)
    }
    
    var countdownString: String {
        let calendar = Calendar.current
        let currentMinute = calendar.component(.minute, from: currentTime)
        let currentSecond = calendar.component(.second, from: currentTime)
        
        var nextBuzzMinute = getNextBuzzMinute(currentMinute: currentMinute)
        
        // If we're exactly on a buzz minute, show next one (unless at second 0)
        if nextBuzzMinute == currentMinute && currentSecond > 0 {
            nextBuzzMinute = getNextBuzzMinute(currentMinute: currentMinute + 1)
        }
        
        var minutesLeft: Int
        var secondsLeft: Int
        
        if nextBuzzMinute >= 60 {
            // Next hour
            minutesLeft = (60 - currentMinute - 1) + (nextBuzzMinute - 60)
            secondsLeft = 60 - currentSecond
            if secondsLeft == 60 {
                secondsLeft = 0
                minutesLeft += 1
            }
        } else {
            minutesLeft = nextBuzzMinute - currentMinute - 1
            secondsLeft = 60 - currentSecond
            if secondsLeft == 60 {
                secondsLeft = 0
                minutesLeft += 1
            }
        }
        
        return String(format: "%02d:%02d", minutesLeft, secondsLeft)
    }
    
    func getNextBuzzMinute(currentMinute: Int) -> Int {
        for m in currentMinute..<60 {
            if (m - startMinute) % buzzInterval == 0 && m >= startMinute {
                return m
            }
        }
        // Next hour
        return startMinute + 60
    }
    
    func shouldBuzzNow() -> Bool {
        let calendar = Calendar.current
        let currentMinute = calendar.component(.minute, from: currentTime)
        let currentSecond = calendar.component(.second, from: currentTime)
        
        // Only buzz at second 0
        guard currentSecond == 0 else { return false }
        
        // Check if current minute matches the pattern
        guard currentMinute >= startMinute else { return false }
        return (currentMinute - startMinute) % buzzInterval == 0
    }
    
    func checkScheduledBuzz() {
        guard !isVibrating && shouldBuzzNow() else { return }
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)
        
        vibrateTime(hour: hour, minute: minute)
    }
    
    func vibrateCurrentTime() {
        guard !isVibrating else { return }
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)
        
        vibrateTime(hour: hour, minute: minute)
    }
    
    func testTime(hour: Int, minute: Int) {
        patternDescription = HapticManager.describePattern(hour: hour, minute: minute, tallyBase: tallyBase)
        vibrateTime(hour: hour, minute: minute)
    }
    
    func vibrateTime(hour: Int, minute: Int) {
        guard !isVibrating else { return }
        
        if hour == 0 && minute == 0 {
            statusMessage = "No vibration (00:00)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                statusMessage = ""
            }
            return
        }
        
        isVibrating = true
        statusMessage = audioEnabled ? "Playing..." : "Vibrating..."
        
        HapticManager.shared.vibrateTime(hour: hour, minute: minute, tallyBase: tallyBase, audioEnabled: audioEnabled) {
            isVibrating = false
            statusMessage = ""
        }
    }
}

struct TallyBaseRow: View {
    let title: String
    @Binding var value: Int
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Picker("", selection: $value) {
                Text("5").tag(5)
                Text("10").tag(10)
            }
            .pickerStyle(.segmented)
            .frame(width: 100)
        }
        .padding(.vertical, 8)
    }
}

struct SettingRow: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Toggle("", isOn: $isOn)
                .tint(Color(red: 0.91, green: 0.27, blue: 0.38))
        }
        .padding(.vertical, 8)
    }
}

struct NumberSettingRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("", value: $value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 60)
                .padding(8)
                .background(Color(.systemGray5))
                .cornerRadius(8)
                .onChange(of: value) { _, newValue in
                    value = min(max(newValue, range.lowerBound), range.upperBound)
                }
        }
        .padding(.vertical, 8)
    }
}

struct TestTimeButton: View {
    let hour: Int
    let minute: Int
    let action: (Int, Int) -> Void
    
    var body: some View {
        Button(action: { action(hour, minute) }) {
            Text(String(format: "%02d:%02d", hour, minute))
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemGray5))
                .cornerRadius(8)
        }
    }
}

#Preview {
    ContentView()
}
