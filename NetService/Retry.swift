//
//  Retry.swift
//  NetService
//
//  Created by steven on 2021/1/7.
//

import Foundation


public typealias RequestRetryCompletion = (_ shouldRetry: Bool, _ timeDelay: TimeInterval) -> Void

public protocol Retryable {
    var retryCount: Int { get set }
    mutating func prepareRetry() -> Void
    mutating func resetRetry() -> Void
}

public protocol RetryPolicyProtocol {
    
    var retryCount: Int { get }
    
    var timeDelay: TimeInterval { get set }
    
    func retry(_ request: Retryable, with error: Error, completion: RequestRetryCompletion)
}

public struct DefaultRetryPolicy: RetryPolicyProtocol {
    
    public var retryCount: Int {
        return 3
    }
    
    public var timeDelay: TimeInterval = 0.0
    
    public func retry(_ request: Retryable, with error: Error, completion: RequestRetryCompletion) {
        var service = request
        service.prepareRetry()
        if request.retryCount < retryCount {
            completion(true, timeDelay)
        } else {
            completion(false, timeDelay)
            service.resetRetry()
        }
    }
}
