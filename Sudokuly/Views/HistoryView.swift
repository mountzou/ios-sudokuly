import SwiftUI

struct HistoryView: View {
    @ObservedObject var history: GameHistoryStore
    let close: () -> Void

    private var days: [Date] {
        Array(Set(history.records.map { Calendar.current.startOfDay(for: $0.finishedAt) })).sorted(by: >)
    }

    private var showsEmptyHistory: Bool {
        history.records.isEmpty && !history.isLoading && history.readError == nil
            && !(history.isCloud && (history.isFromCache || !history.pendingIDs.isEmpty || history.saveError != nil))
    }

    var body: some View {
        Group {
            if showsEmptyHistory {
                emptyHistory
            } else {
                historyContent
            }
        }
        .background(Palette.paper.ignoresSafeArea())
        .foregroundStyle(Palette.ink)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var historyHeader: some View {
        HStack {
            CircleIcon(symbol: "chevron.left", label: "Close history", action: close)
                .accessibilityIdentifier("history-close")
            Spacer()
        }
        .padding(.top, 12)
    }

    private var emptyHistory: some View {
        VStack(spacing: 0) {
            historyHeader
                .padding(.horizontal, 24)
                .frame(maxWidth: 480).frame(maxWidth: .infinity)
            GeometryReader { geometry in
                ScrollView {
                    emptyState
                        .padding(.vertical, 40)
                        .modifier(IllustratedContentWidth())
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
                .scrollIndicators(.hidden)
            }
            // Balance the 46-point back button and its 12-point top inset.
            Color.clear.frame(height: 58).accessibilityHidden(true)
        }
    }

    private var historyContent: some View {
        VStack(spacing: 0) {
            historyHeader
                .padding(.horizontal, 24)
                .frame(maxWidth: 480).frame(maxWidth: .infinity)
            historyScrollContent
        }
    }

    private var historyScrollContent: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 14) {
                    Text("Every game.\nA little progress.")
                        .font(AppFont.text(32, weight: .bold)).tracking(-1.2)
                        .accessibilityAddTraits(.isHeader)
                    Text("Your moments of focus, all in one place.")
                        .font(AppFont.text(14)).foregroundStyle(Palette.muted)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

                if history.isCloud && (!history.pendingIDs.isEmpty || history.saveError != nil) {
                    notice(history.saveError ?? "Some games are waiting to sync to your account.", symbol: "icloud.and.arrow.up")
                } else if history.readError != nil && !history.records.isEmpty {
                    notice(history.readError!, symbol: "icloud.slash")
                } else if history.isCloud && history.isFromCache && !history.records.isEmpty {
                    Text("Showing history kept on this device.")
                        .font(AppFont.text(11)).foregroundStyle(Palette.muted)
                        .multilineTextAlignment(.center)
                }

                if history.records.isEmpty {
                    if history.isLoading {
                        VStack(spacing: 15) {
                            ProgressView().tint(Palette.ink)
                            Text("Finding your moments of focus…").font(AppFont.text(13))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 50)
                        .accessibilityIdentifier("history-loading")
                    } else if let error = history.readError {
                        notice(error, symbol: "icloud.slash")
                    } else if history.isCloud && history.isFromCache {
                        notice("Connect to load your history. Your saved games will be here when you’re back online.", symbol: "icloud")
                    } else { emptyState }
                } else {
                    summary
                    if history.hasMore {
                        Text("Stats reflect the \(history.records.count) games shown below.")
                            .font(AppFont.text(11)).foregroundStyle(Palette.muted)
                            .multilineTextAlignment(.center)
                    }
                    ForEach(days, id: \.self) { day in
                        VStack(spacing: 12) {
                            Text(dayLabel(day))
                                .font(AppFont.text(12, weight: .medium))
                                .foregroundStyle(Palette.muted)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .accessibilityAddTraits(.isHeader)
                            VStack(spacing: 0) {
                                let records = history.records.filter { Calendar.current.isDate($0.finishedAt, inSameDayAs: day) }
                                ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                                    NavigationLink(value: record) { HistoryRow(record: record) }
                                        .buttonStyle(PressStyle())
                                        .accessibilityIdentifier("history-game-\(record.id.uuidString)")
                                    if index < records.count - 1 {
                                        Rectangle().fill(Palette.line).frame(height: 1)
                                    }
                                }
                            }
                        }
                    }
                    if history.hasMore {
                        if history.isLoadingMore { ProgressView().tint(Palette.ink).frame(maxWidth: .infinity) }
                        else {
                            Button("Load earlier games", action: history.loadMore)
                                .font(AppFont.text(14, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 48)
                                .foregroundStyle(Palette.ink)
                                .overlay(Capsule().stroke(Palette.line, lineWidth: 1))
                                .buttonStyle(PressStyle())
                                .accessibilityIdentifier("history-load-more")
                        }
                    }
                    Text("One puzzle at a time.")
                        .font(AppFont.text(11)).foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 32).padding(.top, 24).padding(.bottom, 32)
            .frame(maxWidth: 480).frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private func notice(_ message: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(message, systemImage: symbol).font(AppFont.text(12)).lineSpacing(3)
                .accessibilityIdentifier("history-sync-message")
            Button("Retry", action: history.retry).font(AppFont.text(12, weight: .semibold))
                .frame(minHeight: 44).accessibilityIdentifier("history-retry")
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 22))
    }

    private var summary: some View {
        HStack(spacing: 0) {
            summaryStat("Played", value: "\(history.records.count)")
                .accessibilityLabel("\(history.records.count) \(history.records.count == 1 ? "game" : "games") played")
                .accessibilityIdentifier("history-count")
            summaryStat("Solved", value: "\(history.records.filter { $0.outcome == .won }.count)")
            summaryStat("Focus", value: "\(Int(history.records.reduce(0) { $0 + $1.duration } / 60))m")
        }
        .padding(.top, 4).padding(.bottom, 28)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.line).frame(height: 1)
        }
    }

    private func summaryStat(_ label: String, value: String) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(AppFont.text(30, weight: .semibold)).tracking(-0.8).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(AppFont.text(12)).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        IllustratedMessageHeader(illustration: "HistoryThinking", title: "No games yet.",
                                 message: "Your game results will appear here.", titleID: "history-empty")
    }

    private func dayLabel(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(AppFormatting.historyDay)
    }
}

private struct HistoryRow: View {
    let record: GameRecord

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(record.difficulty.title).font(AppFont.text(17, weight: .semibold)).tracking(-0.3)
                Text(record.outcome.label).font(AppFont.text(12)).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                Text(clockText(record.duration)).font(AppFont.text(16, weight: .medium)).monospacedDigit()
                Text(record.finishedAt, format: AppFormatting.time)
                    .font(AppFont.text(11)).foregroundStyle(Palette.muted)
            }
            Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(Palette.muted)
        }
        .padding(.vertical, 20)
        .foregroundStyle(Palette.ink).contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(record.difficulty.title), \(record.outcome.label), \(clockText(record.duration)), \(record.mistakes) mistakes, \(record.finishedAt.formatted(AppFormatting.dateAndTime))")
    }
}

struct HistoryDetailView: View {
    let record: GameRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CircleIcon(symbol: "chevron.left", label: "Back to history") { dismiss() }
                    .accessibilityIdentifier("history-detail-back")
                Spacer()
            }
            .padding(.top, 12).padding(.horizontal, 24)
            .frame(maxWidth: 480).frame(maxWidth: .infinity)

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 28) {
                        GameResultHeader(outcome: record.outcome, titleIdentifier: "history-detail-title")
                        VStack(spacing: 24) {
                            VStack(spacing: 6) {
                                Text(record.finishedAt, format: AppFormatting.date)
                                    .font(AppFont.text(16, weight: .medium)).tracking(-0.3)
                                    .accessibilityIdentifier("history-detail-date")
                                Text(record.finishedAt, format: AppFormatting.time)
                                    .font(AppFont.text(12)).foregroundStyle(Palette.muted)
                                    .accessibilityIdentifier("history-detail-time")
                            }
                            .multilineTextAlignment(.center)

                            recapStats
                        }
                    }
                    .padding(.vertical, 24)
                    .modifier(IllustratedContentWidth())
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(Palette.paper.ignoresSafeArea()).foregroundStyle(Palette.ink)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var recapStats: some View {
        HStack(alignment: .top, spacing: 12) {
            recapStat("Level", value: record.difficulty.title)
            recapStat("Time", value: clockText(record.duration))
            recapStat("Mistakes", value: "\(record.mistakes) / 3")
        }
        .padding(.vertical, 24)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.line).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.line).frame(height: 1)
        }
    }

    private func recapStat(_ label: String, value: String) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(AppFont.text(24, weight: .semibold)).tracking(-0.6).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label)
                .font(AppFont.text(12)).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}
