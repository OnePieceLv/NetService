//
//  RequestTests.swift
//  Merlin-iOSTests
//
//  Created by steven on 2021/1/5.
//

import XCTest
@testable import NetService

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
            print(String(data: request.response!.data!, encoding: .utf8))
            exception.fulfill()
        }
        waitForExpectations(timeout: timeout, handler: nil)
        XCTAssertNotNil(response)
        print(response?.error)
        XCTAssertNotNil(response?.result.success)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
//        XCTAssertTrue(response!.result.isFailure)
    }
    
    func testSync() throws {
        let api = TestAPI()
        let res = api.sync(transform: DefaultJSONTransform())

        XCTAssertNotNil(res.response)
        print("-------testSync-----")
        print(res.response)
        print("-------testSync-----")
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
