//
//  CALayer+Asset.swift
//  WWDC
//
//  Created by Guilherme Rambo on 14/08/19.
//  Copyright © 2019 Guilherme Rambo. All rights reserved.
//

import Cocoa
import OSLog

public extension CALayer {
    static let log = Logger(subsystem: kConfUIFoundationSubsystem, category: "CALayer+")
}

public extension CALayer {

    /// Temporary storage for animations that have been disabled by `disableAllAnimations`
    private static var _animationStorage: [Int: [String: CAAnimation]] = [:]

    /// Loads a `CALayer` from a Core Animation Archive asset.
    ///
    /// - Parameters:
    ///   - assetName: The name of the asset in the asset catalog.
    ///   - bundle: The bundle where the asset catalog is located.
    /// - Returns: The `CALayer` loaded from the asset in the asset catalog, `nil` in case of failure.
    static func load(assetNamed assetName: String, bundle: Bundle = .main) -> CALayer? {
        guard let asset = NSDataAsset(name: assetName, bundle: bundle) else {
            assertionFailure("Asset not found")
            log.fault("Missing asset \(assetName, privacy: .public)")
            return nil
        }

        do {
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: asset.data)
            unarchiver.requiresSecureCoding = false

            let rootObject = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey)

            guard let dictionary = rootObject as? NSDictionary else {
                assertionFailure("Failed to load asset")
                log.fault("Failed to load asset \(assetName, privacy: .public)")
                return nil
            }

            guard let layer = dictionary["rootLayer"] as? CALayer else {
                assertionFailure("Root layer not found")
                log.fault("Failed to load root layer from asset \(assetName, privacy: .public)")
                return nil
            }

            return layer
        } catch {
            assertionFailure(String(describing: error))
            log.fault("Unarchive failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    func sublayer<T: CALayer>(named name: String, of type: T.Type) -> T? {
        return sublayers?.first(where: { $0.name == name }) as? T
    }

    func sublayer<T: CALayer>(path: String, of type: T.Type) -> T? {
        let components = path.components(separatedBy: ".")
        var target: CALayer? = self
        for component in components {
            target = target?.sublayer(named: component, of: CALayer.self)
        }
        return target as? T
    }

    /// Disables all animations on the layer, but allows them to be re-enabled later by `enableAllAnimations`.
    func disableAllAnimations() {
        guard let keys = animationKeys() else { return }

        keys.forEach { key in
            guard let animation = animation(forKey: key) else { return }

            if CALayer._animationStorage[hash] == nil {
                CALayer._animationStorage[hash] = [:]
            }

            CALayer._animationStorage[hash]?[key] = animation
        }

        removeAllAnimations()
    }

    /// Re-enables animations previously disabled by `disableAllAnimations`.
    func enableAllAnimations() {
        guard let keys = CALayer._animationStorage[hash]?.keys.map({$0}) else { return }

        keys.forEach { key in
            guard let animation = CALayer._animationStorage[hash]?[key] else { return }

            add(animation, forKey: key)
        }

        CALayer._animationStorage.removeValue(forKey: hash)
    }

}

public extension CALayer {

    func resizeLayer(_ targetLayer: CALayer?) {
        guard let targetLayer = targetLayer else { return }

        let layerWidth = targetLayer.bounds.width
        let layerHeight = targetLayer.bounds.height

        let aspectWidth  = bounds.width / layerWidth
        let aspectHeight = bounds.height / layerHeight

        let ratio = min(aspectWidth, aspectHeight)

        let scale = CATransform3DMakeScale(ratio,
                                           ratio,
                                           1)
        let translation = CATransform3DMakeTranslation((bounds.width - (layerWidth * ratio))/2.0,
                                                       (bounds.height - (layerHeight * ratio))/2.0,
                                                       0)

        targetLayer.transform = CATransform3DConcat(scale, translation)
    }

}

public extension NSView {

    func rewind(_ assetLayer: CALayer) {
        assetLayer.timeOffset = 0
        pause(assetLayer)
    }

    func play(_ assetLayer: CALayer) {
        assetLayer.beginTime = CACurrentMediaTime()
        assetLayer.speed = 1
    }

    func pause(_ assetLayer: CALayer) {
        assetLayer.speed = 0
    }

}

public extension CALayer {

    func lastAnimationToFinish() -> (animation: CAAnimation, layer: CALayer, animationKey: String)? {
        var lastAnimation: CAAnimation?
        var lastFinishTime: CFTimeInterval = 0
        var layer: CALayer?
        var animationKey: String?

        animationKeys()?.forEach {
            let aAnimation = animation(forKey: $0)!
            if beginTime + aAnimation.finishTime > lastFinishTime {
                lastAnimation = aAnimation
                lastFinishTime = beginTime + aAnimation.finishTime
                layer = self
                animationKey = $0
            }
        }

        sublayers?.forEach { sLayer in
            if let last = sLayer.lastAnimationToFinish(),
                beginTime + last.animation.finishTime > lastFinishTime {
                lastAnimation = last.animation
                lastFinishTime = beginTime + last.animation.finishTime
                layer = last.layer
                animationKey = last.animationKey
            }
        }

        if
            let animation = lastAnimation,
            let layer = layer,
            let animationKey = animationKey {
            return (animation, layer, animationKey)
        }

        return nil
    }
}

private extension CAAnimation {
    var finishTime: CFTimeInterval {
        return beginTime + duration
    }
}
