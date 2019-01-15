//
//  BacktraceResult.swift
//  Backtrace
//
//  Created by Marcin Karmelita on 15/01/2019.
//

import Foundation

@objc open class BacktraceResult: NSObject {
    
    @objc public let status: BacktraceResultStatus
    @objc public let message: String
    
    init(_ status: BacktraceResultStatus) {
        self.status = status
        self.message = status.description
    }
}

private extension BacktraceResultStatus {
    var description: String {
        switch self {
        case .serverError:
            return "Unknown server error occurred."
        case .ok:
            return "Ok."
        }
    }
}
