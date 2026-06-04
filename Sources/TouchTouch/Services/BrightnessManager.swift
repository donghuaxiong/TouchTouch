import CoreGraphics
import Darwin
import Foundation

final class BrightnessManager {
    private let displayServices = DisplayServicesBrightnessController()
    private let cliController: BrightnessCLIController?

    init(fileManager: FileManager = .default) {
        cliController = [
            "/opt/homebrew/bin/brightness",
            "/usr/local/bin/brightness"
        ]
        .first(where: fileManager.isExecutableFile(atPath:))
        .map(BrightnessCLIController.init(executablePath:))
    }

    var statusDescription: String {
        if displayServices.isAvailable {
            return "系统亮度控制已就绪"
        }
        if cliController != nil {
            return "brightness CLI 已就绪"
        }
        return "当前设备不支持亮度控制"
    }

    func adjust(by delta: Double) -> Double? {
        if displayServices.isAvailable {
            return displayServices.adjust(by: delta)
        }
        if let cliController {
            return cliController.adjust(by: delta)
        }
        print("[TouchTouch] no brightness controller is available")
        return nil
    }
}

private final class DisplayServicesBrightnessController {
    private typealias GetBrightness = @convention(c) (
        CGDirectDisplayID,
        UnsafeMutablePointer<Float>
    ) -> Int32
    private typealias SetBrightness = @convention(c) (
        CGDirectDisplayID,
        Float
    ) -> Int32

    private let handle: UnsafeMutableRawPointer?
    private let getBrightness: GetBrightness?
    private let setBrightness: SetBrightness?

    init() {
        let frameworkPath = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        handle = dlopen(frameworkPath, RTLD_LAZY)
        getBrightness = handle.flatMap {
            dlsym($0, "DisplayServicesGetBrightness")
        }.map {
            unsafeBitCast($0, to: GetBrightness.self)
        }
        setBrightness = handle.flatMap {
            dlsym($0, "DisplayServicesSetBrightness")
        }.map {
            unsafeBitCast($0, to: SetBrightness.self)
        }
    }

    deinit {
        if let handle {
            dlclose(handle)
        }
    }

    var isAvailable: Bool {
        guard let getBrightness, setBrightness != nil else { return false }
        var value: Float = 0
        return getBrightness(CGMainDisplayID(), &value) == 0
    }

    func adjust(by delta: Double) -> Double? {
        guard let getBrightness, let setBrightness else { return nil }

        var currentValue: Float = 0
        guard getBrightness(CGMainDisplayID(), &currentValue) == 0 else {
            print("[TouchTouch] DisplayServices could not read brightness")
            return nil
        }

        let newValue = min(max(Double(currentValue) + delta, 0), 1)
        guard setBrightness(CGMainDisplayID(), Float(newValue)) == 0 else {
            print("[TouchTouch] DisplayServices could not set brightness")
            return nil
        }
        return newValue
    }
}

private final class BrightnessCLIController {
    private let executableURL: URL
    private var cachedValue: Double?

    init(executablePath: String) {
        executableURL = URL(fileURLWithPath: executablePath)
    }

    func adjust(by delta: Double) -> Double? {
        let currentValue = cachedValue ?? currentValue()
        guard let currentValue else {
            print("[TouchTouch] brightness CLI output was unreadable")
            return nil
        }

        let newValue = min(max(currentValue + delta, 0), 1)
        let result = ProcessRunner.run(executableURL, arguments: [String(newValue)])
        guard result.exitCode == 0 else {
            print("[TouchTouch] brightness CLI failed: \(result.output)")
            return nil
        }
        cachedValue = newValue
        return newValue
    }

    private func currentValue() -> Double? {
        let result = ProcessRunner.run(executableURL, arguments: ["-l"])
        guard result.exitCode == 0 else { return nil }

        let pattern = #"brightness\s+([0-9]*\.?[0-9]+)"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: result.output,
                range: NSRange(result.output.startIndex..., in: result.output)
            ),
            let range = Range(match.range(at: 1), in: result.output)
        else {
            return nil
        }
        return Double(result.output[range])
    }
}
