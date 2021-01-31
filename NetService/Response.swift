//
//  APIResponse.swift
//  NetService
//
//  Created by steven on 2021/1/1.
//

import Foundation


/// A set of HTTP response status code that do not contain response data.
private let emptyDataStatusCodes: Set<Int> = [204, 205]

public protocol DataTransformProtocol {
    associatedtype TransformObject
    func transform(_ response: DataResponse) throws -> TransformObject
}

public protocol DownloadTransformProtocol {
    associatedtype TransformObject
    func transform(_ downloadResponse: DownloadResponse) throws -> TransformObject
}

public struct DefaultJSONTransform: DataTransformProtocol {
    
    typealias TranformObject = Any
    
    public func transform(_ response: DataResponse) throws -> Any {
        if let string = response.responseString, let data = string.data(using: .utf8) {
            return try JSONSerialization.jsonObject(with: data, options: .allowFragments)
        }
        throw APIError.responseSerializationFailed(reason: APIError.ResponseSerializationFailureReason.inputDataNilOrZeroLength)
    }
}


public struct DataResponse {
    
    public let request: URLRequest
        
    public let response: HTTPURLResponse?
    
    private let data: Data?
    
    public let metrics: URLSessionTaskMetrics?
    
    public var statusCode: Int {
        return response?.statusCode ?? -1
    }
    
    public let result: Result<Data, Error>
    
    public var value: Data? { result.success }
    
    public var error: Error? { result.failure }
    
    public var responseString: String? {
        if let data = self.data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    public func responseJSON() throws -> [String: Any]? {
        if let data = self.data {
            return try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
        }
        return nil
    }
    
    public init(request: URLRequest,
                response: HTTPURLResponse?,
                data: Data?,
                metrics: URLSessionTaskMetrics?,
                result: Result<Data, Error>
    ) {
        self.request = request
        self.response = response
        self.data = data
        self.result = result
        self.metrics = metrics
    }
    
    public static func serializeResponseData(response: HTTPURLResponse?, data: Data?, error: Error?) -> Result<Data, Error> {
        if let err = error {
            return .failure(err.asAPIError(or: APIError.undefinedFailed(error: err)))
        }

        if let response = response, emptyDataStatusCodes.contains(response.statusCode) {
            return .success(Data())
        }

        guard let validData = data else {
            return .failure(APIError.responseSerializationFailed(reason: .inputDataNilOrZeroLength))
        }

        return .success(validData)
    }
}

public struct DownloadResponse {
    
    public let metrics: URLSessionTaskMetrics?
    
    public let response: HTTPURLResponse?
    
    public let downloadFileURL: URL?

    public let resumeData: Data?
    
    public var statusCode: Int {
        return response?.statusCode ?? -1
    }

    public let result: Result<URL, Error>

    /// Returns the associated value of the result if it is a success, `nil` otherwise.
    public var value: URL? { return result.success }

    /// Returns the associated error value if the result if it is a failure, `nil` otherwise.
    public var error: Error? { return result.failure }
    
    public init(
        response: HTTPURLResponse?,
        destinationURL: URL?,
        resumeData: Data?,
        metrics: URLSessionTaskMetrics?,
        result: Result<URL, Error>)
    {
        self.response = response
        self.downloadFileURL = destinationURL
        self.resumeData = resumeData
        self.metrics = metrics
        self.result = result
    }
    
    public static func downloadResponseSerializer(response: HTTPURLResponse?, fileURL: URL?, error: Error?) -> Result<URL,Error>{
        guard error == nil else { return .failure(error!) }

        guard let fileURL = fileURL else {
            return .failure(APIError.responseSerializationFailed(reason: .inputFileNil))
        }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return .success(fileURL)
        }
        return .failure(APIError.responseSerializationFailed(reason: .inputFileReadFailed(at: fileURL)))
    }
    
}

extension DataResponse: CustomStringConvertible, CustomDebugStringConvertible {
    /// The textual representation used when written to an output stream, which includes whether the result was a
    /// success or failure.
    public var description: String {
        "\(self.debugDescription)"
    }

    /// The debug textual representation used when written to an output stream, which includes (if available) a summary
    /// of the `URLRequest`, the request's headers and body (if decodable as a `String` below 100KB); the
    /// `HTTPURLResponse`'s status code, headers, and body; the duration of the network and serialization actions; and
    /// the `Result` of serialization.
    public var debugDescription: String {
        var result = "[Response]: \r\n"
        if let response = self.response {
            result += "[Status Code]: \(response.statusCode)".trimmingCharacters(in: .whitespacesAndNewlines).indentingNewlines() + "\r\n"
            result += "\r\n"
        } else {
            result = "[response] none \r\n"
        }
        if let headers = self.response?.allHeaderFields {
            result += headers.reduce("[Headers]: ") { "\($0)" + "\($1.key): \($1.value)".trimmingCharacters(in: .whitespacesAndNewlines).indentingNewlines() + "\r\n" }
            result += "\r\n"
        } else {
            result += "[Headers]: none \r\n"
        }
        if let data = self.data {
            result += "[data]:\(String(decoding: data, as: UTF8.self).trimmingCharacters(in:.whitespacesAndNewlines).indentingNewlines()) \r\n"
        } else {
            result += "[data]: none \r\n"
        }
        return """
                \(result.indentingNewlines())
                \(DebugDescription.description(of: self.request))
               """
    }
    
    
}

// MARK - DebugDescription

private enum DebugDescription {
    static func description(of request: URLRequest) -> String {
        let requestSummary = "\(request.httpMethod!) \(request)" + "\r\n"
        
        var requestHeadersDescription = ""
        if let headers = request.allHTTPHeaderFields {
            requestHeadersDescription = headers.reduce("[request headers]: ") { "\($0)" + "\($1.key):\($1.value)" + "\r\n"}
            requestHeadersDescription += "\r\n"
        }
        
        var requestBodyDescription = ""
        if let data = request.httpBody {
            requestBodyDescription = String(data: data, encoding: .utf8) ?? ""
            requestBodyDescription = "\(requestBodyDescription.trimmingCharacters(in: .whitespacesAndNewlines).indentingNewlines())"
            requestBodyDescription += "\r\n"
        }

        return """
        [Request]:
            \(requestSummary)
            \(requestHeadersDescription.indentingNewlines())
            \(requestBodyDescription.indentingNewlines())
        """
    }
}

extension String {
    fileprivate func indentingNewlines(by spaceCount: Int = 4) -> String {
        let spaces = String(repeating: " ", count: spaceCount)
        return replacingOccurrences(of: "\n", with: "\n\(spaces)")
    }
}
