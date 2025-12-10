import SwiftUI

struct ContentView: View {
    @State private var currentTime = Date()
    @State private var isVibrating = false
    @State private var statusMessage = ""
    
    // Settings
    @State private var use12HourFormat = false
    @State private var includeHours = true
    @State private var includeMinutes = true
    
    // Pattern display for test buttons
    @State private var patternDescription = "Tap a time to see pattern"
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var config: VibeConfig {
        VibeConfig(
            use12HourFormat: use12HourFormat,
            includeHours: includeHours,
            includeMinutes: includeMinutes
        )
    }
    
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
                    .font(.system(size: 60, weight: .light, design: .monospaced))
                    .foregroundColor(.primary)
                    .onReceive(timer) { _ in
                        currentTime = Date()
                    }
                
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
                    SettingRow(title: "Include hours", isOn: $includeHours)
                    Divider()
                    SettingRow(title: "Include minutes", isOn: $includeMinutes)
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
                    
                    Text("**LONG (250ms)** = 5 units")
                        .font(.subheadline)
                    
                    Text("**SHORT (100ms)** = 1 unit")
                        .font(.subheadline)
                    
                    Text("Example: 14 = 2 LONG + 4 SHORT")
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
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: currentTime)
    }
    
    func vibrateCurrentTime() {
        guard !isVibrating else { return }
        guard includeHours || includeMinutes else {
            statusMessage = "Enable hours or minutes!"
            return
        }
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)
        
        vibrateTime(hour: hour, minute: minute)
    }
    
    func testTime(hour: Int, minute: Int) {
        patternDescription = HapticManager.describePattern(hour: hour, minute: minute, config: config)
        vibrateTime(hour: hour, minute: minute)
    }
    
    func vibrateTime(hour: Int, minute: Int) {
        guard !isVibrating else { return }
        guard includeHours || includeMinutes else {
            statusMessage = "Enable hours or minutes!"
            return
        }
        
        // Check for zero values
        var h = hour
        if use12HourFormat {
            if h == 0 { h = 12 }
            else if h > 12 { h -= 12 }
        }
        
        let hasHourVibration = includeHours && h > 0
        let hasMinuteVibration = includeMinutes && minute > 0
        
        if !hasHourVibration && !hasMinuteVibration {
            statusMessage = "No vibration (value is 0)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                statusMessage = ""
            }
            return
        }
        
        isVibrating = true
        statusMessage = "Vibrating..."
        
        HapticManager.shared.vibrateTime(hour: hour, minute: minute, config: config) {
            isVibrating = false
            statusMessage = ""
        }
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
