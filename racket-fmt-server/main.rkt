#lang racket/base

(require web-server/servlet
         web-server/servlet-env
         web-server/dispatch
         fmt
         racket/port
         racket/exn
         racket/match
         racket/format
         racket/string
         threading)

; This inherits from fail:user as we don't want stack traces associated with the resulting error
(struct exn:fail:handler exn:fail:user ())
(struct exn:fail:servlet:missing-param exn:fail:user ())

(define (raise-custom-exception exn message)
  (raise (exn message (current-continuation-marks))))

(define (raise-handler-exception message)
  (raise-custom-exception exn:fail:handler message))

(define TEXT-MIME-TYPE #"text/plain; charset=utf-8")

(define (get-query-param req key)
  (with-handlers ([exn:fail? (lambda (_)
                               (raise-custom-exception
                                exn:fail:servlet:missing-param
                                (~a '("Query param " key " expected but not provided"))))])
    (define bindings (request-bindings req))
    (extract-binding/single key bindings)))

(define (resp-with-status body status)
  (response/full 200 #f (current-seconds) TEXT-MIME-TYPE '() (list (string->bytes/utf-8 body))))

(define (ok-resp body)
  (resp-with-status body 200))

(define (not-ok-resp body)
  (resp-with-status body 400))

(define (not-found-resp)
  (resp-with-status "404" 404))

(define (server-error-resp)
  (resp-with-status "Internal server error occurred" 500))

(define (with-text-resp dispatch)
  (lambda (req) (let ([body (dispatch req)]) (ok-resp body))))

(define (print-exception exn)
  (define message (exn-message exn))
  (define stack
    (~>> exn
         exn-continuation-marks
         continuation-mark-set->context
         (map (lambda (c) (srcloc->string (cdr c))))
         (string-join _ "\n")))
  (log-error (~a (list message "\n\nContext:\n" stack))))

(define (servlet-error-responder _ e)
  (match e
    [(? exn:fail:handler? _) (not-ok-resp (exn->string e))]
    [_ (begin
         (print-exception e)
         (server-error-resp))]))

(define (format-handler req)
  (with-handlers ([exn:fail:filesystem? (lambda (_) (raise-handler-exception "Could not open file"))]
                  ; TODO: raise custom error from get-query-param that isn't just exn:fail
                  [exn:fail:servlet:missing-param?
                   (lambda (_) (raise-handler-exception "Path not provided"))]

                  ; This should only happen when the path is an empty string
                  ; If this isn't true we can add more granularity checks in the lambda
                  [exn:fail:contract? (lambda (_) (raise-handler-exception "Path not provided"))])
    (define path (get-query-param req 'path))
    (define file-contents (port->string (open-input-file path #:mode 'text)))
    ; TODO make this formatting a bit nicer for things like let and let-values and threading
    ;      They shouldn't be on the same line
    (program-format file-contents #:formatter-map standard-formatter-map)))

(define (404-handler req)
  (not-found-resp))

(define app
  (let-values ([(dispatch _) (dispatch-rules [("format") format-handler] [else 404-handler])])
    (~> dispatch with-text-resp)))

(displayln "Starting format server on port 49101...")
(serve/servlet app
               #:command-line? #t
               #:port 49101
               #:servlet-regexp #rx"^"
               #:servlet-responder servlet-error-responder)
