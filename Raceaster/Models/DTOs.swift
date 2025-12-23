import Foundation
import SwiftData

// MARK: - DTOs for iCloud migration

/// Lightweight, Codable DTO for Lap
struct LapDTO: Codable {
    var id: UUID
    var lapNumber: Int
    var distance: Double
    var time: Double

    init(id: UUID = UUID(), lapNumber: Int, distance: Double, time: Double) {
        self.id = id
        self.lapNumber = lapNumber
        self.distance = distance
        self.time = time
    }

    init(from model: Lap) {
        // Use model.id which was added to `Lap` to preserve UUID across migration
        self.id = model.id
        self.lapNumber = model.lapNumber
        self.distance = model.distance
        self.time = model.time
    }

    /// Restore to @Model `Lap`. Inserts into provided `ModelContext` and preserves `id` when possible.
    func toModel(in context: ModelContext) -> Lap {
        let lap = Lap(lapNumber: lapNumber, distance: distance, time: time)
        // Preserve DTO id to model
        lap.id = self.id
        context.insert(lap)
        return lap
    }
}

/// Lightweight, Codable DTO for RaceRecord (embeds LapDTOs)
struct RaceRecordDTO: Codable {
    var id: UUID
    var raceName: String
    var date: Date
    var raceTypeRaw: String
    var totalDistance: Double
    var totalTime: Double
    var officialTime: Double?
    var memo: String
    var trackMeetTypeRaw: String?
    var ranking: Int?
    var group: Int?
    var isRelay: Bool
    var relayStage: Int?
    var includeInVDOT: Bool
    var laps: [LapDTO]

    init(
        id: UUID = UUID(),
        raceName: String,
        date: Date,
        raceTypeRaw: String,
        totalDistance: Double,
        totalTime: Double,
        officialTime: Double? = nil,
        memo: String = "",
        trackMeetTypeRaw: String? = nil,
        ranking: Int? = nil,
        group: Int? = nil,
        isRelay: Bool = false,
        relayStage: Int? = nil,
        includeInVDOT: Bool = true,
        laps: [LapDTO] = []
    ) {
        self.id = id
        self.raceName = raceName
        self.date = date
        self.raceTypeRaw = raceTypeRaw
        self.totalDistance = totalDistance
        self.totalTime = totalTime
        self.officialTime = officialTime
        self.memo = memo
        self.trackMeetTypeRaw = trackMeetTypeRaw
        self.ranking = ranking
        self.group = group
        self.isRelay = isRelay
        self.relayStage = relayStage
        self.includeInVDOT = includeInVDOT
        self.laps = laps
    }

    init(from model: RaceRecord) {
        self.id = model.id
        self.raceName = model.raceName
        self.date = model.date
        self.raceTypeRaw = model.raceTypeRaw
        self.totalDistance = model.totalDistance
        self.totalTime = model.totalTime
        self.officialTime = model.officialTime
        self.memo = model.memo
        self.trackMeetTypeRaw = model.trackMeetType?.rawValue
        self.ranking = model.ranking
        self.group = model.group
        self.isRelay = model.isRelay
        self.relayStage = model.relayStage
        self.includeInVDOT = model.includeInVDOT
        self.laps = (model.laps ?? []).map { LapDTO(from: $0) }
    }

    /// Restore to @Model `RaceRecord`. Inserts into provided `ModelContext` and preserves `id`.
    func toModel(in context: ModelContext) -> RaceRecord {
        let raceType = RaceType(rawValue: raceTypeRaw) ?? .road
        let trackType = trackMeetTypeRaw.flatMap { TrackMeetType(rawValue: $0) }

        let model = RaceRecord(
            raceName: raceName,
            date: date,
            raceType: raceType,
            totalDistance: totalDistance,
            totalTime: totalTime,
            memo: memo,
            trackMeetType: trackType,
            ranking: ranking,
            laps: [],
            officialTime: officialTime,
            includeInVDOT: includeInVDOT,
            group: group,
            isRelay: isRelay,
            relayStage: relayStage
        )

        // Preserve the original UUID if possible
        model.id = self.id

        // Insert laps and attach
        context.insert(model)
        // Ensure the optional laps array is initialized before appending
        model.laps = []
        for lapDTO in laps {
            let lap = lapDTO.toModel(in: context)
            lap.raceRecord = model
            model.laps?.append(lap)
        }

        return model
    }

    // MARK: - iCloud helpers

    /// Save an array of RaceRecordDTO to NSUbiquitousKeyValueStore under given key
    static func saveToUbiquitousStore(_ records: [RaceRecordDTO], key: String = "raceRecords_v1") throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(records)
        let base64 = data.base64EncodedString()
        let store = NSUbiquitousKeyValueStore.default
        store.set(base64, forKey: key)
        store.synchronize()
    }

    /// Load an array of RaceRecordDTO from NSUbiquitousKeyValueStore
    static func loadFromUbiquitousStore(key: String = "raceRecords_v1") throws -> [RaceRecordDTO] {
        let store = NSUbiquitousKeyValueStore.default
        guard let base64 = store.string(forKey: key), let data = Data(base64Encoded: base64) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([RaceRecordDTO].self, from: data)
    }
}
