//
//  DateRangePickerView.swift
//  OpenHealth
//
//  Created for OpenHealth - Free & Open Source Health Data Export
//

import SwiftUI

struct DateRangePickerView: View {
    @Binding var dateRange: DateRangePreset
    @Binding var customStartDate: Date
    @Binding var customEndDate: Date

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(DateRangePreset.allCases, id: \.self) { preset in
                    Button {
                        dateRange = preset
                    } label: {
                        HStack {
                            Text(preset.rawValue)
                                .foregroundStyle(.primary)

                            Spacer()

                            if dateRange == preset {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }

                // Custom Range Section
                Section {
                    DatePicker(
                        "Start Date",
                        selection: $customStartDate,
                        displayedComponents: .date
                    )

                    DatePicker(
                        "End Date",
                        selection: $customEndDate,
                        displayedComponents: .date
                    )
                } header: {
                    Text("Custom Range")
                } footer: {
                    Text("Select 'Custom Range' above to use these dates")
                }
            }
            .navigationTitle("Date Range")
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
}

#Preview {
    DateRangePickerView(
        dateRange: .constant(.thisMonth),
        customStartDate: .constant(Date()),
        customEndDate: .constant(Date())
    )
}