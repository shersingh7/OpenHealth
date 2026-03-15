//
//  DataTypeSelectionView.swift
//  OpenHealth
//
//  Created for OpenHealth - Free & Open Source Health Data Export
//

import SwiftUI

struct DataTypeSelectionView: View {
    @Binding var selectedTypes: Set<String>
    let availableTypes: [HealthDataType]

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var expandedCategories: Set<HealthDataCategory> = []

    var filteredTypes: [HealthDataType] {
        if searchText.isEmpty {
            return availableTypes
        }
        return availableTypes.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.id.localizedCaseInsensitiveContains(searchText)
        }
    }

    var groupedTypes: [HealthDataCategory: [HealthDataType]] {
        Dictionary(grouping: filteredTypes, by: { $0.category })
    }

    var body: some View {
        NavigationStack {
            List {
                // Select All / Deselect All
                Section {
                    HStack {
                        Button("Select All") {
                            selectedTypes = Set(availableTypes.map { $0.id })
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button("Deselect All") {
                            selectedTypes.removeAll()
                        }
                        .buttonStyle(.bordered)
                    }
                    .listRowBackground(Color.clear)
                }

                // Categories
                ForEach(HealthDataCategory.allCases, id: \.self) { category in
                    let typesInCategory = groupedTypes[category] ?? []

                    if !typesInCategory.isEmpty {
                        Section {
                            ForEach(typesInCategory) { type in
                                Button {
                                    if selectedTypes.contains(type.id) {
                                        selectedTypes.remove(type.id)
                                    } else {
                                        selectedTypes.insert(type.id)
                                    }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(type.displayName)
                                                .foregroundStyle(.primary)

                                            Text(type.id)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        if selectedTypes.contains(type.id) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.blue)
                                        } else {
                                            Image(systemName: "circle")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        } header: {
                            Label(category.rawValue, systemImage: category.systemImage)
                        }
                    }
                }
            }
            .navigationTitle("Select Data Types")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    DataTypeSelectionView(
        selectedTypes: .constant(Set(["stepCount", "heartRate"])),
        availableTypes: [
            HealthDataType(id: "stepCount", hkIdentifier: "HKQuantityTypeIdentifierStepCount", displayName: "Step Count", category: .activity, unit: "count", description: ""),
            HealthDataType(id: "heartRate", hkIdentifier: "HKQuantityTypeIdentifierHeartRate", displayName: "Heart Rate", category: .cardiovascular, unit: "bpm", description: ""),
            HealthDataType(id: "bodyMass", hkIdentifier: "HKQuantityTypeIdentifierBodyMass", displayName: "Body Mass", category: .bodyMeasurements, unit: "kg", description: "")
        ]
    )
}