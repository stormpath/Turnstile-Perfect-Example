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

let turnstile = TurnstilePerfect()


// Create HTTP server.
let server = HTTPServer()

// Register your own routes and handlers
var routes = Routes()
routes.add(method: .get, uri: "/") {
    request, response in
    if request.user.authenticated {
        response.status = .temporaryRedirect
        response.addHeader(.location, value: "/notes")
        response.completed()
    } else {
        mustacheRequest(request: request, response: response, handler: MustacheHandler(), templatePath: "/Users/edjiang/Documents/code/PerfectAuth/webroot/views/index.mustache")
    }
}

routes.add(method: .get, uri: "/login") { request, response in
    mustacheRequest(request: request, response: response, handler: MustacheHandler(), templatePath: "/Users/edjiang/Documents/code/PerfectAuth/webroot/views/login.mustache")
}


routes.add(method: .post, uri: "/login") { request, response in
    guard let username = request.postData["username"],
        let password = request.postData["password"] else {
            mustacheRequest(request: request, response: response, handler: MustacheHandler(context: ["flash": "Invalid Username or Password"]), templatePath: "/Users/edjiang/Documents/code/PerfectAuth/webroot/views/login.mustache")
            return
    }
    let credentials = UsernamePassword(username: username, password: password)
    
    do {
        try request.user.login(credentials: credentials, persist: true)
        response.status = .temporaryRedirect
        response.addHeader(.location, value: "/notes")
        response.completed()
    } catch {
        mustacheRequest(request: request, response: response, handler: MustacheHandler(context: ["flash": "Invalid Username or Password"]), templatePath: "/Users/edjiang/Documents/code/PerfectAuth/webroot/views/login.mustache")
    }
    
}

routes.add(method: .get, uri: "/register") { request, response in
    mustacheRequest(request: request, response: response, handler: MustacheHandler(), templatePath: "/Users/edjiang/Documents/code/PerfectAuth/webroot/views/register.mustache")
    
}

routes.add(method: .post, uri: "/register") { request, response in
    guard let username = request.postData["username"],
        let password = request.postData["password"] else {
            mustacheRequest(request: request, response: response, handler: MustacheHandler(context: ["flash": "Missing username or password"]), templatePath: "/Users/edjiang/Documents/code/PerfectAuth/webroot/views/register.mustache")
            return
    }
    let credentials = UsernamePassword(username: username, password: password)
    
    do {
        try request.user.register(credentials: credentials)
        try request.user.login(credentials: credentials, persist: true)
        response.status = .temporaryRedirect
        response.addHeader(.location, value: "/")
        response.completed()
    } catch {
        mustacheRequest(request: request, response: response, handler: MustacheHandler(context: ["flash": "Invalid Username or Password"]), templatePath: "/Users/edjiang/Documents/code/PerfectAuth/webroot/views/register.mustache")
    }
}

routes.add(method: .get, uri: "/notes") { request, response in
    mustacheRequest(request: request, response: response, handler: MustacheHandler(context: ["authenticated": true]), templatePath: "/Users/edjiang/Documents/code/PerfectAuth/webroot/views/notes.mustache")
    
}

// Add the routes to the server.
server.addRoutes(routes)

// Set a listen port of 8181
server.serverPort = 8181

server.setRequestFilters([turnstile.requestFilter])
server.setResponseFilters([turnstile.responseFilter])

server.documentRoot = "./webroot"

do {
	// Launch the HTTP server.
	try server.start()
} catch PerfectError.networkError(let err, let msg) {
	print("Network error thrown: \(err) \(msg)")
}
