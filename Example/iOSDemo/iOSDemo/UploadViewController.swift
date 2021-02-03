//
//  UploadViewController.swift
//  iOSDemo
//
//  Created by steven on 2021/2/3.
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

class UploadViewController: UIViewController {
    
    enum UploadType {
        case data
        case file
        case inputstream
        case multipart
        
        func title() -> String {
            switch self {
            case .data:
                return "data 上传"
            case .file:
                return "file 上传"
            case .inputstream:
                return "inputStream 上传"
            case .multipart:
                return "multipartformdata 上传"
            }
        }
    }
    
    var uploadType: UploadType = .multipart

    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var uploadbtn: UIButton!
    @IBOutlet weak var bodyShow: UILabel!
    
    @IBAction func uploadClick(_ sender: Any) {
        switch self.uploadType {
        case .multipart:
            self.multipartUpload()
        case .data:
            self.dataUpload()
        default:
            
            break
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = self.uploadType.title()
        // Do any additional setup after loading the view.
        
    }
    

    private func multipartUpload() {
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
            self.progressView.observedProgress = progress
        }) { (request) in
            let response = request.response?.response
            self.bodyShow.text = response?.description
        }
    }
    
    private func dataUpload() {
        let urlString = "https://httpbin.org/post"
        let data: Data = {
            var text = ""
            for _ in 1...5_000 {
                text += "Lorem ipsum dolor sit amet, consectetur adipiscing elit. "
            }

            return text.data(using: .utf8, allowLossyConversion: false)!
        }()
        
        var uploadProgressValues: [Double] = []

        UploadAPI(with: urlString).upload(data: data) { (progress) in
            self.progressView.observedProgress = progress
            uploadProgressValues.append(progress.fractionCompleted)
        } completion: { (request) in
            let response = request.response?.response
            self.bodyShow.text = response?.description
            print(uploadProgressValues)
        }
    }

}
