//
//  DataProcess.swift
//  NetService
//
//  Created by steven on 2021/1/19.
//

import Foundation

typealias ProgressClosure = (Progress) -> Void
public typealias DestinationClosure = ((_ temporaryURL: URL?, _ response: URLResponse?) -> URL?)
typealias CompletionClosure = ((_ result: TaskResult) -> Void)

public struct TaskResult {
    let data: Data?
    let downloadFileURL: URL?
    let resumeData: Data?
    let response: HTTPURLResponse?
    let error: Error?
    let task: URLSessionTask
    let metrics: URLSessionTaskMetrics?
}

public enum Uploadable {
    case data(Data, URLRequest)
    case file(URL, URLRequest)
    case stream(InputStream, URLRequest)
    
    func task(session: URLSession, queue: DispatchQueue) -> URLSessionUploadTask {
        let task: URLSessionUploadTask
        switch self {
        case .data(let data, let urlRequest):
            task = queue.sync { session.uploadTask(with: urlRequest, from: data) }
        case .file(let url, let urlRequest):
            task = queue.sync {  session.uploadTask(with: urlRequest, fromFile: url) }
        case .stream(_, let urlRequest):
            task = queue.sync { session.uploadTask(withStreamedRequest: urlRequest) }
        }
        return task
    }
    
    func request() -> URLRequest {
        switch self {
        case .data(_, let urlRequest):
            return urlRequest
        case .file(_, let urlRequest):
            return urlRequest
        case .stream(_, let urlRequest):
            return urlRequest
        }
    }
}

public enum Downloadable {
    case request(URLRequest)
    case resume(Data)
    
    func task(session: URLSession, queue: DispatchQueue ) -> URLSessionDownloadTask {
        let task: URLSessionDownloadTask
        switch self {
        case .request(let urlRequest):
            task = queue.sync { session.downloadTask(with: urlRequest) }
        case .resume(let data):
            task = queue.sync { session.downloadTask(withResumeData: data) }
        }
        return task
    }
}


class TaskDelegate: NSObject {
    
    var error: Error?

    var data: Data? {
        if dataStream != nil {
            return nil
        } else {
            return mutableData
        }
    }
    
    var metrics: URLSessionTaskMetrics?
        
    weak var manager: URLSessionManager?
    
    private var credential: URLCredential?
    
    var task: URLSessionTask? {
        get { lock.lock(); defer { lock.unlock() }; return _task }
        set { lock.lock(); defer { lock.unlock() }; _task = newValue }
    }
    
    private let lock: NSLock = NSLock()
    
    private var _task: URLSessionTask? {
        didSet { reset() }
    }
    
    
    // MARK: - data
    
    var dataStream: ((_ data: Data?) -> Void)?
    
    var completionHandler: CompletionClosure?
    
    var progressHandle: (download: ProgressClosure, queue: DispatchQueue)?
    
    private var progress: Progress
    
    private var mutableData: Data
    
    private var totalBytesReceived: Int64 = 0
    
    private var expectedContentLength: Int64 = 0
    
    // MARK: - download
    
    var downloadFile: URL? {
        return destinationHandler == nil ? destinationFile : temporaryFile
    }
    
    var destinationHandler: DestinationClosure?
    
    var resumeData: Data?
    
    private var temporaryFile: URL?
    
    private var destinationFile: URL?
    
    
    class func suggestDestinationFile(
        for searchDirectory: FileManager.SearchPathDirectory = .downloadsDirectory,
        in userDomainMask: FileManager.SearchPathDomainMask = .userDomainMask,
        response: URLResponse
    ) -> URL? {
        let urls = FileManager.default.urls(for: searchDirectory, in: userDomainMask)
        if let url = urls.first {
            return url.appendingPathComponent(response.suggestedFilename!)
            
        }
        return nil
    }
    
    
    // MARK: - Upload
    var uploadProgressHandle: (upload: ProgressClosure, queue: DispatchQueue)?
    
    /// return inputStream for upload
    var taskNeedNewBodyStream: ((_ session: URLSession, _ task: URLSessionTask) -> InputStream?)?
    
    func reset() -> Void {
        error = nil
        progress = Progress(totalUnitCount: 0)
        mutableData = Data()
        expectedContentLength = 0
        totalBytesReceived = 0
        resumeData = nil
    }
    
    init(task: URLSessionTask? = nil) {
        _task = task
        progress = Progress(totalUnitCount: 0)
        mutableData = Data()
    }
    
    func setCredential(credential: URLCredential) -> Void {
        self.credential = credential
    }
    
    // MARK: - work with task
    
    // MARK: - Handling Authentication Challenges
    func taskDidReceiveChallenge(session: URLSession, task: URLSessionTask, challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        var disposition: URLSession.AuthChallengeDisposition = .performDefaultHandling
        var credential: URLCredential?
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            let host = challenge.protectionSpace.host
            if let serverTrust = challenge.protectionSpace.serverTrust,
               let policy = session.serverTrustPolicyManager?.serverTrustPolicy(forHost: host),
               policy.evaluate(serverTrust, forHost: host) {
                disposition = .useCredential
                credential = URLCredential(trust: serverTrust)
            } else {
                disposition = .cancelAuthenticationChallenge
            }
        } else {
            if challenge.previousFailureCount > 0 {
                disposition = .rejectProtectionSpace
            } else {
                credential = self.credential ?? session.configuration.urlCredentialStorage?.defaultCredential(for: challenge.protectionSpace)
                if credential != nil {
                    disposition = .useCredential
                }
            }
        }
        completionHandler(disposition, credential)
    }
    
    // MARK: - Handling Task Life Cycle Changes
    func taskDidComplete(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let completion = self.completionHandler else {
            fatalError("missing completionHandler callback")
        }
        
        let completeTask: (URLSession, URLSessionTask, Error?) -> Void = { [weak self] session, task, error in
            guard let `self` = self else { return }
            self.error = error
            if let err = self.error, self.destinationHandler != nil {
                self.resumeData = (err as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data
            }
            let taskResult = TaskResult(data: self.data, downloadFileURL: self.destinationFile, resumeData: self.resumeData, response: task.response as? HTTPURLResponse, error: error, task: task, metrics: self.metrics)
            completion(taskResult)
            self.completionHandler = nil
            self.manager?.delegate[task] = nil
        }
        
        
        let queue = self.manager?.queue ?? DispatchQueue.main
        queue.async {
            completeTask(session, task, error)
        }
    }
    
    // MARK: - work with upload task
    func uploadTaskDidSendBodyData(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        
        progress.totalUnitCount = totalBytesExpectedToSend
        progress.completedUnitCount = totalBytesSent
        
        if let (closure, queue) = self.uploadProgressHandle {
            queue.async { [weak self] in
                guard let `self` = self else { return }
                closure(self.progress)
            }
        }
    }
    
    
    func taskNeedBodyStream(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
        var inputStream: InputStream?
        inputStream = self.taskNeedNewBodyStream?(session, task)
        if let stream = task.originalRequest?.httpBodyStream {
            inputStream = stream
        }
        completionHandler(inputStream)
        self.taskNeedNewBodyStream = nil
    }
    
    // MARK: - work with data task
    
    // MARK: - Handling Task Life Cycle Changes
    func dataTaskDidReceiveResponse(_ session: URLSession, task: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        
        self.expectedContentLength = response.expectedContentLength
        
        completionHandler(.allow)
    }
    
    // MARK: - Receiving Data
    func dataTaskDidReceiveData(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if let streamHandle = self.dataStream {
            streamHandle(data)
        } else {
            mutableData.append(data)
        }
        
        let receiveBytes = Int64(data.count)
        totalBytesReceived += receiveBytes
        
        progress.completedUnitCount = totalBytesReceived
        progress.totalUnitCount = dataTask.response?.expectedContentLength ?? NSURLSessionTransferSizeUnknown
        
        if let (closure, queue) = self.progressHandle {
            queue.async { [weak self] in
                guard let `self` = self else { return }
                closure(self.progress)
            }
        }
        
    }
    
    
    // MARK: - work with download task
    // MARK: - Handling Download Life Cycle Changes
    
    func downloadTaskDidFinishTo(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
        temporaryFile = location
        
        guard let response = downloadTask.response else { return }
        
        let destinationURL = destinationHandler?(temporaryFile, response) ?? TaskDelegate.suggestDestinationFile(response: response)
        
        self.destinationFile = destinationURL
        
        guard let fileURL = destinationURL else { return }
        
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            try FileManager.default.moveItem(at: location, to: fileURL)
            
        } catch {
            self.error = error
        }
        
    }
    
    func downloadTaskDidResumeAtOffset(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        progress.totalUnitCount = expectedTotalBytes
        progress.completedUnitCount = fileOffset
    }
    
    func downloadTaskDidWriteData(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        progress.completedUnitCount = totalBytesWritten
        progress.totalUnitCount = totalBytesExpectedToWrite
        
        if let (closure, queue) = self.progressHandle {
            queue.async { [weak self] in
                guard let `self` = self else { return }
                closure(self.progress)
            }
        }
    }
}

