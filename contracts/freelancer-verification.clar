;; Freelancer Verification Contract
;; This contract validates worker identities and skills

(define-data-var admin principal tx-sender)

;; Map to store verified freelancers
(define-map verified-freelancers principal
  {
    verified: bool,
    name: (string-utf8 100),
    skills: (list 10 (string-utf8 50)),
    registration-time: uint
  }
)

;; Public function to register as a freelancer
(define-public (register-freelancer (name (string-utf8 100)) (skills (list 10 (string-utf8 50))))
  (let ((caller tx-sender))
    (asserts! (not (default-to false (get verified (map-get? verified-freelancers caller)))) (err u1))
    (ok (map-set verified-freelancers caller
      {
        verified: false,
        name: name,
        skills: skills,
        registration-time: block-height
      }
    ))
  )
)

;; Admin function to verify a freelancer
(define-public (verify-freelancer (freelancer principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))
    (asserts! (is-some (map-get? verified-freelancers freelancer)) (err u3))
    (ok (map-set verified-freelancers freelancer
      (merge (unwrap-panic (map-get? verified-freelancers freelancer)) { verified: true })
    ))
  )
)

;; Read-only function to check if a freelancer is verified
(define-read-only (is-verified-freelancer (freelancer principal))
  (default-to false (get verified (map-get? verified-freelancers freelancer)))
)

;; Read-only function to get freelancer details
(define-read-only (get-freelancer-details (freelancer principal))
  (map-get? verified-freelancers freelancer)
)

;; Function to update admin
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u4))
    (ok (var-set admin new-admin))
  )
)
