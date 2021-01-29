//
//  URLSessionManager.swift
//  NetService
//
//  Created by steven on 2021/1/2.
//

import Foundation


final class URLSessionManager {
    
    var isInBackgroundSession: Bool { session.configuration.identifier != nil }

    private var session: URLSession
    
    let delegate: SessionDelegate
    
    let queue: DispatchQueue
    
    init(
        configuration: URLSessionConfiguration,
        delegate: SessionDelegate = SessionDelegate(),
        queue: DispatchQueue,
        serverTrustPolicyManager: ServerTrustPolicyManager? = nil)
    {
        
        self.delegate = delegate
        let delegateQueue = OperationQueue()
        delegateQueue.maxConcurrentOperationCount = 1
        delegateQueue.underlyingQueue = queue
        delegateQueue.name = "org.netservice.session.sessionDelegateQueue"
        self.session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
        self.queue = queue
        commonInit(serverTrustPolicyManager: serverTrustPolicyManager)
    }
    
    init?(
        session: URLSession,
        delegate: SessionDelegate,
        queue: DispatchQueue,
        serverTrustPolicyManager: ServerTrustPolicyManager? = nil)
    {
        guard delegate === session.delegate else {
            return nil
        }
        self.delegate = delegate
        self.session = session
        self.queue = queue
        commonInit(serverTrustPolicyManager: serverTrustPolicyManager)
    }
        
    private func commonInit(serverTrustPolicyManager: ServerTrustPolicyManager?) {
        delegate.session = self
        session.serverTrustPolicyManager = serverTrustPolicyManager
    }

    deinit {
        session.invalidateAndCancel()
        session.finishTasksAndInvalidate()
    }
}

// MARK: - request resume, cancel, suspend

extension URLSessionManager {
    
    func cancel(url: URL) -> Void {
        session.getTasksWithCompletionHandler { (tasks: [URLSessionDataTask], uploads: [URLSessionUploadTask], downloads: [URLSessionDownloadTask]) in
            if !tasks.isEmpty {
                tasks.filter({ $0.state == .running }).filter({ $0.originalRequest?.url == url }).first?.cancel()
            }
            if !uploads.isEmpty {
                uploads.filter({ $0.state == .running }).filter({ $0.originalRequest?.url == url }).first?.cancel()
            }
            if !downloads.isEmpty {
                downloads.filter({ $0.state == .running }).filter({ $0.originalRequest?.url == url }).first?.cancel()
            }
        }
    }
    
}

// MARK: - create data, upload, download Request
extension URLSessionManager {
    
    func data(with request: URLRequest,
              credential: URLCredential?,
              uploadProgress: ((_ uploadProgress: Progress) -> Void)?,
              downloadProgress: ((_ downloadProgress: Progress) -> Void)?,
              completionHandler: @escaping CompletionClosure
    ) -> URLSessionDataTask {
        let dataTask = session.dataTask(with: request)
        let taskDelegate = TaskDelegate(task: dataTask)
        taskDelegate.manager = self
        if let urlCredential = credential {
            taskDelegate.setCredential(credential: urlCredential)
        }
        if let progress = uploadProgress {
            taskDelegate.uploadProgressHandle = (progress, DispatchQueue.main)
        }
        if let progress = downloadProgress {
            taskDelegate.progressHandle = (progress, DispatchQueue.main)
        }
        taskDelegate.completionHandler = completionHandler
        delegate[dataTask] = taskDelegate
        return dataTask
    }
    
    func upload(with uploadType: Uploadable,
                credential: URLCredential?,
                uploadProgress: ((_ uploadProgress: Progress) -> Void)?,
                downloadProgress: ((_ downloadProgress: Progress) -> Void)?,
                completionHandler: @escaping CompletionClosure
    ) -> URLSessionDataTask {
        let uploadtask = uploadType.task(session: session, queue: queue)
        let uploadDelegate = TaskDelegate(task: uploadtask)
        if case .stream(let inputStream, _) = uploadType {
            uploadDelegate.taskNeedNewBodyStream = { (_ , _)in inputStream }
        }
        uploadDelegate.manager = self
        if let urlCredential = credential {
            uploadDelegate.setCredential(credential: urlCredential)
        }
        if let progress = uploadProgress {
            uploadDelegate.uploadProgressHandle = (progress, DispatchQueue.main)
        }
        if let progress = downloadProgress {
            uploadDelegate.progressHandle = (progress, DispatchQueue.main)
        }
        uploadDelegate.completionHandler = completionHandler
        delegate[uploadtask] = uploadDelegate
        return uploadtask
    }
    
    func download(with downloadType: Downloadable,
                  credential: URLCredential?,
                  destinationHandler: DestinationClosure?,
                  uploadProgress: ((_ uploadProgress: Progress) -> Void)?,
                  downloadProgress: ((_ downloadProgress: Progress) -> Void)?,
                  completionHandler: @escaping CompletionClosure
    ) -> URLSessionDownloadTask {
        let downloadTask = downloadType.task(session: session, queue: queue)
        let downloadDelegate = TaskDelegate(task: downloadTask)
        downloadDelegate.manager = self
        if let urlCredential = credential {
            downloadDelegate.setCredential(credential: urlCredential)
        }
        if let progress = uploadProgress {
            downloadDelegate.uploadProgressHandle = (progress, DispatchQueue.main)
        }
        if let progress = downloadProgress {
            downloadDelegate.progressHandle = (progress, DispatchQueue.main)
        }
        downloadDelegate.completionHandler = completionHandler
        downloadDelegate.destinationHandler = destinationHandler
        delegate[downloadTask] = downloadDelegate
        return downloadTask
    }
}
