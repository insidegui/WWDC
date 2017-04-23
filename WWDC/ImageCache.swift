//
//  ImageCache.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class ImageCache {
    
    static let shared: ImageCache = ImageCache()
    
    private lazy var cacheBasePath: String = {
        let path = PathUtil.appSupportPath + "/ImageCache"
        
        if !FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            } catch  {
                print("Error creating cache directory: \(error)")
            }
        }
        
        return path
    }()
    
    private func cachePath(for url: URL) -> String {
        let filename = url.path.replacingOccurrences(of: "/", with: "-") + "-" + url.lastPathComponent
        
        return cacheBasePath + "/" + filename
    }
    
    func fetchImage(at url: URL, completion: @escaping (URL, NSImage?) -> Void) {
        let imageCachePath = cachePath(for: url)
        
        if FileManager.default.fileExists(atPath: imageCachePath) {
            if let image = NSImage(contentsOfFile: imageCachePath) {
                completion(url, image)
                return
            }
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard error == nil, let data = data else { return }
            guard let image = NSImage(data: data) else { return }
            
            do {
                try data.write(to: URL(fileURLWithPath: imageCachePath), options: .atomicWrite)
            } catch {
                print("Error writing image data to cache path \(imageCachePath): \(error)")
            }
            
            DispatchQueue.main.async {
                completion(url, image)
            }
        }.resume()
    }
    
}
