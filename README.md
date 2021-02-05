<p align="center">
    <img src="https://raw.githubusercontent.com/OnePieceLv/NetService/main/images/logo.png" alt="NetService" title="NetService">
</p>

<p align="center">
    <a href="https://github.com/OnePieceLv/NetService/blob/main/LICENSE"><img alt="Cocoapods" src="https://img.shields.io/cocoapods/l/NetService?color=green"></a>
    <a href="https://cocoapods.org/pods/NetService"><img alt="Cocoapods" src="https://img.shields.io/cocoapods/v/NetService"></a>
    <img alt="Cocoapods platforms" src="https://img.shields.io/cocoapods/p/NetService">
    <a href="https://swift.org"><img alt="swift 5" src="https://img.shields.io/badge/swift-5-important"></a>
</p>

NetService is an lightweight and pure Swift implemented HTTP library for request / download / upload from network. This project is inspired by the popular [Alamofire](https://github.com/Alamofire/Alamofire) and [AFNetworking](https://github.com/AFNetworking/AFNetworking)。Although this project is also built on the [URL Loading System](https://developer.apple.com/documentation/foundation/url_loading_system), but there are fundamentally different between this project and Alamofire/AFNetworking。Both the design concept and the usage

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Contributing](#contributing)

# Features
- [x] URL / JSON Parameter Encoding
- [x] Asynchronous and synchronous requests
- [x] Upload File / Data / Stream / MultipartFormData
- [x] Download File using Request or Resume Data
- [x] Authentication with `URLCredential`
- [x] Support Authentication header three type: `Bearer` / `Basic` /  Custom token
- [x] Upload and Download Progress Closures with Progress
- [x] Retry requests
- [x] TLS Certificate and Public Key Pinning
- [x] Pequest Middlewares
- [x] macOS Compatible
- [x] Default and Custom Cache Controls
- [x] Default and Custom Content Types
- [x] Usage

# Requirements
- iOS 10.0+ / macOS 10.15+
- Xcode 12 +
- Swift 5.0 +

# Installation
```ruby
pod 'NetService', '~> 1.0.2'
```

# Usage

### Request asynchronously
```swift
final class YourAPI: DataNetService, NetServiceProtocol {

    var timeout: TimeInterval {
        30
    }
    
    var authorization: NetServiceBuilder.Authorization {
        return .none
    }
    
    var encoding: ParameterEncoding {
        return URLEncoding.default
    }
    
    var credential: URLCredential? {
        return nil
    }
    
    func httpHeaders() -> [String : String] {
        [:]
    }
    
    func httpParameters() -> [String : Any] {
        [:]
    }
    
    func httpBuilderHelper(builder: NetServiceBuilder) -> NetServiceBuilder {
        return builder
    }
    
    var urlString: String {
        return _urlString
        
    }
    
    var httpMethod: NetBuilders.Method {
        return _method
    }
    
    // above code is conforms to NetServiceProtocol protocol
    
    private var _urlString: String
    
    private var _method: NetBuilders.Method = .GET
    
    init(with url: String) {
        _urlString = url
    }
    
    func setMethod(method: NetBuilders.Method) -> Self {
        _method = method
        return self
    }
}

let urlString = "https://httpbin.org/get"
let api = YourAPI(with: urlString)
api.async { (request) in
    let response = request.response
    request
    ....
}

```

### Request synchronously
```swift

let urlString = "https://httpbin.org/get"
let api = YourAPI(with: urlString)
let response = api.sync().response
...
```

### Request Download
```swift

class DownloadAPI: DownloadNetService, NetServiceRequestProtocol {
    
    var urlString: String {
        return _urlString
    }
    
    func httpHeaders() -> [String : String] {
        return _parameters
    }
    
    func httpParameters() -> [String : Any] {
        return _headers
    }
    
    ....
    
    // Above Code is conforms to NetServiceRequestProtocol
    
    private var _urlString = ""
    
    private var _parameters: [String: Any] = [:]
    
    private var _headers: [String: String] = [:]
    
    init(with url: String, parameters: [String: Any] = [:]) {
        _urlString = url
        _parameters = parameters
    }
    
    init(with url: String, headers: [String: String]) {
        _urlString = url
        _headers = headers
    }
    
}

let fielURL = ... // donwload file save url
let destination: DestinationClosure = {_, _ in fielURL } // config download file position
let numberOfLines = 100
let urlString = "https://httpbin.org/stream/\(numberOfLines)"
let downloadProgresssView: UIProgressView = ....
DownloadAPI(with: urlString).download(progress: { (progress) in
   downloadProgresssView.progress = Float(progress.fractionCompleted)
}, to: destination) { (request) in
   let downloadFileURL = request.response.downloadFileURL
   print(downloadFileURL)
}
```

### Request Upload
```swift
class BaseUploadManager: UploadNetService, NetServiceRequestProtocol {

   ...  
    
    var urlString: String {
        return _urlString
    }
    
    // Above Code is conforms to NetServiceRequestProtocol
    
    var _urlString: String = ""
    
    init(with url: String) {
        _urlString = url
    }
}

let urlString = "https://httpbin.org/post"
let bundle = Bundle(for: BaseTestCase.self)
let imageURL = bundle.url(forResource: "rainbow", withExtension: "jpg")!
let uplodProgressView: UIProgressView = ...
UploadAPI(with: urlString).upload(file: imageURL) { (progress: Progress) in
    uplodProgressView.progress = Fload(progress.fractionCompleted)
} completion: { (request) in
    res = request.response
    if let responseString = res?.responseString {
        print(responseString)
    }
}
```
more usage in example and unit test case

# Want to contribute?
## Contributing
IF you want to contribute, [the Contributing guide is the best place to start(https://github.com/OnePieceLv/NetService/blob/main/CONTRIBUTING.md). If you have questions, feel free to ask.

# License
NetService is released under the MIT license. See [LICENSE](https://github.com/OnePieceLv/NetService/blob/main/LICENSE) for details.
