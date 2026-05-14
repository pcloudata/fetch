import Foundation
import SwiftUI
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

    @Published var phase: Phase = .idle
    @Published var selectedPreset: Preset = Preset.options[0]
    @Published var timeRemaining: Int = Preset.options[0].focusMinutes * 60
    @Published var completedFocusSessions: Int = 0
    @Published var totalFocusSeconds: Int = 0

    private var activeSegmentSeconds: Int = Preset.options[0].focusMinutes * 60
    private var timer: Timer?

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
        totalFocusSeconds / 60
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
    }

    private func startFocus() {
        phase = .focus
        activeSegmentSeconds = selectedPreset.focusMinutes * 60
        if timeRemaining <= 0 || timeRemaining > activeSegmentSeconds {
            timeRemaining = activeSegmentSeconds
        }
        startTimer()
        fireHaptic(.medium)
    }

    private func startBreak() {
        phase = .breakTime
        activeSegmentSeconds = selectedPreset.breakMinutes * 60
        timeRemaining = activeSegmentSeconds
        startTimer()
        fireHaptic(.soft)
    }

    private func pause() {
        phase = .paused
        stopTimer()
        fireHaptic(.light)
    }

    private func resume() {
        if timeRemaining <= 0 {
            timeRemaining = activeSegmentSeconds
        }
        phase = (activeSegmentSeconds == selectedPreset.breakMinutes * 60) ? .breakTime : .focus
        startTimer()
        fireHaptic(.light)
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard timeRemaining > 0 else {
            completeSegment()
            return
        }

        timeRemaining -= 1
        if phase == .focus {
            totalFocusSeconds += 1
        }

        if timeRemaining == 0 {
            completeSegment()
        }
    }

    private func completeSegment() {
        stopTimer()
        if phase == .focus {
            completedFocusSessions += 1
            fireHaptic(.heavy)
            startBreak()
        } else if phase == .breakTime {
            fireHaptic(.rigid)
            reset()
        }
    }

    private func fireHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }
}
