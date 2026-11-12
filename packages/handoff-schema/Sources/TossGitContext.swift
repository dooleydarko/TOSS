import Foundation
#if canImport(TossSchema)
import TossSchema
#endif

public struct TossGitContext {
    public static func currentRepositoryContext(at path: String = FileManager.default.currentDirectoryPath) -> TossRepository {
        #if os(macOS) || os(Linux)
        let branch = runGitCommand(["rev-parse", "--abbrev-ref", "HEAD"], workingDirectory: path)
        let commit = runGitCommand(["rev-parse", "HEAD"], workingDirectory: path)
        let remoteUrl = runGitCommand(["config", "--get", "remote.origin.url"], workingDirectory: path)

        return TossRepository(
            url: remoteUrl.isEmpty ? nil : remoteUrl,
            branch: branch.isEmpty ? nil : branch,
            commit: commit.isEmpty ? nil : commit
        )
        #else
        // iOS cannot spawn git; the desktop receiver supplies repository context.
        return TossRepository()
        #endif
    }

    #if os(macOS) || os(Linux)
    private static func runGitCommand(_ arguments: [String], workingDirectory: String) -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch {
            return ""
        }
    }
    #endif
}
