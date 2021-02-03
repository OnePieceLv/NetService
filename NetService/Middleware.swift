//
//  Interceptor.swift
//  NetService
//
//  Created by steven on 2021/1/7.
//

import Foundation

public protocol Middleware {
    func prepare(_ builder: RequestBuilder) -> RequestBuilder
    
    func beforeSend<TaskType: APIService>(_ request: TaskType) -> Void
    
    func afterReceive<Response: Responseable>(_ result: Response) -> Response
    
    func didStop<TaskType: APIService>(_ request: TaskType) -> Void
}

extension Middleware {
    func prepare(_ builder: RequestBuilder) -> RequestBuilder { builder }
    
    func beforeSend<TaskType: APIService>(_ request: TaskType) -> Void {}
    
    func afterReceive<Response: Responseable>(_ result: Response) -> Response { result }

    func didStop<TaskType: APIService>(_ request: TaskType) -> Void {}
}
