import SwiftUI

/// ペース計算のViewModel
@Observable
class PaceCalculatorViewModel {
    // 距離（km）
    var distance: String = ""
    
    // 時間（時、分、秒）
    var hours: Int = 0
    var minutes: Int = 0
    var seconds: Int = 0
    
    // ペース（分、秒）
    var paceMinutes: Int = 0
    var paceSeconds: Int = 0
    
    // 計算モード
    enum CalculationMode {
        case calculatePace    // 距離と時間からペースを計算
        case calculateTime    // 距離とペースから時間を計算
        case calculateDistance // 時間とペースから距離を計算
    }
    
    var mode: CalculationMode = .calculatePace
    
    // 計算結果
    var resultText: String = ""
    
    /// ペースを計算
    func calculatePace() {
        guard let dist = Double(distance), dist > 0 else {
            resultText = "有効な距離を入力してください"
            return
        }
        
        let totalSeconds = TimeFormatter.toSeconds(hours: hours, minutes: minutes, seconds: seconds)
        guard totalSeconds > 0 else {
            resultText = "有効な時間を入力してください"
            return
        }
        
        let pacePerKm = Double(totalSeconds) / dist
        let (_, paceMin, paceSec) = TimeFormatter.breakdown(Int(pacePerKm))
        
        resultText = "ペース: \(paceMin):\(String(format: "%02d", paceSec)) /km"
    }
    
    /// 時間を計算
    func calculateTime() {
        guard let dist = Double(distance), dist > 0 else {
            resultText = "有効な距離を入力してください"
            return
        }
        
        let paceSecondsPerKm = paceMinutes * 60 + paceSeconds
        guard paceSecondsPerKm > 0 else {
            resultText = "有効なペースを入力してください"
            return
        }
        
        let totalSeconds = Int(Double(paceSecondsPerKm) * dist)
        let timeString = TimeFormatter.formatTime(totalSeconds)
        
        resultText = "タイム: \(timeString)"
    }
    
    /// 距離を計算
    func calculateDistance() {
        let totalSeconds = TimeFormatter.toSeconds(hours: hours, minutes: minutes, seconds: seconds)
        guard totalSeconds > 0 else {
            resultText = "有効な時間を入力してください"
            return
        }
        
        let paceSecondsPerKm = paceMinutes * 60 + paceSeconds
        guard paceSecondsPerKm > 0 else {
            resultText = "有効なペースを入力してください"
            return
        }
        
        let calculatedDistance = Double(totalSeconds) / Double(paceSecondsPerKm)
        
        resultText = String(format: "距離: %.2f km", calculatedDistance)
    }
    
    /// 計算を実行
    func calculate() {
        switch mode {
        case .calculatePace:
            calculatePace()
        case .calculateTime:
            calculateTime()
        case .calculateDistance:
            calculateDistance()
        }
    }
    
    /// リセット
    func reset() {
        distance = ""
        hours = 0
        minutes = 0
        seconds = 0
        paceMinutes = 0
        paceSeconds = 0
        resultText = ""
    }
}

/// ペース計算ビュー
struct PaceCalculatorView: View {
    @State private var viewModel = PaceCalculatorViewModel()
    
    var body: some View {
        NavigationStack {
            Form {
                // 計算モード選択
                Section("計算モード") {
                    Picker("計算する値", selection: $viewModel.mode) {
                        Text("ペース").tag(PaceCalculatorViewModel.CalculationMode.calculatePace)
                        Text("時間").tag(PaceCalculatorViewModel.CalculationMode.calculateTime)
                        Text("距離").tag(PaceCalculatorViewModel.CalculationMode.calculateDistance)
                    }
                    .pickerStyle(.segmented)
                }
                
                // 距離入力（距離を計算する場合は非表示）
                if viewModel.mode != .calculateDistance {
                    Section("距離") {
                        HStack {
                            TextField("距離", text: $viewModel.distance)
                                .keyboardType(.decimalPad)
                            Text("km")
                        }
                    }
                }
                
                // 時間入力（時間を計算する場合は非表示）
                if viewModel.mode != .calculateTime {
                    Section("時間") {
                        HStack {
                            Picker("時", selection: $viewModel.hours) {
                                ForEach(0..<24, id: \.self) { hour in
                                    Text("\(hour)").tag(hour)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80)
                            
                            Text(":")
                            
                            Picker("分", selection: $viewModel.minutes) {
                                ForEach(0..<60, id: \.self) { minute in
                                    Text("\(minute)").tag(minute)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80)
                            
                            Text(":")
                            
                            Picker("秒", selection: $viewModel.seconds) {
                                ForEach(0..<60, id: \.self) { second in
                                    Text("\(second)").tag(second)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80)
                        }
                    }
                }
                
                // ペース入力（ペースを計算する場合は非表示）
                if viewModel.mode != .calculatePace {
                    Section("ペース (/km)") {
                        HStack {
                            Picker("分", selection: $viewModel.paceMinutes) {
                                ForEach(0..<60, id: \.self) { minute in
                                    Text("\(minute)").tag(minute)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 100)
                            
                            Text(":")
                            
                            Picker("秒", selection: $viewModel.paceSeconds) {
                                ForEach(0..<60, id: \.self) { second in
                                    Text("\(second)").tag(second)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 100)
                        }
                    }
                }
                
                // 計算ボタン
                Section {
                    Button(action: {
                        viewModel.calculate()
                    }) {
                        HStack {
                            Spacer()
                            Text("計算")
                                .font(.headline)
                            Spacer()
                        }
                    }
                }
                
                // 結果表示
                if !viewModel.resultText.isEmpty {
                    Section("結果") {
                        Text(viewModel.resultText)
                            .font(.title2)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("ペース計算")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("リセット") {
                        viewModel.reset()
                    }
                }
            }
        }
    }
}

#Preview {
    PaceCalculatorView()
}
