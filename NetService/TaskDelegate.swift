//
//  DataProcess.swift
//  NetService
//
//  Created by steven on 2021/1/19.
//

import Foundation

typealias ProgressClosure = (Progress) -> Void
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


class TaskDelegate: NSObject, Retryable {
    
    var error: Error?

    var data: Data? {
        if dataStream != nil {
            return nil
        } else {
            return mutableData
        }
    }
    
    var metrics: URLSessionTaskMetrics?
    
    var retryPolicy: RetryPolicyProtocol?
        
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
    
    // Retryable
//    weak var retryRequest: (APIService & Retryable)?
    var retryCount: Int = 0

    func prepareRetry() {
        retryCount += 1
    }

    func resetRetry() {
        retryCount = 0
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
        for searchDirectory: FileManager.SearchPathDirectory = .documentDirectory,
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
            if let err = self.error {
                self.resumeData = (err as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data
            }
            let taskResult = TaskResult(data: self.data, downloadFileURL: self.destinationFile, resumeData: self.resumeData, response: task.response as? HTTPURLResponse, error: self.error, task: task, metrics: self.metrics)
            completion(taskResult)
            self.completionHandler = nil
            self.manager?.delegate[task] = nil
        }
        let queue = self.manager?.queue ?? DispatchQueue.main
                
        if let policy = retryPolicy, let err = error {
            policy.retry(self, with: err) { (shouldRetry, delay) in
                guard shouldRetry else {
                    queue.async {
                        completeTask(session, task, error)
                    }
                    return
                }

                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let `self` = self else { return }                    
                    if let (request, new) = self.manager?.retryNewTask(old: task),
                       let newTask = new,
                       let api = request {
                        self.manager?.delegate[newTask] = self
                        api.resume(task: new)
                    }
                }
            }
            
            
        } else {
            queue.async {
                completeTask(session, task, error)
            }
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

