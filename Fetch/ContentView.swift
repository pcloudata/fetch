import SwiftUI

struct ContentView: View {
    @State private var palette = LiquidPalette.moods[0]
    @State private var intensity = 0.64
    @State private var selectedDockItem = "sparkles"

    private let dockItems = ["sparkles", "waveform.path.ecg", "circle.hexagongrid.fill", "person.crop.circle"]

    var body: some View {
        ZStack {
            LiquidGlassBackground(palette: palette, intensity: intensity)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header
                    heroOrb
                    moodPicker
                    intensityControl
                    metricGrid
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
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("Fetch")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("A tactile space for light, depth, and motion")
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

    private var heroOrb: some View {
        GlassPanel(cornerRadius: 34) {
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: palette.colors + palette.colors.prefix(1),
                                center: .center
                            )
                        )
                        .blur(radius: 1)
                        .opacity(0.95)
                        .frame(width: 188, height: 188)
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(0.36), lineWidth: 1)
                                .blur(radius: 0.5)
                        }
                        .shadow(color: palette.colors[0].opacity(0.45), radius: 42, x: 0, y: 18)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.95), .white.opacity(0.16), .clear],
                                center: .topLeading,
                                startRadius: 4,
                                endRadius: 132
                            )
                        )
                        .frame(width: 170, height: 170)
                        .blendMode(.screen)

                    Image(systemName: palette.symbol)
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 8) {
                    Text("\(palette.name) Surface")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Glass bends the background, but the controls stay crisp and reachable.")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.70))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
    }

    private var moodPicker: some View {
        GlassPanel(cornerRadius: 24) {
            HStack(spacing: 10) {
                ForEach(LiquidPalette.moods) { mood in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            palette = mood
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: mood.symbol)
                            Text(mood.name)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(palette == mood ? .black : .white.opacity(0.86))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background {
                            Capsule()
                                .fill(palette == mood ? .white.opacity(0.92) : .white.opacity(0.10))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
    }

    private var intensityControl: some View {
        GlassPanel(cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Refraction", systemImage: "slider.horizontal.3")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(Int(intensity * 100))%")
                        .font(.callout.monospacedDigit().weight(.bold))
                        .foregroundStyle(.white.opacity(0.72))
                }

                Slider(value: $intensity, in: 0.2...1.0)
                    .tint(.white)
            }
            .padding(18)
        }
    }

    private var metricGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricPill(title: "Depth", value: "42 px", symbol: "square.stack.3d.up.fill")
            MetricPill(title: "Glow", value: "\(Int(70 + intensity * 24))%", symbol: "sun.max.fill")
            MetricPill(title: "Blur", value: "\(Int(18 + intensity * 24))", symbol: "drop.fill")
            MetricPill(title: "Motion", value: "Live", symbol: "gyroscope")
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
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
