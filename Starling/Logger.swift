//
//  Logger.swift
//  Starling
//
//  Created by Viktor Strate Kløvedal on 06/12/2023.
//

import Foundation

public enum StarlingLogContext: CustomStringConvertible {
    case tag(_ tag: String), proto
    
    public var description: String {
        switch self {
        case let .tag(tag):
            return tag
        case .proto:
            return "PROTO"
        }
    }
}

public enum StarlingLogPrioroty: CustomStringConvertible {
    case debug, info, warning, error
    
    public var description: String {
        switch self {
        case .debug:
            return "DEBUG"
        case .info:
            return "INFO"
        case .warning:
            return "WARN"
        case .error:
            return "ERROR"
        }
    }
}

public protocol StarlingLogger {
    func log(priority: StarlingLogPrioroty, ctx: StarlingLogContext, message: String)
}

public struct StarlingDefaultLogger: StarlingLogger {
    public init() {}
    
    public func log(priority: StarlingLogPrioroty, ctx: StarlingLogContext, message: String) {
        NSLog("\(priority) \(ctx): \(message)")
    }
}

struct Logger {
    let ctx: StarlingLogContext
    let logger: StarlingLogger
    
    init(ctx: StarlingLogContext, logger: StarlingLogger) {
        self.ctx = ctx
        self.logger = logger
    }
    
    func d(_ msg: String) {
        self.logger.log(priority: .debug, ctx: self.ctx, message: msg)
    }
    
    func i(_ msg: String) {
        self.logger.log(priority: .info, ctx: self.ctx, message: msg)
    }
    
    func w(_ msg: String) {
        self.logger.log(priority: .warning, ctx: self.ctx, message: msg)
    }
    
    func e(_ msg: String) {
        self.logger.log(priority: .error, ctx: self.ctx, message: msg)
    }
}
