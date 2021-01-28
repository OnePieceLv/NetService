//
//  BaseTestCase.swift
//  Merlin-iOSTests
//
//  Created by steven on 2021/1/5.
//

import XCTest
@testable import NetService

class BaseTestCase: XCTestCase {
    let timeout: TimeInterval = 10
    
    final class TestAPI: BaseDataService, NetServiceProtocol {
        var parameters: [String : Any] = [:]
        
        var headers: [String : String] = [:]
        
        var urlString: String {
            return "https://httpbin.org/get"
            
        }
    }
    override func setUp() {
            super.setUp()
    }
}
