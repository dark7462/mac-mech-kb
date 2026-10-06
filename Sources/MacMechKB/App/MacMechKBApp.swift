import SwiftUI

@main
struct MacMechKBApp: App {
    @StateObject private var controller = AppController()

    var body: some Scene {
        MenuBarExtra("mac-mech-kb", systemImage: "keyboard.fill") {
            MenuBarView(controller: controller)
        }
        .menuBarExtraStyle(.window)
    }
}
