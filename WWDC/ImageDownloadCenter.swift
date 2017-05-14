//
//  ImageDownloadOperation.swift
//  JPEG Core
//
//  Created by Guilherme Rambo on 09/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift

typealias ImageDownloadCompletionBlock = (_ sourceURL: URL, _ original: NSImage?, _ thumbnail: NSImage?) -> Void

final class ImageDownloadCenter {
    
    static let shared: ImageDownloadCenter = ImageDownloadCenter()
    
    private let cacheProvider = ImageCacheProvider()
    private let queue = OperationQueue()
    
    func downloadImage(from url: URL, thumbnailHeight: CGFloat, thumbnailOnly: Bool = false, completion: @escaping ImageDownloadCompletionBlock) -> Operation? {
        if let cache = cacheProvider.cacheEntity(for: url) {
            var original: NSImage?
            
            if !thumbnailOnly {
                original = NSImage(data: cache.original)
            }
            
            let thumb = NSImage(data: cache.thumbnail)
            
            original?.cacheMode = .never
            thumb?.cacheMode = .never
            
            completion(url, original, thumb)
            
            return nil
        }
        
        guard !hasActiveOperation(for: url) else { return nil }
        
        let operation = ImageDownloadOperation(url: url, cache: cacheProvider, thumbnailHeight: thumbnailHeight)
        operation.imageCompletionHandler = completion
        
        queue.addOperation(operation)
        
        return operation
    }
    
    func hasActiveOperation(for url: URL) -> Bool {
        return queue.operations.filter { op in
            guard let op = op as? ImageDownloadOperation else { return false }
            
            return op.url == url && op.isExecuting
        }.count > 0
    }
    
}

final class ImageCacheEntity: Object {
    
    dynamic var key: String = ""
    dynamic var createdAt: Date = Date()
    dynamic var original: Data = Data()
    dynamic var thumbnail: Data = Data()
    
    override class func primaryKey() -> String {
        return "key"
    }
    
}

private final class ImageCacheProvider {
    
    private var originalCaches: [URL: URL] = [:]
    private var thumbCaches: [URL: URL] = [:]
    
    private let upperLimit = 16 * 1024 * 1024
    
    private func makeRealm() -> Realm? {
        let filePath = PathUtil.appSupportPath + "/ImageCache.realm"
        
        var realmConfig = Realm.Configuration(fileURL: URL(fileURLWithPath: filePath))
        realmConfig.objectTypes = [ImageCacheEntity.self]
        realmConfig.schemaVersion = 1
        realmConfig.migrationBlock = { _, _ in }
        
        return try? Realm(configuration: realmConfig)
    }
    
    private lazy var realm: Realm? = {
        return self.makeRealm()
    }()
    
    func cacheEntity(for url: URL) -> ImageCacheEntity? {
        return self.realm?.object(ofType: ImageCacheEntity.self, forPrimaryKey: url.absoluteString)
    }
    
    func cacheImage(for key: URL, original: Data?, thumbnail: Data?) {
        guard let original = original, let thumbnail = thumbnail else { return }
        
        guard original.count < upperLimit, thumbnail.count < upperLimit else { return }
        
        DispatchQueue.global(qos: .utility).async {
            let bgRealm = self.makeRealm()
            
            let entity = ImageCacheEntity()
            
            entity.key = key.absoluteString
            entity.original = original
            entity.thumbnail = thumbnail
            
            do {
                try bgRealm?.write {
                    bgRealm?.add(entity, update: true)
                }
            } catch {
                NSLog("Error saving cached image: \(error)")
            }
        }
    }
    
}

private final class ImageDownloadOperation: Operation {
    
    var imageCompletionHandler: ImageDownloadCompletionBlock?
    
    let url: URL
    let thumbnailHeight: CGFloat
    
    let cacheProvider: ImageCacheProvider
    
    init(url: URL, cache: ImageCacheProvider, thumbnailHeight: CGFloat = 1.0) {
        self.url = url
        self.cacheProvider = cache
        self.thumbnailHeight = thumbnailHeight
    }
    
    open override var isAsynchronous: Bool {
        return true
    }
    
    internal var _executing = false {
        willSet {
            willChangeValue(forKey: "isExecuting")
        }
        didSet {
            didChangeValue(forKey: "isExecuting")
        }
    }
    
    open override var isExecuting: Bool {
        return _executing
    }
    
    internal var _finished = false {
        willSet {
            willChangeValue(forKey: "isFinished")
        }
        didSet {
            didChangeValue(forKey: "isFinished")
        }
    }
    
    open override var isFinished: Bool {
        return _finished
    }
    
    override func start() {
        _executing = true
        
        URLSession.shared.dataTask(with: self.url) { [unowned self] data, response, error in
            guard !self.isCancelled else { return }
            
            guard let data = data, let httpResponse = response as? HTTPURLResponse, error == nil else {
                DispatchQueue.main.async { self.imageCompletionHandler?(self.url, nil, nil) }
                self._executing = false
                self._finished = true
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                DispatchQueue.main.async { self.imageCompletionHandler?(self.url, nil, nil) }
                self._executing = false
                self._finished = true
                return
            }
            
            guard data.count > 0 else {
                DispatchQueue.main.async { self.imageCompletionHandler?(self.url, nil, nil) }
                self._executing = false
                self._finished = true
                return
            }
            
            guard let originalImage = NSImage(data: data) else {
                DispatchQueue.main.async { self.imageCompletionHandler?(self.url, nil, nil) }
                self._executing = false
                self._finished = true
                return
            }
            
            guard !self.isCancelled else { return }
            
            let thumbnailImage = originalImage.resized(to: self.thumbnailHeight)
            
            originalImage.cacheMode = .never
            thumbnailImage.cacheMode = .never
            
            DispatchQueue.main.async {
                self.imageCompletionHandler?(self.url, originalImage, thumbnailImage)
            }
            
            self.cacheProvider.cacheImage(for: self.url, original: data, thumbnail: thumbnailImage.tiffRepresentation)
            
            self._executing = false
            self._finished = true
        }.resume()
    }
    
}

private extension NSImage {
    
    func resized(to maxHeight: CGFloat) -> NSImage {
        let scaleFactor = maxHeight / size.height
        let newWidth = size.width * scaleFactor
        let newHeight = size.height * scaleFactor
        
        let resizedImage = NSImage(size: NSSize(width: newWidth, height: newHeight))
        
        resizedImage.lockFocus()
        self.draw(in: NSRect(x: 0, y: 0, width: newWidth, height: newHeight))
        resizedImage.unlockFocus()
        
        return resizedImage
    }
    
}
