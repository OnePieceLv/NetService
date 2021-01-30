//
//  AuthorizationTests.swift
//  Merlin-iOSTests
//
//  Created by steven on 2021/1/27.
//

import XCTest
@testable import NetService

final class Authenticate: BaseDataService, NetServiceProtocol {
    
    var urlString: String {
        return _urlString
    }
    
    var authorization: NetBuilders.Authorization {
        return self._authorization
    }
    
    var credential: URLCredential? {
        return _useCredential
    }
    
    private var _useCredential: URLCredential?
    
    private var _authorization: NetBuilders.Authorization = .none
    
    private var _user: String = ""
    private var _password: String = ""
    
    private var _urlString = ""
    
    func authenticate(urlStr: String, user: String, password: String, useCredential: Bool = false) -> Self {
        if useCredential {
            _useCredential = URLCredential(user: user, password: password, persistence: .forSession)
        } else {
            _authorization = .basic(user: user, password: password)
        }
        _user = user
        _password = password
        _urlString = urlStr
        return self
    }
}

class AuthorizationTests: BaseTestCase {
    let user = "user"
    let password = "password"
    let qop = "auth"

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testHiddenHTTPBasicAuthenticationWithValid() throws {
        let urlString = "https://httpbin.org/hidden-basic-auth/\(user)/\(password)"
        let expectation = self.expectation(description: "\(urlString) 200")
        var response: DataResponse?
        let request = Authenticate().authenticate(urlStr: urlString,user: user, password: password)
        request.async { (request) in
            response = request.response
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.response)
        print(response!)
        XCTAssertEqual(response?.response?.statusCode, 200)
        XCTAssertNotNil(response?.responseString)
        XCTAssertNil(response?.error)
    }
    
    
    func testHTTPBasicAuthenticateWithValidCredential() -> Void {
        let urlString = "https://httpbin.org/basic-auth/\(user)/\(password)"
        let expectation = self.expectation(description: "\(urlString) 200")
        var response: DataResponse?
        let request = Authenticate().authenticate(urlStr: urlString, user: user, password: password, useCredential: true)
        request.async { (api) in
            response = request.response
            expectation.fulfill()
        }
        waitForExpectations(timeout: timeout, handler: nil)
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertEqual(response?.response?.statusCode, 200)
        XCTAssertNotNil(response?.responseString)
        XCTAssertNil(response?.error)
        print(response!)
    }
    
    func testHTTPBasicAuthenticateWithInvalidCredential() -> Void {
        let urlString = "https://httpbin.org/basic-auth/\(user)/\(password)"
        let expectation = self.expectation(description: "\(urlString) 401")
        var response: DataResponse?
        Authenticate().authenticate(urlStr: urlString, user: "invalid", password: "credentials", useCredential: true).async { (request) in
            response = request.response
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: timeout, handler: nil)
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNil(response?.error)
        XCTAssertEqual(response?.statusCode, 401)
        XCTAssertNotNil(response?.responseString)
        print(response!)
    }
    
    func testHTTPDigestAuthenticateWithValidCredential() -> Void {
        let urlString = "https://httpbin.org/digest-auth/\(qop)/\(user)/\(password)"
        let expectation = self.expectation(description: "\(urlString) 200")
        var response: DataResponse?
        Authenticate().authenticate(urlStr: urlString, user: user, password: password, useCredential: true).async { (request) in
            print(request)
            response = request.response
            expectation.fulfill()
        }
        waitForExpectations(timeout: timeout, handler: nil)
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertNotNil(response?.responseString)
        XCTAssertNil(response?.error)
        print(response!)
    }
    
    func testHTTPDigestAuthenticateWithInvalidCredential() -> Void {
        let urlString = "https://httpbin.org/digest-auth/\(qop)/\(user)/\(password)"
        let expectation = self.expectation(description: "\(urlString) 401")
        var response: DataResponse?
        Authenticate().authenticate(urlStr: urlString, user: "invalid", password: "credentials", useCredential: true).async { (request) in
            response = request.response
            expectation.fulfill()
        }
        waitForExpectations(timeout: timeout, handler: nil)
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertEqual(response?.response?.statusCode, 401)
        XCTAssertNotNil(response?.responseString)
        XCTAssertNil(response?.error)
    }

}
