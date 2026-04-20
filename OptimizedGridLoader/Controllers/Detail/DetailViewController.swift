//
//  DetailViewController.swift
//  OptimizedGridLoader
//
//  Created by Coder ACJHP on 12.03.2026.
//

import UIKit

class DetailViewController: UIViewController {

    let photo: Photo
    private let loader = ImageLoader()
    private let router: RouterDelegate
    private let previewImage: UIImage?

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        return imageView
    }()

    init(photo: Photo, previewImage: UIImage?, router: RouterDelegate) {
        self.photo = photo
        self.router = router
        self.previewImage = previewImage
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        configureNavigationBar()
        setupImageView()
        loadImage()
    }

    @objc private func didTapBackButton() {
        router.pop(animated: true)
    }

    private func configureNavigationBar() {
        navigationItem.largeTitleDisplayMode = .never
        let backImage = UIImage(systemName: "chevron.left")
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: backImage,
            style: .plain,
            target: self,
            action: #selector(didTapBackButton)
        )
    }

    private func setupImageView() {
        view.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        // Assign previewImage
        imageView.image = previewImage
    }

    @MainActor
    private func loadImage() {
        Task {
            guard let url = URL(string: photo.downloadURL) else { return }

            let image = try await loader.loadImage(
                from: url,
                targetSize: view.bounds.size,
                scale: UIScreen.main.scale
            )

            guard !Task.isCancelled else { return }

            UIView.transition(
                with: imageView,
                duration: 0.25,
                options: .transitionCrossDissolve
            ) {
                self.imageView.image = image
            }
        }
    }
}

// MARK: - PhotoTransitionDestinationProviding

extension DetailViewController: PhotoTransitionDestinationProviding {
    var photoImageView: UIImageView {
        imageView
    }
}
