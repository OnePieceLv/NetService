//
//  APIServiceAgent.swift
//  NetService
//
//  Created by steven on 2021/1/22.
//

import Foundation

public protocol Service: AnyObject {
    
    static var shared: Service { get }
    
    var isInBackgroundSession: Bool { get }
    
    subscript(_ task: URLSessionTask) -> NetServiceProtocol? { get set }
    
    func data(with request: URLRequest,
              parameter: URLSessionParameter,
              uploadProgress: ((_ uploadProgress: Progress) -> Void)?,
              downloadProgress: ((_ downloadProgress: Progress) -> Void)?,
              completionHandler: @escaping CompletionResult
    ) -> URLSessionDataTask
    
    func upload(with upload: Uploadable,
                parameter: URLSessionParameter,
                uploadProgress: ((_ uploadProgress: Progress) -> Void)?,
                downloadProgress: ((_ downloadProgress: Progress) -> Void)?,
                completionHandler: @escaping CompletionResult
    ) -> URLSessionDataTask
    
    func download(with download: Downloadable,
                  parameter: URLSessionParameter,
                  destinationHandler: DestinationClosure?,
                  uploadProgress: ((_ uploadProgress: Progress) -> Void)?,
                  downloadProgress: ((_ downloadProgress: Progress) -> Void)?,
                  completionHandler: @escaping (_ response: DownloadResponse) -> Void
    ) -> URLSessionDownloadTask
}

public final class ServiceAgent: NSObject {
    
    var manager: URLSessionManager
    
    private var requestMap: [Int: NetServiceProtocol] = [:]

    private var lock: NSLock = NSLock()
    
    let serviceQueue: DispatchQueue = DispatchQueue(label: "org.netservice.session-manager." + UUID().uuidString)
    
    private override init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = NetServiceBuilder.HTTPHeader.defaultFields
        if #available(iOS 11.0, *) {
            configuration.waitsForConnectivity = true
        }
        configuration.allowsCellularAccess = true
        manager = URLSessionManager(configuration:configuration, queue: serviceQueue)
        super.init()
        manager.service = self
    }
    
    public init(configurate: ((_ configuration: URLSessionConfiguration) -> URLSessionConfiguration)? = nil, serverTrustPolicyManager: ServerTrustPolicyManager? = nil) {
        var configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = NetServiceBuilder.HTTPHeader.defaultFields
        if #available(iOS 11.0, *) {
            configuration.waitsForConnectivity = true
        }
        configuration.allowsCellularAccess = true
        configuration = configurate?(configuration) ?? configuration
        manager = URLSessionManager(configuration: configuration,
                                    delegate: SessionDelegate(),
                                    queue: serviceQueue,
                                    serverTrustPolicyManager: serverTrustPolicyManager
        )
        super.init()
        manager.service = self
    }
}


extension ServiceAgent: Service {
    
    public var isInBackgroundSession: Bool {
        return manager.isInBackgroundSession
    }
    
    public static let shared: Service = {
        let client = ServiceAgent { (configuration) -> URLSessionConfiguration in
            let config = configuration
            config.httpAdditionalHeaders = NetServiceBuilder.HTTPHeader.defaultFields
            config.allowsCellularAccess = true
            if #available(iOS 11.0, *) {
                configuration.waitsForConnectivity = true
            }
            return config
        }
        return client
    }()
    
    public subscript(task: URLSessionTask) -> NetServiceProtocol? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return requestMap[task.taskIdentifier]
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            requestMap[task.taskIdentifier] = newValue
        }
    }
    
//    public subscript(_ task: URLSessionTask) -> APIService? {
//
//        get {
//            return manager[task]
//        }
//        set {
//            manager[task] = newValue
//        }
//    }
    
    public func data(with request: URLRequest,
                     parameter: URLSessionParameter,
                     uploadProgress: ((Progress) -> Void)?,
                     downloadProgress: ((Progress) -> Void)?,
                     completionHandler: @escaping CompletionResult) -> URLSessionDataTask {
        let completion = completionHandler
        let dataTask = manager.data(with: request,
                                    parameter: parameter,
                                    uploadProgress: uploadProgress,
                                    downloadProgress: downloadProgress) { (res: TaskResult) in
            let result = DataResponse.serializeResponseData(response: res.response, data: res.data, error: res.error)
            let response = DataResponse(request: res.task.originalRequest ?? request, response: res.response, data: res.data, metrics: res.metrics ,result: result)
            completion(response)
            
        }
        
        return dataTask
    }
    
    public func upload(with upload: Uploadable,
                       parameter: URLSessionParameter,
                       uploadProgress: ((Progress) -> Void)?, downloadProgress: ((Progress) -> Void)?, completionHandler: @escaping CompletionResult) -> URLSessionDataTask {
        let completion = completionHandler
        let uploadTask = manager.upload(with: upload,
                                        parameter: parameter,
                                        uploadProgress: uploadProgress,
                                        downloadProgress: downloadProgress) { (res: TaskResult) in
            let result = DataResponse.serializeResponseData(response: res.response, data: res.data, error: res.error)
            
            let response = DataResponse(request: res.task.originalRequest ?? upload.request(), response: res.response, data: res.data, metrics: res.metrics, result: result)
            completion(response)
        }
        return uploadTask
    }
    
    public func download(with download: Downloadable,
                         parameter: URLSessionParameter,
                         destinationHandler: DestinationClosure?,
                         uploadProgress: ((Progress) -> Void)?,
                         downloadProgress: ((Progress) -> Void)?,
                         completionHandler: @escaping (_ response: DownloadResponse) -> Void
    ) -> URLSessionDownloadTask {
        let completion = completionHandler
        return manager.download(with: download,
                                parameter: parameter,
                                destinationHandler: destinationHandler,
                                uploadProgress: uploadProgress,
                                downloadProgress: downloadProgress) { (res: TaskResult) in
            let result = DownloadResponse.downloadResponseSerializer(response: res.response, fileURL: res.downloadFileURL, error: res.error)
            let response = DownloadResponse(response: res.response, destinationURL: res.downloadFileURL, resumeData: res.resumeData, metrics: res.metrics, result: result)
            completion(response)
        }
    }
    
}
