//
//  VideoConverter.swift
//  jvc-camcorder-converter
//
//  Created by Joshua Impson on 12/23/25.
//

@preconcurrency import AVFoundation
import Foundation

struct VideoConverter {
    func convert(clip: ClipInfo, to outputURL: URL, progress: @escaping (Double) -> Void) async throws {
        let asset = AVURLAsset(url: clip.url)

        guard let exportSession =
            AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) ??
            AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1920x1080)
        else {
            throw VideoConversionError.cannotCreateExportSession
        }

        guard exportSession.supportedFileTypes.contains(.mp4) else {
            throw VideoConversionError.unsupportedFileType
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        let observer = ExportProgressObserver(session: exportSession, handler: progress)
        observer.start()
        defer { observer.stop() }

        if #available(macOS 15.0, *) {
            try await exportSession.export(to: outputURL, as: .mp4)
        } else {
            try await exportLegacy(exportSession)
        }
    }

    @available(macOS, deprecated: 15.0)
    private func exportLegacy(_ exportSession: AVAssetExportSession) async throws {
        let boxedSession = ExportSessionBox(exportSession)
        try await withCheckedThrowingContinuation { continuation in
            boxedSession.session.exportAsynchronously {
                let session = boxedSession.session
                switch session.status {
                case .completed:
                    continuation.resume(returning: ())
                case .failed:
                    let error = session.error ?? VideoConversionError.unknownFailure
                    continuation.resume(throwing: error)
                case .cancelled:
                    continuation.resume(throwing: VideoConversionError.cancelled)
                default:
                    let error = session.error ?? VideoConversionError.unknownFailure
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

enum VideoConversionError: Error, LocalizedError {
    case cannotCreateExportSession
    case unsupportedFileType
    case cancelled
    case unknownFailure

    var errorDescription: String? {
        switch self {
        case .cannotCreateExportSession:
            return "Unable to create a video export session."
        case .unsupportedFileType:
            return "MP4 export is not supported for this clip."
        case .cancelled:
            return "The export was cancelled."
        case .unknownFailure:
            return "The export failed unexpectedly."
        }
    }
}

final class ExportProgressObserver {
    private let session: AVAssetExportSession
    private let handler: (Double) -> Void
    private var timer: DispatchSourceTimer?

    init(session: AVAssetExportSession, handler: @escaping (Double) -> Void) {
        self.session = session
        self.handler = handler
    }

    func start() {
        let handler = handler
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: 0.1)
        timer.setEventHandler { [weak session] in
            handler(Double(session?.progress ?? 0))
        }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }
}

final class ExportSessionBox: @unchecked Sendable {
    let session: AVAssetExportSession

    init(_ session: AVAssetExportSession) {
        self.session = session
    }
}
