//
//  TimeOutViewController.swift
//  iOSDemo
//
//  Created by steven on 2021/8/30.
//

import Foundation
import NetService

class TimeOutAPI: BaseAPIManager {
    
    
    override var urlString: String {
        return _urlString
    }
    
    override var httpMethod: NetServiceBuilder.Method {
        return _method
    }
    
    override var timeout: TimeInterval {
        return 2
    }
        
    private var _urlString: String
    private var _method: NetServiceBuilder.Method
    
    init(with url: String, method: NetServiceBuilder.Method) {
        _urlString = url
        _method = method
        super.init()
    }
}

class TimeOutViewController: UITableViewController {
    
    private var responseContent: ResponseContent = ResponseContent(headers: [:], body: nil)
    
    var url: String = ""
    
    var method: NetServiceBuilder.Method = .GET

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.clearsSelectionOnViewWillAppear = false
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)
        self.refresh()
    }
    
    @objc func refresh() -> Void {
        refreshControl?.beginRefreshing()
        let api = TimeOutAPI(with: url, method: method)
        api.retryPolicy = TestRetryPolicy()
        api.middlewares = [TestMiddleware()]
        api.async { [weak self] (request) in
            guard let `self` = self else { return }
            if let headers = request.response?.response?.allHeaderFields as? [String: String] {
                self.responseContent.headers = headers
            }
            if let error = request.response?.error as NSError? {
                self.responseContent.body = "errorCode: \(error.code),\n errorDomain: \(error.domain),\n reason: \(error.localizedDescription)"
            }
            self.tableView.reloadData()
            self.refreshControl?.endRefreshing()
        }
    }
    
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return self.responseContent.headers.count
        case 1:
            return ((self.responseContent.body != nil) ? 1 : 0)
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "header"
        default:
            return "body"
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let headers = self.responseContent.headers
            let cell = tableView.dequeueReusableCell(withIdentifier: "HeadersCell", for: indexPath)
            let index = headers.index(headers.keys.startIndex, offsetBy: indexPath.row)
            cell.textLabel?.text = headers[index].key
            cell.detailTextLabel?.text = headers[index].value
            return cell
        case 1:
            let body = self.responseContent.body
            let cell = tableView.dequeueReusableCell(withIdentifier: "BodysCell", for: indexPath)
            cell.textLabel?.text = body
            return cell
        default:
            return UITableViewCell()
        }
    }
    
    
}
