//
//  WebSocketErrorsHelper.swift
//  bears-chat-ios
//
//  Created by Sergey Kozlov on 02.04.2026.
//

import Foundation
import Darwin

enum WebSocketErrorsHelper {
    static func shouldDisplay(_ error: Error) -> Bool {
        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain {
            let code = URLError.Code(rawValue: nsError.code)
            switch code {
            case .cancelled, .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
                 .networkConnectionLost, .notConnectedToInternet:
                return false
            default:
                break
            }
        }

        if nsError.domain == NSPOSIXErrorDomain {
            switch nsError.code {
            case Int(ECONNABORTED), Int(ECONNRESET), Int(ENETDOWN), Int(ENETUNREACH),
                 Int(ENOTCONN), Int(ETIMEDOUT), Int(EPIPE):
                return false
            default:
                break
            }
        }

        return true
    }
}
