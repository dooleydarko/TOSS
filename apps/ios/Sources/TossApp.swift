import SwiftUI

@main
public struct TossApp: App {
    @AppStorage("toss.appearance") private var appearance = "Dark"
    public init() {}

    public var body: some Scene {
        WindowGroup {
            TossAppView()
                .tint(TossDesign.tint)
                .preferredColorScheme(appearance == "System" ? nil : (appearance == "Light" ? .light : .dark))
        }
    }
}
