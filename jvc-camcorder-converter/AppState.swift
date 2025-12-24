//
//  AppState.swift
//  jvc-camcorder-converter
//
//  Created by Joshua Impson on 12/23/25.
//

import Foundation

enum AppState: Equatable {
    case idle
    case scanning
    case converting
    case completed
    case error(String)
}
