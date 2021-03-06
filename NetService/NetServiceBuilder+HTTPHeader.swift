//
//  APIRequests.swift
//  NetService
//
//  Created by steven on 2021/1/1.
//

import Foundation

extension NetServiceBuilder {
    // MARK: - HTTPHeader

    /// A representation of a single HTTP header's name / value pair.
    
    public struct HTTPHeader: Hashable {
        
        public enum HeaderField {
            static let contentLength = "Content-Length"
            static let contentType = "Content-Type"
            static let accept = "Accept"
            static let acceptEncoding = "Accept-Encoding"
            static let contentEncoding = "Content-Encoding"
            static let cacheControl = "Cache-Control"
            static let authorization = "Authorization"
            static let userAgent = "User-Agent"
            static let acceptLanguage = "Accept-Language"
            static let acceptCharset = "Accept-Charset"
        }
        
        /// Name of the header.
        public let name: String

        /// Value of the header.
        public let value: String

        /// Creates an instance from the given `name` and `value`.
        ///
        /// - Parameters:
        ///   - name:  The name of the header.
        ///   - value: The value of the header.
        public init(name: String, value: String) {
            self.name = name
            self.value = value
        }
        
        public func dictionary() -> [String: String] {
            return [name:value]
        }
    }
}

extension NetServiceBuilder.HTTPHeader: CustomStringConvertible {
    public var description: String {
        "\(name): \(value)"
    }
}


extension NetServiceBuilder.HTTPHeader {
    /// Returns an `Accept` header.
    ///
    /// - Parameter value: The `Accept` value.
    /// - Returns:         The header.
    public static func accept(_ value: String) -> NetServiceBuilder.HTTPHeader {
        NetServiceBuilder.HTTPHeader(name: HeaderField.accept, value: value)
    }

    /// Returns an `Accept-Charset` header.
    ///
    /// - Parameter value: The `Accept-Charset` value.
    /// - Returns:         The header.
    public static func acceptCharset(_ value: String) -> NetServiceBuilder.HTTPHeader {
        NetServiceBuilder.HTTPHeader(name: HeaderField.acceptCharset, value: value)
    }

    /// Returns an `Accept-Language` header.
    ///
    /// NetService offers a default Accept-Language header that accumulates and encodes the system's preferred languages.
    /// Use `HTTPHeader.defaultAcceptLanguage`.
    ///
    /// - Parameter value: The `Accept-Language` value.
    ///
    /// - Returns:         The header.
    public static func acceptLanguage(_ value: String) -> NetServiceBuilder.HTTPHeader {
        NetServiceBuilder.HTTPHeader(name: HeaderField.acceptLanguage, value: value)
    }

    /// Returns an `Accept-Encoding` header.
    ///
    /// NetService offers a default accept encoding value that provides the most common values. Use
    /// `HTTPHeader.defaultAcceptEncoding`.
    ///
    /// - Parameter value: The `Accept-Encoding` value.
    ///
    /// - Returns:         The header
    public static func acceptEncoding(_ value: String) -> NetServiceBuilder.HTTPHeader {
        NetServiceBuilder.HTTPHeader(name: HeaderField.acceptEncoding, value: value)
    }

    /// Returns a `Basic` `Authorization` header using the `username` and `password` provided.
    ///
    /// - Parameters:
    ///   - username: The username of the header.
    ///   - password: The password of the header.
    ///
    /// - Returns:    The header.
    public static func authorization(username: String, password: String) -> NetServiceBuilder.HTTPHeader {
//        let credential = Data("\(username):\(password)".utf8).base64EncodedString()

//        return authorization("Basic \(credential)")
        return authorization(NetServiceBuilder.Authorization.basic(user: username, password: password).rawValue)
    }

    /// Returns a `Bearer` `Authorization` header using the `bearerToken` provided
    ///
    /// - Parameter bearerToken: The bearer token.
    ///
    /// - Returns:               The header.
    public static func authorization(bearerToken: String) -> NetServiceBuilder.HTTPHeader {
//        authorization("Bearer \(bearerToken)")
        return authorization(NetServiceBuilder.Authorization.bearer(token: bearerToken).rawValue)
    }

    /// Returns an `Authorization` header.
    ///
    /// NetService provides built-in methods to produce `Authorization` headers. For a Basic `Authorization` header use
    /// `HTTPHeader.authorization(username:password:)`. For a Bearer `Authorization` header, use
    /// `HTTPHeader.authorization(bearerToken:)`.
    ///
    /// - Parameter value: The `Authorization` value.
    ///
    /// - Returns:         The header.
    public static func authorization(_ value: String) -> NetServiceBuilder.HTTPHeader {
        NetServiceBuilder.HTTPHeader(name: HeaderField.authorization, value: value)
    }

    /// Returns a `Content-Disposition` header.
    ///
    /// - Parameter value: The `Content-Disposition` value.
    ///
    /// - Returns:         The header.
    public static func contentDisposition(_ value: String) -> NetServiceBuilder.HTTPHeader {
        NetServiceBuilder.HTTPHeader(name: "Content-Disposition", value: value)
    }

    /// Returns a `Content-Type` header.
    ///
    /// `ParameterEncoding`s set the `Content-Type` of the request, so it may not be necessary to manually
    /// set this value.
    ///
    /// - Parameter value: The `Content-Type` value.
    ///
    /// - Returns:         The header.
    public static func contentType(_ value: String) -> NetServiceBuilder.HTTPHeader {
        NetServiceBuilder.HTTPHeader(name: HeaderField.contentType, value: value)
    }
    
    /// Returns a `Content-Length` header.
    ///
    /// `ParameterEncoding`s set the `Content-Length` of the request, so it may not be necessary to manually
    /// set this value.
    ///
    /// - Parameter value: The `Content-Length` value.
    ///
    /// - Returns:         The header.
    public static func contentLength(_ value: UInt64) -> NetServiceBuilder.HTTPHeader {
        NetServiceBuilder.HTTPHeader(name: HeaderField.contentLength, value: "\(value)")
    }

    /// Returns a `User-Agent` header.
    ///
    /// - Parameter value: The `User-Agent` value.
    ///
    /// - Returns:         The header.
    public static func userAgent(_ value: String) -> NetServiceBuilder.HTTPHeader {
        NetServiceBuilder.HTTPHeader(name: HeaderField.userAgent, value: value)
    }
}

extension Array where Element == NetServiceBuilder.HTTPHeader {
    /// Case-insensitively finds the index of an `HTTPHeader` with the provided name, if it exists.
    func index(of name: String) -> Int? {
        let lowercasedName = name.lowercased()
        return firstIndex { $0.name.lowercased() == lowercasedName }
    }
}

//// MARK: - Defaults
//
extension NetServiceBuilder.HTTPHeader {
    /// The default set of `HTTPHeaders` used by NetService. Includes `Accept-Encoding`, `Accept-Language`, and
    /// `User-Agent`.
    public static let defaultFields: [String: String] = {
        let acceptEncoding = NetServiceBuilder.HTTPHeader.defaultAcceptEncoding
        let acceptLanguage = NetServiceBuilder.HTTPHeader.defaultAcceptLanguage
        let useragent = NetServiceBuilder.HTTPHeader.defaultUserAgent
        return [
            acceptEncoding.name: acceptEncoding.value,
            acceptLanguage.name: acceptLanguage.value,
            useragent.name: useragent.value
        ]
    }()
}

extension NetServiceBuilder.HTTPHeader {
    
    static let version: String = {
      return "1.0.2"
    }()
    /// Returns NetService's default `Accept-Encoding` header, appropriate for the encodings supported by particular OS
    /// versions.
    ///
    /// See the [Accept-Encoding HTTP header documentation](https://tools.ietf.org/html/rfc7230#section-4.2.3) .
    public static let defaultAcceptEncoding: NetServiceBuilder.HTTPHeader = {
        let encodings: [String]
        if #available(iOS 11.0, macOS 10.13, tvOS 11.0, watchOS 4.0, *) {
            encodings = [
                NetServiceBuilder.ContentEncoding.br.rawValue,
                NetServiceBuilder.ContentEncoding.gzip.rawValue,
                NetServiceBuilder.ContentEncoding.deflate.rawValue
            ]
        } else {
            encodings = [
                NetServiceBuilder.ContentEncoding.gzip.rawValue,
                NetServiceBuilder.ContentEncoding.deflate.rawValue
            ]
        }

        return .acceptEncoding(encodings.qualityEncoded())
    }()

    /// Returns NetService's default `Accept-Language` header, generated by querying `Locale` for the user's
    /// `preferredLanguages`.
    ///
    /// See the [Accept-Language HTTP header documentation](https://tools.ietf.org/html/rfc7231#section-5.3.5).
    public static let defaultAcceptLanguage: NetServiceBuilder.HTTPHeader = {
        .acceptLanguage(Locale.preferredLanguages.prefix(6).qualityEncoded())
    }()

    /// Returns NetService's default `User-Agent` header.
    ///
    /// See the [User-Agent header documentation](https://tools.ietf.org/html/rfc7231#section-5.5.3).
    ///
    /// Example: `iOS Example/1.0 (org.netservice.iOS-Example; build:1; iOS 13.0.0) NetService/5.0.0`
    public static let defaultUserAgent: NetServiceBuilder.HTTPHeader = {
        let info = Bundle.main.infoDictionary
        let executable = (info?[kCFBundleExecutableKey as String] as? String) ??
            (ProcessInfo.processInfo.arguments.first?.split(separator: "/").last.map(String.init)) ??
            "Unknown"
        let bundle = info?[kCFBundleIdentifierKey as String] as? String ?? "Unknown"
        let appVersion = info?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let appBuild = info?[kCFBundleVersionKey as String] as? String ?? "Unknown"

        let osNameVersion: String = {
            let version = ProcessInfo.processInfo.operatingSystemVersion
            let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
            let osName: String = {
                #if os(iOS)
                #if targetEnvironment(macCatalyst)
                return "macOS(Catalyst)"
                #else
                return "iOS"
                #endif
                #elseif os(watchOS)
                return "watchOS"
                #elseif os(tvOS)
                return "tvOS"
                #elseif os(macOS)
                return "macOS"
                #elseif os(Linux)
                return "Linux"
                #elseif os(Windows)
                return "Windows"
                #else
                return "Unknown"
                #endif
            }()

            return "\(osName) \(versionString)"
        }()

        let NetServiceVersion = "NetService/\(version)"

        let userAgent = "\(executable)/\(appVersion) (\(bundle); build:\(appBuild); \(osNameVersion)) \(NetServiceVersion)"

        return .userAgent(userAgent)
    }()
}

extension Collection where Element == String {
    func qualityEncoded() -> String {
        enumerated().map { index, encoding in
            let quality = 1.0 - (Double(index) * 0.1)
            return "\(encoding);q=\(quality)"
        }.joined(separator: ", ")
    }
}
