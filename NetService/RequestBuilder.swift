//
//  RequestParameter.swift
//  NetService
//
//  Created by steven on 2021/1/1.
//

import Foundation

public struct RequestBuilder {
    
    public var url: URL?
    
    public var httpMethod: NetBuilders.Method = .GET
    
    public var cache: NetBuilders.CachePolicy = .useProtocolCachePolicy
    
    public var timeout: TimeInterval = 30.0
    
    public var serviceType: NetBuilders.ServiceType = .default
    
    public var contentType: NetBuilders.ContentType?
    
    public var contentLength: NetBuilders.ContentLength?
    
    public var accept: NetBuilders.ContentType?
    
    public var acceptEncoding: [NetBuilders.ContentEncoding]?
    
    public var contentEncoding: [NetBuilders.ContentEncoding]?
    
    public var cacheControl: [NetBuilders.CacheControl]?
    
    public var allowsCellularAccess: Bool = false
    
    public var headers: [String : String] = NetBuilders.HTTPHeader.defaultFields
    
    public var handleCookies: Bool = false
    
    public var usePipelining: Bool = false
    
    public var authorization: NetBuilders.Authorization = .none
    
}

extension RequestBuilder {
    
    init(urlString: String = "",
         timeout: TimeInterval = 30,
         httpMethod: NetBuilders.Method = .GET,
         cache: NetBuilders.CachePolicy = .useProtocolCachePolicy,
         serviceType: NetBuilders.ServiceType = .default,
         contentType: NetBuilders.ContentType? = nil,
         contentLength: NetBuilders.ContentLength? = nil,
         accept: NetBuilders.ContentType? = nil,
         acceptEncoding: [NetBuilders.ContentEncoding]? = nil,
         contentEncoding: [NetBuilders.ContentEncoding]? = nil,
         cacheControl: [NetBuilders.CacheControl]? = nil,
         allowsCellularAccess: Bool = false,
         headers: [String : String] = NetBuilders.HTTPHeader.defaultFields,
         handleCookies: Bool = false,
         usePipelining: Bool = false,
         authorization: NetBuilders.Authorization = .none
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
