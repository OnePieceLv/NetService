//
//  ServerTrustPolicyTests.swift
//  NetService iOS Tests
//
//  Created by steven on 2021/2/1.
//

import XCTest
import NetService

private struct TestCertificates {
    // Root Certificates
    static let rootCA = TestCertificates.certificate(with: "alamofire-root-ca")
    
    // Intermediate Certificates
    static let intermediateCA1 = TestCertificates.certificate(with: "alamofire-signing-ca1")
    
    
    // Leaf Certificates - Signing by CA1
    static let leafWildcard = TestCertificates.certificate(with: "wildcard.alamofire.org")
    static let leafDNSNameAndURI = TestCertificates.certificate(with: "test.alamofire.org")
    
    
    // badssl.com
    static let badsslRootCA = TestCertificates.certificate(with: "expired.badssl.com-root-ca")
    static let badsslIntermediateCA1 = TestCertificates.certificate(with: "expired.badssl.com-intermediate-ca-1")
    static let badsslIntermediateCA2 = TestCertificates.certificate(with: "expired.badssl.com-intermediate-ca-2")
    static let badsslLeaf = TestCertificates.certificate(with: "expired.badssl.com-leaf")


    
    
    static func certificate(with filename: String) -> SecCertificate {
        class Locater {}
        let filePath = Bundle(for: Locater.self).path(forResource: filename, ofType: "cer")!
        let data = try! Data(contentsOf: URL(fileURLWithPath: filePath))
        let certificate = SecCertificateCreateWithData(nil, data as CFData)
        return certificate!
    }
}

private struct TestPublicKeys {
    // Root Public Keys
    static let rootCA = TestPublicKeys.publicKey(for: TestCertificates.rootCA)
    
    // Intermediate Public Keys
    static let intermediateCA1 = TestPublicKeys.publicKey(for: TestCertificates.intermediateCA1)
    
    // Leaf Public Keys - Signed by CA1
    static let leafWildcard = TestPublicKeys.publicKey(for: TestCertificates.leafWildcard)
    static let leafDNSNameAndURI = TestPublicKeys.publicKey(for: TestCertificates.leafDNSNameAndURI)
    
    
    static func publicKey(for certificate: SecCertificate) -> SecKey {
        let policy = SecPolicyCreateBasicX509()
        var trust: SecTrust?
        SecTrustCreateWithCertificates(certificate, policy, &trust)
        
        let publicKey = SecTrustCopyPublicKey(trust!)
        
        return publicKey!
    }
}

private enum TestTrusts {
    
    case leafWildcard
    
    var trust: SecTrust {
        let trust: SecTrust
        switch self {
        case .leafWildcard:
            trust = TestTrusts.trustWithCertificate([
                TestCertificates.leafWildcard,
                TestCertificates.intermediateCA1,
                TestCertificates.rootCA
            ])
            return trust
        }
    }
        
    static func trustWithCertificate(_ certificates: [SecCertificate]) -> SecTrust {
        let policy = SecPolicyCreateBasicX509()
        var trust: SecTrust?
        SecTrustCreateWithCertificates(certificates as CFTypeRef, policy, &trust)
        return trust!
    }
}

class ServerTrustPolicyTests: BaseTestCase {
    
    func setRootCertificateAsLoneAnchorCertificateForTrust(_ trust: SecTrust) {
        SecTrustSetAnchorCertificates(trust, [TestCertificates.rootCA] as CFArray)
        SecTrustSetAnchorCertificatesOnly(trust, true)
    }
    
    func trustValid(_ trust: SecTrust) -> Bool {
        var isValid: Bool = false
        var result = SecTrustResultType.invalid
        let status = SecTrustEvaluate(trust, &result)
        if status == errSecSuccess {
            let unspecified = SecTrustResultType.unspecified
            let proceed = SecTrustResultType.proceed
            isValid = result == unspecified || result == proceed
        }
        
        return isValid
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testAnchoredRootCertificateSSLValidationWithRootInTrust() throws {
        let trust = TestTrusts.trustWithCertificate([
            TestCertificates.leafDNSNameAndURI,
            TestCertificates.intermediateCA1,
            TestCertificates.rootCA,
        ])
        
        setRootCertificateAsLoneAnchorCertificateForTrust(trust)
        
        let polices = [SecPolicyCreateSSL(true, "test.alamofire.org" as CFString)]
        SecTrustSetPolicies(trust, polices as CFTypeRef)
        
        XCTAssertTrue(trustValid(trust), "trust should be valid")
    }
    
    private let expiredHost = "expired.badssl.com"
    
    final class ExpiredCertificateAPI: BaseDataService, NetServiceProtocol {
        private let expiredURLString = "https://expired.badssl.com/"
        
        var urlString: String {
            return expiredURLString
        }
    }
    
    var service: ServiceAgent?
    
    func testPinningLeafCertificateWithValidChain() {
        // Given

        let certificates = [TestCertificates.badsslLeaf]
        let policies: [String: ServerTrustPolicy] = [
            expiredHost: .pinCertificates(certificates: certificates, validateCertificateChain: true, validateHost: true)
        ]
        
        let expectation = self.expectation(description: "\("https://expired.badssl.com/")")
        var error: Error?
        
        service = ServiceAgent.init(configurate: { (configuration) -> URLSessionConfiguration in
            let configure = URLSessionConfiguration.ephemeral
            configure.urlCache = nil
            configure.urlCredentialStorage = nil
            return configure
        }, serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies))
        ExpiredCertificateAPI().async(service: service!) { (request) in
            error = request.error
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(error, "error should not be nil")
        
       
        if let error = error as? URLError {
            XCTAssertEqual(error.code, .cancelled, "code should be cancelled")
        } else {
            XCTFail("error should be an URLError")
        }
    }
    
    func testPinningLeafCertificateWithoutValidChain() {
        // Given
        let certificates = [TestCertificates.badsslLeaf]
        let policies: [String: ServerTrustPolicy] = [
            expiredHost: .pinCertificates(certificates: certificates, validateCertificateChain: false, validateHost: true)
        ]

        let expectation = self.expectation(description: "\("https://expired.badssl.com/")")
        var error: Error?
        
        service = ServiceAgent.init(configurate: { (configuration) -> URLSessionConfiguration in
            let configure = URLSessionConfiguration.ephemeral
            configure.urlCache = nil
            configure.urlCredentialStorage = nil
            return configure
        }, serverTrustPolicyManager: ServerTrustPolicyManager(policies: policies))
        
        ExpiredCertificateAPI().async(service: service!) { (request) in
            error = request.error
            expectation.fulfill()
        }
       
        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
