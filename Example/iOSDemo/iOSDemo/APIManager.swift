//
//  APIManager.swift
//  iOSDemo
//
//  Created by steven on 2021/2/4.
//

import Foundation
import NetService

class BaseAPIManager: DataNetService, NetServiceRequestProtocol {
    var urlString: String {
        return ""
    }
    
    var httpMethod: NetServiceBuilder.Method {
        return .GET
    }
    
    var timeout: TimeInterval {
        30
    }
    
    var authorization: NetServiceBuilder.Authorization {
        return .none
    }
    
    var encoding: ParameterEncoding {
        return URLEncoding.default
    }
    
    var credential: URLCredential? {
        return nil
    }
    
    func httpHeaders() -> [String : String] {
        [:]
    }
    
    func httpParameters() -> [String : Any] {
        [:]
    }
    
    func httpBuilderHelper(builder: NetServiceBuilder) -> NetServiceBuilder {
        return builder
    }
    
    
}

class BaseUploadManager: UploadNetService, NetServiceRequestProtocol {
    func httpBuilderHelper(builder: NetServiceBuilder) -> NetServiceBuilder {
        return builder
    }
    
    var urlString: String {
        return ""
    }
    
    var httpMethod: NetServiceBuilder.Method {
        return .GET
    }
    
    var timeout: TimeInterval {
        30
    }
    
    var authorization: NetServiceBuilder.Authorization {
        return .none
    }
    
    var encoding: ParameterEncoding {
        return URLEncoding.default
    }
    
    var credential: URLCredential? {
        return nil
    }
    
    func httpHeaders() -> [String : String] {
        [:]
    }
    
    func httpParameters() -> [String : Any] {
        [:]
    }
    
    
}

class BaseDownloadManager: DownloadNetService, NetServiceRequestProtocol {
    var urlString: String {
        return ""
    }
    
    var httpMethod: NetServiceBuilder.Method {
        return .GET
    }
    
    var timeout: TimeInterval {
        30
    }
    
    var authorization: NetServiceBuilder.Authorization {
        return .none
    }
    
    var encoding: ParameterEncoding {
        return URLEncoding.default
    }
    
    var credential: URLCredential? {
        return nil
    }
    
    func httpHeaders() -> [String : String] {
        [:]
    }
    
    func httpParameters() -> [String : Any] {
        [:]
    }
    
    func httpBuilderHelper(builder: NetServiceBuilder) -> NetServiceBuilder {
        return builder
    }
    
    
}


class TestMiddleware: Middleware {
    
    func afterReceive<Response>(_ result: Response) -> Response where Response : Responseable {
        print(result.response)
        return result
    }
    
    
    func prepare(_ builder: NetServiceBuilder) -> NetServiceBuilder {
        return builder
    }
    func beforeSend<TaskType>(_ request: TaskType) where TaskType : NetServiceProtocol {
        
    }
    
    func didStop<TaskType>(_ request: TaskType) where TaskType : NetServiceProtocol {
        
    }
}

struct TestRetryPolicy: RetryPolicyProtocol {
    
    public var retryCount: Int {
        return 3
    }
    
    public var timeDelay: TimeInterval = 0.0
    
    public func retry(_ request: Retryable, with error: Error, completion: RequestRetryCompletion) {
        var service = request
        if request.retryCount < retryCount {
            completion(true, timeDelay)
            service.prepareRetry()
        } else {
            completion(false, timeDelay)
            service.resetRetry()
        }
    }
}
