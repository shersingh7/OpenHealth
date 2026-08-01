# Export Schema Version 1

## Overview

JSON exports use schema version **1**. The file is the source of truth for record counts: `totalRecords` is the sum of section array lengths, never an independent counter.

Timestamps are ISO-8601 with fractional seconds (UTC when encoded via the shared formatter).

Metrics whose canonical unit is `%` are exported on the conventional **0–100** scale. HealthKit stores its percent unit as a 0–1 fraction; the adapter performs this conversion before creating portable records.

### Memory model (v1)

The app builds a full `HealthDataSnapshot` and `ExportDocument` **in memory**, then encodes the entire document to a temporary file before delivery. v1 does **not** stream samples or guarantee bounded memory for large date ranges. Treat large “All Time” exports accordingly.

## Document root

| Field | Type | Notes |
|-------|------|--------|
| `schemaVersion` | Int | Always `1` for this document |
| `exportID` | UUID string | Correlates with in-app history |
| `generatedAt` | ISO-8601 date | Encode time |
| `appVersion` | String | Marketing version string |
| `requestedRange` | `{start,end}` | Half-open interval that was queried |
| `includedMetricIDs` | [String] | Canonical HealthKit raw IDs / special IDs |
| `quantityRecords` | array | Quantity samples |
| `categoryRecords` | array | Category samples |
| `workouts` | array | Workouts (+ optional route points) |
| `electrocardiograms` | array | ECG metadata (+ optional voltages) |
| `activitySummaries` | array | Move/exercise/stand day summaries |
| `warnings` | array | Structured non-fatal issues |

## Quantity record

| Field | Type |
|-------|------|
| `id` | UUID |
| `metricID` | HealthKit quantity type raw ID |
| `value` | Double |
| `unit` | Canonical unit string |
| `startDate` / `endDate` | ISO-8601 |
| `sourceName` / `sourceBundleID` | Optional strings |
| `metadata` | Optional string map (JSON-safe scalars only) |

## Category record

| Field | Type |
|-------|------|
| `id` | UUID |
| `metricID` | HealthKit category type raw ID |
| `value` | Int (raw HK value) |
| `valueLabel` | Optional semantic label when known |
| `startDate` / `endDate` | ISO-8601 |
| `sourceName` / `sourceBundleID` | Optional |
| `metadata` | Optional string map |

## Workout record

| Field | Type |
|-------|------|
| `id` | UUID |
| `activityType` | Display name |
| `activityTypeRaw` | UInt |
| `startDate` / `endDate` | ISO-8601 |
| `duration` | Seconds |
| `totalEnergyBurnedKilocalories` | Optional Double |
| `totalDistanceMeters` | Optional Double |
| `routePoints` | Optional `[{latitude,longitude,altitude?,timestamp,speed?,course?}]` |
| `sourceName` / `sourceBundleID` / `metadata` | Optional |

## ECG record

Metadata is always preferred over fabricated waveforms. If waveform retrieval fails, metadata is kept and a warning is recorded.

## Activity summary record

Date plus move/exercise/stand values and goals.

## Warnings

| Field | Type |
|-------|------|
| `id` | UUID |
| `code` | Stable machine code (`query_failed`, `no_route_data`, …) |
| `message` | Human-readable, no sample values |
| `metricID` | Optional |

## CSV

Multi-section CSV with `# SECTION:` markers. Quantity, category, workout, ECG, activity, and warning tables are separate—do not treat them as one homogeneous table.

## GPX

GPX 1.1 track export for workouts that have route points. Encoding **fails** (does not emit a false-success empty file) when no route points exist.

## Compatibility

- Additive fields may appear in future v1 minor revisions.
- Breaking changes require `schemaVersion: 2`.
