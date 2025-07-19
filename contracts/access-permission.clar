;; Access Permission Contract
;; Controls identity data sharing permissions

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-INPUT (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-EXISTS (err u103))

;; Permission levels
(define-constant PERMISSION-READ u1)
(define-constant PERMISSION-WRITE u2)
(define-constant PERMISSION-ADMIN u3)

;; Data structures
(define-map access-permissions
  { owner: principal, accessor: principal, resource-type: (string-ascii 50) }
  {
    permission-level: uint,
    granted-at: uint,
    expires-at: uint,
    granted-by: principal
  }
)

(define-map permission-requests
  { requester: principal, owner: principal, resource-type: (string-ascii 50) }
  {
    requested-level: uint,
    requested-at: uint,
    status: (string-ascii 20),
    purpose: (string-ascii 200)
  }
)

(define-map access-logs
  { owner: principal, accessor: principal, log-id: uint }
  {
    resource-type: (string-ascii 50),
    access-time: uint,
    action: (string-ascii 50)
  }
)

(define-map log-counters
  { owner: principal }
  { counter: uint }
)

;; Public functions

;; Grant access permission
(define-public (grant-access
  (accessor principal)
  (resource-type (string-ascii 50))
  (permission-level uint)
  (duration uint)
)
  (let ((owner tx-sender))
    (asserts! (> (len resource-type) u0) ERR-INVALID-INPUT)
    (asserts! (and (>= permission-level u1) (<= permission-level u3)) ERR-INVALID-INPUT)
    (asserts! (> duration u0) ERR-INVALID-INPUT)

    (map-set access-permissions
      { owner: owner, accessor: accessor, resource-type: resource-type }
      {
        permission-level: permission-level,
        granted-at: block-height,
        expires-at: (+ block-height duration),
        granted-by: owner
      }
    )

    ;; Log the access grant
    (log-access owner accessor resource-type "grant")

    (ok true)
  )
)

;; Revoke access permission
(define-public (revoke-access (accessor principal) (resource-type (string-ascii 50)))
  (let ((owner tx-sender))
    (asserts! (is-some (map-get? access-permissions { owner: owner, accessor: accessor, resource-type: resource-type })) ERR-NOT-FOUND)

    (map-delete access-permissions { owner: owner, accessor: accessor, resource-type: resource-type })

    ;; Log the access revocation
    (log-access owner accessor resource-type "revoke")

    (ok true)
  )
)

;; Request access permission
(define-public (request-access
  (owner principal)
  (resource-type (string-ascii 50))
  (requested-level uint)
  (purpose (string-ascii 200))
)
  (let ((requester tx-sender))
    (asserts! (> (len resource-type) u0) ERR-INVALID-INPUT)
    (asserts! (and (>= requested-level u1) (<= requested-level u3)) ERR-INVALID-INPUT)
    (asserts! (> (len purpose) u0) ERR-INVALID-INPUT)

    (map-set permission-requests
      { requester: requester, owner: owner, resource-type: resource-type }
      {
        requested-level: requested-level,
        requested-at: block-height,
        status: "pending",
        purpose: purpose
      }
    )

    (ok true)
  )
)

;; Approve access request
(define-public (approve-request
  (requester principal)
  (resource-type (string-ascii 50))
  (duration uint)
)
  (let (
    (owner tx-sender)
    (request (unwrap! (map-get? permission-requests { requester: requester, owner: owner, resource-type: resource-type }) ERR-NOT-FOUND))
  )
    (asserts! (is-eq (get status request) "pending") ERR-INVALID-INPUT)

    ;; Update request status
    (map-set permission-requests
      { requester: requester, owner: owner, resource-type: resource-type }
      (merge request { status: "approved" })
    )

    ;; Grant the permission
    (unwrap! (grant-access requester resource-type (get requested-level request) duration) ERR-INVALID-INPUT)

    (ok true)
  )
)

;; Deny access request
(define-public (deny-request (requester principal) (resource-type (string-ascii 50)))
  (let (
    (owner tx-sender)
    (request (unwrap! (map-get? permission-requests { requester: requester, owner: owner, resource-type: resource-type }) ERR-NOT-FOUND))
  )
    (asserts! (is-eq (get status request) "pending") ERR-INVALID-INPUT)

    (map-set permission-requests
      { requester: requester, owner: owner, resource-type: resource-type }
      (merge request { status: "denied" })
    )

    (ok true)
  )
)

;; Private functions

;; Log access activity
(define-private (log-access (owner principal) (accessor principal) (resource-type (string-ascii 50)) (action (string-ascii 50)))
  (let (
    (current-counter (default-to u0 (get counter (map-get? log-counters { owner: owner }))))
    (new-counter (+ current-counter u1))
  )
    (map-set access-logs
      { owner: owner, accessor: accessor, log-id: new-counter }
      {
        resource-type: resource-type,
        access-time: block-height,
        action: action
      }
    )

    (map-set log-counters { owner: owner } { counter: new-counter })

    new-counter
  )
)

;; Read-only functions

;; Check permission
(define-read-only (check-permission (owner principal) (accessor principal) (resource-type (string-ascii 50)))
  (match (map-get? access-permissions { owner: owner, accessor: accessor, resource-type: resource-type })
    permission (and
      (> (get expires-at permission) block-height)
      (> (get permission-level permission) u0)
    )
    false
  )
)

;; Get permission details
(define-read-only (get-permission (owner principal) (accessor principal) (resource-type (string-ascii 50)))
  (map-get? access-permissions { owner: owner, accessor: accessor, resource-type: resource-type })
)

;; Get permission request
(define-read-only (get-request (requester principal) (owner principal) (resource-type (string-ascii 50)))
  (map-get? permission-requests { requester: requester, owner: owner, resource-type: resource-type })
)

;; Get permission level
(define-read-only (get-permission-level (owner principal) (accessor principal) (resource-type (string-ascii 50)))
  (match (map-get? access-permissions { owner: owner, accessor: accessor, resource-type: resource-type })
    permission (if (> (get expires-at permission) block-height)
      (some (get permission-level permission))
      none
    )
    none
  )
)

;; Check if permission is expired
(define-read-only (is-permission-expired (owner principal) (accessor principal) (resource-type (string-ascii 50)))
  (match (map-get? access-permissions { owner: owner, accessor: accessor, resource-type: resource-type })
    permission (<= (get expires-at permission) block-height)
    true
  )
)
