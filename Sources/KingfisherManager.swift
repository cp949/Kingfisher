//
//  KingfisherManager.swift
//  Kingfisher
//
//  Created by Wei Wang on 15/4/6.
//
//  Copyright (c) 2017 Wei Wang <onevcat@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

public typealias DownloadProgressBlock = ((_ receivedSize: Int64, _ totalSize: Int64) -> ())
public typealias CompletionHandler = ((_ image: Image?, _ error: NSError?, _ cacheType: CacheType, _ imageLocation: String?) -> ())

/// RetrieveImageTask represents a task of image retrieving process.
/// It contains an async task of getting image from disk and from network.
public class RetrieveImageTask {
    
    public static let empty = RetrieveImageTask()
    
    // If task is canceled before the download task started (which means the `downloadTask` is nil),
    // the download task should not begin.
    var cancelledBeforeDownloadStarting: Bool = false
    
    /// The network retrieve task in this image task.
    public var downloadTask: RetrieveImageDownloadTask?
    
    /**
     Cancel current task. If this task is already done, do nothing.
     */
    public func cancel() {
        if let downloadTask = downloadTask {
            downloadTask.cancel()
        } else {
            cancelledBeforeDownloadStarting = true
        }
    }
}

/// Error domain of Kingfisher
public let KingfisherErrorDomain = "com.onevcat.Kingfisher.Error"

/// Main manager class of Kingfisher. It connects Kingfisher downloader and cache.
/// You can use this class to retrieve an image via a specified URL from web or cache.
public class KingfisherManager {
    
    /// Shared manager used by the extensions across Kingfisher.
    public static let shared = KingfisherManager()
    
    /// Cache used by this manager
    public var cache: ImageCache
    
    /// Downloader used by this manager
    public var downloader: ImageDownloader
    
    convenience init() {
        self.init(downloader: .default, cache: .default)
    }
    
    init(downloader: ImageDownloader, cache: ImageCache) {
        self.downloader = downloader
        self.cache = cache
    }
    
    /**
     Get an image with resource.
     If KingfisherOptions.None is used as `options`, Kingfisher will seek the image in memory and disk first.
     If not found, it will download the image at `resource.downloadURL` and cache it with `resource.cacheKey`.
     These default behaviors could be adjusted by passing different options. See `KingfisherOptions` for more.
     
     - parameter resource:          Resource object contains information such as `cacheKey` and `downloadURL`.
     - parameter options:           A dictionary could control some behaviors. See `KingfisherOptionsInfo` for more.
     - parameter progressBlock:     Called every time downloaded data changed. This could be used as a progress UI.
     - parameter completionHandler: Called when the whole retrieving process finished.
     
     - returns: A `RetrieveImageTask` task object. You can use this object to cancel the task.
     */
    @discardableResult
    public func retrieveImage(with resource: Resource,
                              options: KingfisherOptionsInfo?,
                              progressBlock: DownloadProgressBlock?,
                              completionHandler: CompletionHandler?) -> RetrieveImageTask
    {
        let task = RetrieveImageTask()
        
        if let options = options, options.forceRefresh && resource.isHttpResource
        {
            _ = downloadAndCacheImage(
                forResource: resource,
                retrieveImageTask: task,
                progressBlock: progressBlock,
                completionHandler: completionHandler,
                options: options)
        } else {
            tryToRetrieveImageFromCache(
                forResource: resource,
                with: resource.location,
                retrieveImageTask: task,
                progressBlock: progressBlock,
                completionHandler: completionHandler,
                options: options)
        }
        
        return task
    }
    
    
    @discardableResult
    func downloadAndCacheImage(forResource resource:Resource,
                               retrieveImageTask: RetrieveImageTask,
                               progressBlock: DownloadProgressBlock?,
                               completionHandler: CompletionHandler?,
                               options: KingfisherOptionsInfo?) -> RetrieveImageDownloadTask?
    {
        if resource.isHttpResource == false {
            tryToRetrieveImageFromCache(
                forResource: resource,
                with: resource.location,
                retrieveImageTask: RetrieveImageTask(),
                progressBlock: progressBlock,
                completionHandler: completionHandler,
                options: options)
            return nil
        }
        
        let options = options ?? KingfisherEmptyOptionsInfo
        let downloader = options.downloader
        return downloader.downloadImage(with: resource.httpURL!, retrieveImageTask: retrieveImageTask, options: options,
                                        progressBlock: { receivedSize, totalSize in
                                            progressBlock?(receivedSize, totalSize)
        },
                                        completionHandler: { image, error, imageURL, originalData in
                                            
                                            let targetCache = options.targetCache
                                            if let error = error, error.code == KingfisherError.notModified.rawValue {
                                                // Not modified. Try to find the image from cache.
                                                // (The image should be in cache. It should be guaranteed by the framework users.)
                                                targetCache.retrieveImage(forResource: resource, options: options, completionHandler: { (cacheImage, cacheType) -> () in
                                                    completionHandler?(cacheImage, nil, cacheType, resource.location)
                                                })
                                                return
                                            }
                                            
                                            if let image = image, let originalData = originalData {
                                                targetCache.store(image,
                                                                  original: originalData,
                                                                  forKey: resource.cacheKey,
                                                                  processorIdentifier:options.processor.identifier,
                                                                  cacheSerializer: options.cacheSerializer,
                                                                  toDisk: !options.cacheMemoryOnly,
                                                                  completionHandler: nil)
                                            }
                                            
                                            completionHandler?(image, error, .none, resource.location)
                                            
        })
    }
    
    
    func tryToRetrieveImageFromCache(forResource resource: Resource,
                                     with location: String,
                                     retrieveImageTask: RetrieveImageTask,
                                     progressBlock: DownloadProgressBlock?,
                                     completionHandler: CompletionHandler?,
                                     options: KingfisherOptionsInfo?)
    {
        let diskTaskCompletionHandler: CompletionHandler = { (image, error, cacheType, imageLocation) -> () in
            completionHandler?(image, error, cacheType, imageLocation)
        }
        
        let targetCache = options?.targetCache ?? cache
        targetCache.retrieveImage(forResource: resource, options: options,
                                  completionHandler: { image, cacheType in
                                    if image != nil {
                                        diskTaskCompletionHandler(image, nil, cacheType, location)
                                        return
                                    } else if let options = options, options.onlyFromCache {
                                        let error = NSError(domain: KingfisherErrorDomain, code: KingfisherError.notCached.rawValue, userInfo: nil)
                                        diskTaskCompletionHandler(nil, error, .none, location)
                                        return
                                    }
                                    
                                    if resource.isHttpResource == false {
                                        let error = NSError(domain: KingfisherErrorDomain, code: KingfisherError.notCached.rawValue, userInfo: nil)
                                        diskTaskCompletionHandler(nil, error, .none, location)
                                        return
                                    }
                                    
                                    self.downloadAndCacheImage(
                                        forResource:  resource,
                                        retrieveImageTask: retrieveImageTask,
                                        progressBlock: progressBlock,
                                        completionHandler: diskTaskCompletionHandler,
                                        options: options)
                                    
        }
        )
    }
}
