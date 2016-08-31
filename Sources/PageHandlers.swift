//
//  PageHandlers.swift
//  PerfectTemplate
//
//  Created by Edward Jiang on 8/30/16.
//
//

import PerfectMustache

struct MustacheHandler: MustachePageHandler {
    var context: [String: Any]
    func extendValuesForResponse(context contxt: MustacheWebEvaluationContext, collector: MustacheEvaluationOutputCollector) {
        contxt.extendValues(with: context)
        do {
            contxt.webResponse.setHeader(.contentType, value: "text/html")
            try contxt.requestCompleted(withCollector: collector)
        } catch {
            let response = contxt.webResponse
            response.status = .internalServerError
            response.appendBody(string: "\(error)")
            response.completed()
        }
    }
    
    public init(context: [String: Any] = [String: Any]()) {
        self.context = context
    }
}

