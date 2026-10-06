import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var controller: AppController
    @ObservedObject private var settings: SettingsStore
    @StateObject private var login = LoginItemManager()

    init(controller: AppController) {
        self.controller = controller
        self.settings = controller.settings
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if !controller.hasKeyboardAccess {
                permissionCard
            }
            if let message = controller.status.recoveryMessage {
                issueCard(message)
            }
            Divider()
            Toggle("Keyboard sounds", isOn: Binding(
                get: { settings.enabled },
                set: controller.setEnabled
            ))
            .toggleStyle(.switch)

            VStack(alignment: .leading, spacing: 8) {
                Text("Sound")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    ForEach(SoundPreset.allCases) { preset in
                        Button {
                            controller.setPreset(preset)
                        } label: {
                            Text(preset.rawValue)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(settings.preset == preset ? .accentColor : .gray)
                        .accessibilityAddTraits(settings.preset == preset ? [.isSelected] : [])
                    }
                }
                Text(presetDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 5) {
                Toggle(isOn: Binding(get: { settings.lubed }, set: controller.setLubed)) {
                    HStack {
                        Text("Lube")
                        Text(settings.lubed ? "On" : "Off")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                Text("Rounder thock, softer clicks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Volume")
                    Spacer()
                    Text("\(Int(settings.volume * 100))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: Binding(
                    get: { settings.volume },
                    set: controller.setVolume
                ), in: 0...1)
                .accessibilityLabel("Volume")
                .accessibilityValue("\(Int(settings.volume * 100)) percent")
            }

            Divider()
            Toggle("Launch at login", isOn: Binding(
                get: { login.isRegistered },
                set: login.setEnabled
            ))
            if login.status == .requiresApproval {
                Text("Waiting for your approval in Login Items.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Open Login Items") { login.openSettings() }
            } else if login.status == .notFound {
                Text("Launch at login is unavailable for this app installation.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let error = login.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            Text("Key presses are handled on this Mac. Nothing is recorded or sent.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Refresh status") { refresh() }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(18)
        .frame(width: 320)
        .onAppear { refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "keyboard.fill")
                .font(.title2)
                .frame(width: 42, height: 42)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 2) {
                Text("mac-mech-kb").font(.headline)
                Text(controller.status.title)
                    .font(.caption)
                    .foregroundStyle(controller.status == .playing ? .green : .secondary)
            }
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Allow Input Monitoring")
                .font(.subheadline.weight(.semibold))
            Text("This lets the app hear physical key presses across apps and play sounds locally. You may need to restart it after granting access.")
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Request access") { controller.requestPermission() }
                    .buttonStyle(.borderedProminent)
                Button("Open Settings") { controller.openPermissionSettings() }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func issueCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(controller.status.title).font(.subheadline.weight(.semibold))
            Text(message)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Button("Retry") { controller.refresh() }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private var presetDescription: String {
        switch settings.preset {
        case .blue: "Cherry MX Blue · bright, crisp click"
        case .brown: "WS Brown · warm, tactile tap"
        case .red: "Gateron Red · soft, smooth tick"
        }
    }

    private func refresh() {
        controller.refresh()
        login.refresh()
    }
}
