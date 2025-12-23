import SwiftUI
import SwiftData

struct SeasonDistanceBest: Identifiable {
    let id = UUID()
    let distanceName: String
    let date: Date
    let time: Double
}

struct SeasonBestListView: View {
    @Query(sort: \RaceRecord.date) private var races: [RaceRecord]
    @Query(sort: \RaceDistance.distanceKm) private var distances: [RaceDistance]
    @Query private var userProfiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext

    @State private var expandedSeasons: Set<Int> = []

    private var seasonStartMonth: Int {
        userProfiles.first?.seasonStartMonth ?? 4
    }

    // returns mapping: seasonStartYear -> [SeasonDistanceBest]
    private var seasonBestsByYear: [Int: [SeasonDistanceBest]] {
        var dict: [Int: [SeasonDistanceBest]] = [:]
        guard !distances.isEmpty else { return dict }

        // determine season range
        let calendar = Calendar.current
        guard let firstDate = races.first?.date, let lastDate = races.last?.date else { return dict }
        let firstYear = calendar.component(.year, from: firstDate)
        let lastYear = calendar.component(.year, from: lastDate)

        // we'll span years from firstYear-1 to lastYear
        for year in (firstYear-1)...(lastYear+1) {
            // season start
            var comps = DateComponents(); comps.year = year; comps.month = seasonStartMonth; comps.day = 1
            guard let seasonStart = calendar.date(from: comps) else { continue }
            guard let nextStart = calendar.date(byAdding: .year, value: 1, to: seasonStart) else { continue }
            let seasonEnd = calendar.date(byAdding: .day, value: -1, to: nextStart)!

            // for each registered distance, find best in season
            var list: [SeasonDistanceBest] = []
            for dist in distances {
                let inSeason = races.filter { r in
                    dist.matches(distance: r.totalDistance) && r.raceType == dist.raceType && r.date >= seasonStart && r.date <= seasonEnd
                }
                if let best = inSeason.min(by: { $0.totalTime < $1.totalTime }) {
                    list.append(SeasonDistanceBest(distanceName: dist.name, date: best.date, time: best.totalTime))
                }
            }

            if !list.isEmpty {
                dict[year] = list.sorted(by: { $0.distanceName < $1.distanceName })
            }
        }

        return dict
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            if seasonBestsByYear.isEmpty {
                Text("過去のシーズンベストはありません")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)
            } else {
                ForEach(seasonBestsByYear.keys.sorted(by: >), id: \ .self) { year in
                    let list = seasonBestsByYear[year] ?? []
                    // header button
                    Button(action: {
                        if expandedSeasons.contains(year) { expandedSeasons.remove(year) } else { expandedSeasons.insert(year) }
                    }) {
                        HStack(spacing: 12) {
                            Text(String(year) + "シーズン")
                                .font(.subheadline)
                                .bold()
                            Spacer()
                            let start = seasonStartDate(for: year)
                            let end = seasonEndDate(for: year)
                            let sc = Calendar.current
                            let sy = sc.component(.year, from: start)
                            let sm = sc.component(.month, from: start)
                            let ey = sc.component(.year, from: end)
                            let em = sc.component(.month, from: end)
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(String(sy) + "/" + String(format: "%02d", sm) + " - " + String(ey) + "/" + String(format: "%02d", em))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Image(systemName: expandedSeasons.contains(year) ? "chevron.up" : "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)

                    if expandedSeasons.contains(year) {
                        // group by race type inside the season
                        let orderedTypes: [RaceType] = {
                            let preferred: [RaceType] = [.track, .road]
                            let rest = RaceType.allCases.filter { !preferred.contains($0) }
                            return preferred + rest
                        }()

                        ForEach(orderedTypes, id: \.self) { raceType in
                            let itemsForType = list.filter { sb in
                                if let distModel = distances.first(where: { $0.name == sb.distanceName }) {
                                    return distModel.raceType == raceType
                                }
                                return false
                            }

                            if !itemsForType.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(raceType.displayName)
                                        .font(.subheadline)
                                        .bold()

                                    ForEach(itemsForType) { sb in
                                        let dateLabel = sb.date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits).locale(Locale(identifier: "ja_JP")))
                                        if let matched = findRace(for: sb) {
                                            NavigationLink(destination: RaceDetailView(race: matched)) {
                                                HStack {
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(sb.distanceName)
                                                            .font(.headline)
                                                        Text(matched.raceName)
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                    Spacer()
                                                    VStack(alignment: .trailing, spacing: 4) {
                                                        Text(TimeFormatter.formatTime(sb.time, for: raceType))
                                                            .font(.callout)
                                                            .bold()
                                                            .foregroundStyle(.blue)
                                                        Text(matched.date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits).locale(Locale(identifier: "ja_JP"))))
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                                .padding(.vertical, 8)
                                            }
                                            .buttonStyle(.plain)
                                        } else {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(sb.distanceName)
                                                        .font(.headline)
                                                    Text(dateLabel)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                Spacer()
                                                VStack(alignment: .trailing, spacing: 4) {
                                                    Text(TimeFormatter.formatTime(sb.time, for: raceType))
                                                        .font(.callout)
                                                        .bold()
                                                        .foregroundStyle(.blue)
                                                    Text(dateLabel)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .padding(.vertical, 8)
                                        }
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .onAppear {
            if let latest = seasonBestsByYear.keys.max() {
                expandedSeasons = [latest]
            }
        }
    }

    private func findRace(for sb: SeasonDistanceBest) -> RaceRecord? {
        // match by distance name and time and date (allow small tolerance)
        // find registered distance model
            if let distModel = distances.first(where: { $0.name == sb.distanceName }) {
            return races.first { r in
                distModel.matches(distance: r.totalDistance) && r.raceType == distModel.raceType &&
                abs(r.totalTime - sb.time) < 0.5 &&
                Calendar.current.isDate(r.date, inSameDayAs: sb.date)
            }
        }
        return nil
    }

    private func seasonStartDate(for year: Int) -> Date {
        var comps = DateComponents(); comps.year = year; comps.month = seasonStartMonth; comps.day = 1
        return Calendar.current.date(from: comps) ?? Date()
    }

    private func seasonEndDate(for year: Int) -> Date {
        let start = seasonStartDate(for: year)
        return Calendar.current.date(byAdding: .year, value: 1, to: start)?.addingTimeInterval(-1) ?? start
    }

    private func formatSeconds(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct SeasonBestListView_Previews: PreviewProvider {
    static var previews: some View {
        SeasonBestListView()
            .modelContainer(for: [RaceRecord.self, Lap.self, RaceDistance.self, UserProfile.self], inMemory: true)
            .padding()
    }
}
