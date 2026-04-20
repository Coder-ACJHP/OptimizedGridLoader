//
//  Photo.swift
//  CollectionViewOptimization
//
//  Created by Coder ACJHP on 11.03.2026.
//

import Foundation

// MARK: - Photo
struct Photo: Codable, Hashable, Identifiable {
    let id, author: String
    let width, height: Int
    let url, downloadURL: String

    enum CodingKeys: String, CodingKey {
        case id, author, width, height, url
        case downloadURL = "download_url"
    }
    
    func optimizedURLString(pixelWidth: Int) -> String {
        let aspectRatio = CGFloat(height) / CGFloat(width)
        let pixelHeight = Int(CGFloat(pixelWidth) * aspectRatio)
        return "https://picsum.photos/id/\(id)/\(pixelWidth)/\(pixelHeight)"
    }
}
