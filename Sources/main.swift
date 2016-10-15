import PerfectLib
import PerfectHTTP
import PerfectHTTPServer
import PerfectMustache

import TurnstilePerfect
import Turnstile
import TurnstileCrypto
import TurnstileWeb
import Foundation

let accountStore = ExampleAccountStore()

let turnstile = TurnstilePerfect(sessionManager: ExampleSessionManager(accountStore: accountStore), realm: ExampleRealm(accountStore: accountStore))

// Create HTTP server.
let server = HTTPServer()

/**
 Endpoint for the home page.
 */
var routes = Routes()

routes.add(method: .get, uri: "/") {
    request, response in
    let context: [String : Any] = ["account": (request.user.authDetails?.account as? ExampleAccount)?.dict,
                                   "baseURL": request.baseURL,
                                   "authenticated": request.user.authenticated]
    
    response.render(template: "index", context: context)
}

/**
 Login Endpoint
 */
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

/**
 Registration Endpoint
 */
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

/**
 API Endpoint for /me
 */

routes.add(method: .get, uri: "/api/me") { request, response in
    guard let account = request.user.authDetails?.account as? ExampleAccount else {
        response.status = .unauthorized
        response.appendBody(string: "401 Unauthorized")
        response.completed()
        return
    }
    response.appendBody(string: account.json)
    response.completed()
    return
}

/**
 Logout endpoint
 */
routes.add(method: .post, uri: "/logout") { request, response in
    request.user.logout()
    
    response.redirect(path: "/")
}

/**
 If Facebook Auth is configured, let's add /login/facebook and /login/facebook/consumer
 See this for an overview of the flow:
 https://github.com/stormpath/Turnstile#authenticating-with-facebook-or-google
 */
if let clientID = ProcessInfo.processInfo.environment["FACEBOOK_CLIENT_ID"],
    let clientSecret = ProcessInfo.processInfo.environment["FACEBOOK_CLIENT_SECRET"] {
    
    let facebook = Facebook(clientID: clientID, clientSecret: clientSecret)
    
    routes.add(method: .get, uri: "/login/facebook") { request, response in
        let state = URandom().secureToken
        let redirectURL = facebook.getLoginLink(redirectURL: request.baseURL + "/login/facebook/consumer", state: state)
        
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
} else {
    routes.add(method: .get, uri: "/login/facebook") { request, response in
        response.appendBody(string: "You need to configure Facebook Login first!")
        response.completed()
    }
}

/**
 If Google Auth is configured, let's add /login/google and /login/google/consumer
 See this for an overview of the flow:
 https://github.com/stormpath/Turnstile#authenticating-with-facebook-or-google
 */
if let clientID = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"],
    let clientSecret = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_SECRET"] {
    
    let google = Google(clientID: clientID, clientSecret: clientSecret)
    
    routes.add(method: .get, uri: "/login/google") { request, response in
        let state = URandom().secureToken
        let redirectURL = google.getLoginLink(redirectURL: request.baseURL + "/login/google/consumer", state: state)
        
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
}else {
    routes.add(method: .get, uri: "/login/google") { request, response in
        response.appendBody(string: "You need to configure Google Login first!")
        response.completed()
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
