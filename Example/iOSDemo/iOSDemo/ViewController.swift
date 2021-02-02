//
//  ViewController.swift
//  iOSDemo
//
//  Created by steven on 2021/1/29.
//

import UIKit
import NetService

final class UploadAPI: BaseUploadService, NetServiceProtocol {
    
    var urlString: String {
        return _urlString
    }
    
    var httpMethod: NetBuilders.Method {
        return .POST
    }
    
    var _urlString: String = ""
    
    init(with url: String) {
        _urlString = url
    }
    
    
}

class DataAPI: BaseDataService, NetServiceProtocol {
    var parameters: [String : Any] = [:]
    
    var headers: [String : String] = [:]
    
    var urlString: String {
        return "https://httpbin.org/get"
        
    }
}

class DownloadAPI: BaseDownloadService, NetServiceProtocol {
    
    var urlString: String {
        return _urlString
    }
    
    func httpParameters() -> [String : Any] {
        return _parameters
    }
    
    func httpHeaders() -> [String : String] {
        return _headers
    }
        
    private var _urlString = ""
    
    private var _parameters: [String: Any] = [:]
    
    private var _headers: [String: String] = [:]
    
    init(with url: String, parameters: [String: Any] = [:]) {
        _urlString = url
        _parameters = parameters
//        super.init()
    }
    
    init(with url: String, headers: [String: String]) {
        _urlString = url
        _headers = headers
//        super.init()
    }
    
    
}

struct TestRetryPolicy: RetryPolicyProtocol {
    
    public var retryCount: Int {
        return 3
    }
    
    public var timeDelay: TimeInterval = 0.0
    
    public func retry(_ request: Retryable, with error: Error, completion: RequestRetryCompletion) {
        var service = request
        service.prepareRetry()
        if request.retryCount < retryCount {
            completion(true, timeDelay)
        } else {
            completion(false, timeDelay)
            service.resetRetry()
        }
    }
}

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        let urlString = "https://httpbin.org/post"
        let xiaomingdata: Data = {
            var values: [String] = []
            for _ in 1...1_500 {
                values.append("this is test code, Rapid evacuation of non-combatants")
            }
            return values.joined(separator: " ").data(using: .utf8, allowLossyConversion: false)!
        }()
        
        let hanmeimeidata: Data = {
            var values: [String] = []
            for _ in 1...1_500 {
                values.append("this is test code, ")
            }
            return values.joined(separator: " ").data(using: .utf8, allowLossyConversion: false)!
        }()
        
        let fromDisk = true
        
        var uploadProgressValues: [Double] = []
        UploadAPI(with: urlString).upload(multipartformdata: { (formdata) in
            formdata.append(xiaomingdata, withName: "xiaoming_data")
            formdata.append(hanmeimeidata, withName: "hanmeimei_data")
        },
        isInMemoryThreshold: fromDisk ? 0 : 100_00_00_00,
        progress: { (progress) in
            uploadProgressValues.append(progress.fractionCompleted)
        }) { (request) in
            let response = request.response
            print(response?.statusCode ?? -1)
            print(uploadProgressValues)
        }

        let api: DataAPI = DataAPI()
        api.async { (request) in
            print(request.response?.responseString)
        }
        
        let res = api.sync()
        res.middlewares = []
        print(res.response?.responseString)
        
        let randomBytes = 4 * 1024 * 1024
        let downloadURLStr = "https://httpbin.org/bytes/\(randomBytes)"
        var progressValues: [Double] = []

        let download = DownloadAPI(with: downloadURLStr)
        download.download { (progress) in
            progressValues.append(progress.fractionCompleted)
        } completion: { (downloadrequest) in
            let response = download.response
            print(response?.downloadFileURL)
            print(progressValues)
        }

    }
    
}

