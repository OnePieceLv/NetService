//
//  UploadTests.swift
//  Merlin-iOSTests
//
//  Created by steven on 2021/1/28.
//

import XCTest
@testable import NetService

class UploadTests: BaseTestCase {
    
    class UploadAPI: BaseUploadService, NetServiceProtocol {
        var parameters: [String : Any] = [:]
        
        var headers: [String : String] = [:]
        
        var urlString: String {
            return "https://httpbin.org/post"
        }
        
        var httpMethod: NetBuilders.Method {
            return .POST
        }
        
        
        
    }

    func testUploadMethodWithMethodURLAndFile() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let bundle = Bundle(for: BaseTestCase.self)
        let imageURL = bundle.url(forResource: "rainbow", withExtension: "jpg")!
        let expection = self.expectation(description: "upload api expectation")
        var res: DataResponse?
        UploadAPI().upload(with: imageURL) { (progress: Progress) in
            print(progress.fractionCompleted)
            print(progress.completedUnitCount)
        } completion: { (request) in
            res = request.response
            print(String(data: res!.data!, encoding: .utf8)!)
            expection.fulfill()
        }
        
        waitForExpectations(timeout: timeout, handler: nil)
        XCTAssertTrue(res!.statusCode == 200)

    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
