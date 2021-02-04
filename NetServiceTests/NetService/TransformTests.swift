//
//  TransformTests.swift
//  NetService
//
//  Created by steven on 2021/2/1.
//

import XCTest
@testable import NetService

final class JSONAPI: BaseAPIManager {
    
    private var _urlStr: String = "https://httpbin.org/json"
    
    override var urlString: String {
        return _urlStr
    }
    
    override func httpBuilderHelper(builder: NetServiceBuilder?) -> NetServiceBuilder {
        var customBuilder = builder ?? NetServiceBuilder()
        customBuilder.contentType = NetServiceBuilder.ContentType.json
        return customBuilder
    }
}


/// JSONAPI  result as below:
///"""
///{
///    slideshow =     {
///        author = "Yours Truly";
///        date = "date of publication";
///        slides =         (
///                        {
///                title = "Wake up to WonderWidgets!";
///                type = all;
///            },
///                        {
///                items =                 (
///                    "Why <em>WonderWidgets</em> are great",
///                    "Who <em>buys</em> WonderWidgets"
///                );
///                title = Overview;
///                type = all;
///            }
///        );
///        title = "Sample Slide Show";
///    };
///}
///"""
///

struct JSONData: Codable {
    
    struct Slide: Codable {
        
        let title: String
        let type: String
        let items: [String]?
        
        enum CustomKeys: String, CodingKey {
            case title
            case type
        }
    }
    
    struct SlidesShow: Codable {
        let author: String
        let date: String
        let slides: [Slide]
        let title: String
    }
    
    let slideshow: SlidesShow
}

struct JSONTransform: DataTransformProtocol {
    typealias TransformObject = JSONData
    func transform(_ response: DataResponse) throws -> JSONData {
        if let data = response.responseString?.data(using: .utf8) {
            return try JSONDecoder().decode(JSONData.self, from: data)
        }
        throw APIError.missingResponse
        
    }
}


class TransformTests: BaseTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testJSON() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        let api = JSONAPI()
        let expectation = self.expectation(description: "api result should be a struct json data")
        var json: JSONData?
        api.async { (_) in
            expectation.fulfill()
        }
        waitForExpectations(timeout: timeout, handler: nil)
        json = try api.transform(with: JSONTransform())
        XCTAssertEqual(json?.slideshow.title, "Sample Slide Show")
        XCTAssertEqual(json?.slideshow.date, "date of publication")
        
        
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
