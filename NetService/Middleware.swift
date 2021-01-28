//
//  Interceptor.swift
//  Merlin-iOS
//
//  Created by steven on 2021/1/7.
//

import Foundation

public protocol Middleware {
    func prepare(_ builder: RequestBuilder) -> RequestBuilder
    
    func beforeSend<TaskType: BaseAPIService>(_ request: TaskType) -> Void
    
    func afterReceive<Result>(_ response: Result) -> Result
    
    func didStop<TaskType: BaseAPIService>(_ request: TaskType) -> Void
}

extension Middleware {
    func prepare(_ builder: RequestBuilder) -> RequestBuilder { builder }
    
    func beforeSend<TaskType: BaseAPIService>(_ request: TaskType) -> Void {}
    
    func afterReceive<Result>(_ response: Result) -> Result { response }
    
    func didStop<TaskType: BaseAPIService>(_ request: TaskType) -> Void {}
}
