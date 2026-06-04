import AudioToolbox
import CoreAudio
import Foundation

@MainActor
final class VolumeManager {
    private var cachedVolume: Double?
    private var pendingVolume: Double?
    private var pendingWriteTask: Task<Void, Never>?
    private var isWritingSystemVolume = false

    func adjust(by delta: Double) -> Double? {
        let currentValue = cachedVolume ?? readSystemVolume() ?? readCoreAudioVolume() ?? 0
        let newValue = min(max(currentValue + delta, 0), 1)
        cachedVolume = newValue
        scheduleSystemVolumeWrite(newValue)
        return newValue
    }

    private func readSystemVolume() -> Double? {
        let result = ProcessRunner.run(
            URL(fileURLWithPath: "/usr/bin/osascript"),
            arguments: ["-e", "output volume of (get volume settings)"]
        )
        guard result.exitCode == 0 else {
            print("[TouchTouch] AppleScript could not read volume: \(result.output)")
            return nil
        }
        return Double(result.output.trimmingCharacters(in: .whitespacesAndNewlines))
            .map { $0 / 100 }
    }

    private func scheduleSystemVolumeWrite(_ value: Double) {
        pendingVolume = value
        pendingWriteTask?.cancel()
        pendingWriteTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(35))
            guard !Task.isCancelled else { return }
            self?.flushPendingSystemVolumeWrite()
        }
    }

    private func flushPendingSystemVolumeWrite() {
        guard !isWritingSystemVolume, let value = pendingVolume else { return }
        pendingVolume = nil
        isWritingSystemVolume = true

        Task.detached(priority: .userInitiated) {
            let success = Self.setSystemVolumeSync(value)
            await MainActor.run { [weak self] in
                self?.completeSystemVolumeWrite(value: value, success: success)
            }
        }
    }

    private func completeSystemVolumeWrite(value: Double, success: Bool) {
        isWritingSystemVolume = false
        if !success, !setCoreAudioVolume(value) {
            print("[TouchTouch] could not set output volume")
        }
        if pendingVolume != nil {
            flushPendingSystemVolumeWrite()
        }
    }

    private nonisolated static func setSystemVolumeSync(_ value: Double) -> Bool {
        let percentage = Int((value * 100).rounded())
        let result = ProcessRunner.run(
            URL(fileURLWithPath: "/usr/bin/osascript"),
            arguments: ["-e", "set volume output volume \(percentage)"]
        )
        if result.exitCode != 0 {
            print("[TouchTouch] AppleScript could not set volume: \(result.output)")
        }
        return result.exitCode == 0
    }

    private func readCoreAudioVolume() -> Double? {
        guard let deviceID = defaultOutputDeviceID() else { return nil }

        if let masterValue = readVirtualMainVolume(deviceID: deviceID) {
            return masterValue
        }

        if let masterValue = readScalarVolume(deviceID: deviceID, channel: 0) {
            return masterValue
        }

        let values = [
            readScalarVolume(deviceID: deviceID, channel: 1),
            readScalarVolume(deviceID: deviceID, channel: 2)
        ].compactMap { $0 }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func setCoreAudioVolume(_ value: Double) -> Bool {
        guard let deviceID = defaultOutputDeviceID() else { return false }

        if setVirtualMainVolume(deviceID: deviceID, value: value) {
            return true
        }

        if setScalarVolume(deviceID: deviceID, channel: 0, value: value) {
            return true
        }

        let left = setScalarVolume(deviceID: deviceID, channel: 1, value: value)
        let right = setScalarVolume(deviceID: deviceID, channel: 2, value: value)
        return left || right
    }

    private func defaultOutputDeviceID() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultSystemOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(0)
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize,
            &deviceID
        )
        guard status == noErr, deviceID != 0 else {
            print("[TouchTouch] Core Audio could not find default system output device: \(status)")
            return nil
        }
        return deviceID
    }

    private func readVirtualMainVolume(deviceID: AudioDeviceID) -> Double? {
        var address = virtualMainVolumeAddress()
        guard AudioObjectHasProperty(deviceID, &address) else { return nil }

        var value = Float32(0)
        var dataSize = UInt32(MemoryLayout<Float32>.size)
        let status = AudioHardwareServiceGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &dataSize,
            &value
        )
        guard status == noErr else { return nil }
        return Double(value)
    }

    private func setVirtualMainVolume(deviceID: AudioDeviceID, value: Double) -> Bool {
        var address = virtualMainVolumeAddress()
        guard AudioObjectHasProperty(deviceID, &address) else { return false }

        var scalar = Float32(value)
        let dataSize = UInt32(MemoryLayout<Float32>.size)
        let status = AudioHardwareServiceSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            dataSize,
            &scalar
        )
        return status == noErr
    }

    private func readScalarVolume(deviceID: AudioDeviceID, channel: UInt32) -> Double? {
        var address = scalarVolumeAddress(channel: channel)
        guard AudioObjectHasProperty(deviceID, &address) else { return nil }

        var value = Float32(0)
        var dataSize = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &dataSize,
            &value
        )
        guard status == noErr else { return nil }
        return Double(value)
    }

    private func setScalarVolume(deviceID: AudioDeviceID, channel: UInt32, value: Double) -> Bool {
        var address = scalarVolumeAddress(channel: channel)
        guard AudioObjectHasProperty(deviceID, &address) else { return false }
        var isSettable = DarwinBoolean(false)
        guard AudioObjectIsPropertySettable(deviceID, &address, &isSettable) == noErr else {
            return false
        }
        guard isSettable.boolValue else { return false }

        var scalar = Float32(value)
        let dataSize = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            dataSize,
            &scalar
        )
        return status == noErr
    }

    private func virtualMainVolumeAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private func scalarVolumeAddress(channel: UInt32) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: channel
        )
    }
}
