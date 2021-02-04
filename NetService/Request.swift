//
//  APIRequest.swift
//  NetService
//
//  Created by steven on 2020/12/31.
//

import Foundation

public protocol RequestConvertible: class {
    func asURLRequest(with httpbuilder: NetServiceBuilder, parameters: [String: Any]) throws -> URLRequest
}

public protocol NetServiceRequestProtocol: RequestConvertible {
    var urlString: String { get }
    
    var httpMethod: NetServiceBuilder.Method { get }
    
    var timeout: TimeInterval { get }
    
    var authorization: NetServiceBuilder.Authorization { get }
        
    var encoding: ParameterEncoding { get }
    
    var credential: URLCredential? { get }
    
    func httpHeaders() -> [String: String]
    
    func httpParameters() -> [String: Any]
            
    func httpBuilderHelper(builder: NetServiceBuilder) -> NetServiceBuilder
}

public extension NetServiceRequestProtocol {

    func asURLRequest(with httpbuilder: NetServiceBuilder, parameters: [String: Any]) throws -> URLRequest {
        let builder = httpbuilder
        guard let url = builder.url else {
            throw APIError.missingURL
        }
        var request = URLRequest(url: url,
                                 cachePolicy: URLRequest.CachePolicy(rawValue: builder.cache.rawValue) ?? .useProtocolCachePolicy,
                                 timeoutInterval: builder.timeout
        )
        request.networkServiceType = URLRequest.NetworkServiceType(rawValue: builder.serviceType.rawValue) ?? .default
        request.allowsCellularAccess = builder.allowsCellularAccess
        request.httpMethod = builder.httpMethod.rawValue
        for (headerField, headerValue) in builder.headers {
            request.setValue(headerValue, forHTTPHeaderField: headerField)
        }
        if let accept = builder.accept {
            request.setValue(accept.rawValue, forHTTPHeaderField: NetServiceBuilder.HTTPHeader.HeaderField.accept)
        }
        request.setValue(builder.contentType?.rawValue, forHTTPHeaderField: NetServiceBuilder.HTTPHeader.HeaderField.contentType)
        if let contentLength = builder.contentLength {
            request.setValue("\(contentLength)", forHTTPHeaderField: NetServiceBuilder.HTTPHeader.HeaderField.contentLength)
        }
        request.setValue(builder.acceptEncoding?.compactMap({$0.rawValue}).joined(separator: ", "), forHTTPHeaderField: NetServiceBuilder.HTTPHeader.HeaderField.acceptEncoding)
        request.setValue(builder.contentEncoding?.compactMap({$0.rawValue}).joined(separator: ", "), forHTTPHeaderField: NetServiceBuilder.HTTPHeader.HeaderField.contentEncoding)
        request.setValue(builder.cacheControl?.compactMap({$0.rawValue}).joined(separator: ", "), forHTTPHeaderField: NetServiceBuilder.HTTPHeader.HeaderField.cacheControl)
        if builder.authorization != .none {
            request.setValue(builder.authorization.rawValue, forHTTPHeaderField: NetServiceBuilder.HTTPHeader.HeaderField.authorization)
        }
        request.httpShouldHandleCookies = builder.handleCookies
        request.httpShouldUsePipelining = builder.usePipelining
        request = try encoding.encode(request, parameters: parameters)
        return request
    }
    
}
    

extension URLSessionTask {
    
    var apiState: NetServiceBuilder.State {
        return NetServiceBuilder.State(rawValue: self.state.rawValue) ?? .waitingForConnectivity
    }
}

extension String {
    var asURL: URL {
        if let url = URL(string: self) {
            return url
        }
        var set = CharacterSet()
        set.formUnion(.urlHostAllowed)
        set.formUnion(.urlPathAllowed)
        set.formUnion(.urlQueryAllowed)
        set.formUnion(.urlFragmentAllowed)
        return self.addingPercentEncoding(withAllowedCharacters: set).flatMap({ URL(string: $0) })!
    }
}
