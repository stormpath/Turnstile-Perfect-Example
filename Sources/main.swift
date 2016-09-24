//
//  main.swift
//  PerfectTemplate
//
//  Created by Kyle Jessup on 2015-11-05.
//	Copyright (C) 2015 PerfectlySoft, Inc.
//
//===----------------------------------------------------------------------===//
//
// This source file is part of the Perfect.org open source project
//
// Copyright (c) 2015 - 2016 PerfectlySoft Inc. and the Perfect project authors
// Licensed under Apache License v2.0
//
// See http://perfect.org/licensing.html for license information
//
//===----------------------------------------------------------------------===//
//

import PerfectLib
import PerfectHTTP
import PerfectHTTPServer
import PerfectMustache

import TurnstilePerfect
import Turnstile
import TurnstileCrypto
import TurnstileWeb
import Foundation

let turnstile = TurnstilePerfect()

let facebook = Facebook(clientID: "CLIENT_ID", clientSecret: "CLIENT_SECRET")
let google = Google(clientID: "CLIENT_ID", clientSecret: "CLIENT_SECRET")

// Create HTTP server.
let server = HTTPServer()

// Register your own routes and handlers
var routes = Routes()
routes.add(method: .get, uri: "/") {
    request, response in
    let context: [String : Any] = ["accountID": request.user.authDetails?.account.uniqueID ?? "",
                   "authenticated": request.user.authenticated]
    
    response.render(template: "index", context: context)
}

routes.add(method: .get, uri: "/login") { request, response in
    response.render(template: "login")
}


routes.add(method: .post, uri: "/login") { request, response in
    
    guard let username = request.param(name: "username"),
        let password = request.param(name: "password") else {
            response.render(template: "login", context:  ["flash": "Missing username or password"])
            return
    }
    let credentials = UsernamePassword(username: username, password: password)
    
    do {
        try request.user.login(credentials: credentials, persist: true)
        response.redirect(path: "/")
    } catch {
        response.render(template: "login", context: ["flash": "Invalid Username or Password"])
    }
    
}

routes.add(method: .get, uri: "/register") { request, response in
    response.render(template: "register");
}

routes.add(method: .post, uri: "/register") { request, response in
    guard let username = request.param(name: "username"),
        let password = request.param(name: "password") else {
            response.render(template: "register", context: ["flash": "Missing username or password"])
            return
    }
    let credentials = UsernamePassword(username: username, password: password)
    
    do {
        try request.user.register(credentials: credentials)
        try request.user.login(credentials: credentials, persist: true)
        response.redirect(path: "/")
    } catch let e as TurnstileError {
        response.render(template: "register", context: ["flash": e.description])
    } catch {
        response.render(template: "register", context: ["flash": "An unknown error occurred."])
    }
}

routes.add(method: .post, uri: "/logout") { request, response in
    request.user.logout()
    
    response.redirect(path: "/")
}

routes.add(method: .get, uri: "/login/facebook") { request, response in
    let state = URandom().secureToken
    let redirectURL = facebook.getLoginLink(redirectURL: "http://localhost:8181/login/facebook/consumer", state: state)
    
    response.addCookie(HTTPCookie(name: "OAuthState", value: state, domain: nil, expires: HTTPCookie.Expiration.relativeSeconds(3600), path: "/", secure: nil, httpOnly: true))
    response.redirect(path: redirectURL.absoluteString)
}

routes.add(method: .get, uri: "/login/facebook/consumer") { request, response in
    guard let state = request.cookies.filter({$0.0 == "OAuthState"}).first?.1 else {
        response.render(template: "login", context: ["flash": "Unknown Error"])
        return
    }
    response.addCookie(HTTPCookie(name: "OAuthState", value: state, domain: nil, expires: HTTPCookie.Expiration.absoluteSeconds(0), path: "/", secure: nil, httpOnly: true))
    var uri = "http://localhost:8181" + request.uri

    do {
        let credentials = try facebook.authenticate(authorizationCodeCallbackURL: uri, state: state) as! FacebookAccount
        try request.user.login(credentials: credentials, persist: true)
        response.redirect(path: "/")
    } catch let error {
        let description = (error as? TurnstileError)?.description ?? "Unknown Error"
        response.render(template: "login", context: ["flash": description])
    }
}

routes.add(method: .get, uri: "/login/google") { request, response in
    let state = URandom().secureToken
    let redirectURL = google.getLoginLink(redirectURL: "http://localhost:8181/login/google/consumer", state: state)
    
    response.addCookie(HTTPCookie(name: "OAuthState", value: state, domain: nil, expires: nil, path: "/", secure: nil, httpOnly: true))
    response.redirect(path: redirectURL.absoluteString)
}

routes.add(method: .get, uri: "/login/google/consumer") { request, response in
    guard let state = request.cookies.filter({$0.0 == "OAuthState"}).first?.1 else {
        response.render(template: "login", context: ["flash": "Unknown Error"])
        return
    }
    response.addCookie(HTTPCookie(name: "OAuthState", value: state, domain: nil, expires: HTTPCookie.Expiration.absoluteSeconds(0), path: "/", secure: nil, httpOnly: true))
    var uri = "http://localhost:8181" + request.uri
    
    do {
        let credentials = try google.authenticate(authorizationCodeCallbackURL: uri, state: state) as! GoogleAccount
        try request.user.login(credentials: credentials, persist: true)
        response.redirect(path: "/")
    } catch let error {
        let description = (error as? TurnstileError)?.description ?? "Unknown Error"
        response.render(template: "login", context: ["flash": description])
    }
}

// Add the routes to the server.
server.addRoutes(routes)

// Set a listen port of 8181
server.serverPort = 8181

server.setRequestFilters([turnstile.requestFilter])
server.setResponseFilters([turnstile.responseFilter])


var webroot: String
#if Xcode
    webroot = "/" + #file.characters.split(separator: "/").map(String.init).dropLast(2).joined(separator: "/")
    webroot += "/webroot"
#else
    webroot = "./webroot"
#endif

server.documentRoot = webroot

do {
	// Launch the HTTP server.
	try server.start()
} catch PerfectError.networkError(let err, let msg) {
	print("Network error thrown: \(err) \(msg)")
}
