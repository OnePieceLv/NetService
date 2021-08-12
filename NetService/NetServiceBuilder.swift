//
//  RequestParameter.swift
//  NetService
//
//  Created by steven on 2021/1/1.
//

import Foundation

public struct NetServiceBuilder {
    
    public typealias ContentLength = UInt64
    
    public enum CachePolicy: UInt {
        case useProtocolCachePolicy = 0, reloadIgnoringLocalCacheData = 1, returnCacheDataElseLoad = 2, returnCacheDataDontLoad = 3
    }
    
    public enum ServiceType: UInt {
        case `default`, voip, video, background, voice, responsiveData = 6, callSignaling = 11
    }
    
    public enum Method: String {
        case GET, POST, PUT, DELETE, PATCH, UPDATE, HEAD, TRACE, OPTIONS, CONNECT, SEARCH, COPY, MERGE, LABEL, LOCK, UNLOCK, MOVE, MKCOL, PROPFIND, PROPPATCH
    }
    
    public enum ContentEncoding: String, CaseIterable {
        case gzip, compress, deflate, identity, br
    }
    
    public enum State : Int {
        case running, suspended, canceling, completed, waitingForConnectivity
    }
    
    public var url: URL?
    
    public var httpMethod: Method = .GET
    
    public var cache: CachePolicy = .useProtocolCachePolicy
    
    public var timeout: TimeInterval = 30.0
    
    public var serviceType: ServiceType = .default
    
    public var contentType: NetServiceBuilder.ContentType?
    
    public var contentLength: NetServiceBuilder.ContentLength?
    
    public var accept: NetServiceBuilder.ContentType?
    
    public var acceptEncoding: [ContentEncoding]?
    
    public var contentEncoding: [ContentEncoding]?
    
    public var cacheControl: [NetServiceBuilder.CacheControl]?
    
    public var allowsCellularAccess: Bool = true
    
    public var headers: [String : String] = NetServiceBuilder.HTTPHeader.defaultFields
    
    public var handleCookies: Bool = false
    
    public var usePipelining: Bool = false
    
    public var authorization: NetServiceBuilder.Authorization = .none
    
}

public extension NetServiceBuilder {
    
    init(urlString: String = "",
         timeout: TimeInterval = 30,
         httpMethod: NetServiceBuilder.Method = .GET,
         cache: NetServiceBuilder.CachePolicy = .useProtocolCachePolicy,
         serviceType: NetServiceBuilder.ServiceType = .default,
         contentType: NetServiceBuilder.ContentType? = nil,
         contentLength: NetServiceBuilder.ContentLength? = nil,
         accept: NetServiceBuilder.ContentType? = nil,
         acceptEncoding: [ContentEncoding]? = nil,
         contentEncoding: [ContentEncoding]? = nil,
         cacheControl: [NetServiceBuilder.CacheControl]? = nil,
         allowsCellularAccess: Bool = true,
         headers: [String : String] = NetServiceBuilder.HTTPHeader.defaultFields,
         handleCookies: Bool = false,
         usePipelining: Bool = false,
         authorization: NetServiceBuilder.Authorization = .none
    ){
        url = URL(string: urlString)
        self.timeout = timeout
        self.httpMethod = httpMethod
        self.cache = .useProtocolCachePolicy
        self.serviceType = serviceType
        self.contentType = contentType
        self.accept = accept
        self.contentLength = contentLength
        /// 客户端可以事先声明一系列的可以支持压缩模式，与请求一齐发送。 Accept-Encoding 这个首部就是用来进行这种内容编码形式协商的：
        if #available(iOS 11.0, macOS 10.13, tvOS 11.0, watchOS 4.0, *) {
            self.acceptEncoding = [.br, .gzip, .deflate]
        } else {
            self.acceptEncoding = [.gzip, .deflate]
        }
        if acceptEncoding != nil {
            self.acceptEncoding = acceptEncoding
        }
        /// 服务器在 Content-Encoding 响应首部提供了实际采用的压缩模式：
        self.contentEncoding = contentEncoding
        self.cacheControl = cacheControl
        self.allowsCellularAccess = allowsCellularAccess
        self.headers = headers
        self.handleCookies = handleCookies
        self.usePipelining = usePipelining
        self.authorization = authorization
    }
    
}
