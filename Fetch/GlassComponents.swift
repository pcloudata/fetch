import SwiftUI

struct LiquidPalette: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let symbol: String
    let colors: [Color]

    static let moods: [LiquidPalette] = [
        LiquidPalette(name: "Prism", symbol: "sparkles", colors: [
            Color(red: 0.19, green: 0.88, blue: 0.92),
            Color(red: 0.94, green: 0.25, blue: 0.63),
            Color(red: 0.97, green: 0.86, blue: 0.22)
        ]),
        LiquidPalette(name: "Aurora", symbol: "moon.stars.fill", colors: [
            Color(red: 0.08, green: 0.90, blue: 0.58),
            Color(red: 0.18, green: 0.45, blue: 0.96),
            Color(red: 0.87, green: 0.36, blue: 0.95)
        ]),
        LiquidPalette(name: "Ember", symbol: "flame.fill", colors: [
            Color(red: 1.00, green: 0.36, blue: 0.22),
            Color(red: 0.98, green: 0.73, blue: 0.21),
            Color(red: 0.68, green: 0.13, blue: 0.76)
        ])
    ]
}

struct LiquidGlassBackground: View {
    let palette: LiquidPalette
    let intensity: Double
    @State private var animate = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.04, blue: 0.07), Color(red: 0.06, green: 0.06, blue: 0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ForEach(Array(palette.colors.enumerated()), id: \.offset) { index, color in
                Circle()
                    .fill(color.opacity(0.58 + intensity * 0.22))
                    .frame(width: CGFloat(260 + index * 90), height: CGFloat(260 + index * 90))
                    .blur(radius: 34 + intensity * 28)
                    .offset(
                        x: animate ? CGFloat(index * 64 - 92) : CGFloat(90 - index * 42),
                        y: animate ? CGFloat(160 - index * 76) : CGFloat(-110 + index * 92)
                    )
                    .animation(
                        .easeInOut(duration: Double(7 + index * 2)).repeatForever(autoreverses: true),
                        value: animate
                    )
            }

            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.08 + intensity * 0.10)

            Canvas { context, size in
                for index in 0..<18 {
                    let x = Double(index * 67).truncatingRemainder(dividingBy: max(size.width, 1))
                    let y = Double(index * 113).truncatingRemainder(dividingBy: max(size.height, 1))
                    let rect = CGRect(x: x, y: y, width: 1, height: size.height * 0.18)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(.white.opacity(0.08)))
                }
            }
            .blendMode(.plusLighter)
        }
        .ignoresSafeArea()
        .onAppear { animate = true }
    }
}

struct GlassPanel<Content: View>: View {
    let cornerRadius: CGFloat
    let content: Content

    init(cornerRadius: CGFloat = 28, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.34), .white.opacity(0.08), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blendMode(.screen)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.28), radius: 28, x: 0, y: 20)
            }
    }
}

struct GlassIconButton: View {
    let systemName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isSelected ? .black : .white)
                .frame(width: 48, height: 48)
                .background {
                    Circle()
                        .fill(isSelected ? .white.opacity(0.90) : .white.opacity(0.12))
                        .overlay {
                            Circle().stroke(.white.opacity(0.22), lineWidth: 1)
                        }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(systemName)
    }
}

struct MetricPill: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(.white.opacity(0.16)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.62))
                Text(value)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.09))
        }
    }
}
