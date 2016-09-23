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
    
    mustacheRequest(request: request, response: response, handler: MustacheHandler(context: context), templatePath: request.documentRoot + "/views/index.mustache")
}

routes.add(method: .get, uri: "/login") { request, response in
    mustacheRequest(request: request, response: response, handler: MustacheHandler(), templatePath: request.documentRoot + "/views/login.mustache")
}


routes.add(method: .post, uri: "/login") { request, response in
    guard let username = request.postData["username"],
        let password = request.postData["password"] else {
            mustacheRequest(request: request, response: response, handler: MustacheHandler(context: ["flash": "Missing username or password"]), templatePath: request.documentRoot + "/views/login.mustache")
            return
    }
    let credentials = UsernamePassword(username: username, password: password)
    
    do {
        try request.user.login(credentials: credentials, persist: true)
        response.status = .found
        response.addHeader(.location, value: "/")
        response.completed()
    } catch {
        mustacheRequest(request: request, response: response, handler: MustacheHandler(context: ["flash": "Invalid Username or Password"]), templatePath: request.documentRoot + "/views/login.mustache")
    }
    
}

routes.add(method: .get, uri: "/register") { request, response in
    mustacheRequest(request: request, response: response, handler: MustacheHandler(), templatePath: request.documentRoot + "/views/register.mustache")
    
}

routes.add(method: .post, uri: "/register") { request, response in
    guard let username = request.postData["username"],
        let password = request.postData["password"] else {
            mustacheRequest(request: request, response: response, handler: MustacheHandler(context: ["flash": "Missing username or password"]), templatePath: request.documentRoot + "/views/register.mustache")
            return
    }
    let credentials = UsernamePassword(username: username, password: password)
    
    do {
        try request.user.register(credentials: credentials)
        try request.user.login(credentials: credentials, persist: true)
        response.status = .found
        response.addHeader(.location, value: "/")
        response.completed()
    } catch let e as TurnstileError {
        mustacheRequest(request: request, response: response, handler: MustacheHandler(context: ["flash": e.description]), templatePath: request.documentRoot + "/views/register.mustache")
    } catch {
        mustacheRequest(request: request, response: response, handler: MustacheHandler(context: ["flash": "An unknown error occurred."]), templatePath: request.documentRoot + "/views/register.mustache")
    }
}

routes.add(method: .post, uri: "/logout") { request, response in
    request.user.logout()
    
    response.status = .found
    response.addHeader(.location, value: "/")
    response.completed()
}

routes.add(method: .get, uri: "/login/facebook") { request, response in
    let state = URandom().secureToken
    let redirectURL = facebook.getLoginLink(redirectURL: "http://localhost:8181/login/facebook/consumer", state: state)
    response.status = .found
    response.setHeader(HTTPResponseHeader.Name.location, value: redirectURL.absoluteString)
    response.addCookie(HTTPCookie(name: "OAuthState", value: state, domain: nil, expires: HTTPCookie.Expiration.relativeSeconds(3600), path: "/", secure: nil, httpOnly: true))
    response.completed()
}

routes.add(method: .get, uri: "/login/facebook/consumer") { request, response in
    guard let state = request.cookies.filter({$0.0 == "OAuthState"}).first?.1 else {
        mustacheRequest(request: request, response: response, handler: MustacheHandler(context: ["flash": "Unknown Error"]), templatePath: request.documentRoot + "/views/login.mustache")
        return
    }
    response.addCookie(HTTPCookie(name: "OAuthState", value: state, domain: nil, expires: HTTPCookie.Expiration.absoluteSeconds(0), path: "/", secure: nil, httpOnly: true))
    var uri = "http://localhost:8181" + request.uri

    do {
        let credentials = try facebook.authenticate(authorizationCodeCallbackURL: uri, state: state) as! FacebookAccount
        try request.user.login(credentials: credentials, persist: true)
        response.status = .found
        response.addHeader(.location, value: "/")
        response.completed()
    } catch let error {
        let description = (error as? TurnstileError)?.description ?? "Unknown Error"
        mustacheRequest(request: request, response: response, handler: MustacheHandler(context: ["flash": description]), templatePath: request.documentRoot + "/views/login.mustache")
    }
}

routes.add(method: .get, uri: "/login/google") { request, response in
    let state = URandom().secureToken
    let redirectURL = google.getLoginLink(redirectURL: "http://localhost:8181/login/google/consumer", state: state)
    
    response.status = .found
    response.setHeader(HTTPResponseHeader.Name.location, value: redirectURL.absoluteString)
    response.addCookie(HTTPCookie(name: "OAuthState", value: state, domain: nil, expires: nil, path: "/", secure: nil, httpOnly: true))
    response.completed()
}

routes.add(method: .get, uri: "/login/google/consumer") { request, response in
    guard let state = request.cookies.filter({$0.0 == "OAuthState"}).first?.1 else {
        mustacheRequest(request: request, response: response, handler: MustacheHandler(context: ["flash": "Unknown Error"]), templatePath: request.documentRoot + "/views/login.mustache")
        return
    }
    response.addCookie(HTTPCookie(name: "OAuthState", value: state, domain: nil, expires: HTTPCookie.Expiration.absoluteSeconds(0), path: "/", secure: nil, httpOnly: true))
    var uri = "http://localhost:8181" + request.uri
    
    if uri.hasSuffix(")") { // Workaround for bug at https://github.com/PerfectlySoft/Perfect-HTTP/pull/4
        uri.remove(at: uri.index(before: uri.endIndex))
    }
    do {
        let credentials = try google.authenticate(authorizationCodeCallbackURL: uri, state: state) as! GoogleAccount
        try request.user.login(credentials: credentials, persist: true)
        response.status = .found
        response.addHeader(.location, value: "/")
        response.completed()
    } catch let error {
        let description = (error as? TurnstileError)?.description ?? "Unknown Error"
        mustacheRequest(request: request, response: response, handler: MustacheHandler(context: ["flash": description]), templatePath: request.documentRoot + "/views/login.mustache")
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
