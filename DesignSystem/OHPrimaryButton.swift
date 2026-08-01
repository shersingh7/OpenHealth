import SwiftUI

struct OHPrimaryButton: View {
    let title: String
    var systemImage: String?
    var isEnabled: Bool = true
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: OHTheme.Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: OHTheme.minTapTarget)
        }
        .buttonStyle(.borderedProminent)
        .tint(OHTheme.primaryAction)
        .disabled(!isEnabled || isLoading)
        .accessibilityIdentifier("oh.primaryButton.\(title)")
    }
}

struct OHSecondaryButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: OHTheme.minTapTarget)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("oh.secondaryButton.\(title)")
    }
}
