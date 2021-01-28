//
//  APIError.swift
//  Merlin-iOS
//
//  Created by steven on 2021/1/4.
//

import Foundation

public enum APIError: Error {
    /// The underlying reason the `.parameterEncodingFailed` error occurred.
    public enum ParameterEncodingFailureReason {
        /// The `URLRequest` did not have a `URL` to encode.
        case missingURL
        case missingMethod
        /// JSON serialization failed with an underlying system error during the encoding process.
        case jsonEncodingFailed(error: Error)
        /// Custom parameter encoding failed due to the associated `Error`.
        case customEncodingFailed(error: Error)
    }
    
    public enum ResponseValidationFailureReason {
        /// The data file containing the server response did not exist.
        case dataFileNil
        /// The data file containing the server response at the associated `URL` could not be read.
        case dataFileReadFailed(at: URL)
        /// The response did not contain a `Content-Type` and the `acceptableContentTypes` provided did not contain a
        /// wildcard type.
        case missingContentType(acceptableContentTypes: [String])
        /// The response `Content-Type` did not match any type in the provided `acceptableContentTypes`.
        case unacceptableContentType(acceptableContentTypes: [String], responseContentType: String)
        /// The response status code was not acceptable.
        case unacceptableStatusCode(code: Int)
        /// Custom response validation failed due to the associated `Error`.
        case customValidationFailed(error: Error)
    }

    /// The underlying reason the response serialization error occurred.
    public enum ResponseSerializationFailureReason {
        /// The server response contained no data or the data was zero length.
        case inputDataNilOrZeroLength
        /// The file containing the server response did not exist.
        case inputFileNil
        /// The file containing the server response could not be read from the associated `URL`.
        case inputFileReadFailed(at: URL)
        /// String serialization failed using the provided `String.Encoding`.
        case stringSerializationFailed(encoding: String.Encoding)
        /// JSON serialization failed with an underlying system error.
        case jsonSerializationFailed(error: Error)
        /// A `DataDecoder` failed to decode the response due to the associated `Error`.
        case decodingFailed(error: Error)
        /// A custom response serializer failed due to the associated `Error`.
        case customSerializationFailed(error: Error)
        /// Generic serialization failed for an empty response that wasn't type `Empty` but instead the associated type.
        case invalidEmptyResponse(type: String)
    }
    
    /// The underlying reason the `.urlRequestValidationFailed`
    public enum URLRequestValidationFailureReason {
        /// URLRequest with GET method had body data.
        case bodyDataInGETRequest(Data)
        case missAuthorization
    }
    
    public enum MultipartEncodingFailureReason {
        case bodyPartURLInvalid(url: URL)
        case bodyPartFilenameInvalid(in: URL)
        case bodyPartFileNotReachable(at: URL)
        case bodyPartFileNotReachableWithError(atURL: URL, error: Error)
        case bodyPartFileIsDirectory(at: URL)
        case bodyPartFileSizeNotAvailable(at: URL)
        case bodyPartFileSizeQueryFailedWithError(forURL: URL, error: Error)
        case bodyPartInputStreamCreationFailed(for: URL)

        case outputStreamCreationFailed(for: URL)
        case outputStreamFileAlreadyExists(at: URL)
        case outputStreamURLInvalid(url: URL)
        case outputStreamWriteFailed(error: Error)

        case inputStreamReadFailed(error: Error)
    }
        
    ///  `URLRequestConvertible` threw an error in `asURLRequest()`.
    case createURLRequestFailed(error: Error?)
    case parameterEncodingFailed(reason: ParameterEncodingFailureReason)
    /// `URLConvertible` type failed to create a valid `URL`.
    case invalidURL(url: String)
    
    case missingURL
    
    case responseValidationFailed(reason: ResponseValidationFailureReason)
    /// Response serialization failed.
    case responseSerializationFailed(reason: ResponseSerializationFailureReason)
    
    /// `Session` was explicitly invalidated, possibly with the `Error` produced by the underlying `URLSession`.
    case sessionInvalidated(error: Error?)
    /// `URLSessionTask` completed with error.
    case sessionTaskFailed(error: Error?)
    /// `URLRequest` failed validation.
    case urlRequestValidationFailed(reason: URLRequestValidationFailureReason)
    case multipartEncodingFailed(reason: MultipartEncodingFailureReason)
    /// undefined error 
    case undefinedFailed(error: Error)
    case taskProcessTypeCast
    case customFailure(message: String)
}

extension Error {
    /// Returns the instance cast as an `AFError`.
    public var asAPIError: APIError? {
        self as? APIError
    }

    /// Returns the instance cast as an `AFError`. If casting fails, a `fatalError` with the specified `message` is thrown.
    public func asAPIError(orFailWith message: @autoclosure () -> String, file: StaticString = #file, line: UInt = #line) -> APIError {
        guard let apiError = self as? APIError else {
            fatalError(message(), file: file, line: line)
        }
        return apiError
    }
    /// Casts the instance as `AFError` or returns `defaultAFError`
    func asAPIError(or defaultAFError: @autoclosure () -> APIError) -> APIError {
        self as? APIError ?? defaultAFError()
    }
}


extension APIError.ParameterEncodingFailureReason {
    var localizedDescription: String {
        switch self {
        case .missingURL:
            return "URL request to encode was missing a URL"
        case let .jsonEncodingFailed(error):
            return "JSON could not be encoded because of error:\n\(error.localizedDescription)"
        case let .customEncodingFailed(error):
            return "Custom parameter encoder failed with error: \(error.localizedDescription)"
        case .missingMethod:
            return "URL request to encoding was missing a http method"
        }
    }
}

extension APIError.ParameterEncodingFailureReason {
    var underlyingError: Error? {
        switch self {
        case let .jsonEncodingFailed(error),
             let .customEncodingFailed(error):
            return error
        case .missingURL, .missingMethod:
            return nil
        }
    }
}
