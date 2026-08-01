import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel: OnboardingViewModel
    var onFinished: () -> Void

    init(container: AppContainer, onFinished: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(
            healthDataSource: container.healthDataSource,
            settingsStore: container.settingsStore
        ))
        self.onFinished = onFinished
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: OHTheme.Spacing.lg) {
                if viewModel.step < viewModel.steps.count {
                    let step = viewModel.steps[viewModel.step]
                    Spacer()
                    Image(systemName: step.image)
                        .font(.system(size: 56))
                        .foregroundStyle(OHTheme.healthHighlight)
                        .accessibilityHidden(true)
                    Text(step.title)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text(step.body)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Spacer()
                    OHPrimaryButton(title: "Continue") {
                        viewModel.step += 1
                    }
                    .accessibilityIdentifier("oh.onboarding.continue")
                } else {
                    Spacer()
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(OHTheme.healthHighlight)
                    Text("Choose Health Access")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text("Apple does not tell apps whether read access was granted. After you choose types in Apple Health, OpenHealth will show “access requested,” not “authorized.”")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                    Spacer()
                    OHPrimaryButton(
                        title: "Choose Health Access",
                        systemImage: "heart.text.square",
                        isLoading: viewModel.isRequesting
                    ) {
                        Task {
                            let ok = await viewModel.requestHealthAccess()
                            // Stay on onboarding after failure so the user can retry.
                            if ok { onFinished() }
                        }
                    }
                    .accessibilityIdentifier("oh.onboarding.requestAccess")
                    OHSecondaryButton(title: "Skip for Now") {
                        Task {
                            await viewModel.completeWithoutAccess()
                            onFinished()
                        }
                    }
                    .accessibilityIdentifier("oh.onboarding.skip")
                }
            }
            .padding(OHTheme.Spacing.lg)
            .ohContentWidth()
            .background(OHTheme.pageBackground.ignoresSafeArea())
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
