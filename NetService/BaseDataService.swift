//
//  APITaskRequest.swift
//  NetService
//
//  Created by steven on 2021/1/21.
//

import Foundation


public class BaseAPIService: NSObject {
    
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
        
    var middlewares: [Middleware] = []
    
    var progressHandle: ProgressClosure?
    
    var completionClosure: (() -> Void)?
    
    fileprivate var credential: URLCredential?
        
    private var lock: NSLock = NSLock()
    
    private var _task: URLSessionTask?
    
    private var builder: RequestBuilder = RequestBuilder()
    
    // MARK: - Retry
    var retryPolicy: RetryPolicyProtocol? = DefaultRetryPolicy()
    
    private var _retryCount: Int = 0
    
    private func conformance() throws -> NetServiceProtocol {
        if let api = (self as? NetServiceProtocol) {
            return api
        }
        throw APIError.customFailure(message: "Must be conformance APIRequestConvertible protocol")
    }
    
    private func authenticate(user: String, password: String, persistence: URLCredential.Persistence = .forSession) -> Void {
        let credential = URLCredential(user: user, password: password, persistence: persistence)
        authenticate(using: credential)
    }
    
    private func authenticate(using credential: URLCredential) -> Void {
        self.credential = credential
    }
    
    fileprivate func prepareRequest() throws -> URLRequest {
        let api = try conformance()
        builder = api.httpBuilderHelper(builder: RequestBuilder(urlString: api.urlString))
        builder = middlewares.reduce(builder) { return $1.prepare($0) }
        if case .basic(let user, let password) = builder.authorization {
            authenticate(user: user, password: password)
        }
        let request = try api.asURLRequest(with: builder)
        return request
    }
    
    fileprivate func beforeResume() -> Void {
        middlewares.forEach({ $0.beforeSend(self) })
    }
    
    fileprivate func finishRequest() -> Void {
        middlewares.forEach({ $0.didStop(self) })
        self.clear()
    }
    
    fileprivate func clear() -> Void {
        self.removeRequest(task: self.task)
        progressHandle = nil
        completionClosure = nil
    }
    
    fileprivate func resume(with task: URLSessionTask?) -> Void {
        if let task = task {
            self.task = task
        }
        guard let task = self.task else {
            return
        }
        self.addRequest(task: task)
        beforeResume()
        task.resume()
    }
    
    fileprivate func suspend() -> Void {
        guard let task = self.task else {
            return
        }
        task.suspend()
    }
    
    fileprivate func cancel() -> Void {
        guard let task = self.task else {
            return
        }
        task.cancel()
        self.removeRequest(task: task)
    }
    
    fileprivate func addRequest(task: URLSessionTask) -> Void {
        ServiceAgent.shared[task] = self
    }
    
    fileprivate func removeRequest(task: URLSessionTask?) -> Void {
        guard let task = task else {
            return
        }
        ServiceAgent.shared[task] = nil
    }
}

// MARK: - Retry

extension BaseAPIService: Retryable {
    var retryCount: Int {
        get { _retryCount }
        set { _retryCount = newValue }
    }
    
    func prepareRetry() {
        retryCount += 1
    }
    
    func resetRetry() {
        retryCount = 0
    }
}

public class BaseDataService: BaseAPIService {
    
    var error: Error? {
        return response?.error
    }
        
    var response: DataResponse?
    
    private var urlRequest: URLRequest?
    
    override fileprivate func finishRequest() {
        if let completeHandler = self.completionClosure {
            completeHandler()
        }
        super.finishRequest()
    }
    
    override fileprivate func clear() {
        super.clear()
        urlRequest = nil
    }
    
    private func handleComplete(response: DataResponse) -> Void {
        self.response = self.middlewares.reduce(response) { return $1.afterReceive($0) }
        self.finishRequest()
    }
    
}

extension BaseDataService {
    func retry(retart: @escaping (()->Void), response: DataResponse, error: Error?) -> Void {
        if let policy = self.retryPolicy, let err = error {
            policy.retry(self, with: err) { (shouldRetry, delay) in
                guard !shouldRetry else {
                    /// only handle error when retry finish
                    self.resetRetry()
                    self.handleComplete(response: response)
                    return
                }
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) {
                    retart()
                }
            }
            self.prepareRetry()
        }
    }
}


extension BaseDataService {
    
    func async(service: Service = ServiceAgent.shared, completion: @escaping (_ request: BaseDataService) -> Void) -> Void {
        self.completionClosure = { [weak self] in
            guard let `self` = self else { return }
            DispatchQueue.main.async { completion(self) }
        }
        do {
            self.urlRequest = try prepareRequest()
            
        } catch {
            fatalError(error.localizedDescription)
        }
        guard let urlRequest = self.urlRequest else {
            fatalError("URLRequest is missing")
        }
        let task = service.data(with: urlRequest, credential: self.credential, uploadProgress: nil, downloadProgress: self.progressHandle) { [weak self] (response: DataResponse) in
            guard let `self` = self else { return }
            if let error = response.error {
                self.retry(retart: { [weak self] in
                    guard let `self` = self else { return }
                    self.async(service: service, completion: completion)
                }, response: response, error: error)
                return
            } else {
                /// handle success
                self.handleComplete(response: response)
            }
        }
        self.resume(with: task)
    }
    
    func sync<T: ObjectTransformProtocol>(service: Service = ServiceAgent.shared, transform: T) -> Self {
        do {
            self.urlRequest = try prepareRequest()
        } catch {
            fatalError(error.localizedDescription)
        }
        guard let urlRequest = self.urlRequest else {
            fatalError("URLRequest is missing")
        }
        let semaphore = DispatchSemaphore(value: 0)
        let task = service.data(with: urlRequest, credential: self.credential, uploadProgress: nil, downloadProgress: self.progressHandle) { [weak self] (response: DataResponse) in
            guard let `self` = self else { return }
            if let error = response.error {
                semaphore.signal()
                self.retry(retart: { [weak self] in
                    guard let `self` = self else { return }
                    _ = self.sync(service: service, transform: transform)
                }, response: response, error: error)
            } else {
                /// handle success
                self.handleComplete(response: response)
                semaphore.signal()
            }
        }
        self.resume(with: task)
        semaphore.wait()
        return self
        
    }
    
    func progress(progressClosure: @escaping ProgressClosure) -> Self {
        self.progressHandle = progressClosure
        return self
    }
}


public class BaseDownloadService: BaseAPIService {
    
    var resumeData: Data? {
        get {
            if _resumeData != nil {
                return _resumeData
            } else {
                return response?.resumeData
            }
        }
        set { _resumeData = newValue }
    }
    
    var downloadURL: URL? {
        return response?.downloadFileURL
    }
    
    var downloadTask: URLSessionDownloadTask? {
        return task as? URLSessionDownloadTask
    }
    
    var downloadType: Downloadable?
    
    var response: DownloadResponse?
    
    var error: Error? {
        return response?.failure
    }
    
    private var _resumeData: Data?
    
    func progress(progressClosure: @escaping ProgressClosure) -> Self {
        self.progressHandle = progressClosure
        return self
    }
    
    override fileprivate func cancel() {
        self.cancel(createResumeData: true)
        self.removeRequest(task: self.task)
    }

    private func cancel(createResumeData: Bool) {
        if createResumeData {
            self.downloadTask?.cancel { [weak self] (data) in
                guard let `self` = self else { return }
                self._resumeData = data
            }
        } else {
            self.downloadTask?.cancel()
        }
    }
}

extension BaseDownloadService {
    
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
            let urlRequest = try prepareRequest()
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
        let downloadTask = service.download(with: downloadable, credential: self.credential, destinationHandler: destination, uploadProgress: nil, downloadProgress: progress, completionHandler: { (downloadResponse: DownloadResponse) in
            self.response = self.middlewares.reduce(downloadResponse) { return $1.afterReceive($0) }
            self._resumeData = self.response?.resumeData
            completion(self)
            self.finishRequest()
        })
        self.resume(with: downloadTask)
    }
    
}


public class BaseUploadService: BaseAPIService {
    
    static let multipartFormDataEncodingMemoryThreshold: UInt64 = 10_000_000
    
    var uploadProgress: ((Progress) -> Void)?
    
    var response: DataResponse?
    
    override fileprivate func clear() {
        self.uploadProgress = nil
        super.clear()
    }
    
    private func build(formdata: MultipartFormData, encodingMemoryThreshold: UInt64, isInBackgroundSession: Bool) throws -> (Uploadable, URLRequest?) {
        var request = try self.prepareRequest()
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

            // Create directory inside serial queue to ensure two threads don't do this in parallel
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)

            do {
                try formdata.writeEncodedData(to: fileURL)
            } catch {
                try? FileManager.default.removeItem(at: fileURL)
                throw error
            }

            uploadable = .file(fileURL, request)
        }
        return (uploadable, request)
    }
}

extension BaseUploadService {
    
    func upload(with data: Data,
                progress closure: ((Progress) -> Void)?,
                service: Service = ServiceAgent.shared,
                completion: @escaping (_ request: BaseUploadService) -> Void
    ) -> Void {
        do {
            let request = try prepareRequest()
            let upload: Uploadable = .data(data, request)
            self.upload(with: upload, progress: closure, completion: completion)
        } catch {
            fatalError(error.localizedDescription)
        }
        
        
    }
    
    func upload(with file: URL,
                progress closure: ((Progress) -> Void)?,
                service: Service = ServiceAgent.shared,
                completion: @escaping (_ request: BaseUploadService) -> Void
    ) -> Void {
        do {
            let request = try prepareRequest()
            let upload: Uploadable = .file(file, request)
            self.upload(with: upload, progress: closure, completion: completion)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func upload(with stream: InputStream,
                progress closure: ((Progress) -> Void)?,
                service: Service = ServiceAgent.shared,
                completion: @escaping (_ request: BaseUploadService) -> Void
    ) -> Void {
        do {
            let request = try prepareRequest()
            let upload: Uploadable = .stream(stream, request)
            self.upload(with: upload, progress: closure, completion: completion)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func upload(multipartformdata: @escaping (MultipartFormData) -> Void,
                progress closure: ((Progress) -> Void)?,
                service: Service = ServiceAgent.shared,
                completion: @escaping (_ request: BaseUploadService) -> Void
    ) -> Void {
        let formdata = MultipartFormData()
        multipartformdata(formdata)
        do {
            let (uploadable, _) = try build(formdata: formdata,
                               encodingMemoryThreshold: BaseUploadService.multipartFormDataEncodingMemoryThreshold,
                               isInBackgroundSession: (service as! ServiceAgent).isInBackgroundSession)
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
        let task = service.upload(with: upload, credential: self.credential, uploadProgress: uploadProgress, downloadProgress: nil) { (response: DataResponse) in
            self.response = self.middlewares.reduce(response) { $1.afterReceive($0) }
            print(response.statusCode)
            completion(self)
            self.finishRequest()
        }
        self.resume(with: task)
    }
}


