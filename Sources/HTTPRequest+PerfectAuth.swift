//
//  HTTPRequest+PerfectAuth.swift
//  PerfectTemplate
//
//  Created by Edward Jiang on 8/30/16.
//
//

import PerfectHTTP

extension HTTPRequest {
    var postData: [String: String] {
        var result = [String: String]()
        for param in postParams {
            result[param.0] = param.1
        }
        return result
    }
}
