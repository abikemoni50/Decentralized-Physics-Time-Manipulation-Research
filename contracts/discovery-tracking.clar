;; Discovery Tracking Contract
;; Records time manipulation breakthroughs and discoveries

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_NOT_FOUND (err u401))
(define-constant ERR_ALREADY_VERIFIED (err u402))

;; Discovery types
(define-constant DISCOVERY_THEORETICAL u1)
(define-constant DISCOVERY_EXPERIMENTAL u2)
(define-constant DISCOVERY_PRACTICAL u3)
(define-constant DISCOVERY_BREAKTHROUGH u4)

;; Discovery data structure
(define-map discoveries
  { discovery-id: uint }
  {
    title: (string-ascii 200),
    researcher: principal,
    protocol-id: uint,
    discovery-type: uint,
    description: (string-ascii 1000),
    timestamp: uint,
    verified: bool,
    verification-date: uint,
    verifier: principal,
    significance-score: uint
  }
)

(define-map researcher-discoveries
  { researcher: principal }
  { discovery-count: uint, total-significance: uint }
)

(define-data-var discovery-counter uint u0)

;; Record a new discovery
(define-public (record-discovery
  (title (string-ascii 200))
  (protocol-id uint)
  (discovery-type uint)
  (description (string-ascii 1000))
  (significance-score uint)
)
  (let ((discovery-id (+ (var-get discovery-counter) u1)))
    (begin
      ;; Create discovery record
      (map-set discoveries
        { discovery-id: discovery-id }
        {
          title: title,
          researcher: tx-sender,
          protocol-id: protocol-id,
          discovery-type: discovery-type,
          description: description,
          timestamp: block-height,
          verified: false,
          verification-date: u0,
          verifier: tx-sender,
          significance-score: significance-score
        }
      )

      ;; Update researcher stats
      (match (map-get? researcher-discoveries { researcher: tx-sender })
        existing-stats
        (map-set researcher-discoveries
          { researcher: tx-sender }
          {
            discovery-count: (+ (get discovery-count existing-stats) u1),
            total-significance: (+ (get total-significance existing-stats) significance-score)
          }
        )
        (map-set researcher-discoveries
          { researcher: tx-sender }
          {
            discovery-count: u1,
            total-significance: significance-score
          }
        )
      )

      (var-set discovery-counter discovery-id)
      (ok discovery-id)
    )
  )
)

;; Verify a discovery
(define-public (verify-discovery (discovery-id uint))
  (match (map-get? discoveries { discovery-id: discovery-id })
    discovery-data
    (if (get verified discovery-data)
      ERR_ALREADY_VERIFIED
      (begin
        (map-set discoveries
          { discovery-id: discovery-id }
          (merge discovery-data {
            verified: true,
            verification-date: block-height,
            verifier: tx-sender
          })
        )
        (ok true)
      )
    )
    ERR_NOT_FOUND
  )
)

;; Get discovery details
(define-read-only (get-discovery (discovery-id uint))
  (map-get? discoveries { discovery-id: discovery-id })
)

;; Get researcher statistics
(define-read-only (get-researcher-stats (researcher principal))
  (map-get? researcher-discoveries { researcher: researcher })
)

;; Check if discovery is verified
(define-read-only (is-discovery-verified (discovery-id uint))
  (match (map-get? discoveries { discovery-id: discovery-id })
    discovery-data (ok (get verified discovery-data))
    ERR_NOT_FOUND
  )
)

;; Get discoveries by type
(define-read-only (get-discovery-count-by-type (discovery-type uint))
  (ok u0) ;; Simplified - would need iteration in full implementation
)
