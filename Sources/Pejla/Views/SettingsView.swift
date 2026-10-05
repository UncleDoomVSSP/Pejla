import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKey.probeTimeoutMs) private var probeTimeoutMs = 1000
    @AppStorage(SettingsKey.thoroughPorts) private var thoroughPorts = true
    @AppStorage(SettingsKey.resolveNames) private var resolveNames = true
    @AppStorage(SettingsKey.bonjourSeconds) private var bonjourSeconds = 3.0

    private var timeoutBinding: Binding<Double> {
        Binding(
            get: { Double(probeTimeoutMs) },
            set: { probeTimeoutMs = Int($0) }
        )
    }

    var body: some View {
        Form {
            Section("Probing") {
                Slider(value: timeoutBinding, in: 300...3000, step: 100) {
                    Text("Timeout per probe")
                } minimumValueLabel: {
                    Text("0.3 s")
                } maximumValueLabel: {
                    Text("3 s")
                }
                Text("\(probeTimeoutMs) ms. Raise this on slow Wi-Fi. Lower it for faster scans on a wired network.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Check a wider list of ports on devices that respond", isOn: $thoroughPorts)
            }
            Section("Names") {
                Toggle("Look up device names (Bonjour and reverse DNS)", isOn: $resolveNames)
                Stepper(value: $bonjourSeconds, in: 1...10, step: 1) {
                    Text("Listen for Bonjour announcements for \(Int(bonjourSeconds)) s")
                }
                .disabled(!resolveNames)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
    }
}
