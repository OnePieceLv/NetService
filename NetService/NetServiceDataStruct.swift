//
//  NetServiceDataStruct.swift
//  NetService
//
//  Created by steven on 2021/2/3.
//

import Foundation

//MARK: - ServiceAgent Callback
public typealias CompletionResult = (_ response: DataResponse) -> Void

//MARK: - download location url
public typealias DestinationClosure = ((_ temporaryURL: URL?, _ response: URLResponse?) -> URL?)

public enum Requestable {
    case request(URLRequest)
    
    func task(session: URLSession, queue: DispatchQueue) -> URLSessionTask {
        let task: URLSessionTask
        switch self {
        case .request(let urlRequest):
            task = session.dataTask(with: urlRequest)
        }
        return task
    }
}

//MARK: - upload type
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

// MARK: - download type
public enum Downloadable {
    case request(URLRequest)
    case resume(Data)
    
    func task(session: URLSession, queue: DispatchQueue) -> URLSessionDownloadTask {
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


//MARK: - ServiceAgent Parameter
public struct URLSessionParameter {
    var credential: URLCredential?
    var retryPolicy: RetryPolicyProtocol?
}

public struct TaskResult {
    let data: Data?
    let downloadFileURL: URL?
    let resumeData: Data?
    let response: HTTPURLResponse?
    let error: Error?
    let task: URLSessionTask
    let metrics: URLSessionTaskMetrics?
}
