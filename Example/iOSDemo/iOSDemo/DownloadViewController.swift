//
//  DownloadViewController.swift
//  iOSDemo
//
//  Created by steven on 2021/2/3.
//

import UIKit
import NetService

final class DownloadAPI: BaseDownloadService, NetServiceProtocol {
    
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
        super.init()
    }
    
    init(with url: String, headers: [String: String]) {
        _urlString = url
        _headers = headers
        super.init()
    }
    
    
}

class DownloadViewController: UIViewController {

    @IBOutlet weak var downloadBtn: UIButton!
    @IBOutlet weak var progressView: UIProgressView!
    
    @IBOutlet weak var bodyShow: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
    }
    
    @IBAction func donwloadClick(_ sender: Any) {
        let randomBytes = 4 * 1024 * 1024
        let downloadURLStr = "https://httpbin.org/bytes/\(randomBytes)"

        let download = DownloadAPI(with: downloadURLStr)
        download.download { (progress) in
            self.progressView.observedProgress = progress
        } completion: { (downloadrequest) in
            let response = download.response
            self.bodyShow.text = response?.response?.description
        }
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
