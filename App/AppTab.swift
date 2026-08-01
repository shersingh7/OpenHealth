import Foundation

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home
    case export
    case automations
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .export: return "Export"
        case .automations: return "Automations"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .export: return "square.and.arrow.up.on.square"
        case .automations: return "clock.arrow.circlepath"
        case .settings: return "gearshape.fill"
        }
    }
}
