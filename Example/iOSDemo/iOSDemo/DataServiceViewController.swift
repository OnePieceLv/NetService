//
//  ViewController.swift
//  iOSDemo
//
//  Created by steven on 2021/1/29.
//

import UIKit
import NetService

class DataAPI: BaseDataService, NetServiceProtocol {
    
    var urlString: String {
        return _urlString
        
    }
    
    var httpMethod: NetBuilders.Method {
        return _method
    }
    
    private var _urlString: String
    private var _method: NetBuilders.Method
    
    init(with url: String, method: NetBuilders.Method) {
        _urlString = url
        _method = method
    }
}

struct TestRetryPolicy: RetryPolicyProtocol {
    
    public var retryCount: Int {
        return 3
    }
    
    public var timeDelay: TimeInterval = 0.0
    
    public func retry(_ request: Retryable, with error: Error, completion: RequestRetryCompletion) {
        var service = request
        if request.retryCount < retryCount {
            completion(true, timeDelay)
            service.prepareRetry()
        } else {
            completion(false, timeDelay)
            service.resetRetry()
        }
    }
}

class TestMiddleware: Middleware {
    
    func afterReceive<Response>(_ result: Response) -> Response where Response : Responseable {
        print(result.response)
        return result
    }
    
    
    func prepare(_ builder: RequestBuilder) -> RequestBuilder {
        return builder
    }
    func beforeSend<TaskType>(_ request: TaskType) where TaskType : APIService {
        
    }
    
    func didStop<TaskType>(_ request: TaskType) where TaskType : APIService {
        
    }
    
    
    
}

class DataServiceViewController: UITableViewController {
    
    private var responseContent: ResponseContent = ResponseContent(headers: [:], body: nil)
    
    var url: String = ""
    
    var method: NetBuilders.Method = .GET

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
        let api = DataAPI(with: url, method: method)
        api.retryPolicy = TestRetryPolicy()
        api.middlewares = [TestMiddleware()]
        api.async { [weak self] (request) in
            guard let `self` = self else { return }
            if let headers = request.response?.response?.allHeaderFields as? [String: String] {
                self.responseContent.headers = headers
            }
            if let body = request.response?.responseString {
                self.responseContent.body = body
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

