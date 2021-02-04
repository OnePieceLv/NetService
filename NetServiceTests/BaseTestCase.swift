//
//  BaseTestCase.swift
//  Merlin-iOSTests
//
//  Created by steven on 2021/1/5.
//

import XCTest
@testable import NetService

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
    var urlString: String {
        return ""
    }
    
    var httpMethod: NetServiceBuilder.Method {
        return .POST
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

class BaseTestCase: XCTestCase {
    let timeout: TimeInterval = 10
    
    
    override func setUp() {
            super.setUp()
    }
}
