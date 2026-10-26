import SwiftUI

struct HomeView: View {
    @ObservedObject var history: GameHistoryStore
    let registeredAt: Date?
    let isGenerating: Bool
    let start: (Difficulty) -> Void
    let showAccount: () -> Void
    let showHistory: () -> Void
    let showDemo: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    BrandMark()
                    Spacer()
                    Button(action: showHistory) {
                        Image("FlowStatistics")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 26, height: 26)
                            .foregroundStyle(Palette.ink)
                            .frame(width: 44, height: 44)
                            .accessibilityHidden(true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Game history")
                    .accessibilityIdentifier("history")
                    Button(action: showAccount) {
                        Image("FlowAccount")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 26, height: 26)
                            .foregroundStyle(Palette.ink)
                            .frame(width: 44, height: 44)
                            .accessibilityHidden(true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Your account")
                    .accessibilityIdentifier("account")
                }
                .padding(.top, 12)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Less noise.\nMore numbers.")
                        .font(AppFont.text(39, weight: .bold))
                        .tracking(-2.4)
                        .lineSpacing(-3)
                        .foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("A fresh puzzle. A moment just for you.")
                        .font(AppFont.text(14))
                        .foregroundStyle(Palette.muted)
                }

                ActivityDateStrip(history: history, registeredAt: registeredAt)

                VStack(alignment: .leading, spacing: 14) {
                    Text("SELECT A DIFFICULTY LEVEL")
                        .font(AppFont.text(10, weight: .semibold))
                        .tracking(1.8)
                        .foregroundStyle(Palette.muted)
                        .padding(.horizontal, 3)

                    VStack(spacing: 0) {
                        ForEach(Difficulty.allCases) { difficulty in
                            difficultyButton(difficulty)
                            if difficulty != .expert {
                                Rectangle().fill(Palette.line).frame(height: 1).padding(.horizontal, 20)
                            }
                        }
                    }
                    .background(.white, in: RoundedRectangle(cornerRadius: 26))
                }

                #if DEBUG && targetEnvironment(simulator)
                if let showDemo {
                    Button(action: showDemo) {
                        Label("Test player · Demo scenarios", systemImage: "slider.horizontal.3")
                            .font(AppFont.text(11, weight: .medium)).frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("demo-scenarios")
                    .foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity)
                }
                #endif
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .overlay {
            if isGenerating {
                ZStack {
                    Palette.paper.opacity(0.95).ignoresSafeArea()
                    VStack(spacing: 18) {
                        ProgressView().tint(Palette.ink)
                        Text("Making room for a fresh puzzle…")
                            .font(AppFont.text(15, weight: .medium))
                    }
                    .padding(30)
                }
                .accessibilityIdentifier("generating")
            }
        }
        .accessibilityIdentifier("home-screen")
    }

    private func difficultyButton(_ difficulty: Difficulty) -> some View {
        Button { start(difficulty) } label: {
            HStack(spacing: 15) {
                Image("FlowDifficulty\(difficulty.rank)")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(difficulty.title).font(AppFont.text(17, weight: .semibold))
                    Text(difficulty.detail).font(AppFont.text(11)).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 4)
                Text(difficulty.timeLabel).font(AppFont.text(11, weight: .medium)).foregroundStyle(Palette.muted)
                Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 20)
            .frame(minHeight: 70)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .disabled(isGenerating)
        .accessibilityLabel("\(difficulty.title), \(difficulty.timeLabel). \(difficulty.detail)")
        .accessibilityIdentifier("difficulty-\(difficulty.rawValue)")
    }
}

private struct ActivityDateStrip: View {
    @ObservedObject var history: GameHistoryStore
    let registeredAt: Date?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var today = Calendar.autoupdatingCurrent.startOfDay(for: Date())
    @State private var picker = ActivityDatePicker(day: Calendar.autoupdatingCurrent.startOfDay(for: Date()))
    @State private var daySpacing: CGFloat = 48
    @State private var refreshRevision = 0
    @State private var selectionFeedback = 0
    @State private var calendar = Calendar.autoupdatingCurrent
    @State private var showMonthPicker = false
    private static let english = Locale(identifier: "en_US")
    private var selectedDay: Date {
        let offset = Int((-picker.offset / daySpacing).rounded())
        return calendar.date(byAdding: .day, value: offset, to: picker.day) ?? picker.day
    }
    private var days: [Date] {
        (-4...4).compactMap { calendar.date(byAdding: .day, value: $0, to: picker.day) }
    }
    private var accountBounds: ClosedRange<Date> {
        DailyActivity.dateBounds(registeredAt: registeredAt, today: today, calendar: calendar)
    }
    private var bounds: ClosedRange<Date> {
        DailyActivity.monthBounds(containing: picker.day, within: accountBounds, calendar: calendar) ?? accountBounds
    }
    private var availableMonths: [Date] { DailyActivity.months(in: accountBounds, calendar: calendar) }
    private struct LoadKey: Equatable {
        let day: Date
        let interval: DateInterval?
        let interacting: Bool
        let active: Bool
        let revision: Int
    }
    private var loadKey: LoadKey {
        LoadKey(day: picker.day, interval: interval, interacting: picker.isDragging,
                active: scenePhase == .active, revision: refreshRevision)
    }

    private var interval: DateInterval? {
        DailyActivity.activityInterval(around: picker.day, bounds: bounds, calendar: calendar)
    }

    var body: some View {
        let solvedDays = history.solvedDays(calendar: calendar)
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                if availableMonths.count > 1 {
                    Button {
                        withoutAnimation { picker.cancelDrag() }
                        showMonthPicker = true
                    } label: {
                        HStack(spacing: 6) {
                            monthTitle
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .accessibilityHidden(true)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Choose another month and year")
                    .accessibilityIdentifier("activity-month-picker")
                } else {
                    monthTitle
                }
                Spacer(minLength: 4)
                Button(action: resetToToday) {
                    Label("Back to Today", systemImage: "calendar")
                        .font(AppFont.text(11, weight: .medium))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Palette.ink.opacity(0.06), in: Capsule())
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(picker.day == today ? 0 : 1)
                .allowsHitTesting(picker.day != today)
                .accessibilityHidden(picker.day == today)
                .accessibilityIdentifier("activity-reset-today")
            }
            .frame(height: 44)
            GeometryReader { geometry in
                let width = max(44, (geometry.size.width - 24) / 7)
                ZStack {
                    // The selection marker belongs to the viewport, so it stays still during dragging.
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Palette.ink.opacity(0.10))
                        .frame(width: width, height: 112)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    HStack(spacing: 4) {
                        ForEach(days, id: \.self) { day in
                            if calendar.isDate(day, equalTo: picker.day, toGranularity: .month) {
                                dayButton(day, solved: solvedDays.contains(day))
                                    .frame(width: width)
                            } else {
                                Color.clear.frame(width: width, height: 112)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .frame(width: 9 * width + 32, height: 112)
                    .position(x: geometry.size.width / 2 + picker.offset, y: 56)
                }
                .frame(width: geometry.size.width, height: 112)
                .clipped()
                .contentShape(Rectangle())
                .overlay { dateInteraction(width: geometry.size.width).accessibilityHidden(true) }
                .onAppear { daySpacing = width + 4 }
                .onChange(of: geometry.size.width) { _, _ in
                    withoutAnimation { picker.cancelDrag(); daySpacing = width + 4 }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("activity-picker")
            }
            .frame(height: 112)
            if let error = history.activityError {
                HStack {
                    Text(error)
                    Button("Retry", action: refreshActivity).font(AppFont.text(11, weight: .semibold))
                        .accessibilityIdentifier("activity-retry")
                }
                .font(AppFont.text(11)).foregroundStyle(Palette.muted)
            } else if history.isActivityFromCache && !history.isLoadingActivity {
                Text("Showing offline activity")
                    .font(AppFont.text(11)).foregroundStyle(Palette.muted)
            }
        }
        .foregroundStyle(Palette.ink)
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .sensoryFeedback(.selection, trigger: selectionFeedback)
        .sheet(isPresented: $showMonthPicker) {
            ActivityMonthSheet(months: availableMonths, selectedDay: picker.day, calendar: calendar) { month in
                selectMonth(month)
                showMonthPicker = false
            }
        }
        .task(id: loadKey) {
            guard !loadKey.interacting, loadKey.active, let interval = loadKey.interval else { return }
            await history.loadActivityAfterIdle(interval: interval)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshDate(); refreshActivity() }
            else { withoutAnimation { picker.cancelDrag() }; history.cancelActivityLoad() }
        }
        .onDisappear { history.cancelActivityLoad() }
        .onChange(of: registeredAt) { _, _ in refreshDate() }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in refreshDate() }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in refreshDate() }
    }

    private var monthTitle: some View {
        Text(picker.day.formatted(.dateTime.month(.wide).year().locale(Self.english)))
            .font(AppFont.text(14, weight: .semibold))
            .accessibilityIdentifier("activity-month")
    }

    private func selectMonth(_ month: Date) {
        guard let range = DailyActivity.monthBounds(containing: month, within: accountBounds, calendar: calendar) else { return }
        // Open historical months at their first available day; the current month returns to today.
        let day = range.contains(today) ? today : range.lowerBound
        moveSelection(to: day, within: accountBounds, feedback: true)
    }

    private func dayButton(_ day: Date, solved: Bool) -> some View {
        let selected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isToday = calendar.isDate(day, inSameDayAs: today)
        return dayContent(day, solved: solved)
            .contentShape(RoundedRectangle(cornerRadius: 18))
        // Touch taps are handled exclusively with the drag at the strip level.
        // Each date retains its own button action for VoiceOver and Switch Control.
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { center(day, feedback: true) }
        .disabled(!canCenter(day))
        .opacity(canCenter(day) ? 1 : 0.35)
        .accessibilityLabel("\(isToday ? "Today, " : "")\(day.formatted(.dateTime.weekday(.wide).month(.wide).day().year().locale(Self.english)))")
        .accessibilityValue(solved ? "At least one solved game" : activityValue)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(isToday ? "activity-today" : "activity-day-\(day.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits).locale(Self.english)))")
    }

    private func dateInteraction(width: CGFloat) -> some View {
        DateStripInteraction(
            began: { withoutAnimation { picker.beginHorizontalDrag() } },
            changed: { translation in
                withoutAnimation {
                    picker.drag(x: translation.width, y: translation.height,
                                spacing: daySpacing, calendar: calendar, bounds: bounds)
                }
            },
            ended: finishDrag,
            cancelled: { withoutAnimation { picker.cancelDrag() } },
            tapped: { x in
                let step = Int(((x - width / 2) / daySpacing).rounded())
                if let day = calendar.date(byAdding: .day, value: step, to: picker.day) {
                    center(day, feedback: true)
                }
            })
    }

    private func dayContent(_ day: Date, solved: Bool) -> some View {
        VStack(spacing: 9) {
            Text(day.formatted(.dateTime.weekday(.abbreviated).locale(Self.english)))
                .font(AppFont.text(11, weight: .semibold))
                .foregroundStyle(Palette.muted)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(day.formatted(.dateTime.day().locale(Self.english)))
                .font(AppFont.text(25, weight: .semibold))
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .opacity(solved ? 1 : 0)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 112)
    }

    private var activityValue: String {
        if history.activityError != nil { return "Activity unavailable" }
        if history.isLoadingActivity { return "Loading activity" }
        return history.isActivityFromCache ? "No solved games in offline history" : "No solved games"
    }

    private func resetToToday() {
        today = calendar.startOfDay(for: Date())
        moveSelection(to: today, within: accountBounds, feedback: true)
    }

    private func withoutAnimation(_ changes: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction, changes)
    }

    private func center(_ day: Date, feedback: Bool = false) {
        moveSelection(to: day, within: bounds, feedback: feedback)
    }

    private func moveSelection(to day: Date, within range: ClosedRange<Date>, feedback: Bool = false) {
        guard range.contains(day) else { return }
        let previous = picker.day
        if reduceMotion || !feedback { withoutAnimation { picker.center(day, bounds: range) } }
        else { withAnimation(.easeOut(duration: 0.16)) { picker.center(day, bounds: range) } }
        if feedback && previous != picker.day { selectionFeedback += 1 }
    }

    private func finishDrag(_ translation: CGSize, predicted: CGFloat) {
        let previous = picker.day
        withoutAnimation {
            picker.endDrag(x: translation.width, predicted: predicted,
                           spacing: daySpacing, calendar: calendar, bounds: bounds)
        }
        if previous != picker.day { selectionFeedback += 1 }
        // Only the visual offset animates. No delayed callback can overwrite a newer date.
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { picker.settle() }
    }

    private func canCenter(_ day: Date) -> Bool { bounds.contains(day) }

    private func refreshDate() {
        let followedToday = calendar.isDate(picker.day, inSameDayAs: today)
        calendar = .autoupdatingCurrent
        today = calendar.startOfDay(for: Date())
        if followedToday { moveSelection(to: today, within: accountBounds) }
        else {
            moveSelection(to: max(accountBounds.lowerBound, min(today, calendar.startOfDay(for: picker.day))),
                          within: accountBounds)
        }
        if availableMonths.count < 2 { showMonthPicker = false }
        refreshRevision += 1
    }

    private func refreshActivity() {
        history.invalidateActivityCache()
        refreshRevision += 1
    }

}

private struct ActivityMonthSheet: View {
    let months: [Date]
    let selectedDay: Date
    let calendar: Calendar
    let select: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    private static let english = Locale(identifier: "en_US")
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    private var monthsByYear: [Date: [Date]] {
        Dictionary(grouping: months) { calendar.dateInterval(of: .year, for: $0)?.start ?? $0 }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Choose month")
                    .font(AppFont.text(22, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                CircleIcon(symbol: "xmark", label: "Close month picker", backgroundColor: .white) { dismiss() }
                    .accessibilityIdentifier("activity-month-close")
            }
            .padding(.horizontal, 24)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(monthsByYear.keys.sorted(by: >), id: \.self) { year in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(year.formatted(.dateTime.year().locale(Self.english)))
                                    .font(AppFont.text(16, weight: .semibold))
                                    .accessibilityAddTraits(.isHeader)
                                LazyVGrid(columns: columns, spacing: 10) {
                                    ForEach(monthsByYear[year] ?? [], id: \.self) { month in
                                        monthButton(month)
                                    }
                                }
                            }
                            .id(year)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .accessibilityIdentifier("activity-month-options")
                .onAppear {
                    if let year = calendar.dateInterval(of: .year, for: selectedDay)?.start {
                        proxy.scrollTo(year, anchor: .top)
                    }
                }
            }
        }
        .padding(.top, 24)
        .foregroundStyle(Palette.ink)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.paper)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity-month-sheet")
    }

    private func monthButton(_ month: Date) -> some View {
        let selected = calendar.isDate(month, equalTo: selectedDay, toGranularity: .month)
        let identifier = String(format: "activity-month-%04d-%02d", calendar.component(.year, from: month),
                                calendar.component(.month, from: month))
        return Button { select(month) } label: {
            HStack(spacing: 6) {
                Text(month.formatted(.dateTime.month(.abbreviated).locale(Self.english)))
                    .font(AppFont.text(15, weight: .semibold))
                if selected {
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(selected ? .white : Palette.ink)
            .background(selected ? Palette.ink : .white, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(month.formatted(.dateTime.month(.wide).year().locale(Self.english)))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}
