import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ZStack {
            panelBackground

            VStack(spacing: 10) {
                header
                controlCard
                tuningCard
                feedbackCard
                footer
            }
            .padding(12)
        }
        .environment(\.colorScheme, appState.usesDarkHUDBackground ? .dark : .light)
        .frame(width: 360)
    }

    private var panelBackground: some View {
        ZStack {
            LinearGradient(
                colors: panelBackgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill((appState.usesDarkHUDBackground ? Color.indigo : Color.accentColor).opacity(0.16))
                .frame(width: 150, height: 150)
                .blur(radius: 34)
                .offset(x: -150, y: -190)

            Circle()
                .fill((appState.usesDarkHUDBackground ? Color.cyan : Color.purple).opacity(0.12))
                .frame(width: 130, height: 130)
                .blur(radius: 38)
                .offset(x: 145, y: 120)
        }
    }

    private var panelBackgroundColors: [Color] {
        if appState.usesDarkHUDBackground {
            return [
                Color(red: 0.08, green: 0.10, blue: 0.15),
                Color(red: 0.13, green: 0.16, blue: 0.25),
                Color(red: 0.10, green: 0.13, blue: 0.18)
            ]
        }
        return [
            Color(nsColor: .windowBackgroundColor),
            Color.accentColor.opacity(0.13),
            Color(nsColor: .controlBackgroundColor)
        ]
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: headerGradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 42, height: 42)
            .shadow(color: Color.accentColor.opacity(0.24), radius: 12, x: 0, y: 6)

            VStack(alignment: .leading, spacing: 3) {
                Text("TouchTouch")
                    .font(.system(size: 21, weight: .bold))
                Text("触控板边缘控制")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                Toggle("", isOn: $appState.isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                statusPill
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(cardStroke(cornerRadius: 20))
    }

    private var headerGradientColors: [Color] {
        if appState.usesDarkHUDBackground {
            return [
                Color(red: 0.20, green: 0.28, blue: 0.44),
                Color(red: 0.12, green: 0.18, blue: 0.32)
            ]
        }
        return [Color.accentColor, Color.blue.opacity(0.72)]
    }

    private var statusPill: some View {
        Label(appState.isEnabled ? "运行中" : "已暂停", systemImage: appState.isEnabled ? "bolt.fill" : "pause.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(appState.isEnabled ? Color.green : Color.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(appState.isEnabled ? Color.green.opacity(0.13) : Color.secondary.opacity(0.12))
            )
    }

    private var controlCard: some View {
        DesignedCard(title: "控制方式", subtitle: "选择触发方式和滑动方向", icon: "rectangle.and.hand.point.up.left") {
            VStack(spacing: 9) {
                HStack(spacing: 8) {
                    ShortcutTile(
                        icon: "sun.max.fill",
                        title: "亮度",
                        keys: appState.enhancedEdgeDetection ? ["Option", "左边缘"] : ["Option"],
                        tint: .orange
                    )
                    ShortcutTile(
                        icon: "speaker.wave.2.fill",
                        title: "音量",
                        keys: appState.enhancedEdgeDetection ? ["Option", "右边缘"] : ["Command"],
                        tint: .blue
                    )
                }

                ToggleRow(
                    title: "增强左右边缘识别",
                    subtitle: "Option + 左边缘调亮度，右边缘调音量",
                    systemImage: "sparkles",
                    isOn: $appState.enhancedEdgeDetection
                )

                if appState.enhancedEdgeDetection {
                    SettingSlider(
                        title: "边缘宽度",
                        value: $appState.edgeWidth,
                        range: 0.15...0.35,
                        suffix: "%",
                        scale: 100
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                ToggleRow(
                    title: "反转滑动方向",
                    subtitle: "切换上下滑动对应的加减方向",
                    systemImage: "arrow.up.arrow.down",
                    isOn: $appState.reversesScrollDirection
                )
            }
        }
    }

    private var tuningCard: some View {
        DesignedCard(title: "灵敏度", subtitle: "微调响应速度和每次变化幅度", icon: "slider.horizontal.3") {
            VStack(spacing: 10) {
                SettingSlider(
                    title: "滑动阈值",
                    value: $appState.scrollThreshold,
                    range: 6...18,
                    suffix: "",
                    scale: 1
                )
                SettingSlider(
                    title: "亮度步长",
                    value: $appState.brightnessStep,
                    range: 0.01...0.10,
                    suffix: "%",
                    scale: 100
                )
                SettingSlider(
                    title: "音量步长",
                    value: $appState.volumeStep,
                    range: 0.01...0.10,
                    suffix: "%",
                    scale: 100
                )
            }
        }
    }

    private var feedbackCard: some View {
        DesignedCard(title: "反馈", subtitle: "屏幕提示和触觉确认", icon: "waveform.path") {
            VStack(spacing: 9) {
                HStack(spacing: 8) {
                    CompactToggleTile(
                        title: "显示 HUD",
                        systemImage: "macwindow.on.rectangle",
                        isOn: $appState.showsHUD
                    )
                    CompactToggleTile(
                        title: "震动反馈",
                        systemImage: "hand.tap.fill",
                        isOn: $appState.usesHaptics
                    )
                }

                HUDBackgroundToggle(isDark: $appState.usesDarkHUDBackground)

                if appState.usesHaptics {
                    SettingSlider(
                        title: "震动强度",
                        value: $appState.hapticIntensity,
                        range: 1...3,
                        suffix: "档",
                        scale: 1
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Label(
                    appState.controlStatusDescription,
                    systemImage: appState.isEnabled ? "checkmark.circle.fill" : "pause.circle.fill"
                )
                .foregroundStyle(appState.isEnabled ? Color.green : Color.secondary)

                Text(appState.brightnessStatus)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            Spacer()

            Button("请求权限") {
                appState.requestPermissions()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button("退出") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.top, 2)
    }

    private func cardStroke(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
    }
}

private struct DesignedCard<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24, height: 24)
                    .background(Color.accentColor.opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            content
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 7)
    }
}

private struct ShortcutTile: View {
    let icon: String
    let title: String
    let keys: [String]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                Spacer()
                Text(title)
                    .font(.caption.weight(.semibold))
            }

            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.regularMaterial, in: Capsule(style: .continuous))
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct ToggleRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                .frame(width: 24, height: 24)
                .background(
                    (isOn ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.1)),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }
}

private struct CompactToggleTile: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (isOn ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.08)),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
    }
}

private struct SettingSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let suffix: String
    let scale: Double

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(displayValue)
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.regularMaterial, in: Capsule(style: .continuous))
            }

            Slider(value: $value, in: range)
                .tint(.accentColor)
                .controlSize(.small)
        }
    }

    private var displayValue: String {
        "\(Int((value * scale).rounded()))\(suffix)"
    }
}

private struct HUDBackgroundToggle: View {
    @Binding var isDark: Bool

    var body: some View {
        Button {
            withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.82)) {
                isDark.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Capsule(style: .continuous)
                        .fill(trackGradient)
                    HStack {
                        SunMoonIcon(isDark: false, isActive: !isDark)
                        Spacer()
                        SunMoonIcon(isDark: true, isActive: isDark)
                    }
                    .padding(.horizontal, 9)

                    Circle()
                        .fill(.regularMaterial)
                        .frame(width: 29, height: 29)
                        .overlay(
                            Group {
                                if isDark {
                                    MoonVectorIcon()
                                        .foregroundStyle(Color(red: 0.25, green: 0.31, blue: 0.52))
                                        .frame(width: 16, height: 16)
                                        .transition(.scale.combined(with: .opacity))
                                } else {
                                    SunVectorIcon(rayScale: 1)
                                        .foregroundStyle(Color(red: 1.0, green: 0.62, blue: 0.0))
                                        .frame(width: 17, height: 17)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 5, x: 0, y: 2)
                        .offset(x: isDark ? 24 : -24)
                }
                .frame(width: 78, height: 36)

                VStack(alignment: .leading, spacing: 1) {
                    Text("界面背景")
                        .font(.caption.weight(.semibold))
                    Text(isDark ? "暗色玻璃" : "亮色玻璃")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                }

                Spacer()
            }
            .padding(9)
            .background(
                (isDark ? Color.indigo.opacity(0.18) : Color.orange.opacity(0.10)),
                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private var trackGradient: LinearGradient {
        if isDark {
            return LinearGradient(
                colors: [Color(red: 0.12, green: 0.14, blue: 0.23), Color(red: 0.25, green: 0.22, blue: 0.38)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        return LinearGradient(
            colors: [Color(red: 1.0, green: 0.76, blue: 0.22), Color(red: 1.0, green: 0.47, blue: 0.18)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

private struct SunMoonIcon: View {
    let isDark: Bool
    let isActive: Bool

    var body: some View {
        Group {
            if isDark {
                MoonVectorIcon()
            } else {
                SunVectorIcon(rayScale: isActive ? 1 : 0.65)
            }
        }
        .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.48))
        .frame(width: 15, height: 15)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

private struct SunVectorIcon: Shape {
    let rayScale: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.24
        var path = Path(ellipseIn: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))

        for index in 0..<8 {
            let angle = Double(index) * .pi / 4
            let inner = min(rect.width, rect.height) * (0.34 + 0.03 * rayScale)
            let outer = min(rect.width, rect.height) * (0.48 + 0.09 * rayScale)
            let thickness = min(rect.width, rect.height) * 0.065
            let start = CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner)
            let end = CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer)
            let normal = CGPoint(x: -sin(angle) * thickness, y: cos(angle) * thickness)
            path.move(to: CGPoint(x: start.x + normal.x, y: start.y + normal.y))
            path.addLine(to: CGPoint(x: end.x + normal.x, y: end.y + normal.y))
            path.addLine(to: CGPoint(x: end.x - normal.x, y: end.y - normal.y))
            path.addLine(to: CGPoint(x: start.x - normal.x, y: start.y - normal.y))
            path.closeSubpath()
        }
        return path
    }
}

private struct MoonVectorIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let size = min(rect.width, rect.height)
        var path = Path()
        path.move(to: CGPoint(x: rect.midX + size * 0.30, y: rect.midY - size * 0.43))
        path.addCurve(
            to: CGPoint(x: rect.midX + size * 0.25, y: rect.midY + size * 0.43),
            control1: CGPoint(x: rect.midX - size * 0.28, y: rect.midY - size * 0.38),
            control2: CGPoint(x: rect.midX - size * 0.32, y: rect.midY + size * 0.34)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX - size * 0.42, y: rect.midY),
            control1: CGPoint(x: rect.midX - size * 0.08, y: rect.midY + size * 0.42),
            control2: CGPoint(x: rect.midX - size * 0.42, y: rect.midY + size * 0.25)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX + size * 0.30, y: rect.midY - size * 0.43),
            control1: CGPoint(x: rect.midX - size * 0.42, y: rect.midY - size * 0.28),
            control2: CGPoint(x: rect.midX - size * 0.08, y: rect.midY - size * 0.45)
        )
        path.closeSubpath()
        return path
    }
}
