//
//  BaseDownloadServiceTests.swift
//  Merlin-iOSTests
//
//  Created by steven on 2021/1/27.
//

import XCTest
@testable import NetService

class DownloadAPI: BaseDownloadService, NetServiceProtocol {
    
    var urlString: String {
        let numberOfLines = 100
        let urlString = "https://httpbin.org/stream/\(numberOfLines)"
        return urlString
    }
    
}

class DownloadServiceTests: BaseTestCase {
    
    let testDirectoryURL = URL.init(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("org.netservice.tests")
    
    private var randomCachesFileURL: URL {
        return testDirectoryURL.appendingPathComponent("\(UUID().uuidString).json")
    }
    
    override func setUp() {
        let enumerator = FileManager.default.enumerator(atPath: testDirectoryURL.path)

        while let fileName = enumerator?.nextObject() as? String {
            try! FileManager.default.removeItem(atPath: testDirectoryURL.path + "/\(fileName)")
        }
        try! FileManager.default.createDirectory(at: testDirectoryURL, withIntermediateDirectories: true, attributes: nil)
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testDownloadRequest() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let fielURL = randomCachesFileURL
        let destination: DestinationClosure = {_, _ in fielURL }
        
        let expectation = self.expectation(description: "Download API Should download data to file")
        var response: DownloadResponse?
        
        DownloadAPI().download(progress: { (progress) in
            print(progress.completedUnitCount)
        }, to: destination) { (request) in
            response = request.response
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: timeout, handler: nil)
        // Then
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.downloadFileURL)
        XCTAssertNil(response?.resumeData)
        XCTAssertNil(response?.failure)
        if let downloadFileURL = response?.downloadFileURL {
            print(downloadFileURL)
        }
    }

}
