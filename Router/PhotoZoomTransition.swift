//
//  PhotoZoomTransition.swift
//  OptimizedGridLoader
//
//  Created by Coder ACJHP on 12.03.2026.
//

import UIKit

protocol PhotoTransitionSourceProviding: AnyObject {
    func photoTransitionSourceImageView(for photo: Photo) -> UIImageView?
}

protocol PhotoTransitionDestinationProviding: AnyObject {
    var photo: Photo { get }
    var photoImageView: UIImageView { get }
}

final class PhotoZoomAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    
    enum Operation {
        case push
        case pop
    }
    
    private let operation: Operation
    
    init(operation: Operation) {
        self.operation = operation
        super.init()
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval { 0.45 }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard
            let fromViewController = transitionContext.viewController(forKey: .from),
            let toViewController = transitionContext.viewController(forKey: .to)
        else {
            transitionContext.completeTransition(false)
            return
        }
        
        switch operation {
        case .push:
            performPushTransition(
                context: transitionContext,
                fromViewController: fromViewController,
                toViewController: toViewController
            )
        case .pop:
            performPopTransition(
                context: transitionContext,
                fromViewController: fromViewController,
                toViewController: toViewController
            )
        }
    }
    
    // MARK: - Private
    
    private func performPushTransition(
        context: UIViewControllerContextTransitioning,
        fromViewController: UIViewController,
        toViewController: UIViewController
    ) {
        guard
            let sourceViewController = fromViewController as? (UIViewController & PhotoTransitionSourceProviding),
            let destinationViewController = toViewController as? (UIViewController & PhotoTransitionDestinationProviding)
        else {
            performFallbackPush(context: context, toViewController: toViewController)
            return
        }
        
        let containerView = context.containerView
        let duration = transitionDuration(using: context)
        
        let photo = destinationViewController.photo
        guard let sourceImageView = sourceViewController.photoTransitionSourceImageView(for: photo) else {
            performFallbackPush(context: context, toViewController: toViewController)
            return
        }
        
        let destinationImageView = destinationViewController.photoImageView
        
        // Ensure destination layout is ready
        destinationViewController.view.frame = context.finalFrame(for: destinationViewController)
        destinationViewController.view.layoutIfNeeded()
        
        let startFrame = sourceImageView.convert(sourceImageView.bounds, to: containerView)
        let endFrame = destinationImageView.convert(destinationImageView.bounds, to: containerView)
        
        let transitionImageView = UIImageView(image: destinationImageView.image ?? sourceImageView.image)
        transitionImageView.contentMode = destinationImageView.contentMode
        transitionImageView.clipsToBounds = true
        transitionImageView.frame = startFrame
        
        sourceImageView.isHidden = true
        destinationImageView.isHidden = true
        
        containerView.addSubview(destinationViewController.view)
        destinationViewController.view.alpha = 0
        containerView.addSubview(transitionImageView)
        
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0.0,
            options: [.curveEaseOut]
        ) {
            transitionImageView.frame = endFrame
            destinationViewController.view.alpha = 1.0
        } completion: { finished in
            sourceImageView.isHidden = false
            destinationImageView.isHidden = false
            transitionImageView.removeFromSuperview()
            let wasCancelled = context.transitionWasCancelled
            context.completeTransition(!wasCancelled && finished)
        }
    }
    
    private func performPopTransition(
        context: UIViewControllerContextTransitioning,
        fromViewController: UIViewController,
        toViewController: UIViewController
    ) {
        guard
            let destinationViewController = toViewController as? (UIViewController & PhotoTransitionSourceProviding),
            let sourceViewController = fromViewController as? (UIViewController & PhotoTransitionDestinationProviding)
        else {
            performFallbackPop(context: context, toViewController: toViewController, fromViewController: fromViewController)
            return
        }
        
        let containerView = context.containerView
        let duration = transitionDuration(using: context)
        
        let photo = sourceViewController.photo
        let destinationImageViewOptional = destinationViewController.photoTransitionSourceImageView(for: photo)
        let sourceImageView = sourceViewController.photoImageView
        
        guard let destinationImageView = destinationImageViewOptional else {
            performFallbackPop(context: context, toViewController: toViewController, fromViewController: fromViewController)
            return
        }
        
        destinationViewController.view.frame = context.finalFrame(for: toViewController)
        destinationViewController.view.layoutIfNeeded()
        
        let startFrame = sourceImageView.convert(sourceImageView.bounds, to: containerView)
        let endFrame = destinationImageView.convert(destinationImageView.bounds, to: containerView)
        
        let transitionImageView = UIImageView(image: sourceImageView.image)
        transitionImageView.contentMode = destinationImageView.contentMode
        transitionImageView.clipsToBounds = true
        transitionImageView.frame = startFrame
        
        sourceImageView.isHidden = true
        destinationImageView.isHidden = true
        
        containerView.insertSubview(toViewController.view, belowSubview: fromViewController.view)
        containerView.addSubview(transitionImageView)
        
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0.0,
            options: [.curveEaseOut]
        ) {
            fromViewController.view.alpha = 0
            transitionImageView.frame = endFrame
        } completion: { finished in
            sourceImageView.isHidden = false
            destinationImageView.isHidden = false
            transitionImageView.removeFromSuperview()
            fromViewController.view.alpha = 1
            
            let wasCancelled = context.transitionWasCancelled
            if wasCancelled {
                // Restore hierarchy when cancelled
                toViewController.view.removeFromSuperview()
            }
            context.completeTransition(!wasCancelled && finished)
        }
    }
    
    private func performFallbackPush(
        context: UIViewControllerContextTransitioning,
        toViewController: UIViewController
    ) {
        let containerView = context.containerView
        let duration = transitionDuration(using: context)
        
        toViewController.view.frame = context.finalFrame(for: toViewController)
        toViewController.view.alpha = 0
        containerView.addSubview(toViewController.view)
        
        UIView.animate(withDuration: duration, animations: {
            toViewController.view.alpha = 1
        }, completion: { finished in
            let wasCancelled = context.transitionWasCancelled
            context.completeTransition(!wasCancelled && finished)
        })
    }
    
    private func performFallbackPop(
        context: UIViewControllerContextTransitioning,
        toViewController: UIViewController,
        fromViewController: UIViewController
    ) {
        let containerView = context.containerView
        let duration = transitionDuration(using: context)
        
        toViewController.view.frame = context.finalFrame(for: toViewController)
        containerView.insertSubview(toViewController.view, belowSubview: fromViewController.view)
        
        UIView.animate(withDuration: duration, animations: {
            fromViewController.view.alpha = 0
        }, completion: { finished in
            fromViewController.view.alpha = 1
            let wasCancelled = context.transitionWasCancelled
            if wasCancelled {
                toViewController.view.removeFromSuperview()
            }
            context.completeTransition(!wasCancelled && finished)
        })
    }
}

final class PhotoNavigationControllerDelegate: NSObject, UINavigationControllerDelegate {
    
    func navigationController(
        _ navigationController: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        switch operation {
        case .push:
            guard
                fromVC is (UIViewController & PhotoTransitionSourceProviding),
                toVC is (UIViewController & PhotoTransitionDestinationProviding)
            else {
                return nil
            }
            return PhotoZoomAnimator(operation: .push)
            
        case .pop:
            guard
                toVC is (UIViewController & PhotoTransitionSourceProviding),
                fromVC is (UIViewController & PhotoTransitionDestinationProviding)
            else {
                return nil
            }
            return PhotoZoomAnimator(operation: .pop)
        default:
            return nil
        }
    }
}

