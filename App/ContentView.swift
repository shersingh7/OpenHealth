import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var selectedTab: AppTab = .home
    @State private var showOnboarding = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(container: container) {
                selectedTab = .export
            }
            .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.systemImage) }
            .tag(AppTab.home)
            .accessibilityIdentifier("oh.tab.home")

            ExportBuilderView(container: container)
                .tabItem { Label(AppTab.export.title, systemImage: AppTab.export.systemImage) }
                .tag(AppTab.export)
                .accessibilityIdentifier("oh.tab.export")

            AutomationListView(container: container)
                .tabItem { Label(AppTab.automations.title, systemImage: AppTab.automations.systemImage) }
                .tag(AppTab.automations)
                .accessibilityIdentifier("oh.tab.automations")

            SettingsView(container: container)
                .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage) }
                .tag(AppTab.settings)
                .accessibilityIdentifier("oh.tab.settings")
        }
        .tint(OHTheme.primaryAction)
        .task {
            await container.performLaunchSetup()
            let settings = await container.settingsStore.load()
            showOnboarding = !settings.hasCompletedOnboarding
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(container: container) {
                showOnboarding = false
            }
        }
        .alert(
            "Migration",
            isPresented: Binding(
                get: { container.migrationMessage != nil },
                set: { if !$0 { container.migrationMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { container.migrationMessage = nil }
        } message: {
            Text(container.migrationMessage ?? "")
        }
        .alert(
            "Storage",
            isPresented: Binding(
                get: { container.storageWarning != nil },
                set: { if !$0 { container.storageWarning = nil } }
            )
        ) {
            Button("OK", role: .cancel) { container.storageWarning = nil }
        } message: {
            Text(container.storageWarning ?? "")
        }
    }
}
