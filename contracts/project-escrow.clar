;; Project Escrow Contract
;; This contract manages secure payment during work

(define-constant ERR-NOT-AUTHORIZED u1)
(define-constant ERR-ALREADY-EXISTS u2)
(define-constant ERR-DOES-NOT-EXIST u3)
(define-constant ERR-INVALID-STATE u4)
(define-constant ERR-TRANSFER-FAILED u5)

;; Project states
(define-constant STATE-CREATED u1)
(define-constant STATE-FUNDED u2)
(define-constant STATE-IN-PROGRESS u3)
(define-constant STATE-COMPLETED u4)
(define-constant STATE-CANCELLED u5)

;; Map to store projects
(define-map projects uint
  {
    client: principal,
    freelancer: principal,
    amount: uint,
    state: uint,
    creation-time: uint,
    completion-time: uint
  }
)

(define-data-var project-counter uint u0)

;; Create a new project
(define-public (create-project (freelancer principal) (amount uint))
  (let ((project-id (var-get project-counter))
        (caller tx-sender))
    (ok (begin
      (map-set projects project-id
        {
          client: caller,
          freelancer: freelancer,
          amount: amount,
          state: STATE-CREATED,
          creation-time: block-height,
          completion-time: u0
        }
      )
      (var-set project-counter (+ project-id u1))
      project-id
    ))
  )
)

;; Fund a project (client deposits funds)
(define-public (fund-project (project-id uint))
  (let ((project (unwrap! (map-get? projects project-id) (err ERR-DOES-NOT-EXIST)))
        (caller tx-sender))
    (asserts! (is-eq caller (get client project)) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-eq (get state project) STATE-CREATED) (err ERR-INVALID-STATE))

    ;; Transfer tokens from client to contract
    (match (stx-transfer? (get amount project) caller (as-contract tx-sender))
      success (ok (map-set projects project-id
                  (merge project { state: STATE-FUNDED })))
      error (err ERR-TRANSFER-FAILED))
  )
)

;; Start a project (freelancer accepts)
(define-public (start-project (project-id uint))
  (let ((project (unwrap! (map-get? projects project-id) (err ERR-DOES-NOT-EXIST)))
        (caller tx-sender))
    (asserts! (is-eq caller (get freelancer project)) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-eq (get state project) STATE-FUNDED) (err ERR-INVALID-STATE))

    (ok (map-set projects project-id
        (merge project { state: STATE-IN-PROGRESS })))
  )
)

;; Complete a project (client confirms)
(define-public (complete-project (project-id uint))
  (let ((project (unwrap! (map-get? projects project-id) (err ERR-DOES-NOT-EXIST)))
        (caller tx-sender))
    (asserts! (is-eq caller (get client project)) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-eq (get state project) STATE-IN-PROGRESS) (err ERR-INVALID-STATE))

    ;; Transfer tokens from contract to freelancer
    (as-contract
      (match (stx-transfer? (get amount project) tx-sender (get freelancer project))
        success (ok (map-set projects project-id
                    (merge project {
                      state: STATE-COMPLETED,
                      completion-time: block-height
                    })))
        error (err ERR-TRANSFER-FAILED)))
  )
)

;; Cancel a project (only in created or funded state)
(define-public (cancel-project (project-id uint))
  (let ((project (unwrap! (map-get? projects project-id) (err ERR-DOES-NOT-EXIST)))
        (caller tx-sender)
        (current-state (get state project)))
    (asserts! (is-eq caller (get client project)) (err ERR-NOT-AUTHORIZED))
    (asserts! (or (is-eq current-state STATE-CREATED) (is-eq current-state STATE-FUNDED)) (err ERR-INVALID-STATE))

    ;; If funded, return funds to client
    (if (is-eq current-state STATE-FUNDED)
      (as-contract
        (match (stx-transfer? (get amount project) tx-sender (get client project))
          success (ok (map-set projects project-id
                      (merge project { state: STATE-CANCELLED })))
          error (err ERR-TRANSFER-FAILED)))
      (ok (map-set projects project-id
          (merge project { state: STATE-CANCELLED })))
    )
  )
)

;; Read-only function to get project details
(define-read-only (get-project-details (project-id uint))
  (map-get? projects project-id)
)

;; Read-only function to get project state
(define-read-only (get-project-state (project-id uint))
  (get state (default-to
    { state: u0 }
    (map-get? projects project-id)))
)
