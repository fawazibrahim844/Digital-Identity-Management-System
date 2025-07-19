;; Biometric Authentication Contract
;; Manages biometric data hashing and authentication

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-INPUT (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-EXISTS (err u103))
(define-constant ERR-VERIFICATION-FAILED (err u104))

;; Biometric types
(define-constant BIOMETRIC-FINGERPRINT u1)
(define-constant BIOMETRIC-FACE u2)
(define-constant BIOMETRIC-VOICE u3)
(define-constant BIOMETRIC-IRIS u4)

;; Data structures
(define-map biometric-data
  { user: principal, biometric-type: uint }
  {
    data-hash: (buff 32),
    salt: (buff 16),
    registered-at: uint,
    last-used: uint,
    usage-count: uint,
    active: bool
  }
)

(define-map authentication-attempts
  { user: principal, attempt-id: uint }
  {
    biometric-type: uint,
    timestamp: uint,
    success: bool,
    ip-hash: (optional (buff 32))
  }
)

(define-map attempt-counters
  { user: principal }
  { counter: uint }
)

(define-map user-settings
  { user: principal }
  {
    max-failed-attempts: uint,
    lockout-duration: uint,
    require-multiple-factors: bool,
    last-lockout: uint
  }
)

;; Public functions

;; Register biometric data
(define-public (register-biometric
  (biometric-type uint)
  (data-hash (buff 32))
  (salt (buff 16))
)
  (let ((user tx-sender))
    (asserts! (and (>= biometric-type u1) (<= biometric-type u4)) ERR-INVALID-INPUT)
    (asserts! (> (len data-hash) u0) ERR-INVALID-INPUT)
    (asserts! (> (len salt) u0) ERR-INVALID-INPUT)

    ;; Check if biometric already exists
    (asserts! (is-none (map-get? biometric-data { user: user, biometric-type: biometric-type })) ERR-ALREADY-EXISTS)

    (map-set biometric-data
      { user: user, biometric-type: biometric-type }
      {
        data-hash: data-hash,
        salt: salt,
        registered-at: block-height,
        last-used: u0,
        usage-count: u0,
        active: true
      }
    )

    ;; Initialize user settings if not exists
    (if (is-none (map-get? user-settings { user: user }))
      (map-set user-settings
        { user: user }
        {
          max-failed-attempts: u5,
          lockout-duration: u144, ;; ~24 hours in blocks
          require-multiple-factors: false,
          last-lockout: u0
        }
      )
      true
    )

    (ok true)
  )
)

;; Authenticate using biometric data
(define-public (authenticate
  (biometric-type uint)
  (provided-hash (buff 32))
  (ip-hash (optional (buff 32)))
)
  (let (
    (user tx-sender)
    (biometric (unwrap! (map-get? biometric-data { user: user, biometric-type: biometric-type }) ERR-NOT-FOUND))
    (settings (unwrap! (map-get? user-settings { user: user }) ERR-NOT-FOUND))
    (is-locked-out (> (+ (get last-lockout settings) (get lockout-duration settings)) block-height))
  )
    (asserts! (get active biometric) ERR-NOT-AUTHORIZED)
    (asserts! (not is-locked-out) ERR-NOT-AUTHORIZED)

    (let (
      (auth-success (is-eq (get data-hash biometric) provided-hash))
      (attempt-counter (default-to u0 (get counter (map-get? attempt-counters { user: user }))))
      (new-attempt-id (+ attempt-counter u1))
    )
      ;; Log authentication attempt
      (map-set authentication-attempts
        { user: user, attempt-id: new-attempt-id }
        {
          biometric-type: biometric-type,
          timestamp: block-height,
          success: auth-success,
          ip-hash: ip-hash
        }
      )

      (map-set attempt-counters { user: user } { counter: new-attempt-id })

      (if auth-success
        ;; Successful authentication
        (begin
          (map-set biometric-data
            { user: user, biometric-type: biometric-type }
            (merge biometric {
              last-used: block-height,
              usage-count: (+ (get usage-count biometric) u1)
            })
          )
          (ok true)
        )
        ;; Failed authentication
        (begin
          ;; Check if should lock out user
          (let ((recent-failures (count-recent-failures user)))
            (if (>= recent-failures (get max-failed-attempts settings))
              (map-set user-settings
                { user: user }
                (merge settings { last-lockout: block-height })
              )
              true
            )
          )
          ERR-VERIFICATION-FAILED
        )
      )
    )
  )
)

;; Update biometric data
(define-public (update-biometric
  (biometric-type uint)
  (new-data-hash (buff 32))
  (new-salt (buff 16))
)
  (let (
    (user tx-sender)
    (existing-biometric (unwrap! (map-get? biometric-data { user: user, biometric-type: biometric-type }) ERR-NOT-FOUND))
  )
    (asserts! (> (len new-data-hash) u0) ERR-INVALID-INPUT)
    (asserts! (> (len new-salt) u0) ERR-INVALID-INPUT)

    (map-set biometric-data
      { user: user, biometric-type: biometric-type }
      (merge existing-biometric {
        data-hash: new-data-hash,
        salt: new-salt
      })
    )

    (ok true)
  )
)

;; Deactivate biometric
(define-public (deactivate-biometric (biometric-type uint))
  (let (
    (user tx-sender)
    (existing-biometric (unwrap! (map-get? biometric-data { user: user, biometric-type: biometric-type }) ERR-NOT-FOUND))
  )
    (map-set biometric-data
      { user: user, biometric-type: biometric-type }
      (merge existing-biometric { active: false })
    )

    (ok true)
  )
)

;; Update user settings
(define-public (update-settings
  (max-failed-attempts uint)
  (lockout-duration uint)
  (require-multiple-factors bool)
)
  (let ((user tx-sender))
    (asserts! (> max-failed-attempts u0) ERR-INVALID-INPUT)
    (asserts! (> lockout-duration u0) ERR-INVALID-INPUT)

    (map-set user-settings
      { user: user }
      {
        max-failed-attempts: max-failed-attempts,
        lockout-duration: lockout-duration,
        require-multiple-factors: require-multiple-factors,
        last-lockout: (default-to u0 (get last-lockout (map-get? user-settings { user: user })))
      }
    )

    (ok true)
  )
)

;; Private functions

;; Count recent authentication failures
(define-private (count-recent-failures (user principal))
  ;; This is a simplified implementation
  ;; In practice, you'd iterate through recent attempts
  u0
)

;; Read-only functions

;; Check if biometric is registered
(define-read-only (is-biometric-registered (user principal) (biometric-type uint))
  (is-some (map-get? biometric-data { user: user, biometric-type: biometric-type }))
)

;; Get biometric info (without sensitive data)
(define-read-only (get-biometric-info (user principal) (biometric-type uint))
  (match (map-get? biometric-data { user: user, biometric-type: biometric-type })
    biometric (some {
      registered-at: (get registered-at biometric),
      last-used: (get last-used biometric),
      usage-count: (get usage-count biometric),
      active: (get active biometric)
    })
    none
  )
)

;; Get user settings
(define-read-only (get-user-settings (user principal))
  (map-get? user-settings { user: user })
)

;; Check if user is locked out
(define-read-only (is-locked-out (user principal))
  (match (map-get? user-settings { user: user })
    settings (> (+ (get last-lockout settings) (get lockout-duration settings)) block-height)
    false
  )
)

;; Get authentication attempt
(define-read-only (get-auth-attempt (user principal) (attempt-id uint))
  (map-get? authentication-attempts { user: user, attempt-id: attempt-id })
)
