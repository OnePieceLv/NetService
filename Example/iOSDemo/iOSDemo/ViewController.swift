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
        
        var fromDisk = true
        
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
            print(response?.statusCode)
            print(uploadProgressValues)
        }

    }


}

