//
//  ContentView.swift
//  OpenHealth
//
//  Created for OpenHealth - Free & Open Source Health Data Export
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "heart.fill")
                }
                .tag(0)

            ExportView()
                .tabItem {
                    Label("Export", systemImage: "arrow.up.doc.fill")
                }
                .tag(1)

            AutomationListView()
                .tabItem {
                    Label("Automations", systemImage: "gearshape.2.fill")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .tint(.red)
    }
}

#Preview {
    let hkService = HealthKitService()
    ContentView()
        .environmentObject(hkService)
        .environmentObject(ExportService(healthKitService: hkService))
}