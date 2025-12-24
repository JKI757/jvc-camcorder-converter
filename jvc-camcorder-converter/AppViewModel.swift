//
//  AppViewModel.swift
//  jvc-camcorder-converter
//
//  Created by Joshua Impson on 12/23/25.
//

import AppKit
import Combine
import Foundation
@preconcurrency import UserNotifications

@MainActor
final class AppViewModel: ObservableObject {
    @Published var state: AppState = .idle
    @Published var isDropTargeted = false
    @Published var overallProgress: Double = 0
    @Published var clipProgress: Double = 0
    @Published var processedCount = 0
    @Published var totalCount = 0
    @Published var currentClipName: String?
    @Published var outputFolderURL: URL?
    @Published var errors: [String] = []

    private let converter = VideoConverter()
    private let outputManager = OutputManager()

    var isBusy: Bool {
        switch state {
        case .scanning, .converting:
            return true
        default:
            return false
        }
    }

    var canReset: Bool {
        switch state {
        case .completed, .error:
            return true
        default:
            return false
        }
    }

    var statusTitle: String {
        switch state {
        case .idle:
            return "Drop an SD card or folder"
        case .scanning:
            return "Scanning for AVCHD clips"
        case .converting:
            return "Converting to MP4"
        case .completed:
            return "Import complete"
        case .error:
            return "Import failed"
        }
    }

    var statusDetail: String {
        switch state {
        case .idle:
            return "We will look for PRIVATE/AVCHD/BDMV/STREAM/*.MTS and save MP4 files to your Pictures folder."
        case .scanning:
            return "Looking for .MTS clips. Large cards may take a minute."
        case .converting:
            if totalCount > 0 {
                let clipIndex = min(processedCount + 1, totalCount)
                let clipName = currentClipName ?? "Clip"
                return "Clip \(clipIndex) of \(totalCount) - \(clipName)"
            }
            return "Preparing export session..."
        case .completed:
            let successCount = max(totalCount - errors.count, 0)
            if let outputFolderURL {
                let parent = outputFolderURL.deletingLastPathComponent().lastPathComponent
                let folderName = outputFolderURL.lastPathComponent
                let location = "\(parent)/\(folderName)"
                if errors.isEmpty {
                    return "\(successCount) clips saved to \(location)."
                }
                return "\(successCount) of \(totalCount) clips saved to \(location)."
            }
            if errors.isEmpty {
                return "\(successCount) clips saved."
            }
            return "\(successCount) of \(totalCount) clips saved."
        case .error(let message):
            return message
        }
    }

    var progressDetail: String {
        guard state == .converting, totalCount > 0 else { return "" }
        let clipIndex = min(processedCount + 1, totalCount)
        let clipName = currentClipName ?? "Clip"
        let percent = Int(clipProgress * 100)
        return "Clip \(clipIndex) of \(totalCount) - \(clipName) (\(percent)%)"
    }

    var errorSummary: String? {
        guard !errors.isEmpty else { return nil }
        let sample = errors.prefix(3)
        var summary = "Some clips failed:\n" + sample.joined(separator: "\n")
        if errors.count > sample.count {
            summary += "\n...and \(errors.count - sample.count) more."
        }
        return summary
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard !isBusy else { return false }
        let validProviders = providers.filter { $0.canLoadObject(ofClass: URL.self) }
        guard !validProviders.isEmpty else { return false }

        Task {
            let urls = await loadDropURLs(from: validProviders)
            if urls.isEmpty {
                state = .error("No readable folder or volume was dropped.")
                return
            }
            await runImport(urls: urls)
        }

        return true
    }

    func reset() {
        state = .idle
        overallProgress = 0
        clipProgress = 0
        processedCount = 0
        totalCount = 0
        currentClipName = nil
        outputFolderURL = nil
        errors = []
        isDropTargeted = false
    }

    func openOutputFolder(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    private func runImport(urls: [URL]) async {
        reset()
        state = .scanning

        let accessTokens = urls.map { ScopedAccess(url: $0) }
        var outputAccessToken: ScopedAccess?
        defer {
            outputAccessToken?.stop()
            accessTokens.forEach { $0.stop() }
        }

        do {
            let clips = try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let scanner = MediaScanner()
                        let result = try scanner.scan(urls: urls)
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            guard !clips.isEmpty else {
                state = .error("No AVCHD .MTS clips found. Look for AVCHD/BDMV/STREAM folders on the card.")
                return
            }

            let outputFolder: URL
            do {
                outputFolder = try outputManager.createOutputFolder(for: Date())
            } catch {
                if shouldPromptForOutputLocation(error) {
                    guard let baseFolder = await promptForOutputFolder() else {
                        state = .error("No output folder selected. Import cancelled.")
                        return
                    }
                    outputAccessToken = ScopedAccess(url: baseFolder)
                    do {
                        outputFolder = try outputManager.createOutputFolder(for: Date(), baseURL: baseFolder)
                    } catch {
                        state = .error("Unable to create output folder: \(error.localizedDescription)")
                        return
                    }
                } else {
                    state = .error("Unable to create output folder: \(error.localizedDescription)")
                    return
                }
            }

            outputFolderURL = outputFolder
            totalCount = clips.count
            state = .converting

            for clip in clips {
                currentClipName = clip.url.lastPathComponent
                clipProgress = 0

                let destination = outputManager.uniqueOutputURL(for: clip.url, in: outputFolder)
                do {
                    try await converter.convert(clip: clip, to: destination) { progress in
                        self.clipProgress = progress
                        self.overallProgress = self.calculateOverallProgress(currentClipProgress: progress)
                    }
                } catch {
                    errors.append("\(clip.url.lastPathComponent): \(error.localizedDescription)")
                }

                processedCount += 1
                overallProgress = calculateOverallProgress(currentClipProgress: 0)
            }

            state = .completed
            sendCompletionNotification()
        } catch {
            state = .error("Import failed: \(error.localizedDescription)")
        }
    }

    private func shouldPromptForOutputLocation(_ error: Error) -> Bool {
        if let outputError = error as? OutputError, outputError == .cannotLocatePicturesFolder {
            return true
        }
        if let cocoaError = error as? CocoaError, cocoaError.code == .fileWriteNoPermission {
            return true
        }
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileWriteNoPermissionError {
            return true
        }
        return false
    }

    private func promptForOutputFolder() async -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose Output Folder"
        panel.message = "Select a folder where the converted MP4 files will be saved."
        panel.prompt = "Choose Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first

        return await withCheckedContinuation { continuation in
            panel.begin { response in
                if response == .OK {
                    continuation.resume(returning: panel.url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func calculateOverallProgress(currentClipProgress: Double) -> Double {
        guard totalCount > 0 else { return 0 }
        let progress = (Double(processedCount) + currentClipProgress) / Double(totalCount)
        return min(max(progress, 0), 1)
    }

    private func loadDropURLs(from providers: [NSItemProvider]) async -> [URL] {
        var urls: [URL] = []
        for provider in providers {
            if let url = await provider.loadURL() {
                urls.append(url)
            }
        }
        return urls
    }

    private func sendCompletionNotification() {
        let totalCountValue = totalCount
        let errorCount = errors.count
        let successCount = max(totalCountValue - errorCount, 0)
        let hadErrors = errorCount > 0

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = "Camcorder import complete"

            if !hadErrors {
                content.body = "\(successCount) clips are ready in your Pictures folder."
            } else {
                content.body = "\(successCount) of \(totalCountValue) clips exported. Some files failed."
            }

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }
    }
}

private struct ScopedAccess {
    let url: URL
    private let didStart: Bool

    init(url: URL) {
        self.url = url
        self.didStart = url.startAccessingSecurityScopedResource()
    }

    func stop() {
        if didStart {
            url.stopAccessingSecurityScopedResource()
        }
    }
}

private extension NSItemProvider {
    func loadURL() async -> URL? {
        await withCheckedContinuation { continuation in
            _ = loadObject(ofClass: URL.self) { url, _ in
                continuation.resume(returning: url)
            }
        }
    }
}
