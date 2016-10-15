//
//  ExampleRealm.swift
//  PerfectTemplate
//
//  Created by Edward Jiang on 10/14/16.
//
//

import Turnstile
import TurnstileCrypto
import TurnstileWeb

public class ExampleRealm: Realm {
    private var accountStore: ExampleAccountStore
    private var random: Random = URandom()
    
    /// Initializer for ExampleRealm
    init(accountStore: ExampleAccountStore) {
        self.accountStore = accountStore
    }
    
    /**
     Authenticates PasswordCredentials against the Realm.
     */
    public func authenticate(credentials: Credentials) throws -> Account {
        switch credentials {
        case let credentials as UsernamePassword:
            return try authenticate(credentials: credentials)
        case let credentials as APIKey:
            return try authenticate(credentials: credentials)
        case let credentials as FacebookAccount:
            return try authenticate(credentials: credentials)
        case let credentials as GoogleAccount:
            return try authenticate(credentials: credentials)
        default:
            throw UnsupportedCredentialsError()
        }
    }
    
    private func authenticate(credentials: UsernamePassword) throws -> Account {
        if let account = accountStore.accounts.filter({$0.username == credentials.username}).first,
            (try? BCrypt.verify(password: credentials.password, matchesHash: account.password ?? "")) == true {
            return account
        } else {
            throw IncorrectCredentialsError()
        }
    }
    
    private func authenticate(credentials: APIKey) throws -> Account {
        if let account = accountStore.accounts.filter({$0.uniqueID == credentials.id && $0.apiKeySecret == credentials.secret}).first {
            return account
        } else {
            throw IncorrectCredentialsError()
        }
    }
    
    private func authenticate(credentials: FacebookAccount) throws -> Account {
        if let account = accountStore.accounts.filter({$0.facebookID == credentials.uniqueID}).first {
            return account
        } else {
            return try register(credentials: credentials)
        }
    }
    
    private func authenticate(credentials: GoogleAccount) throws -> Account {
        if let account = accountStore.accounts.filter({$0.googleID == credentials.uniqueID}).first {
            return account
        } else {
            return try register(credentials: credentials)
        }
    }
    
    /**
     Registers PasswordCredentials against the ExampleRealm.
     */
    public func register(credentials: Credentials) throws -> Account {
        var newAccount = ExampleAccount(id: String(random.secureToken))
        
        switch credentials {
        case let credentials as UsernamePassword:
            guard accountStore.accounts.filter({$0.username == credentials.username}).first == nil else {
                throw AccountTakenError()
            }
            newAccount.username = credentials.username
            newAccount.password = BCrypt.hash(password: credentials.password)
        case let credentials as FacebookAccount:
            guard accountStore.accounts.filter({$0.facebookID == credentials.uniqueID}).first == nil else {
                throw AccountTakenError()
            }
            newAccount.username = "fb" + credentials.uniqueID
            newAccount.facebookID = credentials.uniqueID
        case let credentials as GoogleAccount:
            guard accountStore.accounts.filter({$0.googleID == credentials.uniqueID}).first == nil else {
                throw AccountTakenError()
            }
            newAccount.username = "goog" + credentials.uniqueID
            newAccount.googleID = credentials.uniqueID
        default:
            throw UnsupportedCredentialsError()
        }
        accountStore.accounts.append(newAccount)
        return newAccount
    }
}
