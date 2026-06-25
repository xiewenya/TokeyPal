import Darwin
import Foundation

public final class CcusageRunner: Sendable {
    public let executableURL: URL
    public let timeZoneIdentifier: String
    public let timeoutSeconds: TimeInterval
    public let maxOutputBytes: Int

    public init(
        executableURL: URL,
        timeZoneIdentifier: String = TimeZone.current.identifier,
        timeoutSeconds: TimeInterval = 15,
        maxOutputBytes: Int = 20 * 1024 * 1024
    ) {
        self.executableURL = executableURL
        self.timeZoneIdentifier = timeZoneIdentifier
        self.timeoutSeconds = timeoutSeconds
        self.maxOutputBytes = maxOutputBytes
    }

    public func loadUsageResponses(settings: TokeyPalSettings) throws -> [LoadedUsageResponse] {
        var responses: [LoadedUsageResponse] = []
        for app in orderedUsageApps() where settings.usageApps[app.id] == true {
            do {
                let data = try run(app: app, customDirectories: settings.usageAppDirectories[app.id] ?? [])
                responses.append(LoadedUsageResponse(appId: app.id, label: app.label, responseData: data))
            } catch {
                responses.append(LoadedUsageResponse(appId: app.id, label: app.label, error: String(describing: error)))
            }
        }
        return responses
    }

    func run(app: UsageAppConfig, customDirectories: [String]) throws -> Data {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tokeypal-ccusage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let stdoutURL = temporaryDirectory.appendingPathComponent("stdout")
        let stderrURL = temporaryDirectory.appendingPathComponent("stderr")
        try Data().write(to: stdoutURL)
        try Data().write(to: stderrURL)
        let stdout = try FileHandle(forWritingTo: stdoutURL)
        let stderr = try FileHandle(forWritingTo: stderrURL)
        defer {
            try? stdout.close()
            try? stderr.close()
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = buildArgs(app: app, customDirectories: customDirectories)
        process.standardOutput = stdout
        process.standardError = stderr

        let finished = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .utility).async {
            process.waitUntilExit()
            finished.signal()
        }
        try process.run()

        if finished.wait(timeout: .now() + timeoutSeconds) == .timedOut {
            process.terminate()
            if finished.wait(timeout: .now() + 1) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                _ = finished.wait(timeout: .now() + 1)
            }
            throw CcusageRunnerError.timedOut(timeoutSeconds: timeoutSeconds)
        }

        let outputSize = (try? FileManager.default.attributesOfItem(atPath: stdoutURL.path)[.size] as? NSNumber)?.intValue ?? 0
        if outputSize > maxOutputBytes {
            throw CcusageRunnerError.outputTooLarge(limit: maxOutputBytes)
        }

        let output = try Data(contentsOf: stdoutURL)
        if output.count > maxOutputBytes {
            throw CcusageRunnerError.outputTooLarge(limit: maxOutputBytes)
        }

        if process.terminationStatus == 0 {
            return output
        }

        let errorData = try Data(contentsOf: stderrURL)
        let message = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        throw CcusageRunnerError.failed(status: process.terminationStatus, message: message ?? "ccusage failed")
    }

    func buildArgs(app: UsageAppConfig, customDirectories: [String]) -> [String] {
        var args = [
            app.ccusageCommand,
            "daily",
            "--json",
            "--offline",
            "--timezone",
            timeZoneIdentifier
        ]

        if let pathOption = pathOption(for: app.ccusageCommand), !customDirectories.isEmpty {
            args.append(pathOption)
            args.append(customDirectories.joined(separator: ","))
        }

        return args
    }
}

public enum CcusageRunnerError: Error, Equatable {
    case failed(status: Int32, message: String)
    case timedOut(timeoutSeconds: TimeInterval)
    case outputTooLarge(limit: Int)
}

private func pathOption(for command: String) -> String? {
    switch command {
    case "openclaw":
        return "--open-claw-path"
    case "pi":
        return "--pi-path"
    default:
        return nil
    }
}
