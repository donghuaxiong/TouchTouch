import AppKit
import SwiftUI

@MainActor
final class HUDManager {
    private var panel: NSPanel?
    private var state: HUDState?
    private var hideWorkItem: DispatchWorkItem?

    func show(target: ControlTarget, value: Double, usesDarkBackground: Bool) {
        hideWorkItem?.cancel()

        let state = state ?? HUDState(target: target, value: value, usesDarkBackground: usesDarkBackground)
        let panel = panel ?? makePanel(state: state)

        withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.88, blendDuration: 0.08)) {
            state.target = target
            state.value = min(max(value, 0), 1)
            state.usesDarkBackground = usesDarkBackground
        }

        panel.center()
        panel.orderFrontRegardless()
        self.state = state
        self.panel = panel

        let workItem = DispatchWorkItem { [weak self] in
            self?.panel?.orderOut(nil)
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85, execute: workItem)
    }

    private func makePanel(state: HUDState) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 188, height: 188),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSHostingView(rootView: HUDView(state: state))
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }
}

@MainActor
private final class HUDState: ObservableObject {
    @Published var target: ControlTarget
    @Published var value: Double
    @Published var usesDarkBackground: Bool

    init(target: ControlTarget, value: Double, usesDarkBackground: Bool) {
        self.target = target
        self.value = min(max(value, 0), 1)
        self.usesDarkBackground = usesDarkBackground
    }
}

private struct HUDView: View {
    @ObservedObject var state: HUDState

    private var iconColor: Color {
        state.usesDarkBackground ? Color(red: 0.88, green: 0.91, blue: 0.96) : Color(red: 0.18, green: 0.24, blue: 0.32)
    }

    private let brightnessColor = Color(red: 1.0, green: 0.62, blue: 0.0)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 31, style: .continuous)
                .fill(backgroundGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 31, style: .continuous)
                        .strokeBorder(strokeColor, lineWidth: 1.2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 31, style: .continuous))
                .shadow(color: shadowColor, radius: 18, x: 0, y: 10)

            VStack(spacing: 33) {
                Group {
                    switch state.target {
                    case .brightness:
                        SunHUDIcon(value: state.value, color: iconColor)
                    case .volume:
                        VolumeHUDIcon(level: volumeLevel, color: iconColor)
                    }
                }
                .frame(width: 82, height: 76)
                .animation(.easeOut(duration: 0.16), value: state.target)
                .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.86), value: state.value)

                HUDProgressBar(value: state.value, fillColor: progressColor)
            }
            .padding(.top, 12)
        }
        .frame(width: 188, height: 188)
        .background(Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 31, style: .continuous))
        .animation(.easeInOut(duration: 0.22), value: state.usesDarkBackground)
    }

    private var volumeLevel: Int {
        switch state.value {
        case ...0.001:
            return 0
        case ..<0.34:
            return 1
        case ..<0.67:
            return 2
        default:
            return 3
        }
    }

    private var progressColor: Color {
        state.target == .brightness ? brightnessColor : iconColor
    }

    private var strokeColor: Color {
        state.usesDarkBackground ? Color.white.opacity(0.13) : Color.white.opacity(0.72)
    }

    private var shadowColor: Color {
        state.usesDarkBackground ? Color.black.opacity(0.28) : Color.black.opacity(0.13)
    }

    private var backgroundGradient: LinearGradient {
        if state.usesDarkBackground {
            return LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.14, blue: 0.19),
                    Color(red: 0.17, green: 0.16, blue: 0.23),
                    Color(red: 0.20, green: 0.17, blue: 0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.90, blue: 0.98),
                    Color(red: 0.99, green: 0.94, blue: 0.96),
                    Color(red: 0.99, green: 0.94, blue: 0.89)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct SunHUDIcon: View {
    let value: Double
    let color: Color

    private var normalizedValue: Double {
        min(max(value, 0), 1)
    }

    var body: some View {
        ZStack {
            if normalizedValue <= 0.02 {
                Circle()
                    .stroke(color, lineWidth: 5)
                    .frame(width: 43, height: 43)
                    .transition(.scale.combined(with: .opacity))
            } else {
                ForEach(0..<8) { index in
                    Capsule(style: .continuous)
                        .fill(color.opacity(rayOpacity(for: index)))
                        .frame(width: 5.5, height: rayLength(for: index))
                        .offset(y: -rayOffset(for: index))
                        .rotationEffect(.degrees(Double(index) * 45))
                }

                Circle()
                    .fill(color)
                    .frame(width: 31 + normalizedValue * 7, height: 31 + normalizedValue * 7)
                    .shadow(color: color.opacity(0.08), radius: 6, x: 0, y: 4)
            }
        }
    }

    private func rayLength(for index: Int) -> CGFloat {
        let stagger = Double(index % 2) * 0.12
        return CGFloat(8 + (normalizedValue + stagger) * 9)
    }

    private func rayOffset(for index: Int) -> CGFloat {
        let stagger = Double(index % 2) * 0.08
        return CGFloat(27 + (normalizedValue + stagger) * 8)
    }

    private func rayOpacity(for index: Int) -> Double {
        let stagger = Double(index % 2) * 0.12
        return min(1, 0.35 + normalizedValue * 0.65 + stagger)
    }
}

private struct VolumeHUDIcon: View {
    let level: Int
    let color: Color

    var body: some View {
        ZStack {
            SpeakerShape()
                .fill(color)
                .frame(width: 72, height: 72)
                .offset(x: level == 0 ? -7 : -8)

            if level == 0 {
                MuteSlashLine()
                    .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                    .frame(width: 72, height: 72)
                    .offset(x: -7)
                    .transition(.opacity.combined(with: .scale))
            } else {
                ForEach(0..<level, id: \.self) { index in
                    VolumeWaveShape(index: index)
                        .stroke(color, style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
                        .frame(width: 74, height: 74)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
            }
        }
        .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.9), value: level)
    }
}

private struct SpeakerShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        var path = Path()
        path.move(to: CGPoint(x: w * 0.13, y: h * 0.38))
        path.addLine(to: CGPoint(x: w * 0.31, y: h * 0.38))
        path.addLine(to: CGPoint(x: w * 0.55, y: h * 0.18))
        path.addCurve(
            to: CGPoint(x: w * 0.62, y: h * 0.23),
            control1: CGPoint(x: w * 0.59, y: h * 0.15),
            control2: CGPoint(x: w * 0.62, y: h * 0.17)
        )
        path.addLine(to: CGPoint(x: w * 0.62, y: h * 0.77))
        path.addCurve(
            to: CGPoint(x: w * 0.55, y: h * 0.82),
            control1: CGPoint(x: w * 0.62, y: h * 0.83),
            control2: CGPoint(x: w * 0.59, y: h * 0.85)
        )
        path.addLine(to: CGPoint(x: w * 0.31, y: h * 0.62))
        path.addLine(to: CGPoint(x: w * 0.13, y: h * 0.62))
        path.closeSubpath()
        return path
    }
}

private struct VolumeWaveShape: Shape {
    let index: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.width * 0.54, y: rect.height * 0.5)
        let radius = rect.width * (0.18 + CGFloat(index) * 0.15)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-35),
            endAngle: .degrees(35),
            clockwise: false
        )
        return path
    }
}

private struct MuteSlashLine: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.28, y: h * 0.72))
        path.addLine(to: CGPoint(x: w * 0.64, y: h * 0.28))
        return path
    }
}

private struct HUDProgressBar: View {
    let value: Double
    let fillColor: Color

    private var normalizedValue: Double {
        min(max(value, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color(red: 0.72, green: 0.68, blue: 0.73).opacity(0.30))
                    .shadow(color: Color.black.opacity(0.07), radius: 4, x: 0, y: 2)

                Capsule(style: .continuous)
                    .fill(fillColor)
                    .frame(width: fillWidth(in: geometry.size.width))
                    .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.9), value: normalizedValue)
            }
        }
        .frame(width: 142, height: 10)
    }

    private func fillWidth(in totalWidth: CGFloat) -> CGFloat {
        guard normalizedValue > 0 else { return 0 }
        return max(10, totalWidth * normalizedValue)
    }
}
