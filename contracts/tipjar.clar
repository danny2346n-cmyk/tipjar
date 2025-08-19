;; contracts/tipjar.clar
;; Simple STX Tip Jar Contract
;; - Anyone can send tips
;; - Track tip amounts per sender
;; - Owner (deployer) can withdraw funds

(define-map tips
    { sender: principal }
    { amount: uint }
)
(define-data-var total-tips uint u0)

(define-data-var contract-owner principal tx-sender)

(define-constant ERR-NOT-OWNER u100)
(define-constant ERR-NO-FUNDS u101)
(define-constant ERR-INVALID-AMOUNT u102)

;; --- public functions ---

(define-public (tip (amount uint))
    (begin
        (asserts! (> amount u0) (err ERR-INVALID-AMOUNT))
        (try! (stx-transfer? amount tx-sender (as-contract tx)))
        (let ((prev (default-to u0 (get amount (map-get? tips { sender: tx-sender })))))
            (map-set tips { sender: tx-sender } { amount: (+ prev amount) })
            (var-set total-tips (+ (var-get total-tips) amount))
            (ok true)
        )
    )
)

(define-public (withdraw (amount uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-OWNER))
        (asserts! (> amount u0) (err ERR-NO-FUNDS))
        (try! (stx-transfer? amount (as-contract tx) (var-get contract-owner)))
        (ok true)
    )
)

;; --- read-only views ---

(define-read-only (get-tip (who principal))
    (default-to u0 (get amount (map-get? tips { sender: who })))
)

(define-read-only (get-total)
    (var-get total-tips)
)