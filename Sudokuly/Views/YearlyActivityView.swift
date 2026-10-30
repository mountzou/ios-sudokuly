import SwiftUI

struct YearlyActivityView: View {
    @ObservedObject var history: GameHistoryStore
    let registeredAt: Date?
    @Environment(\.scenePhase) private var scenePhase
    @State private var calendar = Calendar.current
    @State private var today = Calendar.current.startOfDay(for: Date())
    @State private var revision = 0
    private static let english = Locale(identifier: "en_US")
    private let cellSize: CGFloat = 8
    private let gap: CGFloat = 3
    private var year: YearlyActivity { YearlyActivity(today: today, registeredAt: registeredAt, calendar: calendar) }
    private var previewDays: Set<Date>? {
        #if DEBUG && targetEnvironment(simulator)
        if history.ownerID == "sudokuly-ui-test", !history.isCloud,
           ProcessInfo.processInfo.arguments.contains("--activity-year-demo") {
            return HistoryDemoData.solvedYearDays(today: today, calendar: calendar)
        }
        #endif
        return nil
    }
    private var solvedDays: Set<Date> {
        year.solvedDays(in: previewDays ?? history.solvedDays(calendar: calendar))
    }
    private struct LoadKey: Equatable {
        let interval: DateInterval?
        let active: Bool
        let revision: Int
    }
    private var loadKey: LoadKey { LoadKey(interval: year.interval, active: scenePhase == .active, revision: revision) }

    var body: some View {
        let year = year
        let solved = solvedDays
        let monthLabels = monthLabels(in: year)
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Your rhythm")
                        .font(AppFont.text(17, weight: .semibold))
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 8)
                    Text("LAST 365 DAYS")
                        .font(AppFont.text(8, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(Palette.muted)
                }
                Text("\(solved.count) \(solved.count == 1 ? "day" : "days") with a solved puzzle")
                    .font(AppFont.text(11))
                    .foregroundStyle(Palette.muted)
                    .accessibilityIdentifier("history-activity-summary")
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: gap) {
                        ForEach(year.weeks.indices, id: \.self) { index in
                            VStack(spacing: 7) {
                                Color.clear.frame(width: cellSize, height: 12)
                                    .overlay(alignment: .leading) {
                                        if let month = monthLabels[index] {
                                            Text(month)
                                                .font(AppFont.text(9, weight: .medium))
                                                .foregroundStyle(Palette.muted)
                                                .fixedSize()
                                        }
                                    }
                                VStack(spacing: gap) {
                                    ForEach(0..<7, id: \.self) { row in
                                        dayCell(year.weeks[index][row], solved: solved, bounds: year.availableBounds)
                                    }
                                }
                            }
                            .id(index)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Activity over the last 365 days")
                .accessibilityValue("\(solved.count) days with at least one solved Sudoku. Earlier dates are to the left.")
                .accessibilityIdentifier("history-activity-grid")
                .onAppear { proxy.scrollTo(year.weeks.count - 1, anchor: .trailing) }
                .onChange(of: today) { _, _ in proxy.scrollTo(year.weeks.count - 1, anchor: .trailing) }
            }

            HStack(spacing: 6) {
                if previewDays != nil {
                    Text("Demo preview").font(AppFont.text(9))
                }
                Spacer(minLength: 4)
                RoundedRectangle(cornerRadius: 2).fill(Palette.ink.opacity(0.08)).frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text("Rest day").font(AppFont.text(9))
                RoundedRectangle(cornerRadius: 2).fill(Palette.ink).frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text("Solved").font(AppFont.text(9))
            }
            .foregroundStyle(Palette.muted)

            if !history.isLoadingActivity {
                if let error = history.activityError {
                    HStack {
                        Text(error)
                        Button("Retry") { history.invalidateActivityCache(); revision += 1 }
                            .font(AppFont.text(10, weight: .semibold))
                    }
                    .font(AppFont.text(10)).foregroundStyle(Palette.muted)
                } else if history.isActivityFromCache {
                    Text("Showing offline activity").font(AppFont.text(10)).foregroundStyle(Palette.muted)
                }
            }
        }
        .padding(18)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("history-activity")
        .task(id: loadKey) {
            guard loadKey.active, let interval = loadKey.interval else { return }
            await history.loadActivityAfterIdle(interval: interval)
        }
        .onDisappear { history.cancelActivityLoad() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshDate(); history.invalidateActivityCache(); revision += 1 }
            else { history.cancelActivityLoad() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in refreshDate() }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in refreshDate() }
    }

    private func monthLabels(in year: YearlyActivity) -> [Int: String] {
        let font = UIFontMetrics.default.scaledFont(for: AppFont.uiFont(9, weight: .medium))
        var labels: [Int: String] = [:]
        var nextLabelX: CGFloat?
        // Keep the most recent labels, omitting earlier ones when their text would overlap.
        for index in year.weeks.indices.reversed() {
            let days = year.weeks[index].compactMap { $0 }
            // Prefer the actual month boundary if a short first month shares its week with the next.
            guard let day = days.first(where: { calendar.component(.day, from: $0) == 1 })
                ?? (index == 0 ? days.first : nil) else { continue }
            let text = day.formatted(.dateTime.month(.abbreviated).locale(Self.english))
            let width = (text as NSString).size(withAttributes: [.font: font]).width
            let x = CGFloat(index) * (cellSize + gap)
            if let nextLabelX, x + width + 4 > nextLabelX { continue }
            labels[index] = text
            nextLabelX = x
        }
        return labels
    }

    private func dayCell(_ day: Date?, solved: Set<Date>, bounds: ClosedRange<Date>) -> some View {
        let available = day.map { bounds.contains($0) } ?? false
        let filled = day.map { solved.contains($0) } ?? false
        return RoundedRectangle(cornerRadius: 2)
            .fill(day == nil ? .clear : filled ? Palette.ink : Palette.ink.opacity(available ? 0.08 : 0.025))
            .overlay {
                if day == today {
                    RoundedRectangle(cornerRadius: 2).strokeBorder(Palette.ink.opacity(0.5), lineWidth: 1)
                }
            }
            .frame(width: cellSize, height: cellSize)
    }

    private func refreshDate() {
        calendar = .current
        today = calendar.startOfDay(for: Date())
    }
}
