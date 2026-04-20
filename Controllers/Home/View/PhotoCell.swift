//
//  PhotoCell.swift
//  CollectionViewOptimization
//
//  Created by Coder ACJHP on 11.03.2026.
//

import UIKit

class PhotoCell: UICollectionViewCell {
    
    private var loadTask: Task<Void, Never>?
    private var representingIdentifier: String?
    static let reuseIdentifier = String(describing: PhotoCell.self)
    
    public let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initCommon()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initCommon()
    }
    
    private func initCommon() {
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }
    
    public func configure(withLoader loader: ImageLoader, photo: Photo, contentMode: UIView.ContentMode) {
        imageView.contentMode = contentMode
        
        let scale = UIScreen.main.scale
        let pixelWidth = Int(contentView.bounds.width) * Int(scale)
        guard let downloadURL = URL(string: photo.optimizedURLString(pixelWidth: pixelWidth)) else { return }
        
        let targetSize = contentView.bounds.size
        representingIdentifier = photo.id
        
        loadTask = Task { [weak self] in
            guard let self else { return }
            
            do {
                let image = try await loader.loadImage(from: downloadURL, targetSize: targetSize, scale: scale)
                guard !Task.isCancelled, self.representingIdentifier == photo.id else { return }
                self.imageView.image = image
            } catch {
                imageView.image = UIImage(systemName: "photo.trianglebadge.exclamationmark")
            }
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        imageView.image = nil
        representingIdentifier = nil
        loadTask?.cancel()
        loadTask = nil
    }
}
