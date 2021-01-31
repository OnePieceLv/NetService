//
//  MultipartFormData.swift
//  NetService
//
//  Created by steven on 2021/1/12.
//

import Foundation

#if os(iOS) || os(watchOS) || os(tvOS)
import MobileCoreServices
#elseif os(macOS)
import CoreServices
#endif

public class MultipartFormData {
    
    
    
    struct EncodingCharacters {
        static let crlf = "\r\n"
    }
    
    struct Boundary {
        enum BoundaryType {
            case initial, encapsulated, final
        }
        
        static func randomBoundary() -> String {
            return String(format: "netservice.boundary.%08x%08x", arc4random(), arc4random())
        }
        
        static func boundaryData(forType type: BoundaryType, boundary: String) -> Data {
            let boundaryText: String
            
            switch type {
            case .initial:
                boundaryText = "--\(boundary)\(EncodingCharacters.crlf)"
            case .encapsulated:
                boundaryText = "\(EncodingCharacters.crlf)--\(boundary)\(EncodingCharacters.crlf)"
            case .final:
                boundaryText = "\(EncodingCharacters.crlf)--\(boundary)--\(EncodingCharacters.crlf)"
            }
            
            return boundaryText.data(using: .utf8, allowLossyConversion: false)!
        }
    }
    
    class BodyPart {
        
        let headers: [String: String]
        let bodyStream: InputStream
        let bodyContentLength: UInt64
        var hasInitialBoundary = false
        var hasFinalBoundary = false
        
        init(headers: [String: String], bodyStream: InputStream, bodyContentLength: UInt64) {
            self.headers = headers
            self.bodyStream = bodyStream
            self.bodyContentLength = bodyContentLength
        }
    }
    
    public var boundary: String
    
    public var contentLength: UInt64 { return bodyParts.reduce(0) { $0+$1.bodyContentLength } }
    
    public lazy var contentType: String = "multipart/form-data; boundary=\(self.boundary)"
    
    private var bodyParts: [BodyPart]
    
    private var bodyPartError: APIError?
    
    private let streamBufferSize: Int
    
    public init() {
        self.boundary = Boundary.randomBoundary()
        self.bodyParts = []
        
        ///
        /// The optimal read/write buffer size in bytes for input and output streams is 1024 (1KB). For more
        /// information, please refer to the following article:
        ///   - https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/Streams/Articles/ReadingInputStreams.html
        ///
        
        self.streamBufferSize = 1024
    }
}

public extension MultipartFormData {
    func append(_ data: Data, withName name: String) -> Void {
        let headers = contentHeaders(withName: name)
        let stream = InputStream(data: data)
        let length = UInt64(data.count)
        append(stream, withLength: length, headers: headers)
    }
    
    func append(_ data: Data, withName name: String, mimeType: String) -> Void {
        let headers = contentHeaders(withName: name, mimeType: mimeType)
        let stream = InputStream(data: data)
        let length = UInt64(data.count)
        append(stream, withLength: length, headers: headers)
    }
    
    func append(_ data: Data, withName name: String, fileName: String, mimeType: String) -> Void {
        let headers = contentHeaders(withName: name, fileName: fileName, mimeType: mimeType)
        let stream = InputStream(data: data)
        let length = UInt64(data.count)
        append(stream, withLength: length, headers: headers)
    }
    
    func append(_ fileURL: URL, withName name: String) -> Void {
        let fileName = fileURL.lastPathComponent
        let pathExtension = fileURL.pathExtension
        
        if !fileName.isEmpty && !pathExtension.isEmpty {
            let mime = mimeType(forPathExtension: pathExtension)
            append(fileURL, withName: name, fileName: fileName, mimeType: mime)
        } else {
            setBodyPartError(withReason: .bodyPartFilenameInvalid(in: fileURL))
        }
    }
    
    func append(_ fileURL: URL, withName name: String, fileName: String, mimeType: String) -> Void {
        let headers = contentHeaders(withName: name, fileName: fileName, mimeType: mimeType)
        // check 1 - is file URL?
        guard fileURL.isFileURL else {
            setBodyPartError(withReason: .bodyPartURLInvalid(url: fileURL))
            return
        }
        
        // check 2 - is file url reachable?
        
        do {
            let isReachable = try fileURL.checkPromisedItemIsReachable()
            guard isReachable else {
                setBodyPartError(withReason: .bodyPartFileNotReachable(at: fileURL))
                return
            }
        } catch {
            setBodyPartError(withReason: .bodyPartFileSizeQueryFailedWithError(forURL: fileURL, error: error))
            return
        }
        
        // check 3 - is file url a directory?
        var isDirectory: ObjCBool = false
        let path = fileURL.path
        
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && !isDirectory.boolValue else {
            setBodyPartError(withReason: .bodyPartFileIsDirectory(at: fileURL))
            return
        }
        
        // check 4 - can the file size be extracted?
        
        let bodyContentLength: UInt64
        
        do {
            guard let filesize = try FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber else {
                setBodyPartError(withReason: .bodyPartFileSizeNotAvailable(at: fileURL))
                return
            }
            bodyContentLength = filesize.uint64Value
        } catch {
            setBodyPartError(withReason: .bodyPartFileSizeQueryFailedWithError(forURL: fileURL, error: error))
            return
        }
        
        // check 5 - can a stream be created from file URL?
        guard let stream = InputStream(url: fileURL) else {
            setBodyPartError(withReason: .bodyPartInputStreamCreationFailed(for: fileURL))
            return
        }
        
        
        append(stream, withLength: bodyContentLength, headers: headers)
        
    }
    
    func append(_ stream: InputStream, withLength length: UInt64, name: String, fileName: String, mimeType: String) -> Void {
        let headers = contentHeaders(withName: name, fileName: fileName, mimeType: mimeType)
        append(stream, withLength: length, headers: headers)
    }
    
    // MARK: - Data Encoding
    
    func encode() throws -> Data {
        if let bodyPartError = bodyPartError {
            throw bodyPartError
        }
        var encoded = Data()
        
        bodyParts.first?.hasInitialBoundary = true
        bodyParts.last?.hasFinalBoundary = true
        
        for bodyPart in bodyParts {
            let encodedData = try encode(bodyPart)
            encoded.append(encodedData)
        }
        
        return encoded
    }
    
    // MARK: - Data write to Disk
    func writeEncodedData(to fileURL: URL) throws -> Void {
        if let bodyPartError = self.bodyPartError {
            throw bodyPartError
        }
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            throw APIError.multipartEncodingFailed(reason: .outputStreamFileAlreadyExists(at: fileURL))
        } else if !fileURL.isFileURL {
            throw APIError.multipartEncodingFailed(reason: .outputStreamURLInvalid(url: fileURL))
        }
        
        guard let outputStream = OutputStream(url: fileURL, append: false) else {
            throw APIError.multipartEncodingFailed(reason: .outputStreamCreationFailed(for: fileURL))
        }
        
        bodyParts.first?.hasInitialBoundary = true
        bodyParts.last?.hasFinalBoundary = true
        
        outputStream.open()
        defer {
            outputStream.close()
        }
        for bodyPart in bodyParts {
            try write(bodyPart, to: outputStream)
        }
        
    }
    
    // MARK: - Private Method
    
    // MARK: - Body Part Encoding
    private func encode(_ bodyPart: BodyPart) throws -> Data {
        var encoded = Data()
        
        /// body delimiter data
        let initialData = bodyPart.hasInitialBoundary ? initialBoundaryData() : encapsulateBoundaryData()
        encoded.append(initialData)
        
        /// body header data
        let headerData = encodeHeaders(for: bodyPart)
        encoded.append(headerData)
        
        /// body content stream data
        let bodyStreamData = try encodeBodyStream(for: bodyPart)
        encoded.append(bodyStreamData)

        
        /// final data
        if bodyPart.hasFinalBoundary {
            encoded.append(finalBoundaryData())
        }
        
        return encoded
    }
    
    private func encodeHeaders(for bodyPart: BodyPart) -> Data {
        let header = bodyPart.headers.reduce("") { (result, accumulator) -> String in
            return result + "\(accumulator.key): \(accumulator.value)\(EncodingCharacters.crlf)"
        }
        return (header + EncodingCharacters.crlf).data(using: .utf8, allowLossyConversion: false)!
    }
    
    private func encodeBodyStream(for bodyPart: BodyPart) throws -> Data {
        var encoded: Data = Data()
        let inputStream = bodyPart.bodyStream
        inputStream.open()
        defer {
            inputStream.close()
        }
        while inputStream.hasBytesAvailable {
            var buffer = [UInt8].init(repeating: 0, count: streamBufferSize)
            let readed = inputStream.read(&buffer, maxLength: buffer.count)
            if let error = inputStream.streamError {
                throw APIError.multipartEncodingFailed(reason: .inputStreamReadFailed(error: error))
            }
            if readed > 0 {
                encoded.append(buffer, count: readed)
            } else {
                break
            }
        }
        
        return encoded
    }
    
    // MARK: - write bodypart to output
    private func write(_ bodyPart: BodyPart, to outputStream: OutputStream) throws {
        try writeIntialBoundary(for: bodyPart, to: outputStream)
        try writeHeadersBoundary(for: bodyPart, to: outputStream)
        try writeBodyStreamBoundary(for: bodyPart, to: outputStream)
        try writeFinalBoundary(for: bodyPart, to: outputStream)
    }
    
    private func writeIntialBoundary(for bodyPart: BodyPart, to outputStream: OutputStream) throws {
        let data = bodyPart.hasInitialBoundary ? initialBoundaryData() : encapsulateBoundaryData()
        try write(data, to: outputStream)
    }
    
    private func writeHeadersBoundary(for bodyPart: BodyPart, to outputStream: OutputStream) throws {
        let data = encodeHeaders(for: bodyPart)
        try write(data, to: outputStream)
    }
    
    private func writeBodyStreamBoundary(for bodyPart: BodyPart, to outputStream: OutputStream) throws {
        let inputStream = bodyPart.bodyStream
        inputStream.open()
        defer { inputStream.close() }
        while inputStream.hasBytesAvailable {
            var buffer = [UInt8](repeating: 0, count: streamBufferSize)
            let readed = inputStream.read(&buffer, maxLength: streamBufferSize)
            
            if let streamError = inputStream.streamError {
                throw APIError.multipartEncodingFailed(reason: .inputStreamReadFailed(error: streamError))
            }
            
            if readed > 0 {
                if buffer.count != readed {
                    buffer = Array(buffer[0..<readed])
                }
                try write(&buffer, to: outputStream)
            } else {
                break
            }
        }
        
        
    }
    
    private func writeFinalBoundary(for bodyPart: BodyPart, to outputStream: OutputStream) throws {
        if bodyPart.hasFinalBoundary {
            return try write(finalBoundaryData(), to: outputStream)
        }
    }
    
    private func write(_ data: Data, to outputStream: OutputStream) throws {
        var buffer = [UInt8](repeating: 0, count: data.count)
        data.copyBytes(to: &buffer, count: data.count)
        
        try write(&buffer, to: outputStream)
    }
    
    private func write(_ buffer: inout [UInt8], to outputStream: OutputStream) throws {
        var bytesToWrites = buffer.count
        while bytesToWrites > 0, outputStream.hasSpaceAvailable {
            let writtenCount = outputStream.write(&buffer, maxLength: streamBufferSize)
            
            if let error = outputStream.streamError {
                throw APIError.multipartEncodingFailed(reason: APIError.MultipartEncodingFailureReason.outputStreamWriteFailed(error: error))
            }
            
            bytesToWrites -= writtenCount
            
            if bytesToWrites > 0 {
                buffer = Array(buffer[writtenCount..<buffer.count])
            }
        }
    }
    
    
    // MARK: - Append Body Part
    
    private func append(_ stream: InputStream, withLength length: UInt64, headers: [String: String]) {
        let bodyPart = BodyPart(headers: headers, bodyStream: stream, bodyContentLength: length)
        bodyParts.append(bodyPart)
    }
    
    // MARK: - Content Headers

    private func contentHeaders(withName name: String, fileName: String? = nil, mimeType: String? = nil) -> [String: String] {
        var disposition = "form-data; name=\"\(name)\""
        if let fileName = fileName { disposition += "; filename=\"\(fileName)\"" }

        var headers = ["Content-Disposition": disposition]
        if let mimeType = mimeType { headers["Content-Type"] = mimeType }

        return headers
    }
    
    // MARK: - Mime Type

    private func mimeType(forPathExtension pathExtension: String) -> String {
        if
            let id = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as CFString, nil)?.takeRetainedValue(),
            let contentType = UTTypeCopyPreferredTagWithClass(id, kUTTagClassMIMEType)?.takeRetainedValue()
        {
            return contentType as String
        }

        return "application/octet-stream"
    }
    
    // MARK: - Boundary Encoding
    
    private func initialBoundaryData() -> Data {
        return Boundary.boundaryData(forType: .initial, boundary: boundary)
    }
    
    private func encapsulateBoundaryData() -> Data {
        return Boundary.boundaryData(forType: .encapsulated, boundary: boundary)
    }
    
    private func finalBoundaryData() -> Data {
        return Boundary.boundaryData(forType: .final, boundary: boundary)
    }
    
    // MARK: - Errors

    private func setBodyPartError(withReason reason: APIError.MultipartEncodingFailureReason) {
        guard bodyPartError == nil else { return }
        bodyPartError = APIError.multipartEncodingFailed(reason: reason)
    }
}
