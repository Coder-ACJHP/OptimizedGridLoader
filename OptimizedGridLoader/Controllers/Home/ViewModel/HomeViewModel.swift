//
//  HomeViewModel.swift
//  CollectionViewOptimization
//
//  Created by Coder ACJHP on 11.03.2026.
//

import Foundation
import OSLog
import Combine

@MainActor
class HomeViewModel {
    
    @Published public private(set) var photos: [Photo] = []
    @Published public private(set) var isLoading: Bool = false
    
    public let loader = ImageLoader()
    public var screenScale: CGFloat = 2
    public var cellSize: CGSize = CGSize(width: 120, height: 120)
    
    private var page: Int = 1
    private var limit: Int = 20
    private var hasMore: Bool = true
    private let service: PhotoService
    private var prefetchTasks: [Int: Task<Void, Never>] = [:]
    
    init(service: PhotoService) {
        self.service = service
    }
    
    /// Fetches the first page of photos from the API and notifies the view
    /// via `initialPhotosLoaded` so it can perform a full `reloadData`.
    func fetchInitialPhotos() {
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                photos = try await self.service.fetchPhotos(page: page, limit: limit)
            } catch {
                Logger(
                    subsystem: "com.collectionView.optimizing.test",
                    category: "fetchInitialPhotos.download.image")
                .log("Failed to fetch initial photos: \(error.localizedDescription)")
            }
        }
    }
    
    /// Triggers pagination when the user scrolls near the end of the list.
    /// Guards against two failure modes:
    /// `isLoading` — prevents concurrent network requests.
    func fetchMorePhotosIfNeeded() {
        guard !isLoading, hasMore else { return }
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                let nextPage = page + 1
                let newPhotos = try await service.fetchPhotos(page: nextPage, limit: limit)
                hasMore = !newPhotos.isEmpty
                photos.append(contentsOf: newPhotos)
                page = nextPage
            } catch {
                // Reset so the user can retry on the next scroll event.
                Logger(
                    subsystem: "com.collectionView.optimizing.test",
                    category: "fetchMorePhotos.download.image")
                .log("Failed to fetch more photos: \(error.localizedDescription)")
            }
        }
    }
    
    /// Pre-warms the image cache for upcoming cells using the same optimized (sized) URL
    /// that `PhotoCell.configure` will request, so the cell gets an instant cache hit.
    func startPrefetchForIndexPaths(_ indexPaths: [IndexPath]) {
        let size = cellSize
        let scale = screenScale
        indexPaths.map(\.item).forEach { index in
            if index >= photos.count { return }
            let photo = photos[index]
            let pixelWidth = Int(size.width) * Int(scale)
            guard let downloadURL = URL(string: photo.optimizedURLString(pixelWidth: pixelWidth)) else { return }
            prefetchTasks[index] = Task {
                _ = try? await loader.loadImage(from: downloadURL, targetSize: size, scale: scale)
            }
        }
    }
    
    /// Cancels any in-progress prefetch tasks for cells that are no longer approaching
    /// the visible area, freeing up network bandwidth for actually visible cells.
    func cancelPrefetchingForIndexPaths(_ indexPaths: [IndexPath]) {
        indexPaths.map(\.item).forEach { index in
            prefetchTasks[index]?.cancel()
            prefetchTasks[index] = nil
        }
    }
}
