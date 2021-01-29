//
//  ParameterEncoding.swift
//  NetService
//
//  Created by steven on 2021/1/3.
//

import Foundation

public protocol ParameterEncoding {
    func encode(_ request: URLRequest, parameters: [String: Any]) throws -> URLRequest
}

public struct URLEncoding: ParameterEncoding {
    
    public enum EncodingFormat {
        case methodDependent
        case queryString
        case httpBody
        
        func encodesParametersInURL(for method: NetBuilders.Method) -> Bool {
            switch self {
            case .methodDependent: return [NetBuilders.Method.GET, NetBuilders.Method.HEAD, NetBuilders.Method.DELETE].contains(method)
            case .queryString: return true
            case .httpBody: return false
            }
        }
    }
    
    public static var `default`: URLEncoding { URLEncoding() }
    
    public static var queryString: URLEncoding { URLEncoding(destination: .queryString) }
    
    public static var httpBody: URLEncoding { URLEncoding(destination: .httpBody) }
    
    public let destination: EncodingFormat
    
    public init(destination: EncodingFormat = .methodDependent) {
        self.destination = destination
    }
    
    public func encode(_ request: URLRequest, parameters: [String: Any]) throws -> URLRequest {
        var apiRequest = request
        let urlParameters = parameters
        guard let url = apiRequest.url else {
            throw APIError.parameterEncodingFailed(reason: APIError.ParameterEncodingFailureReason.missingURL)
        }
        guard !parameters.isEmpty else {
            return apiRequest
        }
        guard let method = apiRequest.httpMethod else {
            throw APIError.parameterEncodingFailed(reason: APIError.ParameterEncodingFailureReason.missingMethod)
        }
        let httpMethod = NetBuilders.Method.init(rawValue: method) ?? NetBuilders.Method.GET
        if destination.encodesParametersInURL(for: httpMethod) {
            if var components = URLComponents(url: url, resolvingAgainstBaseURL: false), !urlParameters.isEmpty {
                let percentEncodedQuery = query(urlParameters)
                components.percentEncodedQuery = percentEncodedQuery
                if let url = components.url {
                    apiRequest.url = url
                }
            }
        } else {
            let contentType = NetBuilders.HTTPHeader.contentType(NetBuilders.ContentType.formURL.rawValue)
            apiRequest.setValue(contentType.value, forHTTPHeaderField: contentType.name)
            apiRequest.httpBody = query(urlParameters).data(using: .utf8)
            if let body = apiRequest.httpBody, body.count > 0 {
                let contentLength = NetBuilders.ContentLength(body.count)
                apiRequest.setValue("\(contentLength)", forHTTPHeaderField: NetBuilders.HTTPHeader.HeaderField.contentLength)
            }
        }
        return apiRequest
    }
}

extension ParameterEncoding {
    func query(_ parameters: [String: Any]) -> String {
        var components = [(String, String)]()

        for key in parameters.keys.sorted(by: <) {
            if let value = parameters[key] {
                components += queryComponents(key, value: value)
            }
        }

        return components.map { "\($0)=\($1)" }.joined(separator: "&")
    }
    
    func queryComponents(_ key: String, value: Any) -> [(String, String)] {
        var components: [(String, String)] = []

        if let dictionary = value as? [String: Any] {
            for (dictionaryKey, value) in dictionary {
                components += queryComponents("\(key)[\(dictionaryKey)]", value: value)
            }
        } else if let array = value as? [Any] {
            for value in array {
                components += queryComponents("\(key)[]", value: value)
            }
        } else if let value = value as? NSNumber {
            if CFBooleanGetTypeID() == CFGetTypeID(value) {
                components.append((escape(key), escape((value.boolValue ? "1" : "0"))))
            } else {
                components.append((escape(key), escape("\(value)")))
            }
        } else if let bool = value as? Bool {
            components.append((escape(key), escape((bool ? "1" : "0"))))
        } else {
            components.append((escape(key), escape("\(value)")))
        }

        return components
    }

    func escape(_ string: String) -> String {
        /// RFC 3986 states that the following characters are "reserved" characters.
        ///
        /// - General Delimiters: ":", "#", "[", "]", "@", "?", "/"
        /// - Sub-Delimiters: "!", "$", "&", "'", "(", ")", "*", "+", ",", ";", "="
        ///
        /// In RFC 3986 - Section 3.4, it states that the "?" and "/" characters should not be escaped to allow
        /// query strings to include a URL. Therefore, all "reserved" characters with the exception of "?" and "/"
        /// should be percent-escaped in the query string.
        
        let generalDelimitersToEncode = ":#[]@"
        let subDelimitersToEncode = "!$&'()*+,;="

        var allowedCharacterSet = CharacterSet.urlQueryAllowed
        allowedCharacterSet.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        var escaped = ""
        
        /// refer to - https://github.com/Alamofire/Alamofire/issues/206
        ///  Batching is required for escaping due to an internal bug in iOS 8.1 and 8.2. Encoding more than a few
        ///  hundred Chinese characters causes various malloc error crashes. To avoid this issue until iOS 8 is no
        ///  longer supported, batching MUST be used for encoding. This introduces roughly a 20% overhead. For more
        ///  info,
        if #available(iOS 8.3, *) {
            escaped = string.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) ?? string
        } else {
            let batchSize = 50
            var index = string.startIndex

            while index != string.endIndex {
                let startIndex = index
                let endIndex = string.index(index, offsetBy: batchSize, limitedBy: string.endIndex) ?? string.endIndex
                let range = startIndex..<endIndex

                let substring = string[range]

                escaped += substring.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) ?? String(substring)

                index = endIndex
            }
        }
        return escaped
    }
}
