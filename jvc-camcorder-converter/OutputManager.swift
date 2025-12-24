//
//  OutputManager.swift
//  jvc-camcorder-converter
//
//  Created by Joshua Impson on 12/23/25.
//

import Foundation

struct OutputManager {
    private let fileManager = FileManager.default
    private let baseFolderName = "Camcorder Imports"
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    func createOutputFolder(for date: Date, baseURL: URL? = nil) throws -> URL {
        let rootURL: URL
        if let baseURL {
            if baseURL.lastPathComponent == baseFolderName {
                rootURL = baseURL
            } else {
                rootURL = baseURL.appendingPathComponent(baseFolderName, isDirectory: true)
            }
        } else {
            guard let picturesURL = fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first else {
                throw OutputError.cannotLocatePicturesFolder
            }
            rootURL = picturesURL.appendingPathComponent(baseFolderName, isDirectory: true)
        }

        let dateFolder = dateFormatter.string(from: date)
        let outputURL = rootURL.appendingPathComponent(dateFolder, isDirectory: true)

        try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true, attributes: nil)
        return outputURL
    }

    func uniqueOutputURL(for inputURL: URL, in outputFolder: URL) -> URL {
        let baseName = inputURL.deletingPathExtension().lastPathComponent
        var candidate = outputFolder.appendingPathComponent(baseName).appendingPathExtension("mp4")

        var index = 1
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = outputFolder
                .appendingPathComponent("\(baseName)-\(index)")
                .appendingPathExtension("mp4")
            index += 1
        }

        return candidate
    }
}

enum OutputError: Error, LocalizedError {
    case cannotLocatePicturesFolder

    var errorDescription: String? {
        switch self {
        case .cannotLocatePicturesFolder:
            return "The Pictures folder could not be located."
        }
    }
}
