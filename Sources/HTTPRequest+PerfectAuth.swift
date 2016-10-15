//
//  HTTPRequest+PerfectAuth.swift
//  PerfectTemplate
//
//  Created by Edward Jiang on 10/10/16.
//
//

import PerfectHTTP
import PerfectNet

extension HTTPRequest {
    var scheme: String {
        if let scheme = header(.xForwardedProto) {
            return scheme
        }
        if let netssl = self.connection as? NetTCPSSL, netssl.usingSSL {
            return "https"
        }
        return "http"
    }
    var host: String {
        return self.header(.host) ?? self.serverAddress.host
    }
    var baseURL: String {
        return "\(scheme)://\(self.host)"
    }
}
