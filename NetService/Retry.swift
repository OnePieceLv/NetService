//
//  Retry.swift
//  NetService
//
//  Created by steven on 2021/1/7.
//

import Foundation


typealias RequestRetryCompletion = (_ shouldRetry: Bool, _ timeDelay: TimeInterval) -> Void

protocol Retryable {
    var retryCount: Int { get set }
    func prepareRetry() -> Void
    func resetRetry() -> Void
}

protocol RetryPolicyProtocol {
    
    var retryCount: Int { get }
    
    var timeDelay: TimeInterval { get set }
    
    func retry(_ request: Retryable, with error: Error, completion: RequestRetryCompletion)
}

struct DefaultRetryPolicy: RetryPolicyProtocol {
    
    var retryCount: Int {
        return 3
    }
    
    var timeDelay: TimeInterval = 0.0
    
    func retry(_ request: Retryable, with error: Error, completion: RequestRetryCompletion) {
        if request.retryCount < retryCount {
            completion(true, timeDelay)
        } else {
            completion(false, timeDelay)
        }
    }
}
