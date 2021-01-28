//
//  AuthorizationTests.swift
//  Merlin-iOSTests
//
//  Created by steven on 2021/1/27.
//

import XCTest
@testable import NetService

final class Authenticate: BaseDataService, NetServiceProtocol {
    
    var headers: [String : String] = [:]
    var parameters: [String : Any] = [:]
    var urlString: String {
        return "https://httpbin.org/hidden-basic-auth/\(_user)/\(_password)"
    }
    
    var authorization: NetBuilders.Authorization {
        return _authorization
    }
    
    private var _authorization: NetBuilders.Authorization = .none
    
    private var _user: String = ""
    private var _password: String = ""
    
    func authenticate(user: String, password: String) -> Self {
        _authorization = .basic(user: user, password: password)
        _user = user
        _password = password
        return self
    }
}

class AuthorizationTests: BaseTestCase {
    let user = "user"
    let password = "password"

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testHTTPBasicAuthentication() throws {
        let urlString = "https://httpbin.org/basic-auth/\(user)/\(password)"
        print(urlString)
        let expectation = self.expectation(description: "\(urlString) 200")
        var response: DataResponse?
        Authenticate().authenticate(user: user, password: password).async { (request) in
            response = request.response
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.response)
        print(response?.response)
        XCTAssertEqual(response?.response?.statusCode, 200)
        XCTAssertNotNil(response?.data)
        XCTAssertNil(response?.error)
    }

}
