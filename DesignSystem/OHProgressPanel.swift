import SwiftUI

struct OHProgressPanel: View {
    let phaseLabel: String
    let fraction: Double
    var onCancel: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: OHTheme.Spacing.sm) {
            Text(phaseLabel)
                .font(.subheadline.weight(.medium))
                .accessibilityLabel(phaseLabel)
            ProgressView(value: fraction)
                .tint(OHTheme.primaryAction)
            if let onCancel {
                Button("Cancel Export", role: .cancel, action: onCancel)
                    .frame(minHeight: OHTheme.minTapTarget)
                    .accessibilityIdentifier("oh.export.cancel")
            }
        }
        .padding(OHTheme.Spacing.md)
        .background(OHTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: OHTheme.cornerRadius, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("oh.export.progress")
    }
}

struct OHDestinationRow: View {
    let name: String
    let kind: ExportDestinationKind
    var isEnabled: Bool = true
    var detail: String?

    var body: some View {
        HStack(spacing: OHTheme.Spacing.sm) {
            Image(systemName: kind.systemImage)
                .foregroundStyle(OHTheme.primaryAction)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body.weight(.medium))
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !isEnabled {
                Text("Off")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: OHTheme.minTapTarget)
        .accessibilityElement(children: .combine)
    }
}
