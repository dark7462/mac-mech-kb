import Combine
import ServiceManagement

@MainActor
protocol LoginService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
    func openSettings()
}

@MainActor
struct SystemLoginService: LoginService {
    var status: SMAppService.Status { SMAppService.mainApp.status }
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
    func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}

@MainActor
final class LoginItemManager: ObservableObject {
    @Published private(set) var status: SMAppService.Status
    @Published private(set) var errorMessage: String?
    private let service: LoginService

    var isRegistered: Bool { status == .enabled || status == .requiresApproval }

    convenience init() { self.init(service: SystemLoginService()) }

    init(service: LoginService) {
        self.service = service
        status = service.status
    }

    func refresh() {
        if status != service.status { status = service.status }
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled { try service.register() }
            else { try service.unregister() }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    func openSettings() { service.openSettings() }
}
