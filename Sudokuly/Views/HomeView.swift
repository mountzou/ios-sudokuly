import SwiftUI

struct HomeView: View {
    @ObservedObject var history: GameHistoryStore
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
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Game history")
                    .accessibilityIdentifier("history")
                    Button(action: showAccount) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 25, weight: .light))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 44, height: 44)
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

                ActivityDateStrip(history: history)

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("PICK YOUR PACE")
                            .font(AppFont.text(10, weight: .semibold))
                            .tracking(1.8)
                        Spacer()
                        Text("4 levels. Endless possibilities.")
                            .font(AppFont.text(10))
                    }
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

                Group {
                    #if DEBUG && targetEnvironment(simulator)
                    if let showDemo {
                        Button(action: showDemo) {
                            Label("Test player · Demo scenarios", systemImage: "slider.horizontal.3")
                                .font(AppFont.text(11, weight: .medium)).frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("demo-scenarios")
                    } else {
                        footer
                    }
                    #else
                    footer
                    #endif
                }
                .foregroundStyle(Palette.muted)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
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

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "heart").font(.system(size: 10))
            Text("Just you and the puzzle.").font(AppFont.text(11))
        }
    }

    private func difficultyButton(_ difficulty: Difficulty) -> some View {
        Button { start(difficulty) } label: {
            HStack(spacing: 15) {
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(1...4, id: \.self) { index in
                        Capsule()
                            .fill(index <= difficulty.rank ? Palette.ink : Palette.ink.opacity(0.12))
                            .frame(width: 4, height: CGFloat(7 + index * 4))
                    }
                }
                .frame(width: 30, height: 30)
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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var today = Calendar.autoupdatingCurrent.startOfDay(for: Date())
    @State private var picker = ActivityDatePicker(day: Calendar.autoupdatingCurrent.startOfDay(for: Date()))
    @State private var daySpacing: CGFloat = 48
    @State private var refreshRevision = 0
    @State private var selectionFeedback = 0
    @State private var calendar = Calendar.autoupdatingCurrent
    private static let english = Locale(identifier: "en_US")
    private var selectedDay: Date {
        let offset = Int((-picker.offset / daySpacing).rounded())
        return calendar.date(byAdding: .day, value: offset, to: picker.day) ?? picker.day
    }
    private var days: [Date] {
        (-4...4).compactMap { calendar.date(byAdding: .day, value: $0, to: picker.day) }
    }
    private var earliestDay: Date { calendar.startOfDay(for: Date(timeIntervalSince1970: 946684800)) }
    private var bounds: ClosedRange<Date> { earliestDay...today }
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
        let week = DailyActivity.week(containing: picker.day, calendar: calendar)
        guard let visibleWeek = DailyActivity.interval(for: week, calendar: calendar),
              let start = calendar.date(byAdding: .day, value: -7, to: visibleWeek.start),
              let end = calendar.date(byAdding: .day, value: 7, to: visibleWeek.end),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return nil }
        // Include adjacent weeks so every partially visible date has its activity loaded.
        return DateInterval(start: max(start, earliestDay), end: min(end, tomorrow))
    }

    var body: some View {
        let solvedDays = history.solvedDays(calendar: calendar)
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text(picker.day.formatted(.dateTime.month(.wide).year().locale(Self.english)))
                    .font(AppFont.text(14, weight: .semibold))
                    .accessibilityIdentifier("activity-month")
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
                            dayButton(day, solved: solvedDays.contains(day))
                                .frame(width: width)
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
        .task(id: loadKey) {
            guard !loadKey.interacting, loadKey.active, let interval = loadKey.interval else { return }
            await history.loadActivityAfterIdle(interval: interval)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshDate(); refreshActivity() }
            else { withoutAnimation { picker.cancelDrag() }; history.cancelActivityLoad() }
        }
        .onDisappear { history.cancelActivityLoad() }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in refreshDate() }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in refreshDate() }
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
        center(today, feedback: true)
    }

    private func withoutAnimation(_ changes: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction, changes)
    }

    private func center(_ day: Date, feedback: Bool = false) {
        guard canCenter(day) else { return }
        let previous = picker.day
        if reduceMotion || !feedback { withoutAnimation { picker.center(day, bounds: bounds) } }
        else { withAnimation(.easeOut(duration: 0.16)) { picker.center(day, bounds: bounds) } }
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

    private func canCenter(_ day: Date) -> Bool { day >= earliestDay && day <= today }

    private func refreshDate() {
        let followedToday = calendar.isDate(picker.day, inSameDayAs: today)
        calendar = .autoupdatingCurrent
        today = calendar.startOfDay(for: Date())
        if followedToday { center(today) }
        else {
            center(min(today, calendar.startOfDay(for: picker.day)))
        }
        refreshRevision += 1
    }

    private func refreshActivity() {
        history.invalidateActivityCache()
        refreshRevision += 1
    }

}
