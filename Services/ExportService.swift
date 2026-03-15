//
//  ExportService.swift
//  OpenHealth
//
//  Created for OpenHealth - Free & Open Source Health Data Export
//

import Foundation
import HealthKit

/// Service for exporting health data to various formats and destinations
@MainActor
class ExportService: ObservableObject {

    // MARK: - Properties

    private let healthKitService: HealthKitService
    private let fileManager = FileManager.default

    @Published var isExporting = false
    @Published var exportProgress: Double = 0
    @Published var lastExportResult: ExportResult?

    // MARK: - Initialization

    init(healthKitService: HealthKitService = HealthKitService()) {
        self.healthKitService = healthKitService
    }

    // MARK: - Export Methods

    /// Export health data according to configuration
    func export(configuration: ExportConfiguration) async throws -> ExportResult {
        await MainActor.run {
            isExporting = true
            exportProgress = 0
        }

        let startTime = Date()

        do {
            // Fetch data
            let (start, end) = configuration.effectiveDateRange
            var allSamples: [HealthDataSample] = []
            var totalRecords = 0

            // Export progress: 10% fetching, 80% processing, 10% writing
            await MainActor.run { exportProgress = 0.1 }

            // Fetch quantity samples for selected types
            for typeId in configuration.dataTypes {
                guard let identifier = HKQuantityTypeIdentifier(rawValue: typeId) else { continue }

                do {
                    let samples = try await healthKitService.fetchQuantitySamples(
                        type: identifier,
                        from: start,
                        to: end
                    )

                    let healthDataSamples = samples.map { HealthDataSample(from: $0, typeId: typeId) }
                    allSamples.append(contentsOf: healthDataSamples)
                    totalRecords += samples.count
                } catch {
                    print("Failed to fetch \(typeId): \(error)")
                }
            }

            await MainActor.run { exportProgress = 0.5 }

            // Fetch workouts if included
            var workouts: [WorkoutData] = []
            if configuration.includeWorkoutRoutes {
                let hkWorkouts = try await healthKitService.fetchWorkouts(from: start, to: end)
                for workout in hkWorkouts {
                    let route = try await healthKitService.fetchWorkoutRoute(for: workout)
                    let routeData = route.isEmpty ? nil : RouteData(from: route)
                    workouts.append(WorkoutData(from: workout, routeData: routeData))
                }
            }

            await MainActor.run { exportProgress = 0.7 }

            // Export to format
            let data: Data
            let filename: String

            switch configuration.format {
            case .csv:
                data = try exportToCSV(samples: allSamples, workouts: workouts, configuration: configuration)
                filename = generateFilename(prefix: "health_export", format: .csv)
            case .json:
                data = try exportToJSON(samples: allSamples, workouts: workouts, configuration: configuration)
                filename = generateFilename(prefix: "health_export", format: .json)
            case .gpx:
                data = try exportToGPX(workouts: workouts)
                filename = generateFilename(prefix: "workout_routes", format: .gpx)
            }

            await MainActor.run { exportProgress = 0.9 }

            // Save to destinations
            var finalURL: URL?
            for destination in configuration.destinations where destination.isEnabled {
                do {
                    finalURL = try await exportToDestination(data: data, filename: filename, destination: destination)
                } catch {
                    print("Failed to export to \(destination.name): \(error)")
                }
            }

            // If no destinations, save locally
            if finalURL == nil {
                finalURL = try saveLocally(data: data, filename: filename)
            }

            let duration = Date().timeIntervalSince(startTime)

            let result = ExportResult(
                success: true,
                fileURL: finalURL,
                error: nil,
                recordsExported: totalRecords + workouts.count,
                duration: duration
            )

            await MainActor.run {
                isExporting = false
                exportProgress = 1.0
                lastExportResult = result
            }

            return result

        } catch {
            let duration = Date().timeIntervalSince(startTime)
            let result = ExportResult(
                success: false,
                fileURL: nil,
                error: error,
                recordsExported: 0,
                duration: duration
            )

            await MainActor.run {
                isExporting = false
                exportProgress = 0
                lastExportResult = result
            }

            return result
        }
    }

    // MARK: - Format Exporters

    private func exportToCSV(
        samples: [HealthDataSample],
        workouts: [WorkoutData],
        configuration: ExportConfiguration
    ) throws -> Data {
        var csv = "type,value,unit,start_date,end_date,source\n"

        for sample in samples {
            let row = [
                sample.typeId,
                String(sample.value),
                sample.unit,
                ISO8601DateFormatter().string(from: sample.startDate),
                ISO8601DateFormatter().string(from: sample.endDate),
                sample.source.replacingOccurrences(of: ",", with: ";")
            ]
            csv += row.joined(separator: ",") + "\n"
        }

        // Add workouts
        if !workouts.isEmpty {
            csv += "\n# Workouts\n"
            csv += "workout_type,start_date,end_date,duration_seconds,energy_kcal,distance_meters\n"

            for workout in workouts {
                let row = [
                    workout.workoutType,
                    ISO8601DateFormatter().string(from: workout.startDate),
                    ISO8601DateFormatter().string(from: workout.endDate),
                    String(format: "%.1f", workout.duration),
                    String(format: "%.1f", workout.totalEnergyBurned ?? 0),
                    String(format: "%.1f", workout.totalDistance ?? 0)
                ]
                csv += row.joined(separator: ",") + "\n"
            }
        }

        return Data(csv.utf8)
    }

    private func exportToJSON(
        samples: [HealthDataSample],
        workouts: [WorkoutData],
        configuration: ExportConfiguration
    ) throws -> Data {
        struct HealthExport: Codable {
            let exportDate: Date
            let configuration: String
            let samples: [HealthDataSample]
            let workouts: [WorkoutData]
        }

        let export = HealthExport(
            exportDate: Date(),
            configuration: configuration.name,
            samples: samples,
            workouts: workouts
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        return try encoder.encode(export)
    }

    private func exportToGPX(workouts: [WorkoutData]) throws -> Data {
        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="OpenHealth" xmlns="http://www.topografix.com/GPX/1/1">

        """

        for workout in workouts {
            guard let route = workout.routeData else { continue }

            gpx += """
            <trk>
                <name>\(workout.workoutType)</name>
                <time>\(ISO8601DateFormatter().string(from: workout.startDate))</time>
                <trkseg>

            """

            for point in route.points {
                gpx += """
                    <trkpt lat="\(point.latitude)" lon="\(point.longitude)">
                        <ele>\(point.altitude)</ele>
                        <time>\(ISO8601DateFormatter().string(from: point.timestamp))</time>
                    </trkpt>

                """
            }

            gpx += """
                </trkseg>
            </trk>

            """
        }

        gpx += "</gpx>"

        return Data(gpx.utf8)
    }

    // MARK: - Destination Exporters

    private func exportToDestination(
        data: Data,
        filename: String,
        destination: ExportDestination
    ) async throws -> URL {
        switch destination.type {
        case .localFiles:
            return try saveLocally(data: data, filename: filename)

        case .iCloudDrive:
            return try saveToICloud(data: data, filename: filename, folder: destination.configuration.folderPath)

        case .restAPI:
            return try await sendToAPI(data: data, destination: destination)

        default:
            throw ExportError.unsupportedDestination
        }
    }

    private func saveLocally(data: Data, filename: String) throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let exportsPath = documentsPath.appendingPathComponent("OpenHealthExports")

        try FileManager.default.createDirectory(at: exportsPath, withIntermediateDirectories: true)

        let fileURL = exportsPath.appendingPathComponent(filename)
        try data.write(to: fileURL)

        return fileURL
    }

    private func saveToICloud(data: Data, filename: String, folder: String?) throws -> URL {
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            throw ExportError.iCloudNotAvailable
        }

        let exportsPath = containerURL.appendingPathComponent("Documents")
            .appendingPathComponent("OpenHealthExports")

        if let folder = folder {
            let folderPath = exportsPath.appendingPathComponent(folder)
            try FileManager.default.createDirectory(at: folderPath, withIntermediateDirectories: true)
            let fileURL = folderPath.appendingPathComponent(filename)
            try data.write(to: fileURL)
            return fileURL
        } else {
            try FileManager.default.createDirectory(at: exportsPath, withIntermediateDirectories: true)
            let fileURL = exportsPath.appendingPathComponent(filename)
            try data.write(to: fileURL)
            return fileURL
        }
    }

    private func sendToAPI(data: Data, destination: ExportDestination) async throws -> URL {
        guard let urlString = destination.configuration.apiURL,
              let url = URL(string: urlString) else {
            throw ExportError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = destination.configuration.httpMethod.rawValue
        request.httpBody = data

        // Set content type based on format
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add custom headers
        for (key, value) in destination.configuration.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Add authentication
        switch destination.configuration.authentication {
        case .bearer:
            if let token = destination.configuration.accessToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        case .basic:
            // Would need username/password encoding
            break
        case .apiKey:
            if let key = destination.configuration.accessToken {
                request.setValue(key, forHTTPHeaderField: "X-API-Key")
            }
        case .none, .oauth2:
            break
        }

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ExportError.apiError
        }

        return url
    }

    // MARK: - Helpers

    private func generateFilename(prefix: String, format: ExportFormat) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        return "\(prefix)_\(timestamp).\(format.fileExtension)"
    }
}

// MARK: - Errors

enum ExportError: LocalizedError {
    case iCloudNotAvailable
    case unsupportedDestination
    case invalidURL
    case apiError
    case fileWriteFailed

    var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable:
            return "iCloud Drive is not available"
        case .unsupportedDestination:
            return "This export destination is not yet supported"
        case .invalidURL:
            return "Invalid URL for API endpoint"
        case .apiError:
            return "API request failed"
        case .fileWriteFailed:
            return "Failed to write file"
        }
    }
}