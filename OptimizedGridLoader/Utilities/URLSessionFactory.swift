//
//  URLSessionFactory.swift
//  OptimizedGridLoader
//
//  Created by Coder ACJHP on 23.03.2026.
//

import Foundation

enum URLSessionFactory {
    nonisolated static func make() -> URLSession {
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 12
        config.timeoutIntervalForRequest = 15.0
        config.urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 100 * 1024 * 1024,
            diskPath: "apiResultCache"
        )
        config.allowsCellularAccess = true
        config.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: config)
    }
}
