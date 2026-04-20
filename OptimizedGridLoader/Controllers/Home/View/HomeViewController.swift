//
//  HomeViewController.swift
//  CollectionViewOptimization
//
//  Created by Coder ACJHP on 11.03.2026.
//

import UIKit
import Combine

class HomeViewController: UIViewController {

    private lazy var gridLayout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 5
        layout.minimumInteritemSpacing = 5
        layout.itemSize = vm.cellSize
        return layout
    }()

    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: gridLayout)
        collectionView.backgroundColor = .systemBackground
        collectionView.contentInsetAdjustmentBehavior = .automatic
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: PhotoCell.reuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.prefetchDataSource = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()

    private lazy var loadingBarItem: UIBarButtonItem = {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = .label
        spinner.startAnimating()
        return UIBarButtonItem(customView: spinner)
    }()

    private lazy var contentModeButton: UIBarButtonItem = {
        let action = UIAction(image: contentModeIcon(for: cellImageContentMode)) { [weak self] _ in
            self?.toggleContentMode()
        }
        let item = UIBarButtonItem(primaryAction: action)
        item.tintColor = .label
        return item
    }()

    private let vm: HomeViewModel
    private let router: RouterDelegate
    private var cancellables: Set<AnyCancellable> = []
    private lazy var preferredCellSize: CGSize = vm.cellSize
    private var cellImageContentMode: UIView.ContentMode = .scaleAspectFill
    /// Local snapshot of photos that drives the collection view data source.
    /// This is the single source of truth for numberOfItemsInSection and cellForItem.
    /// It is always updated synchronously before performBatchUpdates so that UIKit's
    /// internal consistency check (expected count == dataSource count) never fails,
    /// even when two network pages complete before the RunLoop delivers either Combine event.
    private var displayedPhotos: [Photo] = []

    init(viewModel: HomeViewModel, router: RouterDelegate) {
        self.vm = viewModel
        self.vm.screenScale = UIScreen.main.scale
        self.router = router
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        configureNavigationBar()
        setupBinding()
        setupCollectionView()
        vm.fetchInitialPhotos()
    }

    /// Syncs the computed cell size to the ViewModel after layout completes,
    /// so prefetch requests use the correct pixel dimensions.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        vm.cellSize = preferredCellSize
    }

    /// Wires ViewModel callbacks to UI updates.
    /// - First emission: full `reloadData` for the initial page.
    /// - Subsequent emissions: incremental insert via `performBatchUpdates`.
    ///
    /// We intentionally avoid `scan` here. `scan` computes `oldCount` from a
    /// Combine-internal snapshot that can lag behind `vm.photos` when two network
    /// pages complete before the RunLoop delivers either event. The result is that
    /// `numberOfItemsInSection` (which reads `vm.photos.count`) returns a value
    /// higher than `oldCount + inserted`, crashing UIKit's consistency check.
    ///
    /// Fix: maintain `displayedPhotos` as the data-source backing store and update
    /// it synchronously *before* calling `performBatchUpdates`. UIKit then always
    /// sees a consistent count regardless of how many pending Combine deliveries exist.
    private func setupBinding() {
        vm.$isLoading
            .receive(on: RunLoop.main)
            .sink { [weak self] isLoading in
                guard let self else { return }
                navigationItem.leftBarButtonItem = isLoading ? loadingBarItem : nil
            }
            .store(in: &cancellables)

        vm.$photos
            .receive(on: RunLoop.main)
            .sink { [weak self] newPhotos in
                guard let self else { return }

                if displayedPhotos.isEmpty {
                    displayedPhotos = newPhotos
                    collectionView.reloadData()
                } else if newPhotos.count > displayedPhotos.count {
                    let oldCount = displayedPhotos.count
                    // Update the backing store first so numberOfItemsInSection
                    // returns newPhotos.count when UIKit validates the batch.
                    displayedPhotos = newPhotos
                    let indexPaths = (oldCount..<newPhotos.count).map {
                        IndexPath(item: $0, section: 0)
                    }
                    collectionView.performBatchUpdates { [weak self] in
                        self?.collectionView.insertItems(at: indexPaths)
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func configureNavigationBar() {
        navigationItem.title = "OptimizedGridLoader"
        navigationItem.largeTitleDisplayMode = .automatic
        navigationItem.rightBarButtonItem = contentModeButton

        guard let navbar = navigationController?.navigationBar else { return }
        navbar.prefersLargeTitles = true

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        if #unavailable(iOS 26) {
            appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        }
        navbar.standardAppearance = appearance
        navbar.scrollEdgeAppearance = appearance
        navbar.compactAppearance = appearance
    }

    private func setupCollectionView() {
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func contentModeIcon(for mode: UIView.ContentMode) -> UIImage? {
        let name = mode == .scaleAspectFill
            ? "arrow.up.left.and.arrow.down.right.square.fill"
            : "arrow.down.right.and.arrow.up.left.square.fill"
        return UIImage(systemName: name)?.withRenderingMode(.alwaysTemplate)
    }

    private func toggleContentMode() {
        cellImageContentMode = cellImageContentMode == .scaleAspectFill
            ? .scaleAspectFit
            : .scaleAspectFill
        contentModeButton.image = contentModeIcon(for: cellImageContentMode)

        collectionView.visibleCells.forEach { cell in
            guard let photoCell = cell as? PhotoCell else { return }
            UIView.transition(
                with: photoCell.imageView,
                duration: 0.25,
                options: .transitionCrossDissolve
            ) {
                photoCell.imageView.contentMode = self.cellImageContentMode
            }
        }
    }
}

// MARK: - UICollectionView delegate & dataSource & layout & prefetch

extension HomeViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        displayedPhotos.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let photo = displayedPhotos[indexPath.item]
        guard let cell: PhotoCell = collectionView.dequeueReusableCell(withReuseIdentifier: PhotoCell.reuseIdentifier, for: indexPath) as? PhotoCell else {
            return UICollectionViewCell()
        }
        cell.configure(
            withLoader: vm.loader,
            photo: photo,
            contentMode: cellImageContentMode
        )
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let item = displayedPhotos[indexPath.item]
        if let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell {
            let preViewImage = cell.imageView.image
            router.navigate(to: .detail(photo: item, previewImage: preViewImage), animated: true)
        }
    }

}

extension HomeViewController: UICollectionViewDelegateFlowLayout {
    /// Calculates a 3-column grid cell size based on the available width,
    /// accounting for inter-item spacing. Stores the result in `preferredCellSize`
    /// which is later forwarded to the ViewModel in `viewDidLayoutSubviews`.
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let flowLayout = collectionViewLayout as? UICollectionViewFlowLayout else {
            return vm.cellSize
        }
        let gapBetween: CGFloat = flowLayout.minimumInteritemSpacing * 2
        let availableSpace = collectionView.frame.width - gapBetween
        let width = availableSpace / 3
        preferredCellSize = CGSize(width: width, height: width)
        return preferredCellSize
    }
}

extension HomeViewController: UICollectionViewDataSourcePrefetching {

    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        vm.startPrefetchForIndexPaths(indexPaths)
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        vm.cancelPrefetchingForIndexPaths(indexPaths)
    }
}

// MARK: - PhotoTransitionSourceProviding

extension HomeViewController: PhotoTransitionSourceProviding {
    func photoTransitionSourceImageView(for photo: Photo) -> UIImageView? {
        guard let index = displayedPhotos.firstIndex(where: { $0.id == photo.id }) else {
            return nil
        }
        let indexPath = IndexPath(item: index, section: 0)
        guard let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell else {
            return nil
        }
        return cell.imageView
    }
}
// MARK: - UIScrollViewDelegate

extension HomeViewController: UIScrollViewDelegate {
    /// Proactively fetches the next page when the user is within 1.5 screen-heights
    /// of the bottom. Using content-offset distance (rather than a cell index) makes
    /// this approach immune to fast scrolling: the check fires on every scroll event
    /// and is naturally debounced by the `isLoading` / `fetchedUpToCount` guards in
    /// the ViewModel, so no extra throttling is needed here.
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.frame.height
        guard contentHeight > frameHeight else { return }
        if offsetY > contentHeight - (frameHeight * 1.5) {
            vm.fetchMorePhotosIfNeeded()
        }
    }
}
