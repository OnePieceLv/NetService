//
//  UploadTests.swift
//  Merlin-iOSTests
//
//  Created by steven on 2021/1/28.
//

import XCTest
@testable import NetService

class UploadAPI: BaseUploadManager {
    
    override var urlString: String {
        return _urlString
    }
    
    var _urlString: String = ""
    
    init(with url: String) {
        _urlString = url
    }
    
    
}

class UploadTests: BaseTestCase {
    

    func testUploadMethodWithMethodURLAndFile() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let urlString = "https://httpbin.org/post"
        let bundle = Bundle(for: BaseTestCase.self)
        let imageURL = bundle.url(forResource: "rainbow", withExtension: "jpg")!
        let expection = self.expectation(description: "upload api expectation")
        var res: DataResponse?
        var uploadProgressValues: [Double] = []
        UploadAPI(with: urlString).upload(file: imageURL) { (progress: Progress) in
            uploadProgressValues.append(progress.fractionCompleted)
            print(progress.fractionCompleted)
        } completion: { (request) in
            res = request.response
            if let responseString = res?.responseString {
                print(responseString)
            }
            expection.fulfill()
        }
        
        waitForExpectations(timeout: timeout, handler: nil)
        XCTAssertEqual(res?.statusCode, 200)
        XCTAssertNotNil(res?.response)
        XCTAssertNil(res?.error)
        XCTAssertGreaterThan(uploadProgressValues.count, 0)
        
        var previousUploadProgress: Double = uploadProgressValues.first ?? 0.0
        
        for progress in uploadProgressValues {
            XCTAssertGreaterThanOrEqual(progress, previousUploadProgress)
            previousUploadProgress = progress
        }
        
        if let lastProgressValue = uploadProgressValues.last {
            XCTAssertEqual(lastProgressValue, 1.0)
        } else {
            XCTFail("last item in uploadProgressValues should not be nil")
        }

    }
    
    func testUploadDataRequestWithProgress() -> Void {
        let urlString = "https://httpbin.org/post"
        let data: Data = {
            var text = ""
            for _ in 1...3_000 {
                text += "Lorem ipsum dolor sit amet, consectetur adipiscing elit. "
            }

            return text.data(using: .utf8, allowLossyConversion: false)!
        }()
        
        let expectation = self.expectation(description: "Bytes upload progress should be reported: \(urlString)")
        
        var uploadProgressValues: [Double] = []
        
        var response: DataResponse?
        
        UploadAPI(with: urlString).upload(data: data) { (progress) in
            uploadProgressValues.append(progress.fractionCompleted)
        } completion: { (request) in
            response = request.response
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: timeout, handler: nil)
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.responseString)
        XCTAssertNil(response?.error)
        
        var previousUploadProgress: Double = uploadProgressValues.first ?? 0.0

        for progress in uploadProgressValues {
            XCTAssertGreaterThanOrEqual(progress, previousUploadProgress)
            previousUploadProgress = progress
        }

        if let lastProgressValue = uploadProgressValues.last {
            XCTAssertEqual(lastProgressValue, 1.0)
        } else {
            XCTFail("last item in uploadProgressValues should not be nil")
        }


    }
    
    func testUploadRequestFromInputStreamWithProgress() -> Void {
        let urlString = "https://httpbin.org/post"
        let data: Data = {
            var text = ""
            for _ in 1...3_000 {
                text += "Lorem ipsum dolor sit amet, consectetur adipiscing elit. "
            }

            return text.data(using: .utf8, allowLossyConversion: false)!
        }()
        
        let expectation = self.expectation(description: "Bytes upload progress should be reported: \(urlString)")
        
        var uploadProgressValues: [Double] = []
        
        var response: DataResponse?
        
        let inputStream = InputStream(data: data)
        UploadAPI(with: urlString).upload(stream: inputStream, contentLength: UInt64(data.count)) { (progress) in
            uploadProgressValues.append(progress.fractionCompleted)
        } completion: { (request) in
            response = request.response
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: timeout, handler: nil)
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertNotNil(response?.response)
        XCTAssertNil(response?.error)
        XCTAssertGreaterThan(uploadProgressValues.count, 0)
        
        var previousUploadProgress: Double = uploadProgressValues.first ?? 0.0
        
        for progress in uploadProgressValues {
            XCTAssertGreaterThanOrEqual(progress, previousUploadProgress)
            previousUploadProgress = progress
        }
        
        print(uploadProgressValues)
        if let lastProgressValue = uploadProgressValues.last {
            XCTAssertEqual(lastProgressValue, 1.0)
        } else {
            XCTFail("last item in uploadProgressValues should not be nil")
        }

        
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    

}

class UploadMultipartFormDataTestCase: BaseTestCase {
    // MARK: Tests
    
    func testMultipartFormDataSetsContentTypeHeader() -> Void {
        let urlString = "https://httpbin.org/post"
        let uploadData = "upload_data".data(using: .utf8, allowLossyConversion: false)!
        
        let expectation = self.expectation(description: "multipart form data upload should succeed")
        
        var multipartFormdata: MultipartFormData?
        var response: DataResponse?
        
        UploadAPI(with: urlString).upload { (formData) in
            formData.append(uploadData, withName: "upload_data")
            multipartFormdata = formData
        } progress: { (progress) in
            print(progress.fractionCompleted)
        } completion: { (request) in
            response = request.response
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: timeout, handler: nil)
        
        //Then
        XCTAssertNotNil(response?.request)
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.responseString)
        XCTAssertNil(response?.error)
        
        if let request = response?.request,
           let multipartFormdata = multipartFormdata,
           let contentType = request.value(forHTTPHeaderField: "Content-Type")
        {
            XCTAssertEqual(contentType, multipartFormdata.contentType)
        } else {
            XCTFail("Content-Type header value should not be nil")
        }
    }
    
    func testUploadWithMultipartFormDataEncodingInMemory() {
        multipartformdataUploadInProgress(fromDisk: false)
    }
    
    func testUploadWithMultipartFormDataStreamingFromDisk() {
        multipartformdataUploadInProgress(fromDisk: true)
    }
    
    func testBuildFormData() -> Void {
        let urlString = "https://httpbin.org/post"
        let uploadAPI = UploadAPI(with: urlString)
        if let (uploadable, uploadrequest) = try? uploadAPI.build(formdata: MultipartFormData(), encodingMemoryThreshold: 0, isInBackgroundSession: false) {
            if case .file(let url, let request) = uploadable {
                XCTAssertNotNil(url)
                XCTAssertEqual(request, uploadrequest)
                XCTAssertEqual(request.url?.absoluteString, urlString)
                print(url)
            }
        } else {
            XCTFail("build should be return uploadable and request")
        }
        
    }
    
    
    private func multipartformdataUploadInProgress(fromDisk: Bool) {
        let urlString = "https://httpbin.org/post"
        let xiaomingdata: Data = {
            var values: [String] = []
            for _ in 1...1_500 {
                values.append("this is test code, Rapid evacuation of non-combatants")
            }
            return values.joined(separator: " ").data(using: .utf8, allowLossyConversion: false)!
        }()
        
        let hanmeimeidata: Data = {
            var values: [String] = []
            for _ in 1...1_500 {
                values.append("this is test code, ")
            }
            return values.joined(separator: " ").data(using: .utf8, allowLossyConversion: false)!
        }()
        
        let expectation = self.expectation(description: "upload should succeed")
        
        var uploadProgressValues: [Double] = []
        var response: DataResponse?
        UploadAPI(with: urlString).upload(multipartformdata: { (formdata) in
            formdata.append(xiaomingdata, withName: "xiaoming_data")
            formdata.append(hanmeimeidata, withName: "hanmeimei_data")
            formdata.append(xiaomingdata, withName: "xiaoming_data2")
            formdata.append(hanmeimeidata, withName: "hanmeimei_data2")

        },
        isInMemoryThreshold: fromDisk ? 0 : 100_000_000,
        progress: { (progress) in
            uploadProgressValues.append(progress.fractionCompleted)
        }) { (request) in
            response = request.response
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: timeout, handler: nil)
        XCTAssertEqual(response?.statusCode, 200)
        print(uploadProgressValues)
        XCTAssertGreaterThan(uploadProgressValues.count, 0)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.responseString)
        XCTAssertNil(response?.error)
        
        var previousUploadProgress: Double = uploadProgressValues.first ?? 0.0
        
        for progress in uploadProgressValues {
            XCTAssertGreaterThanOrEqual(progress, previousUploadProgress)
            previousUploadProgress = progress
        }
        
        if let lastProgressValue = uploadProgressValues.last {
            XCTAssertEqual(lastProgressValue, 1.0)
        } else {
            XCTFail("last item in uploadProgressValues should not be nil")
        }
        
    }
    
}

