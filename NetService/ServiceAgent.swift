//
//  APIServiceAgent.swift
//  NetService
//
//  Created by steven on 2021/1/22.
//

import Foundation

public typealias CompletionResult = (_ response: DataResponse) -> Void

public protocol Service: AnyObject {
    
    static var shared: Service { get }
    
    subscript(_ task: URLSessionTask) -> BaseAPIService? { get set }
    
    func data(with request: URLRequest,
              credential: URLCredential?,
              uploadProgress: ((_ uploadProgress: Progress) -> Void)?,
              downloadProgress: ((_ downloadProgress: Progress) -> Void)?,
              completionHandler: @escaping CompletionResult
    ) -> URLSessionDataTask
    
    func upload(with upload: Uploadable,
                credential: URLCredential?,
                uploadProgress: ((_ uploadProgress: Progress) -> Void)?,
                downloadProgress: ((_ downloadProgress: Progress) -> Void)?,
                completionHandler: @escaping CompletionResult
    ) -> URLSessionDataTask
    
    func download(with download: Downloadable,
                  credential: URLCredential?,
                  destinationHandler: DestinationClosure?,
                  uploadProgress: ((_ uploadProgress: Progress) -> Void)?,
                  downloadProgress: ((_ downloadProgress: Progress) -> Void)?,
                  completionHandler: @escaping (_ response: DownloadResponse) -> Void
    ) -> URLSessionDownloadTask
}

public final class ServiceAgent: NSObject {
    
    private var manager: URLSessionManager
    
    private var requestMap: [Int: BaseAPIService] = [:]
    
    private var lock: NSLock = NSLock()
    
    let serviceQueue: DispatchQueue = DispatchQueue(label: "org.netservice.session-manager." + UUID().uuidString)
    
    let isInBackgroundSession: Bool
    
    private override init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = NetBuilders.HTTPHeader.defaultFields
        if #available(iOS 11.0, *) {
            configuration.waitsForConnectivity = true
        }
        configuration.allowsCellularAccess = true
        isInBackgroundSession = (configuration.identifier != nil)
        manager = URLSessionManager(configuration:configuration, queue: serviceQueue)
        super.init()
    }
    
    init(configurate: ((_ configuration: URLSessionConfiguration) -> URLSessionConfiguration)? = nil) {
        var configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = NetBuilders.HTTPHeader.defaultFields
        if #available(iOS 11.0, *) {
            configuration.waitsForConnectivity = true
        }
        configuration.allowsCellularAccess = true
        configuration = configurate?(configuration) ?? configuration
        isInBackgroundSession = (configuration.identifier != nil)
        manager = URLSessionManager(configuration: configuration, queue: serviceQueue)
        super.init()
    }
}


extension ServiceAgent: Service {
    
    public static let shared: Service = {
        let client = ServiceAgent { (configuration) -> URLSessionConfiguration in
            let config = configuration
            config.httpAdditionalHeaders = NetBuilders.HTTPHeader.defaultFields
            config.allowsCellularAccess = true
            if #available(iOS 11.0, *) {
                configuration.waitsForConnectivity = true
            }
            return config
        }
        return client
    }()
    
    public subscript(_ task: URLSessionTask) -> BaseAPIService? {
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
    
    public func data(with request: URLRequest,
                     credential: URLCredential?,
                     uploadProgress: ((Progress) -> Void)?,
                     downloadProgress: ((Progress) -> Void)?,
                     completionHandler: @escaping CompletionResult) -> URLSessionDataTask {
        let completion = completionHandler
        let dataTask = manager.data(with: request,
                                    credential: credential,
                                    uploadProgress: uploadProgress,
                                    downloadProgress: downloadProgress) { (res: TaskResult) in
            let result = DataResponse.serializeResponseData(response: res.response, data: res.data, error: res.error)
            let response = DataResponse(request: res.task.originalRequest ?? request, response: res.response, data: res.data, metrics: res.metrics ,result: result)
            completion(response)
            
        }
        
        return dataTask
    }
    
    public func upload(with upload: Uploadable,
                       credential: URLCredential?,
                       uploadProgress: ((Progress) -> Void)?, downloadProgress: ((Progress) -> Void)?, completionHandler: @escaping CompletionResult) -> URLSessionDataTask {
        let completion = completionHandler
        let uploadTask = manager.upload(with: upload,
                                        credential: credential,
                                        uploadProgress: uploadProgress,
                                        downloadProgress: downloadProgress) { (res: TaskResult) in
            let result = DataResponse.serializeResponseData(response: res.response, data: res.data, error: res.error)
            
            let response = DataResponse(request: res.task.originalRequest ?? upload.request(), response: res.response, data: res.data, metrics: res.metrics, result: result)
            completion(response)
        }
        return uploadTask
    }
    
    public func download(with download: Downloadable,
                         credential: URLCredential?,
                         destinationHandler: DestinationClosure?,
                         uploadProgress: ((Progress) -> Void)?,
                         downloadProgress: ((Progress) -> Void)?,
                         completionHandler: @escaping (_ response: DownloadResponse) -> Void
    ) -> URLSessionDownloadTask {
        let completion = completionHandler
        return manager.download(with: download,
                                credential: credential,
                                destinationHandler: destinationHandler,
                                uploadProgress: uploadProgress,
                                downloadProgress: downloadProgress) { (res: TaskResult) in
            let result = DownloadResponse.downloadResponseSerializer(response: res.response, fileURL: res.downloadFileURL, error: res.error)
            let response = DownloadResponse(response: res.response, destinationURL: res.downloadFileURL, resumeData: res.resumeData, metrics: res.metrics, result: result)
            completion(response)
        }
    }
    
}
