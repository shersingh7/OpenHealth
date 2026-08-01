import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel: HomeViewModel
    var onCreateExport: () -> Void

    init(container: AppContainer, onCreateExport: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(container: container))
        self.onCreateExport = onCreateExport
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: OHTheme.Spacing.md) {
                    header
                    accessCard
                    OHPrimaryButton(title: "Create Export", systemImage: "square.and.arrow.up") {
                        onCreateExport()
                    }
                    .accessibilityIdentifier("oh.home.createExport")

                    lastExportCard
                    nextAutomationCard
                    coverageCard
                    privacyFooter
                }
                .padding(OHTheme.Spacing.md)
                .ohContentWidth()
            }
            .background(OHTheme.pageBackground.ignoresSafeArea())
            .navigationTitle("OpenHealth")
            .refreshable { await viewModel.refresh() }
            .task { await viewModel.refresh() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: OHTheme.Spacing.xxs) {
            Text("Private health exports, under your control.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var accessCard: some View {
        OHCard {
            VStack(alignment: .leading, spacing: OHTheme.Spacing.sm) {
                OHSectionHeader(title: "Health Access")
                if let state = viewModel.accessState {
                    OHStatusBadge(
                        title: state.statusLabel,
                        kind: badgeKind(for: state)
                    )
                    if state.requestState == .notRequested || state.requestState == .requestRecommended {
                        OHSecondaryButton(title: "Review Health Access") {
                            Task { await viewModel.requestAccess() }
                        }
                        .accessibilityIdentifier("oh.home.reviewAccess")
                    }
                } else if viewModel.isLoading {
                    ProgressView()
                }
                Text("Apple does not reveal whether read access was granted. Empty results can mean no data or that a type was not shared.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var lastExportCard: some View {
        OHCard {
            VStack(alignment: .leading, spacing: OHTheme.Spacing.sm) {
                OHSectionHeader(title: "Last Export")
                if let last = viewModel.lastExport {
                    OHStatusBadge(title: outcomeLabel(last.outcome), kind: outcomeKind(last.outcome))
                    Text("\(last.serializedRecordCount) records")
                        .font(.body.monospacedDigit())
                    Text(last.destinationSummaries.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if last.warningCount > 0 {
                        Text("\(last.warningCount) warning(s)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } else {
                    Text("No export history yet.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier("oh.home.lastExport")
    }

    private var nextAutomationCard: some View {
        OHCard {
            VStack(alignment: .leading, spacing: OHTheme.Spacing.sm) {
                OHSectionHeader(
                    title: "Next Automation",
                    subtitle: "Background timing is best effort, not exact."
                )
                if let next = viewModel.nextAutomation {
                    Text(next.name)
                        .font(.body.weight(.semibold))
                    Text("Earliest after \(next.date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No enabled automations scheduled.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier("oh.home.nextAutomation")
    }

    private var coverageCard: some View {
        OHCard {
            VStack(alignment: .leading, spacing: OHTheme.Spacing.sm) {
                OHSectionHeader(title: "Data Coverage")
                if let coverage = viewModel.coverage {
                    Text("\(coverage.detectedCount) detected types")
                        .font(.body.monospacedDigit())
                    Text("Scanned \(coverage.scannedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not scanned yet.")
                        .foregroundStyle(.secondary)
                }
                OHSecondaryButton(title: "Scan Coverage") {
                    Task { await viewModel.scanCoverage() }
                }
                .accessibilityIdentifier("oh.home.scanCoverage")
            }
        }
    }

    private var privacyFooter: some View {
        Text("OpenHealth does not collect data. Data is sent only to destinations you choose.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, OHTheme.Spacing.sm)
            .accessibilityIdentifier("oh.home.privacy")
    }

    private func badgeKind(for state: HealthAccessState) -> OHStatusKind {
        guard state.isHealthDataAvailable else { return .error }
        switch state.requestState {
        case .previouslyRequested: return .info
        case .requestRecommended, .notRequested: return .warning
        case .unavailable: return .error
        }
    }

    private func outcomeLabel(_ outcome: ExportOutcome) -> String {
        switch outcome {
        case .completeSuccess: return "Complete success"
        case .partialSuccess: return "Partial success"
        case .failure: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    private func outcomeKind(_ outcome: ExportOutcome) -> OHStatusKind {
        switch outcome {
        case .completeSuccess: return .success
        case .partialSuccess: return .partial
        case .failure: return .error
        case .cancelled: return .neutral
        }
    }
}
