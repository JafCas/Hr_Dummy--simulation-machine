import SwiftUI

@main
struct LocationSimulatorApp: App {
    @State private var viewModel = AppEnvironment.makeViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
}
