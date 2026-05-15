import Foundation
import SwiftUI
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

final class FocusTimerStore: ObservableObject {
    enum Phase: String {
        case idle
        case focus
        case paused
        case breakTime
    }

    struct Preset: Identifiable, Hashable {
        let id: String
        let label: String
        let focusMinutes: Int
        let breakMinutes: Int

        static let options: [Preset] = [
            Preset(id: "quick", label: "25/5", focusMinutes: 25, breakMinutes: 5),
            Preset(id: "deep", label: "50/10", focusMinutes: 50, breakMinutes: 10),
            Preset(id: "sprint", label: "90/15", focusMinutes: 90, breakMinutes: 15)
        ]
    }

    struct DailyHistoryEntry: Codable {
        var id: String { dateKey }
        let dateKey: String
        var focusSeconds: Int
    }

    private struct PersistedState: Codable {
        var totalFocusSeconds: Int
        var completedFocusSessions: Int
        var streakDays: Int
        var lastCompletedDateKey: String?
        var history: [DailyHistoryEntry]
    }

    @Published var phase: Phase = .idle
    @Published var selectedPreset: Preset = Preset.options[0]
    @Published var timeRemaining: Int = Preset.options[0].focusMinutes * 60
    @Published var completedFocusSessions: Int = 0
    @Published var totalFocusSeconds: Int = 0
    @Published var notificationsEnabled = false
    @Published var streakDays = 0

    struct DayFocusSummary: Identifiable {
        let id: String
        let label: String
        let minutes: Int
    }

    struct HistoryRow: Identifiable {
        let id: String
        let label: String
        let minutes: Int
    }

    private var activeSegmentSeconds: Int = Preset.options[0].focusMinutes * 60
    private var timer: Timer?
    private var lastTickDate: Date?

    private var history: [DailyHistoryEntry] = []
    private var focusSecondsThisSession = 0
    private var lastCompletedDateKey: String?

    private let center = UNUserNotificationCenter.current()
    private let segmentNotificationID = "fetch.segment.complete"
    private let persistenceKey = "fetch.focus.state.v1"

    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var progress: Double {
        guard activeSegmentSeconds > 0 else { return 0 }
        return 1 - (Double(timeRemaining) / Double(activeSegmentSeconds))
    }

    var timeLabel: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var todayFocusMinutes: Int {
        focusMinutes(forDateKey: todayDateKey)
    }

    var weeklyFocusMinutes: Int {
        weeklyTrend.reduce(0) { $0 + $1.minutes }
    }

    var weeklyTrend: [DayFocusSummary] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("EEE")

        let today = calendar.startOfDay(for: Date())

        return (0...6).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let key = dayFormatter.string(from: date)
            let minutes = focusMinutes(forDateKey: key)
            let label = formatter.string(from: date)
            return DayFocusSummary(id: key, label: label, minutes: minutes)
        }
    }

    var recentHistory: [HistoryRow] {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMM d")

        return history
            .sorted { $0.dateKey > $1.dateKey }
            .prefix(10)
            .compactMap { entry in
                guard let date = dayFormatter.date(from: entry.dateKey) else { return nil }
                return HistoryRow(
                    id: entry.dateKey,
                    label: formatter.string(from: date),
                    minutes: entry.focusSeconds / 60
                )
            }
    }

    init() {
        loadPersistedState()
        refreshNotificationAuthorizationStatus()
    }

    func requestNotificationPermission() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.notificationsEnabled = granted
                if granted {
                    self?.syncSegmentNotification()
                }
            }
        }
    }

    func refreshNotificationAuthorizationStatus() {
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }

    func applyPreset(_ preset: Preset) {
        selectedPreset = preset
        reset()
    }

    func startOrPause() {
        switch phase {
        case .idle:
            startFocus()
        case .focus, .breakTime:
            pause()
        case .paused:
            resume()
        }
    }

    func reset() {
        stopTimer()
        phase = .idle
        activeSegmentSeconds = selectedPreset.focusMinutes * 60
        timeRemaining = activeSegmentSeconds
        focusSecondsThisSession = 0
        lastTickDate = nil
        cancelSegmentNotification()
    }

    func handleAppDidEnterBackground() {
        lastTickDate = Date()
        syncSegmentNotification()
        persistState()
    }

    func handleAppDidBecomeActive() {
        refreshElapsedTimeFromBackground()
        cancelSegmentNotification()
    }

    private func startFocus() {
        phase = .focus
        activeSegmentSeconds = selectedPreset.focusMinutes * 60
        if timeRemaining <= 0 || timeRemaining > activeSegmentSeconds {
            timeRemaining = activeSegmentSeconds
        }
        focusSecondsThisSession = 0
        startTimer()
        syncSegmentNotification()
        fireHaptic(.medium)
    }

    private func startBreak() {
        phase = .breakTime
        activeSegmentSeconds = selectedPreset.breakMinutes * 60
        timeRemaining = activeSegmentSeconds
        startTimer()
        syncSegmentNotification()
        fireHaptic(.soft)
    }

    private func pause() {
        phase = .paused
        stopTimer()
        cancelSegmentNotification()
        fireHaptic(.light)
    }

    private func resume() {
        if timeRemaining <= 0 {
            timeRemaining = activeSegmentSeconds
        }
        phase = (activeSegmentSeconds == selectedPreset.breakMinutes * 60) ? .breakTime : .focus
        startTimer()
        syncSegmentNotification()
        fireHaptic(.light)
    }

    private func startTimer() {
        stopTimer()
        lastTickDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick(usingElapsedSeconds: 1)
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func refreshElapsedTimeFromBackground() {
        guard let lastTickDate else { return }
        guard phase == .focus || phase == .breakTime else {
            self.lastTickDate = Date()
            return
        }

        let elapsed = Int(Date().timeIntervalSince(lastTickDate))
        guard elapsed > 0 else { return }
        tick(usingElapsedSeconds: elapsed)
    }

    private func tick(usingElapsedSeconds elapsed: Int) {
        guard elapsed > 0 else { return }
        guard phase == .focus || phase == .breakTime else { return }

        lastTickDate = Date()

        let consumed = min(elapsed, max(0, timeRemaining))
        if phase == .focus {
            totalFocusSeconds += consumed
            focusSecondsThisSession += consumed
            addFocusToToday(seconds: consumed)
        }

        timeRemaining -= elapsed

        if timeRemaining <= 0 {
            completeSegment()
        }

        persistState()
    }

    private func completeSegment() {
        stopTimer()
        cancelSegmentNotification()

        if phase == .focus {
            completedFocusSessions += 1
            updateStreakAfterFocusCompletion()
            fireHaptic(.heavy)
            persistState()
            startBreak()
        } else if phase == .breakTime {
            fireHaptic(.rigid)
            persistState()
            reset()
        }
    }

    private func syncSegmentNotification() {
        cancelSegmentNotification()
        guard notificationsEnabled else { return }
        guard phase == .focus || phase == .breakTime else { return }
        guard timeRemaining > 0 else { return }

        let content = UNMutableNotificationContent()
        if phase == .focus {
            content.title = "Focus session complete"
            content.body = "Nice work. Time for a short break."
        } else {
            content.title = "Break complete"
            content.body = "Ready for your next focus session."
        }
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(timeRemaining), repeats: false)
        let request = UNNotificationRequest(identifier: segmentNotificationID, content: content, trigger: trigger)
        center.add(request)
    }

    private func cancelSegmentNotification() {
        center.removePendingNotificationRequests(withIdentifiers: [segmentNotificationID])
    }

    private var todayDateKey: String {
        dayFormatter.string(from: Date())
    }

    private func recentDateKeys(daysBack: Int) -> Set<String> {
        var keys = Set<String>()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for offset in 0...daysBack {
            if let date = calendar.date(byAdding: .day, value: -offset, to: today) {
                keys.insert(dayFormatter.string(from: date))
            }
        }

        return keys
    }

    private func focusMinutes(forDateKey key: String) -> Int {
        let seconds = history.first(where: { $0.dateKey == key })?.focusSeconds ?? 0
        return seconds / 60
    }

    private func addFocusToToday(seconds: Int) {
        let key = todayDateKey
        if let index = history.firstIndex(where: { $0.dateKey == key }) {
            history[index].focusSeconds += seconds
        } else {
            history.append(DailyHistoryEntry(dateKey: key, focusSeconds: seconds))
        }

        // Keep history bounded to avoid unbounded growth.
        history = history.sorted { $0.dateKey < $1.dateKey }
        if history.count > 90 {
            history.removeFirst(history.count - 90)
        }
    }

    private func updateStreakAfterFocusCompletion() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayKey = dayFormatter.string(from: today)

        if let lastKey = lastCompletedDateKey,
           let lastDate = dayFormatter.date(from: lastKey) {
            let dayDiff = calendar.dateComponents([.day], from: lastDate, to: today).day ?? 0
            if dayDiff == 0 {
                // Same day completion; keep streak unchanged.
            } else if dayDiff == 1 {
                streakDays += 1
            } else {
                streakDays = 1
            }
        } else {
            streakDays = 1
        }

        lastCompletedDateKey = todayKey
    }

    private func persistState() {
        let state = PersistedState(
            totalFocusSeconds: totalFocusSeconds,
            completedFocusSessions: completedFocusSessions,
            streakDays: streakDays,
            lastCompletedDateKey: lastCompletedDateKey,
            history: history
        )

        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: persistenceKey)
        }
    }

    private func loadPersistedState() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data) else {
            return
        }

        totalFocusSeconds = state.totalFocusSeconds
        completedFocusSessions = state.completedFocusSessions
        streakDays = state.streakDays
        lastCompletedDateKey = state.lastCompletedDateKey
        history = state.history
    }

    private func fireHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }
}
