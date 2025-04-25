;; Client Verification Contract
;; This contract validates legitimate employers

(define-data-var admin principal tx-sender)

;; Map to store verified clients
(define-map verified-clients principal
  {
    verified: bool,
    company-name: (string-utf8 100),
    industry: (string-utf8 50),
    registration-time: uint
  }
)

;; Public function to register as a client
(define-public (register-client (company-name (string-utf8 100)) (industry (string-utf8 50)))
  (let ((caller tx-sender))
    (asserts! (not (default-to false (get verified (map-get? verified-clients caller)))) (err u1))
    (ok (map-set verified-clients caller
      {
        verified: false,
        company-name: company-name,
        industry: industry,
        registration-time: block-height
      }
    ))
  )
)

;; Admin function to verify a client
(define-public (verify-client (client principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))
    (asserts! (is-some (map-get? verified-clients client)) (err u3))
    (ok (map-set verified-clients client
      (merge (unwrap-panic (map-get? verified-clients client)) { verified: true })
    ))
  )
)

;; Read-only function to check if a client is verified
(define-read-only (is-verified-client (client principal))
  (default-to false (get verified (map-get? verified-clients client)))
)

;; Read-only function to get client details
(define-read-only (get-client-details (client principal))
  (map-get? verified-clients client)
)

;; Function to update admin
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u4))
    (ok (var-set admin new-admin))
  )
)
