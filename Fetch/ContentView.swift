import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var timerStore = FocusTimerStore()
    @State private var palette = LiquidPalette.moods[0]
    @State private var intensity = 0.64
    @State private var selectedDockItem = "timer"

    private let dockItems = ["timer", "chart.bar.fill", "sparkles", "gearshape.fill"]

    var body: some View {
        ZStack {
            LiquidGlassBackground(palette: palette, intensity: intensity)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header
                    timerHero
                    presetPicker
                    focusControls
                    metricGrid
                    notificationCard
                    Spacer(minLength: 92)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
            }

            VStack {
                Spacer()
                dock
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                timerStore.handleAppDidBecomeActive()
            case .background:
                timerStore.handleAppDidEnterBackground()
            default:
                break
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("Fetch")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Focus sessions with a liquid-glass interface")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.66))
            }

            Spacer()

            GlassIconButton(systemName: "wand.and.stars", isSelected: true) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    palette = LiquidPalette.moods.randomElement() ?? palette
                    intensity = Double.random(in: 0.35...0.95)
                }
            }
        }
    }

    private var timerHero: some View {
        GlassPanel(cornerRadius: 34) {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.14), lineWidth: 12)
                        .frame(width: 210, height: 210)

                    Circle()
                        .trim(from: 0, to: timerStore.progress)
                        .stroke(
                            AngularGradient(colors: palette.colors + palette.colors.prefix(1), center: .center),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 210, height: 210)
                        .animation(.easeInOut(duration: 0.25), value: timerStore.progress)

                    VStack(spacing: 8) {
                        Text(timerStore.timeLabel)
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()

                        Text(phaseLabel)
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.14), in: Capsule())
                            .foregroundStyle(.white)
                    }
                }

                Text("Run focused sessions, pause anytime, and let Fetch guide breaks automatically.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
    }

    private var presetPicker: some View {
        GlassPanel(cornerRadius: 24) {
            HStack(spacing: 10) {
                ForEach(FocusTimerStore.Preset.options) { preset in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            timerStore.applyPreset(preset)
                        }
                    } label: {
                        Text(preset.label)
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(timerStore.selectedPreset == preset ? .black : .white.opacity(0.86))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background {
                                Capsule()
                                    .fill(timerStore.selectedPreset == preset ? .white.opacity(0.92) : .white.opacity(0.10))
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
    }

    private var focusControls: some View {
        GlassPanel(cornerRadius: 24) {
            HStack(spacing: 10) {
                Button(action: timerStore.startOrPause) {
                    Label(primaryActionLabel, systemImage: primaryActionSymbol)
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)

                Button(action: timerStore.reset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 19, weight: .bold))
                        .frame(width: 52, height: 52)
                        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
        }
    }

    private var metricGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricPill(title: "Preset", value: timerStore.selectedPreset.label, symbol: "slider.horizontal.below.square.filled.and.square")
            MetricPill(title: "Today", value: "\(timerStore.todayFocusMinutes) min", symbol: "clock.fill")
            MetricPill(title: "Sessions", value: "\(timerStore.completedFocusSessions)", symbol: "checkmark.circle.fill")
            MetricPill(title: "State", value: phaseLabel, symbol: "bolt.heart.fill")
        }
    }

    private var notificationCard: some View {
        GlassPanel(cornerRadius: 22) {
            HStack(spacing: 12) {
                Image(systemName: timerStore.notificationsEnabled ? "bell.badge.fill" : "bell.slash.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(.white.opacity(0.18)))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Session Alerts")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(.white)
                    Text(timerStore.notificationsEnabled ? "Enabled for phase transitions" : "Enable notifications for timer alerts")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.66))
                }

                Spacer()

                if !timerStore.notificationsEnabled {
                    Button("Enable") {
                        timerStore.requestNotificationPermission()
                    }
                    .buttonStyle(.plain)
                    .font(.footnote.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.9), in: Capsule())
                    .foregroundStyle(.black)
                }
            }
            .padding(14)
        }
    }

    private var dock: some View {
        GlassPanel(cornerRadius: 32) {
            HStack(spacing: 12) {
                ForEach(dockItems, id: \.self) { item in
                    GlassIconButton(systemName: item, isSelected: selectedDockItem == item) {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                            selectedDockItem = item
                        }
                    }
                }
            }
            .padding(10)
        }
    }

    private var phaseLabel: String {
        switch timerStore.phase {
        case .idle:
            return "Ready"
        case .focus:
            return "Focus"
        case .paused:
            return "Paused"
        case .breakTime:
            return "Break"
        }
    }

    private var primaryActionLabel: String {
        switch timerStore.phase {
        case .idle:
            return "Start Session"
        case .focus, .breakTime:
            return "Pause"
        case .paused:
            return "Resume"
        }
    }

    private var primaryActionSymbol: String {
        switch timerStore.phase {
        case .idle, .paused:
            return "play.fill"
        case .focus, .breakTime:
            return "pause.fill"
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
