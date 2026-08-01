import SwiftUI

enum OHStatusKind {
    case neutral
    case info
    case success
    case warning
    case error
    case partial

    var color: Color {
        switch self {
        case .neutral: return .secondary
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        case .partial: return .orange
        }
    }

    var systemImage: String {
        switch self {
        case .neutral: return "circle"
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .partial: return "exclamationmark.circle.fill"
        }
    }
}

struct OHStatusBadge: View {
    let title: String
    let kind: OHStatusKind

    var body: some View {
        Label(title, systemImage: kind.systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(kind.color)
            .padding(.horizontal, OHTheme.Spacing.sm)
            .padding(.vertical, OHTheme.Spacing.xs)
            .background(kind.color.opacity(0.12))
            .clipShape(Capsule())
            .accessibilityLabel(title)
    }
}
