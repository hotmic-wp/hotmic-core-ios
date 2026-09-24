import SwiftUI

@main
struct HotMicCoreExampleApp: App {
    /// Credentials are entered in the Settings screen. For automated runs they can also be
    /// supplied through the launch environment (`HOTMIC_CORE_API_KEY`, `HOTMIC_CORE_ACCESS_TOKEN`).
    /// Never commit real credentials here.
    static let defaultAPIKey = ProcessInfo.processInfo.environment["HOTMIC_CORE_API_KEY"] ?? ""
    static let defaultAccessToken = ProcessInfo.processInfo.environment["HOTMIC_CORE_ACCESS_TOKEN"] ?? ""

    var body: some Scene {
        WindowGroup {
            StreamsView()
        }
    }
}
