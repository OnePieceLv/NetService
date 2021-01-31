//
//  RequestTests.swift
//  Merlin-iOSTests
//
//  Created by steven on 2021/1/5.
//

import XCTest
@testable import NetService

final class TestAPI: BaseDataService, NetServiceProtocol {
    var parameters: [String : Any] = [:]
    
    var headers: [String : String] = [:]
    
    var urlString: String {
        return "https://httpbin.org/get"
        
    }
}

class BaseDataServiceTests: BaseTestCase {
    

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testAsync() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let api = TestAPI()
        var response: DataResponse?
        let exception = self.expectation(description: "\(api.urlString)")
        api.async { (request) in
            response = request.response
            exception.fulfill()
        }
        waitForExpectations(timeout: timeout, handler: nil)
        XCTAssertNotNil(response)
        if let response = response, let responseString = response.responseString {
            print(responseString)
        }
        XCTAssertNotNil(response?.result.success)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.responseString)
//        XCTAssertTrue(response!.result.isFailure)
    }
    
    func testSync() throws {
        let api = TestAPI()
        let res = api.sync()

        XCTAssertNotNil(res.response)
        XCTAssertEqual(res.response?.statusCode, 200)
        XCTAssertNotNil(res.response?.responseString, "response string must be not nil")
        if let response = res.response, let responseString = response.responseString {
            print(responseString)
        }
        
    }
    
    func testPublished() throws {
        let api = TestAPI()
        let request = URLRequest(url: URL.init(string: "\(api.urlString)")!)
        let exception = self.expectation(description: "test \(api.urlString)")
        var responseString: String? = nil
        let dataTask: URLSessionDataTask = URLSession(configuration: .default).dataTask(with: request) { (data, response, error) in
            responseString = String(data: data!, encoding: .utf8)
            print(responseString ?? "null string")
            exception.fulfill()
        }
        dataTask.resume()
        waitForExpectations(timeout: 10, handler: nil)
        XCTAssertTrue(true)
    }

//    func testPerformanceExample() throws {
//        // This is an example of a performance test case.
//        self.measure {
//            // Put the code you want to measure the time of here.
//        }
//    }

}
