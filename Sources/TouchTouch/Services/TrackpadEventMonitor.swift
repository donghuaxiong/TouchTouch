import AppKit
import CoreGraphics
import Foundation

enum ControlTarget: String {
    case brightness
    case volume
}

enum AdjustmentDirection: String {
    case increase
    case decrease

    var reversed: AdjustmentDirection {
        switch self {
        case .increase:
            return .decrease
        case .decrease:
            return .increase
        }
    }
}

@MainActor
final class TrackpadEventMonitor {
    struct Configuration {
        let enhancedEdgeDetection: Bool
        let edgeWidth: Double
        let scrollThreshold: Double
        let debounceInterval: TimeInterval

        static let `default` = Configuration(
            enhancedEdgeDetection: true,
            edgeWidth: 0.22,
            scrollThreshold: 10,
            debounceInterval: 0.1
        )
    }

    private let configurationProvider: () -> Configuration
    private let actionHandler: (ControlTarget, AdjustmentDirection) -> Void
    private let multiTouchManager = MultiTouchSupportManager()
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var eventTap: CFMachPort?
    private var eventTapRunLoopSource: CFRunLoopSource?
    private var eventTapHealthTimer: Timer?
    private nonisolated(unsafe) var eventTapCanConsume = false
    private var accumulatedDelta: Double = 0
    private var activeTarget: ControlTarget?
    private var lastTriggerDate = Date.distantPast

    init(
        configurationProvider: @escaping () -> Configuration,
        actionHandler: @escaping (ControlTarget, AdjustmentDirection) -> Void
    ) {
        self.configurationProvider = configurationProvider
        self.actionHandler = actionHandler
    }

    func start() {
        guard globalMonitor == nil, localMonitor == nil, eventTap == nil else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) {
            [weak self] event in
            _ = self?.handle(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) {
            [weak self] event in
            guard let self else { return event }
            return self.handle(event) ? nil : event
        }

        startEventTap()
        startEventTapHealthCheck()
        multiTouchManager.start()
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
        stopEventTapHealthCheck()
        stopEventTap()
        multiTouchManager.stop()
        resetAccumulator()
    }

    @discardableResult
    private func handle(_ event: NSEvent) -> Bool {
        guard event.momentumPhase.isEmpty else {
            resetAccumulator()
            return false
        }

        let configuration = configurationProvider()
        guard let target = resolveTarget(for: event, configuration: configuration) else {
            resetAccumulator()
            return false
        }

        if activeTarget != target {
            accumulatedDelta = 0
            activeTarget = target
        }

        let deltaY = Double(event.scrollingDeltaY)
        guard deltaY != 0 else { return true }

        accumulatedDelta += deltaY

        guard abs(accumulatedDelta) >= configuration.scrollThreshold else { return true }
        guard Date().timeIntervalSince(lastTriggerDate) >= configuration.debounceInterval else {
            return true
        }

        let direction: AdjustmentDirection = accumulatedDelta > 0 ? .increase : .decrease
        accumulatedDelta = 0
        lastTriggerDate = Date()
        actionHandler(target, direction)
        return true
    }

    @discardableResult
    private func handle(_ event: CGEvent) -> Bool {
        let configuration = configurationProvider()
        guard currentModifierFlagsStillContainTrigger() else {
            resetAccumulator()
            return false
        }
        guard !isMomentumScroll(event) else {
            resetAccumulator()
            return false
        }

        guard let target = resolveTarget(for: event, configuration: configuration) else {
            resetAccumulator()
            return false
        }

        let deltaY = scrollDeltaY(from: event)
        guard deltaY != 0 else { return true }

        if activeTarget != target {
            accumulatedDelta = 0
            activeTarget = target
        }

        accumulatedDelta += deltaY

        guard abs(accumulatedDelta) >= configuration.scrollThreshold else { return true }
        guard Date().timeIntervalSince(lastTriggerDate) >= configuration.debounceInterval else {
            return true
        }

        let direction: AdjustmentDirection = accumulatedDelta > 0 ? .increase : .decrease
        accumulatedDelta = 0
        lastTriggerDate = Date()
        actionHandler(target, direction)
        return true
    }

    private func resolveTarget(
        for event: NSEvent,
        configuration: Configuration
    ) -> ControlTarget? {
        let modifierFlags = effectiveModifierFlags(for: event)
        if configuration.enhancedEdgeDetection,
           modifierFlags.contains(.option),
           let target = enhancedEdgeTarget(edgeWidth: configuration.edgeWidth) {
            return target
        }
        if modifierFlags.contains(.option) {
            return .brightness
        }
        if modifierFlags.contains(.command) {
            return .volume
        }
        return nil
    }

    private func resolveTarget(
        for event: CGEvent,
        configuration: Configuration
    ) -> ControlTarget? {
        let flags = effectiveModifierFlags(for: event)
        if configuration.enhancedEdgeDetection,
           flags.contains(.option),
           let target = enhancedEdgeTarget(edgeWidth: configuration.edgeWidth) {
            return target
        }
        if flags.contains(.option) {
            return .brightness
        }
        if flags.contains(.command) {
            return .volume
        }
        return nil
    }

    private func effectiveModifierFlags(for event: NSEvent) -> NSEvent.ModifierFlags {
        var modifierFlags = event.modifierFlags
        let sessionFlags = CGEventSource.flagsState(.combinedSessionState)
        if sessionFlags.contains(.maskAlternate) {
            modifierFlags.insert(.option)
        }
        if sessionFlags.contains(.maskCommand) {
            modifierFlags.insert(.command)
        }
        return modifierFlags
    }

    private func effectiveModifierFlags(for event: CGEvent) -> NSEvent.ModifierFlags {
        var modifierFlags = NSEvent.ModifierFlags()
        let eventFlags = event.flags
        let sessionFlags = CGEventSource.flagsState(.combinedSessionState)
        if eventFlags.contains(.maskAlternate) || sessionFlags.contains(.maskAlternate) {
            modifierFlags.insert(.option)
        }
        if eventFlags.contains(.maskCommand) || sessionFlags.contains(.maskCommand) {
            modifierFlags.insert(.command)
        }
        return modifierFlags
    }

    private func scrollDeltaY(from event: CGEvent) -> Double {
        let pointDelta = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
        if pointDelta != 0 {
            return Double(pointDelta)
        }
        return Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
    }

    private func enhancedEdgeTarget(edgeWidth: Double) -> ControlTarget? {
        guard let averageX = multiTouchManager.recentAverageX() else { return nil }
        if averageX <= edgeWidth {
            return .brightness
        }
        if averageX >= 1 - edgeWidth {
            return .volume
        }
        return nil
    }

    private func startEventTap() {
        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<TrackpadEventMonitor>
                .fromOpaque(refcon)
                .takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                Task { @MainActor in
                    monitor.reenableEventTap()
                }
                return Unmanaged.passUnretained(event)
            }

            guard type == .scrollWheel else { return Unmanaged.passUnretained(event) }

            let copiedEvent = event.copy() ?? event
            Task { @MainActor in
                _ = monitor.handle(copiedEvent)
            }
            if monitor.eventTapCanConsume, monitor.shouldConsume(event) {
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        if let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: refcon
        ) {
            installEventTap(eventTap, canConsume: true)
            return
        }

        if let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: refcon
        ) {
            installEventTap(eventTap, canConsume: false)
            return
        }
    }

    private func installEventTap(_ eventTap: CFMachPort, canConsume: Bool) {
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        self.eventTap = eventTap
        self.eventTapRunLoopSource = source
        eventTapCanConsume = canConsume
    }

    private func reenableEventTap() {
        guard let eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func startEventTapHealthCheck() {
        eventTapHealthTimer?.invalidate()
        eventTapHealthTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if let eventTap = self.eventTap, self.eventTapCanConsume {
                    CGEvent.tapEnable(tap: eventTap, enable: true)
                    return
                }
                self.stopEventTap()
                self.startEventTap()
            }
        }
    }

    private func stopEventTapHealthCheck() {
        eventTapHealthTimer?.invalidate()
        eventTapHealthTimer = nil
    }

    private nonisolated func shouldConsume(_ event: CGEvent) -> Bool {
        let flags = event.flags
        let sessionFlags = CGEventSource.flagsState(.combinedSessionState)
        return flags.contains(.maskAlternate)
            || flags.contains(.maskCommand)
            || sessionFlags.contains(.maskAlternate)
            || sessionFlags.contains(.maskCommand)
    }

    private func isMomentumScroll(_ event: CGEvent) -> Bool {
        let momentumPhase = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
        return momentumPhase != 0
    }

    private func currentModifierFlagsStillContainTrigger() -> Bool {
        let sessionFlags = CGEventSource.flagsState(.combinedSessionState)
        return sessionFlags.contains(.maskAlternate) || sessionFlags.contains(.maskCommand)
    }

    private func stopEventTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let eventTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapRunLoopSource, .commonModes)
        }
        eventTap = nil
        eventTapRunLoopSource = nil
        eventTapCanConsume = false
    }

    private func resetAccumulator() {
        accumulatedDelta = 0
        activeTarget = nil
    }

}
