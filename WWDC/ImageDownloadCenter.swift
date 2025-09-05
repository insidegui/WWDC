//
//  ImageDownloadOperation.swift
//  JPEG Core
//
//  Created by Guilherme Rambo on 09/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore
import ConcurrencyExtras

typealias ImageDownloadCompletionBlock = @Sendable @MainActor (ImageDownloadResult) -> Void
private let isLogVerbose = false

struct ImageDownloadResult {
    var sourceURL: URL
    var original: NSImage?
    var thumbnail: NSImage?
}

private struct ImageDownload {
    static let subsystemName = "io.WWDC.app.imageDownload"
}

/// Singleton coordinator for concurrent image downloads with caching and request deduplication via Operation dependencies.
///
/// Critical to the implementation is that an ImageRetrievalOperation is responsible for both cache retrieval and downloading (if necessary).
///
/// ```
/// Request(URL)
///      │
///      ▼
/// ┌─────────────┐
/// │ Active Op?  │──Yes──→ Chain as Dependency ──→ Reuse Result
/// └─────────────┘
///      │ No
///      ▼
/// ┌─────────────┐
/// │ Memory Cache│──Hit───→ Return Cached
/// └─────────────┘
///      │ Miss
///      ▼
/// ┌─────────────┐
/// │ Disk Cache  │──Hit───→ Load + Store in Memory ──→ Return
/// └─────────────┘
///      │ Miss
///      ▼
/// ┌─────────────┐
/// │   Network   │──────→ Download + Store All Caches ──→ Return
/// └─────────────┘
/// ```
final class ImageDownloadCenter: Logging, Sendable {

    static let shared: ImageDownloadCenter = ImageDownloadCenter()

    private let cache = ImageCacheProvider()

    static let log = makeLogger(subsystem: ImageDownload.subsystemName, category: "ImageDownloadCenter")

    private let dispatchQueue: DispatchQueue
    private let queue: LockIsolated<OperationQueue>

    init() {
        let dispatchQueue = DispatchQueue(label: "ImageDownloadCenter", qos: .userInteractive, attributes: .concurrent)
        let queue: OperationQueue = OperationQueue()
        queue.underlyingQueue = dispatchQueue

        self.dispatchQueue = dispatchQueue
        self.queue = LockIsolated(queue)
    }

    func cachedThumbnail(from url: URL) -> NSImage? { cache.cachedImage(for: url, thumbnailOnly: true).thumbnail }

    /// The completion handler is always called on the main thread if it's downloaded, but it's called on the callers thread if it comes from the cache
    /// Cache retrieval happens synchronously, so the completion handler is called immediately if the image is cached. But that means you're hitting
    /// the file system on the main thread.
    @discardableResult
    func downloadImage(from url: URL, thumbnailHeight: CGFloat, thumbnailOnly: Bool = false, completion: @escaping ImageDownloadCompletionBlock) -> Operation {
        let fastCache = cache.memoryCachedImage(for: url, thumbnailOnly: thumbnailOnly)

        // Provide an in-memory fast path for responsiveness

        if fastCache.thumbnail != nil && (thumbnailOnly || fastCache.original != nil) {
            if isLogVerbose {
                log.trace("Fast cache hit for \(url.absoluteString)")
            }

            DispatchQueue.main.async {
                completion(ImageDownloadResult(sourceURL: url, original: fastCache.original, thumbnail: fastCache.thumbnail))
            }

            let operation = BlockOperation {}
            operation.cancel()
            return operation
        }

        // Slow cache (disk) or network retrieval

        return queue.withValue {
            let operation = retrievalOperation(for: url, thumbnailHeight: thumbnailHeight, thumbnailOnly: thumbnailOnly, completion: completion)
            $0.addOperation(operation)
            return operation
        }
    }

    private func retrievalOperation(for url: URL, thumbnailHeight: CGFloat, thumbnailOnly: Bool, completion: @escaping ImageDownloadCompletionBlock) -> Operation {
        if let pendingOperation = activeOperation(for: url) {
            let operation = ImageRetrievalOperation(url: url, cache: cache, cacheArguments: .init(thumbnailHeight: thumbnailHeight, thumbnailOnly: thumbnailOnly), completion: completion)

            operation.addDependency(pendingOperation)
            pendingOperation.queuePriority = .veryHigh

            if isLogVerbose {
                log.trace("Enqueuing image retrieval operation \(operation) dependent on \(pendingOperation)")
            }

            return operation
        }

        let operation = ImageRetrievalOperation(url: url, cache: cache, cacheArguments: .init(thumbnailHeight: thumbnailHeight, thumbnailOnly: thumbnailOnly), completion: completion)

        if isLogVerbose {
            log.trace("Enqueuing image retrieval operation \(operation)")
        }

        return operation
    }

    fileprivate func activeOperation(for url: URL) -> ImageRetrievalOperation? {
        queue.withValue {
            $0.operations.compactMap({ $0 as? ImageRetrievalOperation }).first { op -> Bool in
                op.url == url && !op.isFinished && !op.isCancelled && op.dependencies.isEmpty
            }
        }
    }

    private var deletedLegacyImageCache: Bool {
        get { UserDefaults.standard.bool(forKey: #function) }
        set { UserDefaults.standard.set(newValue, forKey: #function) }
    }

    func deleteLegacyImageCacheIfNeeded() {
        guard !deletedLegacyImageCache else { return }
        deletedLegacyImageCache = true

        log.debug("\(#function, privacy: .public)")

        let baseURL = URL(fileURLWithPath: PathUtil.appSupportPathAssumingExisting)
        let realmURL = baseURL.appendingPathComponent("ImageCache.realm")
        let lockURL = realmURL.appendingPathExtension("lock")
        let managementURL = realmURL.appendingPathExtension("management")

        do {
            try FileManager.default.removeItem(at: realmURL)
            try FileManager.default.removeItem(at: lockURL)
            try FileManager.default.removeItem(at: managementURL)
        } catch {
            log.error("Failed to delete legacy image cache: \(String(describing: error), privacy: .public)")
        }
    }

}

extension ImageDownloadCenter {
    func downloadImage(from url: URL, thumbnailHeight: CGFloat, thumbnailOnly: Bool = false) async -> ImageDownloadResult {
        let fastCache = cache.memoryCachedImage(for: url, thumbnailOnly: thumbnailOnly)

        // Provide an in-memory fast path for responsiveness

        if fastCache.thumbnail != nil && (thumbnailOnly || fastCache.original != nil) {
            if isLogVerbose {
                log.trace("Fast cache hit for \(url.absoluteString)")
            }
            return ImageDownloadResult(sourceURL: url, original: fastCache.original, thumbnail: fastCache.thumbnail)
        }

        // Slow cache (disk) or network retrieval

        let lockIsolatedContinuation = LockIsolated<CheckedContinuation<ImageDownloadResult, Never>?>(nil)
        let lockIsolatedOperation = LockIsolated<Operation?>(nil)

        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<ImageDownloadResult, Never>) in
                // The onCancel cannot be invoked during withValue
                lockIsolatedContinuation.withValue {
                    // The task itself may already be cancelled
                    if Task.isCancelled {
                        continuation.resume(returning: ImageDownloadResult(sourceURL: url, original: nil, thumbnail: nil))
                        return
                    } else {
                        // Enqueue the operation and store the continuation atomically
                        $0 = continuation
                        queue.withValue {
                            let operation = retrievalOperation(for: url, thumbnailHeight: thumbnailHeight, thumbnailOnly: thumbnailOnly) { result in
                                lockIsolatedContinuation.withValue {
                                    // Guard against incorrect callback contract issues, only resume once!
                                    guard let continuation = $0 else { return }
                                    $0 = nil
                                    continuation.resume(returning: result)
                                }
                            }
                            lockIsolatedOperation.setValue(operation)
                            $0.addOperation(operation)
                        }
                    }
                }
            }
        } onCancel: {
            lockIsolatedContinuation.withValue {
                guard $0 != nil else {
                    // if we don't have a continuation, it means the operation was never enqueued
                    return
                }

                // Forward Task cancellation to the Operation.
                lockIsolatedOperation.value?.cancel()
            }
        }
    }
}

/// Sendable box for NSCache & NSImage behavior
struct InMemoryImageCache: Sendable {
    private let inMemoryCache: LockIsolated<NSCache<NSString, NSImage>>

    init(countLimit: Int) {
        self.inMemoryCache = LockIsolated(NSCache(countLimit: countLimit))
    }

    subscript(key: String) -> NSImage? {
        get {
            let thumbnailImage: NSImageBox? = inMemoryCache.withValue {
                guard let image = $0.object(forKey: key as NSString) else { return nil }
                return NSImageBox(image: image)
            }

            return thumbnailImage?.image
        }
        nonmutating set {
            guard let newValue else {
                inMemoryCache.withValue { $0.removeObject(forKey: key as NSString) }
                return
            }

            inMemoryCache.withValue { $0.setObject(newValue, forKey: key as NSString) }
        }
    }

    struct NSImageBox: @unchecked Sendable {
        let image: NSImage
    }
}

/// Regarding the sendability of NSImage: https://forums.swift.org/t/sending-a-sendable-but-non-sendable-type/69318
///
/// For the purposes of caching, we have to be careful to follow the rules with NSImage's thread safety.
final class ImageCacheProvider: Sendable, Logging {
    static let log = makeLogger(subsystem: ImageDownload.subsystemName, category: "ImageCacheProvider")
    private let storageQueue = DispatchQueue(label: "ImageStorage", qos: .userInitiated, attributes: .concurrent)
    private let fileManager = LockIsolated(FileManager())

    private let inMemoryCache = InMemoryImageCache(countLimit: 100)
    private let cacheURL: URL

    init() {
        let url = URL(fileURLWithPath: PathUtil.appSupportPathAssumingExisting).appendingPathComponent("ImageCache")

        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            } catch {
                Self.log.error("Failed to create image cache directory: \(String(describing: error), privacy: .public)")
            }
        }
        self.cacheURL = url
    }

    private func cacheFileURL(for sourceURL: URL) -> URL { self.cacheURL.appendingPathComponent(sourceURL.imageCacheKey) }
    private func thumbnailCacheFileURL(for sourceURL: URL) -> URL { self.cacheURL.appendingPathComponent(sourceURL.thumbCacheKey) }

    func cacheImage(for sourceURL: URL, original: URL?, thumbnailHeight: CGFloat? = nil, completion: @escaping ((original: NSImage, thumbnail: NSImage)?) -> Void) {
        guard let original = original else {
            completion(nil)
            return
        }

        storageQueue.async {
            do {
                let url = self.cacheFileURL(for: sourceURL)

                if self.fileManager.withValue({ $0.fileExists(atPath: url.path) }) {
                    try self.fileManager.withValue { try $0.removeItem(at: url) }
                }

                try self.fileManager.withValue { try $0.copyItem(at: original, to: url) }

                guard let image = NSImage(contentsOf: url) else {
                    self.log.error("Failed to initialize image with \(url.path)")
                    completion(nil)
                    return
                }

                let thumbImage: NSImage

                if let thumbnailHeight {
                    let thumb = image.resized(to: thumbnailHeight)
                    guard let thumbData = thumb.pngRepresentation else {
                        self.log.fault("Failed to create thumbnail")
                        completion(nil)
                        return
                    }

                    let thumbURL = self.thumbnailCacheFileURL(for: sourceURL)
                    try thumbData.write(to: thumbURL)

                    image.cacheMode = .never
                    thumb.cacheMode = .never

                    self.inMemoryCache[url.thumbCacheKey] = thumb
                    thumbImage = thumb
                } else {
                    thumbImage = image
                }

                self.inMemoryCache[url.imageCacheKey] = image

                completion((image, thumbImage))
            } catch {
                self.log.error("Image storage failed: \(String(describing: error), privacy: .public)")

                completion(nil)
            }
        }
    }

    /// Returns cached image from disk cache, if available, and stores it in memory cache.
    private func diskCachedImage(for sourceURL: URL, thumbnail: Bool = false) -> NSImage? {
        let url: URL
        let key: String
        if thumbnail {
            url = thumbnailCacheFileURL(for: sourceURL)
            key = sourceURL.thumbCacheKey
        } else {
            url = cacheFileURL(for: sourceURL)
            key = sourceURL.imageCacheKey
        }

        guard fileManager.withValue({ $0.fileExists(atPath: url.path) }), let image = NSImage(contentsOf: url) else { return nil }

        inMemoryCache[key] = image

        return image
    }

    /// Returns cached image from either memory or disk cache, if available.
    func cachedImage(for sourceURL: URL, thumbnailOnly: Bool = false) -> (original: NSImage?, thumbnail: NSImage?) {
        var (original, thumb) = memoryCachedImage(for: sourceURL, thumbnailOnly: thumbnailOnly)

        if thumb == nil {
            thumb = diskCachedImage(for: sourceURL, thumbnail: true)
        }

        if !thumbnailOnly && original == nil {
            original = diskCachedImage(for: sourceURL)
        }

        original?.cacheMode = .never
        thumb?.cacheMode = .never

        return (original, thumb)
    }

    func memoryCachedImage(for sourceURL: URL, thumbnailOnly: Bool = false) -> (original: NSImage?, thumbnail: NSImage?) {
        let originalImageKey = sourceURL.imageCacheKey
        let thumbKey = sourceURL.thumbCacheKey

        var original: NSImage?
        var thumb: NSImage?

        if let thumbnailImage = inMemoryCache[thumbKey] {
            thumb = thumbnailImage
        }

        if !thumbnailOnly {
            if let originalImage = inMemoryCache[originalImageKey] {
                original = originalImage
            }
        }

        original?.cacheMode = .never
        thumb?.cacheMode = .never

        return (original, thumb)
    }

}

private final class ImageRetrievalOperation: Operation, @unchecked Sendable, Logging {
    static let log = makeLogger(subsystem: ImageDownload.subsystemName, category: "ImageRetrievalOperation")

    struct CacheArguments {
        var thumbnailHeight: CGFloat = Constants.thumbnailHeight
        /// When cached, only retrieve the thumbnail
        var thumbnailOnly: Bool = false
    }

    private let completionHandler: ImageDownloadCompletionBlock

    let url: URL
    /// When this is nil, cache retrieval will be bypassed
    let cacheArguments: CacheArguments?

    let cacheProvider: ImageCacheProvider

    init(
        url: URL,
        cache: ImageCacheProvider,
        cacheArguments: CacheArguments? = nil,
        completion: @escaping ImageDownloadCompletionBlock
    ) {
        self.url = url
        self.cacheProvider = cache
        self.cacheArguments = cacheArguments
        self.completionHandler = completion
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

        if !dependencies.isEmpty && isLogVerbose {
            log.trace("Cancelled with dependencies: \(self.dependencies)")
        }

        super.cancel()
    }

    /// It is extremely inadvisable to create 1 session per download operation, so this is a shared session.
    ///
    /// Figuring that out cost a couple of hours. (This used to be lazy var, not static)
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.httpMaximumConnectionsPerHost = 15

        return URLSession(configuration: config)
    }()

    private var inFlightTask: URLSessionDownloadTask?

    private func callCompletionHandlers(with image: NSImage? = nil, thumbnail: NSImage? = nil) {
        if (image != nil || thumbnail != nil) && !self.isCancelled && isLogVerbose {
            log.trace("\(self)\nCompleted retrieval of image at \(self.url.absoluteString)")
        }
        DispatchQueue.main.async {
            self.completionHandler(ImageDownloadResult(sourceURL: self.url, original: image, thumbnail: thumbnail))
        }
    }

    override func start() {
        guard checkCancellation() else { return }

        if isLogVerbose {
            log.trace("\(self)\nBeginning retrieval of image at \(self.url.absoluteString)")
        }

        _executing = true

        if let cachedResult = retrieveFromCache() {
            self.callCompletionHandlers(with: cachedResult.original, thumbnail: cachedResult.thumbnail)
            self._executing = false
            self._finished = true
            return
        }

        guard checkCancellation() else { return }

        if isLogVerbose {
            log.trace("\(self)\nFetching image from source at \(self.url.absoluteString)")
        }

        inFlightTask = Self.session.downloadTask(with: url) { [weak self] fileURL, response, error in
            guard let self = self else { return }
            guard checkCancellation() else { return }

            guard let fileURL = fileURL, let httpResponse = response as? HTTPURLResponse, error == nil else {
                completeWithNoImage()
                return
            }

            guard httpResponse.statusCode == 200 else {
                completeWithNoImage()
                return
            }

            self.cacheProvider.cacheImage(for: self.url, original: fileURL, thumbnailHeight: self.cacheArguments?.thumbnailHeight ?? Constants.thumbnailHeight) { [weak self] result in
                guard let self = self else { return }
                guard checkCancellation() else { return }

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

    func checkCancellation() -> Bool {
        guard !self.isCancelled else {
            self.callCompletionHandlers()
            self._executing = false
            self._finished = true
            return false
        }

        return true
    }

    func completeWithNoImage() {
        self.callCompletionHandlers()
        self._executing = false
        self._finished = true
    }

    func retrieveFromCache() -> (original: NSImage?, thumbnail: NSImage?)? {
        guard let cacheArguments else { return nil }

        if cacheArguments.thumbnailOnly, let thumbnailImage = cacheProvider.cachedImage(for: url, thumbnailOnly: true).thumbnail {
            if isLogVerbose {
                log.trace("\(self)\nRetrieved thumbnail image from cache at \(self.url.absoluteString)")
            }
            return (original: nil, thumbnail: thumbnailImage)
        }

        let cachedResult = cacheProvider.cachedImage(for: url)

        if cachedResult.original != nil && cachedResult.thumbnail != nil {
            if isLogVerbose {
                log.trace("\(self)\nRetrieved image from cache at \(self.url.absoluteString)")
            }
            return cachedResult
        }

        return nil
    }
}

extension ImageRetrievalOperation {
    override var description: String {
        func yesNo(_ value: Bool) -> String { value ? "YES" : "NO" }
        return "<\(String(describing: type(of: self))) \(ObjectIdentifier(self).hexString) isFinished=\(yesNo(isFinished)) isReady=\(yesNo(isReady)) isCancelled=\(yesNo(isCancelled)) isExecuting=\(yesNo(isExecuting)) url=\(url.absoluteString)>"
    }

    override var debugDescription: String { description }
}

fileprivate extension ObjectIdentifier {
    /// Returns a pointer-style hex string, e.g. "0x12a875630"
    var hexString: String {
        let value = UInt(bitPattern: self)
        return "0x" + String(value, radix: 16)
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

extension NSCache {
    @objc convenience init(countLimit: Int) {
        self.init()
        self.countLimit = countLimit
    }
}
