//
//  ImageDownloadOperation.swift
//  JPEG Core
//
//  Created by Guilherme Rambo on 09/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import os.log

typealias ImageDownloadCompletionBlock = (_ sourceURL: URL, _ result: (original: NSImage?, thumbnail: NSImage?)) -> Void

private struct ImageDownload {
    static let subsystemName = "io.WWDC.app.imageDownload"
}

final class ImageDownloadCenter {

    static let shared: ImageDownloadCenter = ImageDownloadCenter()

    private let cacheProvider = ImageCacheProvider()
    private let log = OSLog(subsystem: ImageDownload.subsystemName, category: "ImageDownloadCenter")

    private let dispatchQueue = DispatchQueue(label: "ImageDownloadCenter", qos: .userInitiated, attributes: .concurrent)
    private lazy var queue: OperationQueue = {
        let q = OperationQueue()
        
        q.underlyingQueue = dispatchQueue

        return q
    }()

    func downloadImage(from url: URL, thumbnailHeight: CGFloat, thumbnailOnly: Bool = false, completion: @escaping ImageDownloadCompletionBlock) -> Operation? {
        if thumbnailOnly {
            if let thumbnailImage = cacheProvider.cachedImage(for: url, thumbnailOnly: true).thumbnail {
                completion(url, (nil, thumbnailImage))
                return nil
            }
        }

        let cachedResult = cacheProvider.cachedImage(for: url)

        guard cachedResult.original == nil && cachedResult.thumbnail == nil else {
            completion(url, cachedResult)
            return nil
        }

        if let pendingOperation = activeOperation(for: url) {
            os_log("A valid download operation already exists for the URL %@",
                   log: self.log,
                   type: .debug,
                   url.absoluteString)

            pendingOperation.addCompletionHandler(with: completion)

            return nil
        }

        let operation = ImageDownloadOperation(url: url, cache: cacheProvider, thumbnailHeight: thumbnailHeight)
        operation.addCompletionHandler(with: completion)

        queue.addOperation(operation)

        return operation
    }

    fileprivate func activeOperation(for url: URL) -> ImageDownloadOperation? {
        return queue.operations.compactMap({ $0 as? ImageDownloadOperation }).first { op -> Bool in
            return op.url == url && op.isExecuting && !op.isCancelled
        }
    }

    private var deletedLegacyImageCache: Bool {
        get { UserDefaults.standard.bool(forKey: #function) }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }

    func deleteLegacyImageCacheIfNeeded() {
        guard !deletedLegacyImageCache else { return }
        deletedLegacyImageCache = true

        os_log("%{public}@", log: log, type: .debug, #function)

        let baseURL = URL(fileURLWithPath: PathUtil.appSupportPathAssumingExisting)
        let realmURL = baseURL.appendingPathComponent("ImageCache.realm")
        let lockURL = realmURL.appendingPathExtension("lock")
        let managementURL = realmURL.appendingPathExtension("management")

        do {
            try FileManager.default.removeItem(at: realmURL)
            try FileManager.default.removeItem(at: lockURL)
            try FileManager.default.removeItem(at: managementURL)
        } catch {
            os_log("Failed to delete legacy image cache: %{public}@", log: self.log, type: .error, String(describing: error))
        }
    }

}

private final class ImageCacheProvider {

    private lazy var inMemoryCache: NSCache<NSString, NSImage> = {
        let c = NSCache<NSString, NSImage>()

        c.countLimit = 100

        return c
    }()

    private let log = OSLog(subsystem: ImageDownload.subsystemName, category: "ImageCacheProvider")

    private let storageQueue = DispatchQueue(label: "ImageStorage", qos: .userInitiated, attributes: .concurrent)

    private let fileManager = FileManager()

    private lazy var cacheURL: URL = {
        let url = URL(fileURLWithPath: PathUtil.appSupportPathAssumingExisting).appendingPathComponent("ImageCache")

        if !fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            } catch {
                os_log("Failed to create image cache directory: %{public}@", log: self.log, type: .error, String(describing: error))
            }
        }

        return url
    }()

    private func cacheFileURL(for sourceURL: URL) -> URL { self.cacheURL.appendingPathComponent(sourceURL.imageCacheKey) }
    private func thumbnailCacheFileURL(for sourceURL: URL) -> URL { self.cacheURL.appendingPathComponent(sourceURL.thumbCacheKey) }

    func cacheImage(for sourceURL: URL, original: URL?, thumbnailHeight: CGFloat, completion: @escaping ((original: NSImage, thumbnail: NSImage)?) -> Void) {
        guard let original = original else {
            completion(nil)
            return
        }

        storageQueue.async {
            do {
                let url = self.cacheFileURL(for: sourceURL)

                if self.fileManager.fileExists(atPath: url.path) {
                    try self.fileManager.removeItem(at: url)
                }

                try self.fileManager.copyItem(at: original, to: url)

                guard let image = NSImage(contentsOf: url) else {
                    os_log("Failed to initalize image with %@", log: self.log, type: .error, url.path)
                    completion(nil)
                    return
                }

                let thumbImage = image.resized(to: thumbnailHeight)
                guard let thumbData = thumbImage.pngRepresentation else {
                    os_log("Failed to create thumbnail", log: self.log, type: .fault)
                    completion(nil)
                    return
                }

                let thumbURL = self.thumbnailCacheFileURL(for: sourceURL)
                try thumbData.write(to: thumbURL)

                image.cacheMode = .never
                thumbImage.cacheMode = .never

                self.inMemoryCache.setObject(thumbImage, forKey: url.thumbCacheKey as NSString)
                self.inMemoryCache.setObject(image, forKey: url.imageCacheKey as NSString)

                completion((image, thumbImage))
            } catch {
                os_log("Image storage failed: %{public}@", log: self.log, type: .error, String(describing: error))

                completion(nil)
            }
        }
    }

    private func storedImage(for sourceURL: URL, thumbnail: Bool = false) -> NSImage? {
        let url: URL
        let key: NSString
        if thumbnail {
            url = thumbnailCacheFileURL(for: sourceURL)
            key = sourceURL.thumbCacheKey as NSString
        } else {
            url = cacheFileURL(for: sourceURL)
            key = sourceURL.imageCacheKey as NSString
        }

        guard fileManager.fileExists(atPath: url.path), let image = NSImage(contentsOf: url) else { return nil }

        inMemoryCache.setObject(image, forKey: key)

        return image
    }

    func cachedImage(for sourceURL: URL, thumbnailOnly: Bool = false) -> (original: NSImage?, thumbnail: NSImage?) {
        let originalImageKey = sourceURL.imageCacheKey as NSString
        let thumbKey = sourceURL.thumbCacheKey as NSString

        var original: NSImage?
        var thumb: NSImage?

        if let thumbnailImage = inMemoryCache.object(forKey: thumbKey) {
            thumb = thumbnailImage
        } else {
            thumb = storedImage(for: sourceURL, thumbnail: true)
        }

        if !thumbnailOnly {
            if let originalImage = inMemoryCache.object(forKey: originalImageKey) {
                original = originalImage
            } else {
                original = storedImage(for: sourceURL)
            }
        }

        original?.cacheMode = .never
        thumb?.cacheMode = .never

        return (original, thumb)
    }

}

private final class ImageDownloadOperation: Operation {

    private var completionHandlers: [ImageDownloadCompletionBlock] = []

    func addCompletionHandler(with block: @escaping ImageDownloadCompletionBlock) {
        completionHandlers.append(block)
    }

    let url: URL
    let thumbnailHeight: CGFloat

    let cacheProvider: ImageCacheProvider

    init(url: URL, cache: ImageCacheProvider, thumbnailHeight: CGFloat = Constants.thumbnailHeight) {
        self.url = url
        cacheProvider = cache
        self.thumbnailHeight = thumbnailHeight
    }

    public override var isAsynchronous: Bool {
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

    public override var isExecuting: Bool {
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

    public override var isFinished: Bool {
        return _finished
    }

    override func cancel() {
        inFlightTask?.cancel()

        super.cancel()
    }

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true

        return URLSession(configuration: config)
    }()

    private var inFlightTask: URLSessionDownloadTask?

    private func callCompletionHandlers(with image: NSImage? = nil, thumbnail: NSImage? = nil) {
        DispatchQueue.main.async {
            self.completionHandlers.forEach { $0(self.url, (image, thumbnail)) }
        }
    }

    override func start() {
        _executing = true

        inFlightTask = session.downloadTask(with: url) { [weak self] fileURL, response, error in
            guard let self = self else { return }

            guard !self.isCancelled else {
                self._executing = false
                self._finished = true
                return
            }

            guard let fileURL = fileURL, let httpResponse = response as? HTTPURLResponse, error == nil else {
                self.callCompletionHandlers()
                self._executing = false
                self._finished = true
                return
            }

            guard httpResponse.statusCode == 200 else {
                self.callCompletionHandlers()
                self._executing = false
                self._finished = true
                return
            }

            guard !self.isCancelled else {
                self._executing = false
                self._finished = true
                return
            }

            self.cacheProvider.cacheImage(for: self.url, original: fileURL, thumbnailHeight: self.thumbnailHeight) { [weak self] result in
                guard let self = self else { return }

                guard let result = result else {
                    self.callCompletionHandlers()
                    self._executing = false
                    self._finished = true
                    return
                }

                self.callCompletionHandlers(with: result.original, thumbnail: result.thumbnail)

                self._executing = false
                self._finished = true
            }
        }
        inFlightTask?.resume()
    }

}

fileprivate extension URL {
    var imageCacheKey: String {
        var components = pathComponents
        components.removeFirst()
        return components.joined(separator: "-")
    }

    var thumbCacheKey: String {
        "thumb-" + imageCacheKey
    }
}

extension NSImage {

    func resized(to maxHeight: CGFloat) -> NSImage {
        let scaleFactor = maxHeight / size.height
        let newWidth = size.width * scaleFactor
        let newHeight = size.height * scaleFactor

        let resizedImage = NSImage(size: NSSize(width: newWidth, height: newHeight))

        resizedImage.lockFocus()
        draw(in: NSRect(x: 0, y: 0, width: newWidth, height: newHeight))
        resizedImage.unlockFocus()

        return resizedImage
    }

    var pngRepresentation: Data? {
        guard let rawImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            assertionFailure("This shouldn't fail")
            return nil
        }

        let newRep = NSBitmapImageRep(cgImage: rawImage)

        return newRep.representation(using: .png, properties: [:])
    }

}
