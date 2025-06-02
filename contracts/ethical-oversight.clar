;; Ethical Oversight Contract
;; Ensures time manipulation research ethics compliance

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_NOT_FOUND (err u501))
(define-constant ERR_ETHICS_VIOLATION (err u502))

;; Ethics review status
(define-constant REVIEW_PENDING u1)
(define-constant REVIEW_APPROVED u2)
(define-constant REVIEW_REJECTED u3)
(define-constant REVIEW_CONDITIONAL u4)

;; Ethics violation severity
(define-constant VIOLATION_MINOR u1)
(define-constant VIOLATION_MAJOR u2)
(define-constant VIOLATION_CRITICAL u3)

;; Ethics review data
(define-map ethics-reviews
  { review-id: uint }
  {
    protocol-id: uint,
    reviewer: principal,
    status: uint,
    review-date: uint,
    comments: (string-ascii 1000),
    conditions: (string-ascii 500)
  }
)

;; Ethics violations
(define-map ethics-violations
  { violation-id: uint }
  {
    protocol-id: uint,
    reporter: principal,
    severity: uint,
    description: (string-ascii 1000),
    timestamp: uint,
    resolved: bool,
    resolution-action: (string-ascii 500)
  }
)

;; Protocol ethics status
(define-map protocol-ethics-status
  { protocol-id: uint }
  {
    ethics-approved: bool,
    violation-count: uint,
    last-review-date: uint,
    compliance-score: uint
  }
)

(define-data-var review-counter uint u0)
(define-data-var violation-counter uint u0)

;; Submit protocol for ethics review
(define-public (submit-ethics-review (protocol-id uint) (comments (string-ascii 1000)))
  (let ((review-id (+ (var-get review-counter) u1)))
    (begin
      (map-set ethics-reviews
        { review-id: review-id }
        {
          protocol-id: protocol-id,
          reviewer: tx-sender,
          status: REVIEW_PENDING,
          review-date: block-height,
          comments: comments,
          conditions: ""
        }
      )
      (var-set review-counter review-id)
      (ok review-id)
    )
  )
)

;; Complete ethics review
(define-public (complete-ethics-review
  (review-id uint)
  (status uint)
  (conditions (string-ascii 500))
)
  (match (map-get? ethics-reviews { review-id: review-id })
    review-data
    (if (is-eq (get reviewer review-data) tx-sender)
      (begin
        (map-set ethics-reviews
          { review-id: review-id }
          (merge review-data {
            status: status,
            conditions: conditions
          })
        )

        ;; Update protocol ethics status
        (let ((protocol-id (get protocol-id review-data)))
          (map-set protocol-ethics-status
            { protocol-id: protocol-id }
            {
              ethics-approved: (is-eq status REVIEW_APPROVED),
              violation-count: u0,
              last-review-date: block-height,
              compliance-score: (if (is-eq status REVIEW_APPROVED) u100 u0)
            }
          )
        )
        (ok true)
      )
      ERR_UNAUTHORIZED
    )
    ERR_NOT_FOUND
  )
)

;; Report ethics violation
(define-public (report-ethics-violation
  (protocol-id uint)
  (severity uint)
  (description (string-ascii 1000))
)
  (let ((violation-id (+ (var-get violation-counter) u1)))
    (begin
      ;; Create violation record
      (map-set ethics-violations
        { violation-id: violation-id }
        {
          protocol-id: protocol-id,
          reporter: tx-sender,
          severity: severity,
          description: description,
          timestamp: block-height,
          resolved: false,
          resolution-action: ""
        }
      )

      ;; Update protocol ethics status
      (match (map-get? protocol-ethics-status { protocol-id: protocol-id })
        existing-status
        (map-set protocol-ethics-status
          { protocol-id: protocol-id }
          (merge existing-status {
            violation-count: (+ (get violation-count existing-status) u1),
            compliance-score: (if (> (get compliance-score existing-status) u20)
              (- (get compliance-score existing-status) u20)
              u0
            )
          })
        )
        (map-set protocol-ethics-status
          { protocol-id: protocol-id }
          {
            ethics-approved: false,
            violation-count: u1,
            last-review-date: u0,
            compliance-score: u0
          }
        )
      )

      (var-set violation-counter violation-id)
      (ok violation-id)
    )
  )
)

;; Resolve ethics violation
(define-public (resolve-ethics-violation (violation-id uint) (resolution-action (string-ascii 500)))
  (match (map-get? ethics-violations { violation-id: violation-id })
    violation-data
    (begin
      (map-set ethics-violations
        { violation-id: violation-id }
        (merge violation-data {
          resolved: true,
          resolution-action: resolution-action
        })
      )
      (ok true)
    )
    ERR_NOT_FOUND
  )
)

;; Get ethics review
(define-read-only (get-ethics-review (review-id uint))
  (map-get? ethics-reviews { review-id: review-id })
)

;; Get ethics violation
(define-read-only (get-ethics-violation (violation-id uint))
  (map-get? ethics-violations { violation-id: violation-id })
)

;; Get protocol ethics status
(define-read-only (get-protocol-ethics-status (protocol-id uint))
  (map-get? protocol-ethics-status { protocol-id: protocol-id })
)

;; Check if protocol is ethically approved
(define-read-only (is-protocol-ethically-approved (protocol-id uint))
  (match (map-get? protocol-ethics-status { protocol-id: protocol-id })
    status-data (get ethics-approved status-data)
    false
  )
)
