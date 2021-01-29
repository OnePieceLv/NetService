//
//  APIResponse.swift
//  NetService
//
//  Created by steven on 2021/1/1.
//

import Foundation


/// A set of HTTP response status code that do not contain response data.
private let emptyDataStatusCodes: Set<Int> = [204, 205]

public protocol ObjectTransformProtocol {
    associatedtype TransformObject
    func transform(_ data: Data) throws -> TransformObject
}

public struct DefaultJSONTransform: ObjectTransformProtocol {
    typealias TranformObject = Any
    
    public func transform(_ data: Data) throws -> Any {
        do {
            let dict = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
            return dict
        } catch {
            throw error
        }
    }
}


public struct DataResponse {
    
    public let request: URLRequest
        
    public let response: HTTPURLResponse?
    
    public let data: Data?
    
    public let metrics: URLSessionTaskMetrics?
    
    var statusCode: Int {
        return response?.statusCode ?? -1
    }
    
    public let result: Result<Data, Error>
    
    public var value: Data? { result.success }
    
    public var error: Error? { result.failure }
    
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
    
    public func transform<T: ObjectTransformProtocol>(with transform: T) throws -> T.TransformObject {
        let res = result.tryMap({ (data) -> T.TransformObject in
            return try transform.transform(data)
        })
        
        if let object = res.success {
            return object
        }
        
        throw res.failure ?? APIError.customFailure(message: "transform error is missing")
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

    public let result: Result<URL, Error>

    /// Returns the associated value of the result if it is a success, `nil` otherwise.
    public var success: URL? { return result.success }

    /// Returns the associated error value if the result if it is a failure, `nil` otherwise.
    public var failure: Error? { return result.failure }
    
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
        var result = ""
        if let response = self.response {
            result = "[Status Code]: \(response.statusCode) \n"
        } else {
            result = "[response] none \n"
        }
        if let headers = self.response?.allHeaderFields {
            result += "[Headers]: \(headers.reduce(""){ $0 + "\($1.key)\($1.value)" }) \n"
        } else {
            result += "[Headers]: none \n"
        }
        if let data = self.data {
            result += "[Response]:\(String(decoding: data, as: UTF8.self).trimmingCharacters(in:.whitespacesAndNewlines).indentingNewlines())"
        } else {
            result += "[Response]: none \n"
        }
        return """
                [Debug Response]:
                    \(result)
                    [Request]: \(DebugDescription.description(of: self.request))
               """
    }
    
    
}

// MARK - DebugDescription

private enum DebugDescription {
    static func description(of request: URLRequest) -> String {
        let requestSummary = "\(request.httpMethod!) \(request)"
        let requestHeadersDescription = DebugDescription.description(for: request.httpBody, headers: request.allHTTPHeaderFields)
        let requestBodyDescription = DebugDescription.description(for: request.httpBody, headers: request.allHTTPHeaderFields)

        return """
        [Request]: \(requestSummary)
            \(requestHeadersDescription.indentingNewlines())
            \(requestBodyDescription.indentingNewlines())
        """
    }

    static func description(for data: Data?,
                            headers: [String: String]?,
                            allowingPrintableTypes printableTypes: [String] = ["json", "xml", "text"],
                            maximumLength: Int = 100_000) -> String {
        guard let data = data, !data.isEmpty else { return "[Body]: None" }

        guard
            data.count <= maximumLength,
            printableTypes.compactMap({ headers?["Content-Type"]?.contains($0) }).contains(true)
        else { return "[Body]: \(data.count) bytes" }

        return """
        [Body]:
            \(String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .indentingNewlines())
        """
    }
}

extension String {
    fileprivate func indentingNewlines(by spaceCount: Int = 4) -> String {
        let spaces = String(repeating: " ", count: spaceCount)
        return replacingOccurrences(of: "\n", with: "\n\(spaces)")
    }
}
