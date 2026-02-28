import SwiftData
import SwiftUI

@main
struct PushTestApp: App {
    @State private var state = PushToolState()

    private let modelContainer: ModelContainer = {
        do {
            let schema = Schema([
                PushHistoryRecord.self
            ])
            return try ModelContainer(for: schema)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(state: state)
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 900, height: 700)
    }
}
