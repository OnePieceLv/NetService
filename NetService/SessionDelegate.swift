//
//  APISessionDelegate.swift
//  NetService
//
//  Created by steven on 2021/1/20.
//

import Foundation

class SessionDelegate: NSObject {
        
    private var taskDelegateMap: [Int:TaskDelegate] = [:]
    
    private var lock: NSLock = NSLock()
    
    subscript(task: URLSessionTask) -> TaskDelegate? {
        get { lock.lock(); defer { lock.unlock() }; return taskDelegateMap[task.taskIdentifier] }
        set { lock.lock(); defer { lock.unlock() }; taskDelegateMap[task.taskIdentifier] = newValue }
    }
}

// MARK: URLSessionDelegate
extension SessionDelegate: URLSessionDelegate {
    
    // MARK: Handling Task Life Cycle Changes
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        
    }
    
    // MARK: Handling Authentication Challenges
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        var disposition: URLSession.AuthChallengeDisposition = .performDefaultHandling
        var credential: URLCredential? = nil
        
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            let host = challenge.protectionSpace.host
            if let serverTrust = challenge.protectionSpace.serverTrust,
               let policy = session.serverTrustPolicyManager?.serverTrustPolicy(forHost: host) {
                if policy.evaluate(serverTrust, forHost: host) {
                    disposition = .useCredential
                    credential = URLCredential(trust: serverTrust)
                } else {
                    disposition = .cancelAuthenticationChallenge
                }
            }
        }
        completionHandler(disposition, credential)
    }
    
}


// MARK: - URLSessionTaskDelegate

extension SessionDelegate: URLSessionTaskDelegate {
    
    //MARK: Handling Task Life Cycle Changes
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let delegate = self[task] {
            delegate.taskDidComplete(session, task: task, didCompleteWithError: error)
        }
    }
    
    // MARK: Handling Redirects
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        let redirectURLRequest: URLRequest = request
        completionHandler(redirectURLRequest)
    }
    
    
    // MARK: Working with Upload Tasks
    func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
        if let delegate = self[task] {
            delegate.taskNeedBodyStream(session, task: task, needNewBodyStream: completionHandler)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        if let delegate = self[task] {
            delegate.uploadTaskDidSendBodyData(session, task: task, didSendBodyData: bytesSent, totalBytesSent: totalBytesSent, totalBytesExpectedToSend: totalBytesExpectedToSend)
        }
    }
    
    // MARK: Handling Authentication Challenges
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let delegate = self[task] {
            delegate.taskDidReceiveChallenge(session: session, task: task, challenge: challenge, completionHandler: completionHandler)
        }
    }
    
    // MARK: Handling Delayed and Waiting Tasks
    
    @available(iOS 11.0, *)
    func urlSession(_ session: URLSession, task: URLSessionTask, willBeginDelayedRequest request: URLRequest, completionHandler: @escaping (URLSession.DelayedRequestDisposition, URLRequest?) -> Void) {
        
    }
    
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        
    }
    
    
    // MARK: Collecting Task Metrics
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        self[task]?.metrics = metrics
    }
    
}

// MARK: - URLSessionDataDelegate
extension SessionDelegate: URLSessionDataDelegate {
    
    // MARK: Receiving Data
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if let delegate = self[dataTask] {
            delegate.dataTaskDidReceiveData(session, dataTask: dataTask, didReceive: data)
        }
    }
    
    // MARK: Handling Task Life Cycle Changes
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        
        if let delegate = self[dataTask] {
            delegate.dataTaskDidReceiveResponse(session, task: dataTask, didReceive: response, completionHandler: completionHandler)
            return
        }
        completionHandler(.allow)
        
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
        if let delegate = self[dataTask] {
            self[dataTask] = nil
            self[downloadTask] = delegate
        }
    }
    
    // MARK: Handling Caching
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        let cachedResponse: CachedURLResponse? = proposedResponse
        completionHandler(cachedResponse)
    }
}

// MARK: - URLSessionDownloadDelegate

extension SessionDelegate: URLSessionDownloadDelegate {
    
    // MARK: Handling Download Life Cycle Changes
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let delegate = self[downloadTask] {
            delegate.downloadTaskDidFinishTo(session, downloadTask: downloadTask, didFinishDownloadingTo: location)
        }
    }
    
    // MARK: Receiving Progress Updates
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if let delegate = self[downloadTask] {
            delegate.downloadTaskDidWriteData(session, downloadTask: downloadTask, didWriteData: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
        }
    }
    
    // MARK: Resuming Paused Downloads
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        if let delegate = self[downloadTask] {
            delegate.downloadTaskDidResumeAtOffset(session, downloadTask: downloadTask, didResumeAtOffset: fileOffset, expectedTotalBytes: expectedTotalBytes)
        }
    }
}

