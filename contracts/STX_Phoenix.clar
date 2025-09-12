;; contracts/phoenix.clar
;; STX Phoenix - Rebirth Vault
;; Contributors deposit STX, one random contributor
;; wins the entire vault when the Phoenix rises.

(define-data-var vault-balance uint u0)
(define-data-var deposit-count uint u0)
(define-data-var cycle-id uint u0)

(define-map deposits
  { cycle: uint, id: uint }
  { contributor: principal, amount: uint }
)

(define-constant ERR-NO-DEPOSITS u100)
(define-constant ERR-NOT-OWNER u101)

(define-data-var contract-owner principal tx-sender)

;; 🔥 Deposit into Phoenix Vault
(define-public (deposit (amount uint))
  (begin
    (as-contract (stx-transfer? amount tx-sender (contract-caller)))
    (let ((id (+ u1 (var-get deposit-count))))
      (var-set deposit-count id)
      (map-set deposits { cycle: (var-get cycle-id), id: id }
        { contributor: tx-sender, amount: amount })
      (var-set vault-balance (+ (var-get vault-balance) amount))
      (ok id)
    )
  )
)

;; 🦅 Phoenix rises – owner triggers rebirth
(define-public (rise)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-OWNER))
    (asserts! (> (var-get deposit-count) u0) (err ERR-NO-DEPOSITS))

    (let (
      (winner-id (+ u1 (mod block-height (var-get deposit-count))))
      (pot (var-get vault-balance))
      (winner (unwrap-panic (map-get? deposits { cycle: (var-get cycle-id), id: winner-id })))
    )
      (begin
        ;; Bless winner with full rebirth
        (as-contract (stx-transfer? pot (contract-caller) (get contributor winner)))
        ;; Reset cycle
        (var-set vault-balance u0)
        (var-set deposit-count u0)
        (var-set cycle-id (+ u1 (var-get cycle-id)))
        (ok (get contributor winner))
      )
    )
  )
)

;; --- views ---
(define-read-only (get-vault) (var-get vault-balance))
(define-read-only (get-cycle) (var-get cycle-id))
(define-read-only (get-deposit (cycle uint) (id uint)) (map-get? deposits { cycle: cycle, id: id }))
