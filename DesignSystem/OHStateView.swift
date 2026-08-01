import SwiftUI

struct OHStateView: View {
    enum Kind {
        case loading
        case empty
        case error
        case access
    }

    let kind: Kind
    let title: String
    var message: String?
    var systemImage: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: OHTheme.Spacing.md) {
            if kind == .loading {
                ProgressView()
                    .controlSize(.large)
            } else {
                Image(systemName: systemImage ?? defaultImage)
                    .font(.system(size: 40))
                    .foregroundStyle(kind == .error ? Color.red : OHTheme.primaryAction)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                OHPrimaryButton(title: actionTitle, action: action)
                    .frame(maxWidth: 280)
            }
        }
        .padding(OHTheme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("oh.state.\(kind)")
    }

    private var defaultImage: String {
        switch kind {
        case .loading: return "hourglass"
        case .empty: return "tray"
        case .error: return "exclamationmark.triangle"
        case .access: return "heart.text.square"
        }
    }
}
