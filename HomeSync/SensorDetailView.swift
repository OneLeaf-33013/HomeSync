import SwiftUI

struct SensorDetailView: View {
    let isDoorSensor: Bool
    @EnvironmentObject var bleManager: BLEManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if isDoorSensor {
                    HStack {
                        Text("Ultrasonic (cm)")
                            .font(.headline)
                        Spacer()
                        Text(displayValue(bleManager.doorUltrasonicCM))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Motion Detected")
                            .font(.headline)
                        Spacer()
                        Text(displayValue(bleManager.doorMotionDetected))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack {
                        Text("Temperature")
                            .font(.headline)
                        Spacer()
                        Text(displayValue(bleManager.temperatureDegrees))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Humidity")
                            .font(.headline)
                        Spacer()
                        Text(displayValue(bleManager.humidityPercent))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding()
            .navigationTitle(isDoorSensor ? "Door" : "Temperature")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func displayValue(_ value: Bool?) -> String {
        guard let value = value else { return "-" }
        return value ? "Yes" : "No"
    }
    
    private func displayValue(_ value: Double?) -> String {
        guard let value = value else { return "-" }
        return String(value)
    }
    
    private func displayValue(_ value: Int?) -> String {
        guard let value = value else { return "-" }
        return String(value)
    }
}

#Preview {
    SensorDetailView(isDoorSensor: true)
        .environmentObject(BLEManager())
}
