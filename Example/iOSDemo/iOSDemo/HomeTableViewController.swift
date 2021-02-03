//
//  TableViewController.swift
//  iOSDemo
//
//  Created by steven on 2021/2/3.
//

import UIKit
import NetService

struct RequestContent {
    
    enum RequestType: Int {
        
        case normal = 0
        case download
        case upload
        
        func name() -> String {
            switch self {
            case .normal:
                return "普通请求"
            case .download:
                return "下载"
            case .upload:
                return "上传"
            }
        }
    }
    let name: String
    let url: String
    let method: String
    let identifier: String
    
    var action: ((_ sender: UINavigationController?) -> Void)?
    
}

struct ResponseContent {
    var headers: [String: String]
    var body: String?
}

class HomeTableViewController: UITableViewController {
    
    var requestContents: [RequestContent.RequestType: [RequestContent]] = {
        let contents: [RequestContent.RequestType: [RequestContent]] = [
            .normal: [
                RequestContent(
                    name: "GetRequest",
                    url: "https://httpbin.org/get",
                    method: "Get",
                    identifier: "DataServiceSegue",
                    action: { (navigation) in
                        let main = UIStoryboard.init(name: "Main", bundle: nil)
                        let controller = main.instantiateViewController(identifier: "DataServiceViewController") as? DataServiceViewController
                        controller?.url = "https://httpbin.org/get"
                        controller?.method = .GET
                        navigation?.show(controller!, sender: navigation)
                    }
                )
            ],
            .download: [
                RequestContent(
                    name: "DownloadWithData",
                    url: "",
                    method: "POST",
                    identifier: "DownloadSegue",
                    action: { (navigation) in
                        let main = UIStoryboard.init(name: "Main", bundle: nil)
                        let controller = main.instantiateViewController(identifier: "DownloadViewController") as? DownloadViewController
                        navigation?.show(controller!, sender: navigation)
                    }
                )
            ],
            .upload: [
//                RequestContent(
//                    name: "UploadWithData",
//                    url: "", method: "POST",
//                    identifier: "UploadSegue",
//                    action: { (navigation) in
//                        let main = UIStoryboard.init(name: "Main", bundle: nil)
//                        let controller = main.instantiateViewController(identifier: "UploadViewController") as? UploadViewController
//                        controller?.uploadType = .data
//                        navigation?.show(controller!, sender: navigation)
//                    }
//                ),
                RequestContent(
                    name: "UploadWithMultipart",
                    url: "",
                    method: "POST",
                    identifier: "UploadSegue",
                    action: { (navigation) in
                        let main = UIStoryboard.init(name: "Main", bundle: nil)
                        let controller = main.instantiateViewController(identifier: "UploadViewController") as? UploadViewController
                        controller?.uploadType = .multipart
                        navigation?.show(controller!, sender: navigation)
                    }
                )
            ]
        ]
        return contents
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Uncomment the following line to preserve selection between presentations
         self.clearsSelectionOnViewWillAppear = false
        self.title = "NetService 示例"
        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return requestContents.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return requestContents.filter({ (element: Dictionary<RequestContent.RequestType, [RequestContent]>.Element) -> Bool in
            return element.key.rawValue == section
        }).values.first?.count ?? 0
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let requests = requestContents.filter { $0.key.rawValue == indexPath.section }.values.first!
        let request = requests[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)
        cell.textLabel?.text = request.name
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let requests = requestContents.filter { $0.key.rawValue == indexPath.section }.values.first!
        let request = requests[indexPath.row]
        if let action = request.action {
            action(self.navigationController)
        }
//        self.performSegue(withIdentifier: request.identifier, sender: self)
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    
    // MARK: - Navigation
    /*
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
