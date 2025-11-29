import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("API Configuration")) {
                    Text("Gemini API Key: [Not Set]")
                    Text("Environment: \(AppConfig.shared.environment.rawValue)")
                }

                Section(header: Text("BARK Protocol")) {
                    Text("Operator: \(BARKConfig.shared.operatorId)")
                    Text("Version: \(BARKConfig.shared.version)")
                }

                Section(header: Text("Security")) {
                    Toggle("Enable Certificate Pinning", isOn: .constant(AppConfig.shared.enableCertificatePinning))
                    Toggle("SSL Validation", isOn: .constant(AppConfig.shared.enableSSLValidation))
                }
            }
            .navigationTitle("Settings")
        }
    }
}
