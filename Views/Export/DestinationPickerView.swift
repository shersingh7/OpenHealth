//
//  DestinationPickerView.swift
//  OpenHealth
//
//  Created for OpenHealth - Free & Open Source Health Data Export
//

import SwiftUI

struct DestinationPickerView: View {
    @Binding var destinations: [ExportDestination]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(ExportDestinationType.allCases) { type in
                    Button {
                        addDestination(type: type)
                    } label: {
                        HStack {
                            Label(type.rawValue, systemImage: type.systemImage)
                                .foregroundStyle(.primary)

                            Spacer()

                            if destinations.contains(where: { $0.type == type }) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            } else {
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !destinations.isEmpty {
                    Section("Added Destinations") {
                        ForEach(destinations) { destination in
                            HStack {
                                Label(destination.name, systemImage: destination.type.systemImage)

                                Spacer()

                                Button {
                                    destinations.removeAll { $0.id == destination.id }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Export Destinations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func addDestination(type: ExportDestinationType) {
        guard !destinations.contains(where: { $0.type == type }) else { return }
        destinations.append(ExportDestination(type: type))
    }
}

// MARK: - Destination Configuration View

struct DestinationConfigurationView: View {
    @Binding var destination: ExportDestination
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Destination") {
                    Text(destination.type.rawValue)
                        .font(.headline)

                    Toggle("Enabled", isOn: $destination.isEnabled)
                }

                switch destination.type {
                case .iCloudDrive:
                    iCloudDriveConfiguration
                case .restAPI:
                    restAPIConfiguration
                case .mqtt:
                    mqttConfiguration
                case .homeAssistant:
                    homeAssistantConfiguration
                default:
                    EmptyView()
                }
            }
            .navigationTitle("Configure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var iCloudDriveConfiguration: some View {
        Section("iCloud Drive Settings") {
            TextField(
                "Folder (optional)",
                text: Binding(
                    get: { destination.configuration.folderPath ?? "" },
                    set: { destination.configuration.folderPath = $0.isEmpty ? nil : $0 }
                )
            )
            .textContentType(.URL)
        }
    }

    @ViewBuilder
    private var restAPIConfiguration: some View {
        Section("REST API Settings") {
            TextField(
                "API URL",
                text: Binding(
                    get: { destination.configuration.apiURL ?? "" },
                    set: { destination.configuration.apiURL = $0.isEmpty ? nil : $0 }
                )
            )
            .textContentType(.URL)
            .autocapitalization(.none)
            .keyboardType(.URL)

            Picker("HTTP Method", selection: $destination.configuration.httpMethod) {
                ForEach([HTTPMethod.POST, HTTPMethod.PUT, HTTPMethod.PATCH], id: \.self) { method in
                    Text(method.rawValue).tag(method)
                }
            }

            Picker("Authentication", selection: $destination.configuration.authentication) {
                ForEach(AuthenticationType.allCases, id: \.self) { auth in
                    Text(auth.rawValue).tag(auth)
                }
            }

            if destination.configuration.authentication == .bearer {
                SecureField(
                    "Bearer Token",
                    text: Binding(
                        get: { destination.configuration.accessToken ?? "" },
                        set: { destination.configuration.accessToken = $0.isEmpty ? nil : $0 }
                    )
                )
            }
        }
    }

    @ViewBuilder
    private var mqttConfiguration: some View {
        Section("MQTT Settings") {
            TextField(
                "Broker URL",
                text: Binding(
                    get: { destination.configuration.brokerURL ?? "" },
                    set: { destination.configuration.brokerURL = $0.isEmpty ? nil : $0 }
                )
            )
            .textContentType(.URL)
            .autocapitalization(.none)

            Stepper("Port: \(destination.configuration.port)", value: $destination.configuration.port, in: 1...65535)

            TextField(
                "Topic",
                text: Binding(
                    get: { destination.configuration.topic ?? "" },
                    set: { destination.configuration.topic = $0.isEmpty ? nil : $0 }
                )
            )

            TextField(
                "Client ID (optional)",
                text: Binding(
                    get: { destination.configuration.clientId ?? "" },
                    set: { destination.configuration.clientId = $0.isEmpty ? nil : $0 }
                )
            )

            TextField(
                "Username (optional)",
                text: Binding(
                    get: { destination.configuration.username ?? "" },
                    set: { destination.configuration.username = $0.isEmpty ? nil : $0 }
                )

            SecureField(
                "Password (optional)",
                text: Binding(
                    get: { destination.configuration.password ?? "" },
                    set: { destination.configuration.password = $0.isEmpty ? nil : $0 }
                )
            )
        }
    }

    @ViewBuilder
    private var homeAssistantConfiguration: some View {
        Section("Home Assistant Settings") {
            TextField(
                "Home Assistant URL",
                text: Binding(
                    get: { destination.configuration.homeAssistantURL ?? "" },
                    set: { destination.configuration.homeAssistantURL = $0.isEmpty ? nil : $0 }
                )
            )
            .textContentType(.URL)
            .autocapitalization(.none)

            SecureField(
                "Access Token",
                text: Binding(
                    get: { destination.configuration.accessToken ?? "" },
                    set: { destination.configuration.accessToken = $0.isEmpty ? nil : $0 }
                )
            )

            TextField(
                "Entity ID",
                text: Binding(
                    get: { destination.configuration.entityId ?? "" },
                    set: { destination.configuration.entityId = $0.isEmpty ? nil : $0 }
                )
            )
        }
    }
}

#Preview {
    DestinationPickerView(
        destinations: .constant([])
    )
}