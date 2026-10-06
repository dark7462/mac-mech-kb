import SwiftUI

@main
struct MechanicalKeyboardApp: App {
    @StateObject private var controller = AppController()

    var body: some Scene {
        MenuBarExtra("Mechanical Keyboard", systemImage: "keyboard.fill") {
            MenuBarView(controller: controller)
        }
        .menuBarExtraStyle(.window)
    }
}
