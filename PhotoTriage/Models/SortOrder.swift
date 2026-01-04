//
//  SortOrder.swift
//  PhotoTriage
//

import Foundation

enum SortOrder: String, CaseIterable, Codable {
    case newestFirst = "Newest First"
    case oldestFirst = "Oldest First"
}
