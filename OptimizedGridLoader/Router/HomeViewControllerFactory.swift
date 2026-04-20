//
//  HomeViewControllerFactory.swift
//  OptimizedGridLoader
//
//  Created by Coder ACJHP on 12.03.2026.
//

import Foundation
import UIKit

protocol HomeViewControllerFactory {
    func makeHomeViewController(router: RouterDelegate) -> UIViewController
}

class DefaultHomeViewControllerFactory: HomeViewControllerFactory {
    func makeHomeViewController(router: RouterDelegate) -> UIViewController {
        let service = PhotoService()
        let viewModel = HomeViewModel(service: service)
        return HomeViewController(viewModel: viewModel, router: router)
    }
}
