//
//  APITaskRequest.swift
//  NetService
//
//  Created by steven on 2021/1/21.
//

import Foundation


public protocol APIService: AnyObject, Retryable {
    var apiService: BaseAPIService { get set }
    var middlewares: [Middleware] { get set }
    var retryPolicy: RetryPolicyProtocol? { get set }
    var state: NetBuilders.State { get }
    var task: URLSessionTask? { get set }
    var originalRequest: URLRequest? { get }
    var currentRequest: URLRequest? { get }
    var progressHandle: ((Progress) -> Void)? { get set }
    var completionClosure: (() -> Void)? { get set }
    func cancel() -> Void
    func suspend() -> Void
//    func resume(task: URLSessionTask?) -> Void
//    func prepareRequest(api: APIService) throws -> URLRequest
//    func addRequest(task: URLSessionTask) -> Void
//    func removeRequest(task: URLSessionTask?) -> Void
//    func clear() -> Void
//    func finishRequest() -> Void
}

public extension APIService {
    var middlewares: [Middleware] {
        get { apiService.middlewares }
        set { apiService.middlewares = newValue}
    }

    var state: NetBuilders.State {
        apiService.state
    }

    var task: URLSessionTask? {
        get { apiService.task }
        set { apiService.task = newValue}
    }

    var originalRequest: URLRequest? {
        apiService.originalRequest
    }

    var currentRequest: URLRequest? {
        apiService.currentRequest
    }

    func suspend() -> Void {
        guard let task = self.task else {
            return
        }
        task.suspend()
    }

    func cancel() -> Void {
        guard let task = self.task else {
            return
        }
        removeRequest(task: self.task)
        task.cancel()
    }
        
    
}

extension APIService {
    
    func resume(task: URLSessionTask?) -> Void {
        self.task = task
        middlewares.forEach({ $0.beforeSend(self) })
        guard let task = self.task else {
            return
        }
        addRequest(task: task)
        task.resume()
    }
    
    func prepareRequest(api: APIService) throws -> URLRequest {
         try apiService.prepareRequest(api: api)
    }
    
    func addRequest(task: URLSessionTask) -> Void {
        ServiceAgent.shared[task] = self
    }
    
    func removeRequest(task: URLSessionTask?) -> Void {
        guard let task = task else {
            return
        }
        ServiceAgent.shared[task] = nil
    }
    

    func finishRequest(_ clear:()-> Void) -> Void {
        middlewares.forEach({ $0.didStop(self) })
        clear()
    }

    func clear() -> Void {
        self.clean()
    }
    
    func clean() -> Void {
        self.removeRequest(task: self.task)
        self.progressHandle = nil
        self.completionClosure = nil
    }

}

// MARK: - Retry
extension APIService {
    
    public var retryPolicy: RetryPolicyProtocol? {
        get { apiService.retryPolicy }
        set { apiService.retryPolicy = newValue}
    }
    
    public var retryCount: Int {
        get { apiService.retryCount }
        set { apiService.retryCount = newValue }
    }
    
    public func resetRetry() {
        self.retryCount = 0
    }
    
    public func prepareRetry() {
        self.retryCount += 1
    }
}

public class BaseAPIService {
    
    var middlewares: [Middleware] = []
    
    // MARK: - Retry
    var retryPolicy: RetryPolicyProtocol? = DefaultRetryPolicy()
    
    var state: NetBuilders.State {
        return task?.apiState ?? .waitingForConnectivity
    }
    
    var task: URLSessionTask? {
        get { lock.lock(); defer { lock.unlock() }; return _task }
        set { lock.lock(); defer { lock.unlock() }; _task = newValue }
    }
    
    var originalRequest: URLRequest? {
        return task?.originalRequest
    }
    
    var currentRequest: URLRequest? {
        return task?.currentRequest
    }
    
    fileprivate var userCredential: URLCredential?
        
    private var lock: NSLock = NSLock()
    
    private var _task: URLSessionTask?
    
    fileprivate var builder: RequestBuilder = RequestBuilder()
    
    
    var retryCount: Int = 0
    
    private func conformance(api: APIService) throws -> NetServiceProtocol {
        if let netServiceAPI = (api as? NetServiceProtocol) {
            return netServiceAPI
        }
        throw APIError.customFailure(message: "Must be conformance APIRequestConvertible protocol")
    }
    
    private func authenticate(using credential: URLCredential) -> Void {
        self.userCredential = credential
    }
    
    func prepareRequest(api: APIService) throws -> URLRequest {
        let api = try conformance(api: api)
        var builderObj = RequestBuilder(urlString: api.urlString)
        builderObj.headers.merge(api.httpHeaders()) { (_, new) in new }
        builderObj.httpMethod = api.httpMethod
        builderObj.timeout = api.timeout
        if let userCredential = api.credential {
            authenticate(using: userCredential)
        } else {
            builderObj.authorization = api.authorization
        }
        builder = api.httpBuilderHelper(builder: builderObj)
        builder = middlewares.reduce(builder) { return $1.prepare($0) }
        
        let request = try api.asURLRequest(with: builder, parameters: api.httpParameters())
        return request
    }
}


extension BaseAPIService: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return self.debugDescription
    }
    
    public var debugDescription: String {
        var custom = "\r\n"
        var credential = "none"
        if let cre = self.userCredential {
            credential = "user: \(String(describing: cre.user)), password: \(String(describing: cre.password)), haspassword: \(cre.hasPassword), certificates: \(cre.certificates)"
        }
        if let api = (self as? NetServiceProtocol) {
            custom += "[Parameters: ] \(api.httpParameters())" + "\r\n"
            custom += "[Headers: ] \(self.builder.headers)" + "\r\n"
            custom += "[Authorization: ] \(api.authorization.description)" + "\r\n"
            custom += "[Method: ] \(api.httpMethod)" + "\r\n"
            custom += "[URL: ] \(api.urlString)" + "\r\n"
            custom += "[Credential: ] \(credential)" + "\r\n"
            custom += "\r\n"
        }
        return (custom)
    }
}

open class BaseDataService: NSObject, APIService {
    
    public var progressHandle: ((Progress) -> Void)?
    
    public var completionClosure: (() -> Void)?

    public var apiService: BaseAPIService = BaseAPIService()
        
    public var error: Error? {
        return response?.error
    }
        
    public var response: DataResponse?
    
    var requestType: Requestable?
    
    private var urlRequest: URLRequest?
    
    public func finishRequest() {
        if let completeHandler = self.completionClosure {
            completeHandler()
        }
        self.finishRequest {
            self.clear()
        }
    }
    
    
    public func clear() {
        urlRequest = nil
        requestType = nil
        self.clean()
    }
    
    private func handleComplete(response: DataResponse) -> Void {
        self.response = self.middlewares.reduce(response) { return $1.afterReceive($0) }
        self.finishRequest()
    }
    
}

// MARK: - start request
public extension BaseDataService {
    
    /// set progress
    func progress(progressClosure: @escaping (Progress) -> Void) -> Self {
        self.progressHandle = progressClosure
        return self
    }
    
    func async(service: Service = ServiceAgent.shared, completion: @escaping (_ request: BaseDataService) -> Void) -> Void {
        self.completionClosure = { [weak self] in
            guard let `self` = self else { return }
            DispatchQueue.main.async { completion(self) }
        }
        do {
            self.urlRequest = try prepareRequest(api: self)
        } catch {
            fatalError(error.localizedDescription)
        }
        guard let urlRequest = self.urlRequest else {
            fatalError("URLRequest is missing")
        }
        self.requestType = .request(urlRequest)
        let parameter = URLSessionParameter(credential: apiService.userCredential, retryPolicy: self.retryPolicy)
        let task = service.data(with: urlRequest,
                                parameter: parameter,
                                uploadProgress: nil,
                                downloadProgress: self.progressHandle
        ) { [weak self] (response: DataResponse) in
            guard let `self` = self else { return }
            self.handleComplete(response: response)
        }
        self.resume(task: task)
    }
    
    func sync(service: Service = ServiceAgent.shared) -> Self {
        do {
            self.urlRequest = try prepareRequest(api: self)
        } catch {
            fatalError(error.localizedDescription)
        }
        guard let urlRequest = self.urlRequest else {
            fatalError("URLRequest is missing")
        }
        self.requestType = .request(urlRequest)
        let semaphore = DispatchSemaphore(value: 0)
        let parameter = URLSessionParameter(credential: apiService.userCredential, retryPolicy: self.retryPolicy)
        let task = service.data(with: urlRequest,
                                parameter: parameter,
                                uploadProgress: nil,
                                downloadProgress: self.progressHandle
        ) { [weak self] (response: DataResponse) in
            guard let `self` = self else { return }
            self.handleComplete(response: response)
            semaphore.signal()
        }
        self.resume(task: task)
        semaphore.wait()
        return self
        
    }
    

}

// MARK: - transform
public extension BaseDataService {
    func transform<T: DataTransformProtocol>(with transform: T) throws -> T.TransformObject {
        if let response = self.response {
            return try transform.transform(response)
        }
        throw APIError.missingResponse
    }
}


open class BaseDownloadService: APIService {
    
    public var completionClosure: (() -> Void)?
    
    public var progressHandle: ((Progress) -> Void)?
    
    public var apiService: BaseAPIService = BaseAPIService()
    
    public var resumeData: Data? {
        get {
            if _resumeData != nil {
                return _resumeData
            } else {
                return response?.resumeData
            }
        }
        set { _resumeData = newValue }
    }
    
    public var downloadURL: URL? {
        return response?.downloadFileURL
    }
    
    public var downloadTask: URLSessionDownloadTask? {
        return task as? URLSessionDownloadTask
    }
    
    var downloadType: Downloadable?
    
    public var response: DownloadResponse?
    
    public var error: Error? {
        return response?.error
    }
    
    private var _resumeData: Data?
    
    func progress(progressClosure: @escaping ProgressClosure) -> Self {
        self.progressHandle = progressClosure
        return self
    }
    
    public func clear() {
        self.downloadType = nil
        self.clean()
    }
    
    public func cancel() {
        self.cancel(createResumeData: false)
    }

    public func cancel(createResumeData: Bool) {
        if createResumeData {
            self.downloadTask?.cancel { [weak self] (data) in
                guard let `self` = self else { return }
                self._resumeData = data
            }
        } else {
            self.downloadTask?.cancel()
        }
        self.removeRequest(task: self.task)
    }
}

public extension BaseDownloadService {
    
    func download(resumingWith resumeData: Data,
                  to destination: DestinationClosure? = nil,
                  progress: @escaping (Progress) -> Void,
                  service: Service = ServiceAgent.shared,
                  completion: @escaping ((_ request: BaseDownloadService) -> Void)
    ) -> Void {
        let downloadable: Downloadable = .resume(resumeData)
        self.download(with: downloadable, progress: progress, destination: destination, service: service, completion: completion)
    }
    
    func download(resumingWith resumeURL: URL,
                  to destination: DestinationClosure? = nil,
                  progress: @escaping (Progress) -> Void,
                  service: Service = ServiceAgent.shared,
                  completion: @escaping ((_ request: BaseDownloadService) -> Void)
    ) -> Void {
        do {
            let data = try Data(contentsOf: resumeURL)
            let downloadable: Downloadable = .resume(data)
            self.download(with: downloadable, progress: progress, destination: destination, service: service, completion: completion)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func download(progress: @escaping (Progress) -> Void,
                  to destination: DestinationClosure? = nil,
                  service: Service = ServiceAgent.shared,
                  completion: @escaping ((_ request: BaseDownloadService) -> Void)
    ) -> Void {
        do {
            let urlRequest = try prepareRequest(api: self)
            let downloadable: Downloadable = .request(urlRequest)
            self.download(with: downloadable, progress: progress, destination: destination, service: service, completion: completion)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    private func download(with downloadable: Downloadable,
                          progress: @escaping (Progress) -> Void,
                          destination: DestinationClosure?,
                          service: Service,
                          completion: @escaping ((_ request: BaseDownloadService) -> Void)
    ) -> Void {
        let parameter = URLSessionParameter(credential: apiService.userCredential, retryPolicy: self.retryPolicy)
        self.downloadType = downloadable
        let downloadTask = service.download(with: downloadable, parameter: parameter, destinationHandler: destination, uploadProgress: nil, downloadProgress: progress, completionHandler: { (downloadResponse: DownloadResponse) in
            self.response = self.middlewares.reduce(downloadResponse) { return $1.afterReceive($0) }
            self._resumeData = self.response?.resumeData
            completion(self)
            self.finishRequest {
                self.clear()
            }
        })
        self.resume(task: downloadTask)
    }
    
}

public extension BaseDownloadService {
    func transform<T: DownloadTransformProtocol>(with transform: T) throws -> T.TransformObject {
        if let downloadResponse = self.response {
            return try transform.transform(downloadResponse)
        }
        throw APIError.missingResponse
    }
}


open class BaseUploadService: NSObject, APIService {
    
    public var progressHandle: ((Progress) -> Void)?
    
    public var completionClosure: (() -> Void)?
    
    public var apiService: BaseAPIService = BaseAPIService()
    
    public func clear() {
        self.uploadProgress = nil
        self.uploadType = nil
        self.clean()
    }
    
    public var response: DataResponse?
    
    public static let multipartFormDataEncodingMemoryThreshold: UInt64 = 10_000_000
    
    var uploadProgress: ((Progress) -> Void)?
    
    var uploadType: Uploadable?
    
    func build(formdata: MultipartFormData, encodingMemoryThreshold: UInt64, isInBackgroundSession: Bool) throws -> (Uploadable, URLRequest?) {
        var request = try self.prepareRequest(api: self)
        request.setValue(formdata.contentType, forHTTPHeaderField: "Content-Type")
        
        let uploadable: Uploadable
        if formdata.contentLength < encodingMemoryThreshold && !isInBackgroundSession {
            let data = try formdata.encode()
            uploadable = .data(data, request)
        } else {
            let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            let directoryURL = temporaryDirectoryURL.appendingPathComponent("netservice.upload/multipart.form.data")
            let fileName = UUID().uuidString
            let fileURL = directoryURL.appendingPathComponent(fileName)


            do {
                // Create directory inside serial queue to ensure two threads don't do this in parallel
                var isDirectory: ObjCBool = true
                if FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory) {
                    try FileManager.default.removeItem(at: directoryURL)
                }
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)

                try formdata.writeEncodedData(to: fileURL)
                
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    throw APIError.multipartEncodingFailed(reason: APIError.MultipartEncodingFailureReason.bodyPartFileNotReachable(at: fileURL))
                }
            } catch {
                try? FileManager.default.removeItem(at: fileURL)
                throw error
            }

            uploadable = .file(fileURL, request)
        }
        return (uploadable, request)
    }
}

public extension BaseUploadService {
    
    func upload(data: Data,
                progress closure: ((Progress) -> Void)?,
                service: Service = ServiceAgent.shared,
                completion: @escaping (_ request: BaseUploadService) -> Void
    ) -> Void {
        do {
            let request = try prepareRequest(api: self)
            let upload: Uploadable = .data(data, request)
            self.upload(with: upload, progress: closure, completion: completion)
        } catch {
            fatalError(error.localizedDescription)
        }
        
        
    }
    
    func upload(file: URL,
                progress closure: ((Progress) -> Void)?,
                service: Service = ServiceAgent.shared,
                completion: @escaping (_ request: BaseUploadService) -> Void
    ) -> Void {
        do {
            let request = try prepareRequest(api: self)
            let upload: Uploadable = .file(file, request)
            self.upload(with: upload, progress: closure, completion: completion)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func upload(stream: InputStream,
                contentLength: UInt64,
                progress closure: ((Progress) -> Void)?,
                service: Service = ServiceAgent.shared,
                completion: @escaping (_ request: BaseUploadService) -> Void
    ) -> Void {
        do {
            var request = try prepareRequest(api: self)
            let header: NetBuilders.HTTPHeader = NetBuilders.HTTPHeader.contentLength(contentLength)
            request.setValue(header.value, forHTTPHeaderField: header.name)
            let upload: Uploadable = .stream(stream, request)
            self.upload(with: upload, progress: closure, completion: completion)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func upload(multipartformdata: @escaping (MultipartFormData) -> Void,
                isInMemoryThreshold: UInt64 = BaseUploadService.multipartFormDataEncodingMemoryThreshold,
                progress closure: ((Progress) -> Void)?,
                service: Service = ServiceAgent.shared,
                completion: @escaping (_ request: BaseUploadService) -> Void
    ) -> Void {
        let formdata = MultipartFormData()
        multipartformdata(formdata)
        do {
            let (uploadable, _) = try build(formdata: formdata,
                               encodingMemoryThreshold: isInMemoryThreshold,
                               isInBackgroundSession: service.isInBackgroundSession)
            self.upload(with: uploadable, progress: closure, completion: completion)
        } catch {
            fatalError(error.localizedDescription)
        }
        
    }
    
    private func upload(with upload: Uploadable,
                        progress closure: ((Progress) -> Void)?,
                        service: Service = ServiceAgent.shared,
                        completion: @escaping (_ request: BaseUploadService) -> Void
    ) {
        self.uploadProgress = closure
        self.uploadType = upload
        let parameter = URLSessionParameter(credential: apiService.userCredential, retryPolicy: self.retryPolicy)
        let task = service.upload(with: upload, parameter: parameter, uploadProgress: uploadProgress, downloadProgress: nil) { (response: DataResponse) in
            self.response = self.middlewares.reduce(response) { $1.afterReceive($0) }
            print(response.statusCode)
            completion(self)
            self.finishRequest {
                self.clear()
            }
        }
        self.resume(task: task)
    }
}


