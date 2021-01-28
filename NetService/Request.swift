//
//  APIRequest.swift
//  Merlin-iOS
//
//  Created by steven on 2020/12/31.
//

import Foundation

public protocol RequestConvertible: class {
    func asURLRequest(with httpbuilder: RequestBuilder) throws -> URLRequest
}

public protocol NetServiceProtocol: RequestConvertible {
    var urlString: String { get }
    
    var httpMethod: NetBuilders.Method { get }
    
    var parameters: [String:Any] { get set }
    
    var timeout: TimeInterval { get }
    
    var authorization: NetBuilders.Authorization { get }
    
    var headers: [String : String] { get set }
    
    var encoding: ParameterEncoding { get }
            
    func httpBuilderHelper(builder: RequestBuilder?) -> RequestBuilder
}

public extension NetServiceProtocol {
    
    var urlString: String { "" }
    
    var httpMethod: NetBuilders.Method { .GET }
    
    var timeout: TimeInterval { 30 }
    
    var authorization: NetBuilders.Authorization { .none }
    
    var encoding: ParameterEncoding { URLEncoding.default }
    
    func httpBuilderHelper(builder: RequestBuilder?) -> RequestBuilder {
        let httpBuilder = builder ?? RequestBuilder()
        return httpBuilder
    }

    func asURLRequest(with httpbuilder: RequestBuilder) throws -> URLRequest {
        var builder = httpbuilder
        if !headers.isEmpty {
            builder.headers.merge(self.headers) { (_, new) -> String in
                new
            }
        }
        guard let url = builder.url else {
            throw APIError.missingURL
        }
        
        builder.timeout = timeout
        builder.authorization = authorization
        builder.httpMethod = httpMethod
        var request = URLRequest(url: url,
                                 cachePolicy: URLRequest.CachePolicy(rawValue: builder.cache.rawValue) ?? .useProtocolCachePolicy,
                                 timeoutInterval: timeout
        )
        request.networkServiceType = URLRequest.NetworkServiceType(rawValue: builder.serviceType.rawValue) ?? .default
        request.allowsCellularAccess = builder.allowsCellularAccess
        request.httpMethod = builder.httpMethod.rawValue
        for (headerField, headerValue) in builder.headers {
            request.setValue(headerValue, forHTTPHeaderField: headerField)
        }
        if let accept = builder.accept {
            request.setValue(accept.rawValue, forHTTPHeaderField: NetBuilders.HTTPHeader.HeaderField.accept)
        }
        request.setValue(builder.contentType?.rawValue, forHTTPHeaderField: NetBuilders.HTTPHeader.HeaderField.contentType)
        if let contentLength = builder.contentLength {
            request.setValue("\(contentLength)", forHTTPHeaderField:NetBuilders.HTTPHeader.HeaderField.contentLength)
        }
        request.setValue(builder.acceptEncoding?.compactMap({$0.rawValue}).joined(separator: ", "), forHTTPHeaderField: NetBuilders.HTTPHeader.HeaderField.acceptEncoding)
        request.setValue(builder.contentEncoding?.compactMap({$0.rawValue}).joined(separator: ", "), forHTTPHeaderField: NetBuilders.HTTPHeader.HeaderField.contentEncoding)
        request.setValue(builder.cacheControl?.compactMap({$0.rawValue}).joined(separator: ", "), forHTTPHeaderField: NetBuilders.HTTPHeader.HeaderField.cacheControl)
        if authorization != .none {
            request.setValue(authorization.rawValue, forHTTPHeaderField: NetBuilders.HTTPHeader.HeaderField.authorization)
        }
        request.httpShouldHandleCookies = builder.handleCookies
        request.httpShouldUsePipelining = builder.usePipelining
        request = try encoding.encode(request, parameters: self.parameters)
        return request
    }
    
}
    

extension URLSessionTask {
    
    var apiState: NetBuilders.State {
        return NetBuilders.State(rawValue: self.state.rawValue) ?? .waitingForConnectivity
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
