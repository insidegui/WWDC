//
//  ImageDownloadOperation.swift
//  JPEG Core
//
//  Created by Guilherme Rambo on 09/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift
import os.log

typealias ImageDownloadCompletionBlock = (_ sourceURL: URL, _ image: NSImage?) -> Void

private struct ImageDownload {
    static let subsystemName = "io.WWDC.app.imageDownload"
}

final class ImageDownloadCenter {

    static let shared: ImageDownloadCenter = ImageDownloadCenter()

    private let cacheProvider = ImageCacheProvider()
    private let queue = OperationQueue()
    private let log = OSLog(subsystem: ImageDownload.subsystemName, category: "ImageDownloadCenter")

    func downloadImage(from url: URL, thumbnailHeight: CGFloat, thumbnailOnly: Bool = false, completion: @escaping ImageDownloadCompletionBlock) -> Operation? {
        if let cachedImage = cacheProvider.cachedImage(for: url) {
            completion(url, cachedImage)

            return nil
        }

        guard !hasActiveOperation(for: url) else {
            os_log("Unhandled case: A valid download operation already exists for the URL %{public}@",
                   log: self.log,
                   type: .error,
                   url.absoluteString)

            return nil
        }

        let operation = ImageDownloadOperation(url: url, cache: cacheProvider, thumbnailHeight: thumbnailHeight)
        operation.imageCompletionHandler = completion

        queue.addOperation(operation)

        return operation
    }

    func hasActiveOperation(for url: URL) -> Bool {
        return queue.operations.contains { op in
            guard let op = op as? ImageDownloadOperation else { return false }

            return op.url == url && op.isExecuting && !op.isCancelled
        }
    }

}

final class ImageCacheEntity: Object {

    @objc dynamic var key: String = ""
    @objc dynamic var createdAt: Date = Date()
    @objc dynamic var original: Data = Data()
    @objc dynamic var thumbnail: Data = Data()

    override class func primaryKey() -> String {
        return "key"
    }

}

private final class ImageCacheProvider {

    private lazy var inMemoryCache: NSCache<NSString, NSImage> = {
        let c = NSCache<NSString, NSImage>()

        c.countLimit = 100

        return c
    }()

    private let upperLimit = 16 * 1024 * 1024
    private let log = OSLog(subsystem: ImageDownload.subsystemName, category: "ImageCacheProvider")

    private let storageQueue = DispatchQueue(label: "ImageStorage", qos: .utility)

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

    func cacheImage(for sourceURL: URL, original: URL?, completion: @escaping (NSImage?) -> Void) {
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

                image.cacheMode = .never

                self.inMemoryCache.setObject(image, forKey: url.imageCacheKey as NSString)

                completion(image)
            } catch {
                os_log("Image storage failed: %{public}@", log: self.log, type: .error, String(describing: error))

                completion(nil)
            }
        }
    }

    func cachedImage(for sourceURL: URL) -> NSImage? {
        let memoryKey = sourceURL.imageCacheKey as NSString

        if let fastImage = inMemoryCache.object(forKey: memoryKey) {
            return fastImage
        }

        let cacheURL = self.cacheFileURL(for: sourceURL)

        if fileManager.fileExists(atPath: cacheURL.path), let image = NSImage(contentsOf: cacheURL) {
            inMemoryCache.setObject(image, forKey: memoryKey)
            return image
        } else {
            return nil
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
                DispatchQueue.main.async { self.imageCompletionHandler?(self.url, nil) }
                self._executing = false
                self._finished = true
                return
            }

            guard httpResponse.statusCode == 200 else {
                DispatchQueue.main.async { self.imageCompletionHandler?(self.url, nil) }
                self._executing = false
                self._finished = true
                return
            }

            guard !self.isCancelled else {
                self._executing = false
                self._finished = true
                return
            }

            self.cacheProvider.cacheImage(for: self.url, original: fileURL) { [weak self] image in
                guard let self = self else { return }

                guard let image = image else {
                    DispatchQueue.main.async { self.imageCompletionHandler?(self.url, nil) }
                    self._executing = false
                    self._finished = true
                    return
                }

                DispatchQueue.main.async {
                    self.imageCompletionHandler?(self.url, image)
                }

                self._executing = false
                self._finished = true
            }
        }
        inFlightTask?.resume()
    }

}

fileprivate extension URL {
    var imageCacheKey: String {
        pathComponents.joined(separator: "-")
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

}
