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
        return _urlString
    }
    
    func httpParameters() -> [String : Any] {
        return _parameters
    }
    
    func httpHeaders() -> [String : String] {
        return _headers
    }
        
    private var _urlString = ""
    
    private var _parameters: [String: Any] = [:]
    
    private var _headers: [String: String] = [:]
    
    init(with url: String, parameters: [String: Any] = [:]) {
        _urlString = url
        _parameters = parameters
    }
    
    init(with url: String, headers: [String: String]) {
        _urlString = url
        _headers = headers
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
        let numberOfLines = 100
        let urlString = "https://httpbin.org/stream/\(numberOfLines)"
        
        let expectation = self.expectation(description: "Download API Should download data to file")
        var response: DownloadResponse?
        
        DownloadAPI(with: urlString).download(progress: { (progress) in
            print(progress.fractionCompleted)
        }, to: destination) { (request) in
            response = request.response
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: timeout, handler: nil)
        // Then
        XCTAssertNotNil(response?.response)
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertNotNil(response?.downloadFileURL)
        XCTAssertNil(response?.resumeData)
        XCTAssertNil(response?.error)
        if let downloadFileURL = response?.downloadFileURL {
            print(downloadFileURL)
        }
    }
    
    func testDownloadServiceWithparameters() {
        let urlString = "https://httpbin.org/get"
        let parameters = ["foo": "bar"]
        
        let expectation = self.expectation(description: "Download request should download data to file")
        var response: DownloadResponse?
        DownloadAPI(with: urlString, parameters: parameters).download { (progress) in
            print(progress.completedUnitCount)
        } completion: { (request) in
            response = request.response
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.downloadFileURL)
        XCTAssertNil(response?.resumeData)
        XCTAssertNil(response?.result.failure)
        
        if let downloadFileURL = response?.downloadFileURL, let data = try? Data(contentsOf: downloadFileURL), let jsonObject = try? JSONSerialization.jsonObject(with: data, options: .allowFragments), let json = jsonObject as? [String: Any], let args = json["args"] as? [String: String] {
            XCTAssertEqual(args["foo"], "bar")
        } else {
            XCTFail("args parameter in json should not be nil")
        }

    }
    
    func testDownloadRequestWithProgress() {
        let randomBytes = 4 * 1024 * 1024
        let urlString = "https://httpbin.org/bytes/\(randomBytes)"
        let expectation = self.expectation(description: "Bytes download progress should be reported: \(urlString)")
        var progressValues: [Double] = []
        var response: DownloadResponse?
        
        DownloadAPI(with: urlString).download { (progress) in
            progressValues.append(progress.fractionCompleted)
            print(progressValues)
        } completion: { (request) in
            response = request.response
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: timeout, handler: nil)
        
        XCTAssertNotNil(response?.response)
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertNotNil(response?.downloadFileURL)
        XCTAssertNil(response?.resumeData)
        XCTAssertNil(response?.error)
        
        var previousProgress: Double = progressValues.first ?? 0.0

        for progress in progressValues {
            XCTAssertGreaterThanOrEqual(progress, previousProgress)
            previousProgress = progress
        }

        if let lastProgressValue = progressValues.last {
            XCTAssertEqual(lastProgressValue, 1.0)
        } else {
            XCTFail("last item in progressValues should not be nil")
        }
    }
    
    func testDownloadRequestWithHeaders() {
        let fileURL = randomCachesFileURL
        let urlString = "https://httpbin.org/get"
        let headers = ["Authorization": "123456"]
        let destination: DestinationClosure = {_,_ in fileURL }
        
        let expectation = self.expectation(description: "Download request should download data to file: \(fileURL)")
        
        var response: DownloadResponse?
        
        DownloadAPI(with: urlString, headers: headers).download(progress: { (progress) in
            print(progress.completedUnitCount)
        }, to: destination) { (downloadRequest) in
            response = downloadRequest.response
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: timeout, handler: nil)
        
        // Then
        XCTAssertNotNil(response?.response)
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertNotNil(response?.downloadFileURL)
        XCTAssertNil(response?.resumeData)
        XCTAssertNil(response?.error)

        if
            let data = try? Data(contentsOf: fileURL),
            let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
            let json = jsonObject as? [String: Any],
            let headers = json["headers"] as? [String: String]
        {
            XCTAssertEqual(headers["Authorization"], "123456")
        } else {
            XCTFail("headers parameter in JSON should not be nil")
        }
    }
    
    func testDownloadRequestMatchesResumeDataWhenisCancelled() -> Void {
        let urlString = "https://upload.wikimedia.org/wikipedia/commons/6/69/NASA-HS201427a-HubbleUltraDeepField2014-20140603.jpg"
        
        let expectation = self.expectation(description: "Download should be cancelled")
        
        var response: DownloadResponse?
        
        let downloadapi = DownloadAPI(with: urlString)
        downloadapi.download { (progress) in
            if progress.fractionCompleted > 0.1 {
                downloadapi.cancel()
            }
        } completion: { (downloadRequest) in
            response = downloadRequest.response
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: timeout, handler: nil)
        XCTAssertNotNil(response?.response)
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertNil(response?.downloadFileURL)
        XCTAssertNotNil(response?.error)

        XCTAssertNotNil(response?.resumeData)
        XCTAssertNotNil(downloadapi.resumeData)

        XCTAssertEqual(response?.resumeData, downloadapi.resumeData)

    }
    
    // https://developer.apple.com/documentation/foundation/urlsessiondownloadtask/1411634-cancel
    func testDownloadRequestCanBeResumedWithResumeData() -> Void {
//        let urlString = "https://upload.wikimedia.org/wikipedia/commons/6/69/NASA-HS201427a-HubbleUltraDeepField2014-20140603.jpg"
        let urlString = "https://cloud.githubusercontent.com/assets/1567433/9781817/ecb16e82-57a0-11e5-9b43-6b4f52659997.jpg"

        let fileURL = randomCachesFileURL
        let destination: DestinationClosure = {_, _ in fileURL }

        
        let expectation1 = self.expectation(description: "Download should be cancelled")
        var cancelled = false
        
        var response1: DownloadResponse?
        let downloadAPI = DownloadAPI(with: urlString)
        downloadAPI.download(progress: { (progress) in
            guard !cancelled else { return }
            if progress.fractionCompleted > 0.4 {
                print(progress.fractionCompleted)
                downloadAPI.cancel()
                cancelled = true
            }
        }, to: destination) { (request) in
            response1 = request.response
            expectation1.fulfill()
        }
        
        waitForExpectations(timeout: timeout, handler: nil)
        
        guard let resumeData = downloadAPI.resumeData else {
            XCTFail("resumeData should not be nil")
            return
        }
        
        do {
            try resumeData.write(to: fileURL)
        } catch {
            print(error)
            XCTAssertNil(error, "error should be nil")
        }
        
        let expectation2 = self.expectation(description: "Download should complete")

        var progressValues: [Double] = []
        
        var response2: DownloadResponse?
        let downloadAPI2 = DownloadAPI(with: urlString)
        print(resumeData)
        downloadAPI2.download(resumingWith: resumeData, to: destination, progress: { (progress) in
            progressValues.append(progress.fractionCompleted)
        }) { (request) in
            response2 = request.response
            expectation2.fulfill()
        }
        
        waitForExpectations(timeout: timeout, handler: nil)
        
        // Then
        XCTAssertNotNil(response1?.response)
        XCTAssertEqual(response1?.statusCode, 200)
        XCTAssertNil(response1?.downloadFileURL)
        XCTAssertEqual(response1?.result.isFailure, true)
        XCTAssertNotNil(response1?.error)

        XCTAssertNotNil(response2?.response)
        XCTAssertEqual(response2?.statusCode, 206)
        XCTAssertNotNil(response2?.downloadFileURL)
        XCTAssertEqual(response2?.result.isSuccess, true)
        XCTAssertNil(response2?.error)
        print(progressValues)
        progressValues.forEach { XCTAssertGreaterThanOrEqual($0, 0.4) }

    }
    
    func testDownloadRequestCanBeCancelledWithoutResumeData() -> Void {
        let urlString = "https://upload.wikimedia.org/wikipedia/commons/6/69/NASA-HS201427a-HubbleUltraDeepField2014-20140603.jpg"

        let expectation = self.expectation(description: "Download should be cancelled")
        
        var cancelled = false
        
        var response: DownloadResponse?
        
        let downloadAPI = DownloadAPI(with: urlString)
        
        downloadAPI.download { (progress) in
            guard !cancelled else { return }
            
            if progress.fractionCompleted > 0.1 {
                downloadAPI.cancel(createResumeData: false)
                cancelled = true
            }
            
        } completion: { (request) in
            response = request.response
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: timeout, handler: nil)
        // Then
        XCTAssertNotNil(response?.response)
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertNil(response?.downloadFileURL)
        XCTAssertNotNil(response?.error)

        XCTAssertNil(response?.resumeData)
        XCTAssertNil(downloadAPI.resumeData)

    }

}
