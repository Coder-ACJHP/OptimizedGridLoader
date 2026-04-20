//
//  PhotoService.swift
//  CollectionViewOptimization
//
//  Created by Coder ACJHP on 11.03.2026.
//

import Foundation

enum PhotoError: Error {
    case invalidURL
    case invalidData
    case decodingError
}

final class PhotoService {
    
    private let session = URLSessionFactory.make()
        
    /// Fetches a paginated list of photos from the Picsum API.
    /// Uses `returnCacheDataElseLoad` policy so repeated requests for the same page
    /// are served from URLCache without hitting the network again.
    func fetchPhotos(page: Int, limit: Int) async throws -> [Photo] {
        guard let url = URL(string: "https://picsum.photos/v2/list?page=\(page)&limit=\(limit)") else {
            throw PhotoError.invalidURL
        }
                
        do {
            
            let (data, _) = try await session.data(from: url)
            let photos: [Photo] = try JSONDecoder().decode([Photo].self, from: data)
            return photos
            
        } catch {
            throw PhotoError.decodingError
        }
    }
}
