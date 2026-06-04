import Foundation

private struct MTPoint {
    var x: Float32
    var y: Float32
}

private struct MTReadout {
    var position: MTPoint
    var velocity: MTPoint
}

private struct MTFinger {
    var frame: Int32
    var timestamp: Double
    var identifier: Int32
    var state: Int32
    var fingerID: Int32
    var handID: Int32
    var normalized: MTReadout
    var size: Float32
    var zero1: Int32
    var angle: Float32
    var majorAxis: Float32
    var minorAxis: Float32
    var absolute: MTReadout
    var zero2a: Int32
    var zero2b: Int32
    var unknown: Float32
}

@MainActor
final class MultiTouchSupportManager {
    private typealias MTDeviceRef = UnsafeMutableRawPointer
    private typealias MTContactFrameCallback = @convention(c) (
        Int32,
        UnsafeMutableRawPointer?,
        Int32,
        Double,
        Int32
    ) -> Int32
    private typealias MTDeviceCreateListFunction = @convention(c) () -> Unmanaged<CFArray>
    private typealias MTRegisterContactFrameCallbackFunction = @convention(c) (
        MTDeviceRef,
        MTContactFrameCallback?
    ) -> Void
    private typealias MTDeviceStartFunction = @convention(c) (MTDeviceRef, Int32) -> Int32
    private typealias MTDeviceStopFunction = @convention(c) (MTDeviceRef) -> Int32

    private nonisolated(unsafe) static weak var activeMonitor: MultiTouchSupportManager?

    private var frameworkHandle: UnsafeMutableRawPointer?
    private var devices: [MTDeviceRef] = []
    private var latestAverageX: Double?
    private var latestUpdateDate = Date.distantPast

    func start() {
        guard frameworkHandle == nil else { return }
        let path = "/System/Library/PrivateFrameworks/MultiTouchSupport.framework/MultitouchSupport"
        guard let handle = dlopen(path, RTLD_LAZY) else {
            return
        }

        guard
            let createListSymbol = dlsym(handle, "MTDeviceCreateList"),
            let registerSymbol = dlsym(handle, "MTRegisterContactFrameCallback"),
            let startSymbol = dlsym(handle, "MTDeviceStart")
        else {
            dlclose(handle)
            return
        }

        let createList = unsafeBitCast(
            createListSymbol,
            to: MTDeviceCreateListFunction.self
        )
        let registerCallback = unsafeBitCast(
            registerSymbol,
            to: MTRegisterContactFrameCallbackFunction.self
        )
        let startDevice = unsafeBitCast(
            startSymbol,
            to: MTDeviceStartFunction.self
        )

        let deviceList = createList().takeRetainedValue()
        let deviceCount = CFArrayGetCount(deviceList)
        guard deviceCount > 0 else {
            dlclose(handle)
            return
        }

        Self.activeMonitor = self
        frameworkHandle = handle
        devices = (0..<deviceCount).compactMap { index in
            guard let value = CFArrayGetValueAtIndex(deviceList, index) else { return nil }
            return MTDeviceRef(mutating: value)
        }

        for device in devices {
            registerCallback(device, Self.contactFrameCallback)
            _ = startDevice(device, 0)
        }
    }

    func stop() {
        if let stopSymbol = frameworkHandle.flatMap({ dlsym($0, "MTDeviceStop") }) {
            let stopDevice = unsafeBitCast(stopSymbol, to: MTDeviceStopFunction.self)
            for device in devices {
                _ = stopDevice(device)
            }
        }
        devices.removeAll()

        if let frameworkHandle {
            dlclose(frameworkHandle)
        }
        frameworkHandle = nil
        Self.activeMonitor = nil
        latestAverageX = nil
        latestUpdateDate = .distantPast
    }

    func recentAverageX(maxAge: TimeInterval = 0.30) -> Double? {
        guard let latestAverageX else { return nil }
        guard Date().timeIntervalSince(latestUpdateDate) <= maxAge else { return nil }
        return latestAverageX
    }

    private func update(averageX: Double) {
        latestAverageX = averageX
        latestUpdateDate = Date()
    }

    private nonisolated static func averageX(fingers: UnsafeMutableRawPointer?, count: Int32) -> Double? {
        guard let fingers, count > 0 else { return nil }
        let typedFingers = fingers.bindMemory(to: MTFinger.self, capacity: Int(count))

        let xs = (0..<Int(count)).compactMap { index -> Double? in
            let x = Double(typedFingers[index].normalized.position.x)
            guard x >= 0, x <= 1 else { return nil }
            return x
        }

        guard !xs.isEmpty else { return nil }
        return xs.reduce(0, +) / Double(xs.count)
    }

    private nonisolated static let contactFrameCallback: MTContactFrameCallback = {
        _, fingers, fingerCount, _, _ in
        guard let averageX = MultiTouchSupportManager.averageX(
            fingers: fingers,
            count: fingerCount
        ) else {
            return 0
        }
        Task { @MainActor in
            MultiTouchSupportManager.activeMonitor?.update(averageX: averageX)
        }
        return 0
    }
}
