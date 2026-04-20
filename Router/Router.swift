//
//  Router.swift
//  OptimizedGridLoader
//
//  Created by Coder ACJHP on 12.03.2026.
//

import Foundation
import UIKit

enum Route {
    case home
    case detail(photo: Photo, previewImage: UIImage?)
}

protocol RouterDelegate: AnyObject {
    var controller: UINavigationController { get }
    func navigate(to route: Route, animated: Bool)
    func present(route: Route, animated: Bool)
    func dismiss(animated: Bool)
    func pop(animated: Bool)
    func popToRoot(animated: Bool)
    func makeViewController(route: Route) -> UIViewController
}

@MainActor
class Router: RouterDelegate {
    var controller: UINavigationController
    let homeFactory: HomeViewControllerFactory
    private let navigationTransitionDelegate: UINavigationControllerDelegate
    
    
    init(controller: UINavigationController, homeFactory: HomeViewControllerFactory) {
        self.controller = controller
        self.homeFactory = homeFactory
        let transitionDelegate = PhotoNavigationControllerDelegate()
        self.navigationTransitionDelegate = transitionDelegate
        controller.delegate = transitionDelegate
    }
    
    func navigate(to route: Route, animated: Bool = true) {
        let destinationVC = makeViewController(route: route)
        controller.pushViewController(destinationVC, animated: animated)
    }
    
    func present(route: Route, animated: Bool = true) {
        let rootViewController = makeViewController(route: route)
        // Wraps in a new NavigationController so if needed the modal has its own navigation stack
        let navController = UINavigationController(rootViewController: rootViewController)
        controller.present(navController, animated: animated)
    }
    
    func dismiss(animated: Bool = true) {
        controller.dismiss(animated: animated)
    }
    
    func pop(animated: Bool = true) {
        controller.popViewController(animated: animated)
    }

    func popToRoot(animated: Bool = true) {
        controller.popToRootViewController(animated: animated)
    }
        
    func makeViewController(route: Route) -> UIViewController {
        switch route {
            case .home:
                return homeFactory.makeHomeViewController(router: self)
            case .detail(let photo, let previewImage):
                let vc = DetailViewController(photo: photo, previewImage: previewImage, router: self)
                return vc
        }
    }
}
