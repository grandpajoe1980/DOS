import SwiftUI

@main
@MainActor
struct DOSApp: App {
    @StateObject private var model: AppModel

    init() {
#if DEBUG
        _model = StateObject(wrappedValue: AppModel(dependencies: .preview()))
#else
        do {
            let configuration = try AppRuntimeConfiguration(bundle: .main)
            _model = StateObject(wrappedValue: AppModel(dependencies: .live(configuration: configuration)))
        } catch {
            _model = StateObject(wrappedValue: AppModel(configurationError: error))
        }
#endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}
