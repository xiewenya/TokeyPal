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
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = executableURL
        process.arguments = buildArgs(app: app, customDirectories: customDirectories)
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            process.waitUntilExit()
            group.leave()
        }

        if group.wait(timeout: .now() + timeoutSeconds) == .timedOut {
            process.terminate()
            _ = group.wait(timeout: .now() + 1)
            throw CcusageRunnerError.timedOut(timeoutSeconds: timeoutSeconds)
        }

        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        if output.count > maxOutputBytes {
            throw CcusageRunnerError.outputTooLarge(limit: maxOutputBytes)
        }

        if process.terminationStatus == 0 {
            return output
        }

        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
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
