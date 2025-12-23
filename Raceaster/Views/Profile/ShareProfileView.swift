import SwiftUI
import UIKit

final class PhotoSaveHelper: NSObject {
    static let shared = PhotoSaveHelper()
    var lastCompletion: ((Error?) -> Void)?

    @objc func image(_ image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: UnsafeRawPointer?) {
        let err = error as Error?
        lastCompletion?(err)
        lastCompletion = nil
    }
}

struct ShareProfileView: View {
    @Environment(\.dismiss) var dismiss

    var userName: String
    var affiliation: String
    var allRecords: [ShareRecordItem]

    @State private var selectedTitleMode: TitleMode = .pb
    @State private var customTitle: String = ""
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedRecordIds: Set<UUID> = []
    @State private var showingShareSheet: Bool = false
    @State private var showDateOnCard: Bool = true
    @State private var showSaveAlert: Bool = false
    @FocusState private var isTitleFocused: Bool
    @State private var selectedCardRatio: CardRatio = .standard

    enum TitleMode: String, CaseIterable {
        case pb = "PB"
        case sb = "SB"
        case custom = "自由入力"

        var fullTitle: String {
            switch self {
            case .pb: return "PERSONAL BEST"
            case .sb: return "SEASON BEST"
            case .custom: return "CUSTOM"
            }
        }
    }

    private func getBaseRecords() -> [ShareRecordItem] {
        let source: [ShareRecordItem]
        switch selectedTitleMode {
        case .pb: source = allRecords
        case .sb: source = allRecords.filter { Calendar.current.component(.year, from: $0.date) == selectedYear }
        case .custom: return allRecords
        }
        let grouped = Dictionary(grouping: source, by: { "\($0.totalDistance)-\($0.raceType)" })
        return grouped.values.compactMap { $0.min(by: { $0.totalTime < $1.totalTime }) }
    }

    enum CardRatio: String, CaseIterable, Identifiable {
        case standard
        case square
        case story

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .standard: return "標準"
            case .square: return "正方形"
            case .story: return "ストーリー"
            }
        }
        func size(baseWidth: CGFloat) -> CGSize {
            switch self {
            case .standard:
                return CGSize(width: baseWidth, height: baseWidth * (440.0 / 320.0))
            case .square:
                return CGSize(width: baseWidth, height: baseWidth)
            case .story:
                return CGSize(width: baseWidth, height: baseWidth * (16.0 / 9.0))
            }
        }
    }

    private var trackRecords: [ShareRecordItem] {
        getBaseRecords().filter { $0.raceType == .track }.sorted { $0.totalDistance < $1.totalDistance }
    }

    private var roadRecords: [ShareRecordItem] {
        getBaseRecords().filter { $0.raceType == .road }.sorted { $0.totalDistance < $1.totalDistance }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        let baseWidth: CGFloat = 320
                        let cardSize = selectedCardRatio.size(baseWidth: baseWidth)
                        // 内部のビュー自体に明示的なサイズを与え、プレビューでは縮小して表示する
                        generatedCardView()
                            .frame(width: cardSize.width, height: cardSize.height)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 10)
                            .scaleEffect(0.6)
                            .frame(width: cardSize.width * 0.6, height: cardSize.height * 0.6)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical)
                }
                .background(Color(uiColor: .systemGroupedBackground))

                List {
                    Section("タイトル・モード設定") {
                        Picker("モード", selection: $selectedTitleMode) {
                            ForEach(TitleMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        // ✅ 修正：iOS 17+ の新しい引数形式に変更
                        .onChange(of: selectedTitleMode) { oldValue, newValue in
                            selectedRecordIds.removeAll()
                        }

                        if selectedTitleMode == .sb {
                            let years = Array(Set(allRecords.map { Calendar.current.component(.year, from: $0.date) })).sorted(by: >)
                            Picker("対象年度", selection: $selectedYear) {
                                ForEach(years, id: \.self) { Text("\(String($0))年度").tag($0) }
                            }
                        }
                        if selectedTitleMode == .custom {
                            TextField("タイトルを入力", text: $customTitle)
                                .focused($isTitleFocused)
                                .submitLabel(.done) // ✅ キーボードに完了を表示
                        }
                    }

                    Section("表示オプション") {
                        Toggle("日付を表示する", isOn: $showDateOnCard)

                        Picker("カード比率", selection: $selectedCardRatio) {
                            ForEach(CardRatio.allCases) { ratio in
                                Text(ratio.displayName).tag(ratio)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedCardRatio) { oldValue, newValue in
                            // 切り替え先が正方形なら選択数を3つに絞る
                            if newValue == .square && selectedRecordIds.count > 3 {
                                selectedRecordIds = Set(Array(selectedRecordIds).prefix(3))
                            }
                        }
                    }

                    if !trackRecords.isEmpty {
                        Section("トラック種目 (BEST)") { ForEach(trackRecords) { recordRow($0) } }
                    }
                    if !roadRecords.isEmpty {
                        Section("ロード種目 (BEST)") { ForEach(roadRecords) { recordRow($0) } }
                    }
                }
            }
            .navigationTitle("共有画像の作成").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    HStack(spacing: 16) {
                        Button(action: saveToPhotos) { Image(systemName: "square.and.arrow.down") }.disabled(selectedRecordIds.isEmpty)
                        Button(action: { showingShareSheet = true }) { Image(systemName: "square.and.arrow.up") }.disabled(selectedRecordIds.isEmpty)
                    }
                }
                // ✅ キーボードを閉じるボタン（ツールバー上にも配置）
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { isTitleFocused = false }
                }
            }
            .sheet(isPresented: $showingShareSheet) { ActivityView(activityItems: [generateUIImage()]) }
            .alert("保存完了", isPresented: $showSaveAlert) { Button("OK", role: .cancel) { } } message: { Text("写真ライブラリに保存しました。") }
        }
    }

    @ViewBuilder
    private func recordRow(_ record: ShareRecordItem) -> some View {
        Button(action: { toggleSelection(record) }) {
            HStack {
                VStack(alignment: .leading) {
                    Text(record.distanceName).fontWeight(.semibold)
                    Text(record.timeString).font(.caption).foregroundStyle(.blue)
                }
                Spacer()
                Image(systemName: selectedRecordIds.contains(record.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedRecordIds.contains(record.id) ? Color.blue : Color.secondary.opacity(0.3))
            }
        }.buttonStyle(.plain)
    }

    private func toggleSelection(_ record: ShareRecordItem) {
        if selectedRecordIds.contains(record.id) {
            selectedRecordIds.remove(record.id)
        } else {
            let limit = (selectedCardRatio == .square) ? 3 : 5
            if selectedRecordIds.count < limit {
                selectedRecordIds.insert(record.id)
            }
        }
    }
    
    private func generatedCardView() -> some View {
        let selected = allRecords.filter { selectedRecordIds.contains($0.id) }
        let sorted = selected.sorted { (r1, r2) in
            if r1.raceType != r2.raceType { return r1.raceType == .track }
            return r1.totalDistance < r2.totalDistance
        }
        let displayTitle = selectedTitleMode == .custom ? (customTitle.isEmpty ? "RECORD" : customTitle) : selectedTitleMode.fullTitle
        return ProfileShareCard(userName: userName, affiliation: affiliation, title: displayTitle, records: sorted, showDate: showDateOnCard)
    }
    
    @MainActor private func generateUIImage() -> UIImage {
        let baseWidth: CGFloat = 320
        let size = selectedCardRatio.size(baseWidth: baseWidth)
        let content = generatedCardView().frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3.0
        return renderer.uiImage ?? UIImage()
    }

    // ✅ 写真ライブラリへの保存関数（完了ハンドラを設定し、エラーをログ出力）
    private func saveToPhotos() {
        let image = generateUIImage()

        PhotoSaveHelper.shared.lastCompletion = { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("UIImageWriteToSavedPhotosAlbum error:", error.localizedDescription)
                } else {
                    showSaveAlert = true
                }
            }
        }

        UIImageWriteToSavedPhotosAlbum(image, PhotoSaveHelper.shared, #selector(PhotoSaveHelper.image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
}