<p align="center">
    <img src="https://raw.githubusercontent.com/OnePieceLv/NetService/main/images/logo.png" alt="NetService" title="NetService">
</p>

NetService is an lightweight and pure Swift implemented HTTP library for request / download / upload from network. This project is inspired by the popular [Alamofire](https://github.com/Alamofire/Alamofire) and [AFNetworking](https://github.com/AFNetworking/AFNetworking)。Although this project is also built on the [URL Loading System](https://developer.apple.com/documentation/foundation/url_loading_system), but there are fundamentally different between this project and Alamofire/AFNetworking。Both the design concept and the usage

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)

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
- [ ] Complete Documentation

# Requirements
- iOS 10.0+ / macOS 10.15+
- Xcode 12 +
- Swift 5.0 +

# Installation
```ruby
pod 'NetService', '~> 1.0'
```

# 🐒 Usage

### Request asynchronously
```swift
final class YourAPI: BaseDataService, NetServiceProtocol {
    
    var urlString: String {
        return _urlString
        
    }
    
    var httpMethod: NetBuilders.Method {
        return _method
    }
    
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
