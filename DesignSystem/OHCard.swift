import SwiftUI

struct OHCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(OHTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(OHTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: OHTheme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: OHTheme.cornerRadius, style: .continuous)
                    .stroke(OHTheme.separator.opacity(0.35), lineWidth: 1)
            )
    }
}

struct OHSectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: OHTheme.Spacing.xxs) {
            Text(title)
                .font(.headline)
            if let subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
