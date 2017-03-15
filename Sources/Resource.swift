//
//  Resource.swift
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

import Foundation


/// `Resource` protocol defines how to download and cache a resource from network.
public protocol Resource {
    /// The key used in cache.
    var cacheKey: String { get }
    
    /// The target image URL.
    var location: String { get }
    
    var fileURL:URL? { get }
    
    var isNamedResource:Bool { get }
}

public extension Resource {
    var fileURL:URL? {
        if location.hasPrefix("file://") {
            return URL(string:location)
        }
        
        if location.hasPrefix("/") {
            return URL(fileURLWithPath: location)
        }
        
        return nil
    }
    
    var httpURL:URL? {
        if location.hasPrefix("http://") {
            return URL(string:location)
        }
        return nil
    }
    
    var isNamedResource:Bool {
        return isFileResource == false && isHttpResource == false
    }
    
    var isFileResource:Bool {
        return location.hasPrefix("file://") || location.hasPrefix("/")
    }
    
    var isHttpResource:Bool {
        return location.hasPrefix("http://") || location.hasPrefix("https://")
    }
}

/**
 ImageResource is a simple combination of `downloadURL` and `cacheKey`.
 
 When passed to image view set methods, Kingfisher will try to download the target 
 image from the `downloadURL`, and then store it with the `cacheKey` as the key in cache.
 */
public struct ImageResource: Resource {
    /// The key used in cache.
    public let cacheKey: String
    
    /// The target image URL.
    public let location: String
    
    /**
     Create a resource.
     
     - parameter downloadURL: The target image URL.
     - parameter cacheKey:    The cache key. If `nil`, Kingfisher will use the `absoluteString` of `downloadURL` as the key.
     
     - returns: A resource.
     */
    public init(_ location: String, cacheKey: String? = nil) {
        self.location = location
        self.cacheKey = cacheKey ?? location
    }
}

/**
 URL conforms to `Resource` in Kingfisher.
 The `absoluteString` of this URL is used as `cacheKey`. And the URL itself will be used as `downloadURL`.
 If you need customize the url and/or cache key, use `ImageResource` instead.
 */
extension URL: Resource {
    public var cacheKey: String { return absoluteString }
    public var location: String { return self.absoluteString }
}
