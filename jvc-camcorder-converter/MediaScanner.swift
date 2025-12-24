//
//  MediaScanner.swift
//  jvc-camcorder-converter
//
//  Created by Joshua Impson on 12/23/25.
//

import Foundation

struct ClipInfo: Identifiable, Hashable {
    let url: URL
    let fileSize: Int64
    let modificationDate: Date

    var id: URL { url }
}

struct MediaScanner {
    private let fileManager = FileManager.default
    private let minimumFileSizeBytes: Int64 = 10 * 1024 * 1024

    func scan(urls: [URL]) throws -> [ClipInfo] {
        var clips: [ClipInfo] = []
        var seen: Set<URL> = []

        for url in urls {
            let standardized = url.standardizedFileURL
            if standardized.hasDirectoryPath {
                clips.append(contentsOf: try scanDirectory(standardized, seen: &seen))
            } else {
                if let clip = try scanFile(standardized), seen.insert(standardized).inserted {
                    clips.append(clip)
                }
            }
        }

        return clips.sorted {
            if $0.modificationDate != $1.modificationDate {
                return $0.modificationDate < $1.modificationDate
            }
            return $0.url.lastPathComponent.localizedCaseInsensitiveCompare($1.url.lastPathComponent) == .orderedAscending
        }
    }

    private func scanDirectory(_ directoryURL: URL, seen: inout Set<URL>) throws -> [ClipInfo] {
        let keys: [URLResourceKey] = [
            .isDirectoryKey,
            .isRegularFileKey,
            .fileSizeKey,
            .contentModificationDateKey
        ]

        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var clips: [ClipInfo] = []
        for case let fileURL as URL in enumerator {
            let standardized = fileURL.standardizedFileURL
            if seen.contains(standardized) {
                continue
            }

            do {
                let values = try standardized.resourceValues(forKeys: Set(keys))
                guard values.isRegularFile == true else { continue }
                guard standardized.pathExtension.lowercased() == "mts" else { continue }
                guard containsAVCHDStream(standardized.pathComponents) else { continue }
                let fileSize = Int64(values.fileSize ?? 0)
                guard fileSize >= minimumFileSizeBytes else { continue }
                let modificationDate = values.contentModificationDate ?? Date.distantPast

                seen.insert(standardized)
                clips.append(ClipInfo(url: standardized, fileSize: fileSize, modificationDate: modificationDate))
            } catch {
                continue
            }
        }

        return clips
    }

    private func scanFile(_ fileURL: URL) throws -> ClipInfo? {
        let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey])
        guard values.isRegularFile == true else { return nil }
        guard fileURL.pathExtension.lowercased() == "mts" else { return nil }
        guard containsAVCHDStream(fileURL.pathComponents) else { return nil }
        let fileSize = Int64(values.fileSize ?? 0)
        guard fileSize >= minimumFileSizeBytes else { return nil }
        let modificationDate = values.contentModificationDate ?? Date.distantPast
        return ClipInfo(url: fileURL, fileSize: fileSize, modificationDate: modificationDate)
    }

    private func containsAVCHDStream(_ components: [String]) -> Bool {
        let lowercased = components.map { $0.lowercased() }
        guard lowercased.count >= 3 else { return false }

        for index in 0..<(lowercased.count - 2) {
            if lowercased[index] == "avchd",
               lowercased[index + 1] == "bdmv",
               lowercased[index + 2] == "stream" {
                return true
            }
        }

        return false
    }
}
