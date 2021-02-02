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
    
    func afterReceive<Result>(_ response: Result) -> Result
    
    func didStop<TaskType: APIService>(_ request: TaskType) -> Void
}

extension Middleware {
    func prepare(_ builder: RequestBuilder) -> RequestBuilder { builder }
    
    func beforeSend<TaskType: APIService>(_ request: TaskType) -> Void {}
    
    func afterReceive<Result>(_ response: Result) -> Result { response }
    
    func didStop<TaskType: APIService>(_ request: TaskType) -> Void {}
}
