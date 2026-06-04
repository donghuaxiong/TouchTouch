import AppKit
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Keys.isEnabled)
            refreshMonitoring()
        }
    }

    @Published var brightnessStep: Double {
        didSet { defaults.set(brightnessStep, forKey: Keys.brightnessStep) }
    }

    @Published var volumeStep: Double {
        didSet { defaults.set(volumeStep, forKey: Keys.volumeStep) }
    }

    @Published var enhancedEdgeDetection: Bool {
        didSet { defaults.set(enhancedEdgeDetection, forKey: Keys.enhancedEdgeDetection) }
    }

    @Published var edgeWidth: Double {
        didSet { defaults.set(edgeWidth, forKey: Keys.edgeWidth) }
    }

    @Published var scrollThreshold: Double {
        didSet { defaults.set(scrollThreshold, forKey: Keys.scrollThreshold) }
    }

    @Published var debounceMilliseconds: Double {
        didSet { defaults.set(debounceMilliseconds, forKey: Keys.debounceMilliseconds) }
    }

    @Published var showsHUD: Bool {
        didSet { defaults.set(showsHUD, forKey: Keys.showsHUD) }
    }

    @Published var usesDarkHUDBackground: Bool {
        didSet { defaults.set(usesDarkHUDBackground, forKey: Keys.usesDarkHUDBackground) }
    }

    @Published var usesHaptics: Bool {
        didSet { defaults.set(usesHaptics, forKey: Keys.usesHaptics) }
    }

    @Published var hapticIntensity: Double {
        didSet { defaults.set(hapticIntensity, forKey: Keys.hapticIntensity) }
    }

    @Published var reversesScrollDirection: Bool {
        didSet { defaults.set(reversesScrollDirection, forKey: Keys.reversesScrollDirection) }
    }

    private let defaults = UserDefaults.standard
    private let brightnessManager = BrightnessManager()
    private let volumeManager = VolumeManager()
    private let hudManager = HUDManager()
    private let hapticManager = HapticManager()
    private lazy var eventMonitor = TrackpadEventMonitor(
        configurationProvider: { [weak self] in
            self?.monitorConfiguration ?? .default
        },
        actionHandler: { [weak self] target, direction in
            self?.perform(target: target, direction: direction)
        }
    )

    init() {
        defaults.register(defaults: [
            Keys.isEnabled: true,
            Keys.brightnessStep: 0.05,
            Keys.volumeStep: 0.05,
            Keys.enhancedEdgeDetection: true,
            Keys.edgeWidth: 0.22,
            Keys.scrollThreshold: 10.0,
            Keys.debounceMilliseconds: 100.0,
            Keys.showsHUD: true,
            Keys.usesDarkHUDBackground: false,
            Keys.usesHaptics: true,
            Keys.hapticIntensity: 2.0,
            Keys.reversesScrollDirection: false
        ])

        isEnabled = defaults.bool(forKey: Keys.isEnabled)
        brightnessStep = defaults.double(forKey: Keys.brightnessStep)
        volumeStep = defaults.double(forKey: Keys.volumeStep)
        enhancedEdgeDetection = defaults.bool(forKey: Keys.enhancedEdgeDetection)
        edgeWidth = defaults.double(forKey: Keys.edgeWidth)
        scrollThreshold = defaults.double(forKey: Keys.scrollThreshold)
        debounceMilliseconds = defaults.double(forKey: Keys.debounceMilliseconds)
        showsHUD = defaults.bool(forKey: Keys.showsHUD)
        usesDarkHUDBackground = defaults.bool(forKey: Keys.usesDarkHUDBackground)
        usesHaptics = defaults.bool(forKey: Keys.usesHaptics)
        hapticIntensity = defaults.double(forKey: Keys.hapticIntensity)
        reversesScrollDirection = defaults.bool(forKey: Keys.reversesScrollDirection)

        refreshMonitoring()
    }

    var controlStatusDescription: String {
        isEnabled ? "控制监听已启用" : "控制监听已关闭"
    }

    var brightnessStatus: String {
        brightnessManager.statusDescription
    }

    func requestPermissions() {
        PermissionManager.requestPermissions()
        objectWillChange.send()
    }

    func refreshMonitoring() {
        if isEnabled {
            eventMonitor.start()
        } else {
            eventMonitor.stop()
        }
    }

    private var monitorConfiguration: TrackpadEventMonitor.Configuration {
        .init(
            enhancedEdgeDetection: enhancedEdgeDetection,
            edgeWidth: edgeWidth,
            scrollThreshold: scrollThreshold,
            debounceInterval: debounceMilliseconds / 1_000
        )
    }

    private func perform(target: ControlTarget, direction: AdjustmentDirection) {
        let effectiveDirection = reversesScrollDirection ? direction.reversed : direction
        let signedMultiplier = effectiveDirection == .increase ? 1.0 : -1.0
        let value: Double?

        switch target {
        case .brightness:
            value = brightnessManager.adjust(by: signedMultiplier * brightnessStep)
        case .volume:
            value = volumeManager.adjust(by: signedMultiplier * volumeStep)
        }

        if usesHaptics {
            hapticManager.perform(intensity: hapticIntensity)
        }

        if showsHUD, let value {
            hudManager.show(target: target, value: value, usesDarkBackground: usesDarkHUDBackground)
        }
    }

    private enum Keys {
        static let isEnabled = "isEnabled"
        static let brightnessStep = "brightnessStep"
        static let volumeStep = "volumeStep"
        static let enhancedEdgeDetection = "enhancedEdgeDetection"
        static let edgeWidth = "edgeWidth"
        static let scrollThreshold = "scrollThreshold"
        static let debounceMilliseconds = "debounceMilliseconds"
        static let showsHUD = "showsHUD"
        static let usesDarkHUDBackground = "usesDarkHUDBackground"
        static let usesHaptics = "usesHaptics"
        static let hapticIntensity = "hapticIntensity"
        static let reversesScrollDirection = "reversesScrollDirection"
    }
}
