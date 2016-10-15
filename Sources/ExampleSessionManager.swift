//
//  ExampleSessionManager.swift
//  PerfectTemplate
//
//  Created by Edward Jiang on 10/14/16.
//
//

import Turnstile
import Foundation
import TurnstileCrypto

/**
 ExampleSessionManager manages sessions in-memory and is great for development
 purposes.
 */
public class ExampleSessionManager: SessionManager {
    /// Dictionary of sessions
    private var sessions = [String: String]()
    private let random: Random = URandom()
    private var accountStore: ExampleAccountStore
    
    /// Initializes the Session Manager.
    init(accountStore: ExampleAccountStore) {
        self.accountStore = accountStore
    }
    
    /// Creates a session for a given Subject object and returns the identifier.
    public func createSession(account: Account) -> String {
        var identifier: String
        
        // Create new random identifiers and find an unused one.
        repeat {
            identifier = random.secureToken
        } while sessions[identifier] != nil
        
        sessions[identifier] = account.uniqueID
        return identifier
    }
    
    /// Deletes the session for a session identifier.
    public func destroySession(identifier: String) {
        sessions.removeValue(forKey: identifier)
    }
    
    /**
     Creates a Session-backed Account object from the Session store. This only
     contains the SessionID.
     */
    public func restoreAccount(fromSessionID identifier: String) throws -> Account {
        if let accountID = sessions[identifier],
            let account = accountStore.accounts.filter({$0.uniqueID == accountID}).first {
            return account
        } else {
            throw InvalidSessionError()
        }
    }
}
