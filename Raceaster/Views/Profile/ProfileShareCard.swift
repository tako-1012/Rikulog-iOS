import SwiftUI

struct ProfileShareCard: View {
    let userName: String
    let affiliation: String
    let title: String
    let records: [ShareRecordItem]
    let showDate: Bool

    var body: some View {
        ZStack {
            Color.white
            VStack(spacing: 16) {
                Spacer(minLength: 20)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.system(size: 10, weight: .bold)).padding(.horizontal, 6).padding(.vertical, 2).background(Color.blue).foregroundColor(.white).cornerRadius(4)
                        Text(userName).font(.system(size: 28, weight: .bold)) // 20 -> 28
                        if !affiliation.isEmpty { Text(affiliation).font(.system(size: 14)).foregroundColor(.secondary) } // 12 -> 14
                    }
                    Spacer()
                    Image(systemName: "stopwatch").font(.system(size: 40)).foregroundColor(.blue.opacity(0.2)) // 30 -> 40
                }
                Divider()
                VStack(spacing: 12) {
                    if records.isEmpty {
                        Text("share.profile.select").font(.system(size: 14)).foregroundColor(.secondary).frame(maxWidth: .infinity, minHeight: 100)
                    } else {
                        ForEach(records) { record in
                            HStack {
                                Text(record.distanceName).font(.system(size: 14)).foregroundColor(.secondary)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(record.timeString).font(.system(size: 24, weight: .black, design: .monospaced)).italic()
                                    if showDate { Text(record.date.formatted(date: .numeric, time: .omitted)).font(.system(size: 8)).foregroundColor(.secondary) }
                                }
                            }
                        }
                    }
                }
                Spacer()
                HStack {
                    Text("app.name").font(.system(size: 12, weight: .bold)).foregroundColor(.blue)
                    Spacer()
                    Text("RECORDED BY APP").font(.system(size: 8)).foregroundColor(.secondary).kerning(1)
                }
                Spacer(minLength: 40)
            }
            .padding(32) // 24 -> 32に増やして全体をより中央に寄せる
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}