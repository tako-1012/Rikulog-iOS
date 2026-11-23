import SwiftUI
import SwiftData

struct ShareRaceView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    let race: RaceRecord
    let userProfile: UserProfile
    
    @Query private var allRaces: [RaceRecord]
    
    // UI State
    @State private var showRaceName: Bool = true
    @State private var showTime: Bool = true
    @State private var showDate: Bool = true
    @State private var showRank: Bool = true
    @State private var showPersonalRank: Bool = true
    @State private var showMemo: Bool = false
    @State private var selectedCardRatio: CardRatio = .standard
    @State private var showSaveAlert: Bool = false
    @State private var showingShareSheet: Bool = false
    
    // Calculated State
    @State private var personalRankTitle: String? = nil
    
    enum CardRatio: String, CaseIterable, Identifiable {
        case standard
        case square
        case story
        
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .standard: return String(localized: "share.card.standard")
            case .square: return String(localized: "share.card.square")
            case .story: return String(localized: "share.card.story")
            }
        }
        
        func size(baseWidth: CGFloat) -> CGSize {
            switch self {
            case .standard:
                return CGSize(width: baseWidth, height: baseWidth * (4.0 / 3.0))
            case .square:
                return CGSize(width: baseWidth, height: baseWidth)
            case .story:
                return CGSize(width: baseWidth, height: baseWidth * (16.0 / 9.0))
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Preview Area
                ScrollView {
                    VStack(spacing: 20) {
                        let baseWidth: CGFloat = 320
                        let cardSize = selectedCardRatio.size(baseWidth: baseWidth)
                        
                        generatedCardView()
                            .frame(width: cardSize.width, height: cardSize.height)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 10)
                            .scaleEffect(0.65)
                            .frame(width: cardSize.width * 0.65, height: cardSize.height * 0.65)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                .background(Color(uiColor: .systemGroupedBackground))
                
                // Settings List
                List {
                    Section("share.display.options") {
                        Toggle("share.show.race.name", isOn: $showRaceName)
                        Toggle("share.show.time", isOn: $showTime)
                        Toggle("share.show.date", isOn: $showDate)
                        if race.ranking != nil {
                            Toggle("share.show.rank.overall", isOn: $showRank)
                        }
                        if personalRankTitle != nil {
                            Toggle("share.show.rank.personal", isOn: $showPersonalRank)
                        }
                        if !race.memo.isEmpty {
                            Toggle("share.show.memo", isOn: $showMemo)
                        }
                    }

                    Section("share.size.section") {
                        Picker("share.card.ratio", selection: $selectedCardRatio) {
                            ForEach(CardRatio.allCases) { ratio in
                                Text(ratio.displayName).tag(ratio)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                // Bottom Button Area
                VStack(spacing: 12) {
                    Button(action: { showingShareSheet = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("share.action.share")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    Button(action: saveToPhotos) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("share.action.save")
                        }
                        .font(.headline)
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding()
                .background(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: -4)
            }
            .navigationTitle("share.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") { dismiss() }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ActivityView(activityItems: [generateUIImage()])
            }
            .alert("share.save.success", isPresented: $showSaveAlert) {
                Button("common.ok", role: .cancel) { }
            } message: {
                Text("share.save.message")
            }
            .onAppear {
                calculatePersonalRank()
            }
        }
    }
    
    private func generatedCardView() -> some View {
        SingleRaceShareCard(
            race: race,
            userProfile: userProfile,
            showRaceName: showRaceName,
            showTime: showTime,
            showDate: showDate,
            showRank: showRank,
            showPersonalRank: showPersonalRank,
            showMemo: showMemo,
            personalRankTitle: personalRankTitle
        )
    }
    
    @MainActor
    private func generateUIImage() -> UIImage {
        let baseWidth: CGFloat = 320 // プレビューと同じサイズでレンダリング
        let size = selectedCardRatio.size(baseWidth: baseWidth)
        let content = generatedCardView().frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: content)
        // Retinaスケール（3倍など）を適用して高解像度化
        renderer.scale = min(UIScreen.main.scale * 2.0, 4.0) // より高画質にするためスケールを調整
        return renderer.uiImage ?? UIImage()
    }
    
    private func saveToPhotos() {
        let image = generateUIImage()
        PhotoSaveHelper.shared.lastCompletion = { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Save error:", error.localizedDescription)
                } else {
                    showSaveAlert = true
                }
            }
        }
        UIImageWriteToSavedPhotosAlbum(image, PhotoSaveHelper.shared, #selector(PhotoSaveHelper.image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    private func calculatePersonalRank() {
        // Filter races same distance and type
        let matchingRaces = allRaces.filter {
            $0.raceType == race.raceType &&
            abs($0.totalDistance - race.totalDistance) < 0.01
        }

        // フィールド種目は記録が大きい方が優秀
        if !race.raceType.smallerIsBetter {
            let sorted = matchingRaces.sorted {
                ($0.fieldHeight ?? $0.fieldDistance ?? 0) > ($1.fieldHeight ?? $1.fieldDistance ?? 0)
            }
            if let index = sorted.firstIndex(where: { $0.id == race.id }) {
                personalRankTitle = index == 0 ? "PB" : index == 1 ? String(localized: "rank.alert.2nd.title") : index == 2 ? String(localized: "rank.alert.3rd.title") : nil
            }
            return
        }

        let sorted = matchingRaces.sorted { $0.totalTime < $1.totalTime }

        if let index = sorted.firstIndex(where: { $0.id == race.id }) {
            let rank = index + 1
            if rank == 1 {
                personalRankTitle = "PB"
            } else if rank == 2 {
                personalRankTitle = String(localized: "rank.alert.2nd.title")
            } else if rank == 3 {
                personalRankTitle = String(localized: "rank.alert.3rd.title")
            } else {
                // Fiscal Year Logic
                let startMonth = userProfile.seasonStartMonth
                
                func getFiscalYear(date: Date) -> Int {
                    let y = Calendar.current.component(.year, from: date)
                    let m = Calendar.current.component(.month, from: date)
                    return (m < startMonth) ? y - 1 : y
                }
                
                let targetFiscalYear = getFiscalYear(date: race.date)
                
                let seasonRaces = matchingRaces.filter { getFiscalYear(date: $0.date) == targetFiscalYear }
                let sortedSeason = seasonRaces.sorted { $0.totalTime < $1.totalTime }
                
                if let sbIndex = sortedSeason.firstIndex(where: { $0.id == race.id }), sbIndex == 0 {
                    personalRankTitle = "SB"
                } else {
                    personalRankTitle = nil
                }
            }
        }
    }
}
