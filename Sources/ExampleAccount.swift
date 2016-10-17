//
//  ExampleAccount.swift
//  PerfectAuth
//
//  Created by Edward Jiang on 10/17/16.
//
//

import Foundation
import Turnstile
import TurnstileCrypto

public struct ExampleAccount: Account {
    public var uniqueID: String
    public var username: String?
    public var password: String?
    public var apiKeySecret: String = URandom().secureToken
    
    public var facebookID: String?
    public var googleID: String?
    
    init(id: String) {
        uniqueID = id
    }
    
    var dict: [String: String] {
        return [ "id": uniqueID,
                 "username": username ?? "",
                 "password": password ?? "",
                 "facebook_id": facebookID ?? "",
                 "google_id": googleID ?? "",
                 "api_key_id": uniqueID,
                 "api_key_secret": apiKeySecret
        ]
    }
    
    var json: String {
        if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: []),
            let result = String(data: jsonData, encoding: .utf8) {
            return result
        }
        return ""
        
    }
}
