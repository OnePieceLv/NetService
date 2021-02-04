//
//  Interceptor.swift
//  NetService
//
//  Created by steven on 2021/1/7.
//

import Foundation

public protocol Middleware {
    func prepare(_ builder: NetServiceBuilder) -> NetServiceBuilder
    
    func beforeSend<TaskType: NetServiceProtocol>(_ request: TaskType) -> Void
    
    func afterReceive<Response: Responseable>(_ result: Response) -> Response
    
    func didStop<TaskType: NetServiceProtocol>(_ request: TaskType) -> Void
}

public extension Middleware {
    func prepare(_ builder: NetServiceBuilder) -> NetServiceBuilder { builder }
    
    func beforeSend<TaskType: NetServiceProtocol>(_ request: TaskType) -> Void {}
    
    func afterReceive<Response: Responseable>(_ result: Response) -> Response { result }

    func didStop<TaskType: NetServiceProtocol>(_ request: TaskType) -> Void {}
}
