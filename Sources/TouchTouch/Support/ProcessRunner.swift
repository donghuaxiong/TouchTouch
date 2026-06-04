import Foundation

enum ProcessRunner {
    struct Result {
        let exitCode: Int32
        let output: String
    }

    static func run(_ executableURL: URL, arguments: [String]) -> Result {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return Result(
                exitCode: process.terminationStatus,
                output: String(decoding: data, as: UTF8.self)
            )
        } catch {
            return Result(exitCode: -1, output: error.localizedDescription)
        }
    }
}
