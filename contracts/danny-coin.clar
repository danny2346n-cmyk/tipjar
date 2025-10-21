;; contracts/danny-coin.clar
;; Danny Coin (DANNY) — SIP-010 compliant fungible token with security hardening
;; Features: owner-only mint, capped supply, pause, blacklist, approve/transfer-from, burn/burn-from

(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-PAUSED u101)
(define-constant ERR-BLACKLISTED u102)
(define-constant ERR-INSUFFICIENT-BALANCE u103)
(define-constant ERR-INSUFFICIENT-ALLOWANCE u104)
(define-constant ERR-MAX-SUPPLY-EXCEEDED u105)
(define-constant ERR-ZERO-AMOUNT u106)

(define-constant DECIMALS u6)
(define-constant MAX-SUPPLY u1000000000000000) ;; 1,000,000,000 DANNY with 6 decimals (1e15 base units)

(define-data-var owner principal tx-sender)
(define-data-var total-supply uint u0)
(define-data-var paused bool false)

(define-map balances principal uint)
(define-map allowances { owner: principal, spender: principal } uint)
(define-map blacklisted principal bool)

;; --- helpers ---
(define-read-only (get-name) (ok "Danny Coin"))
(define-read-only (get-symbol) (ok "DANNY"))
(define-read-only (get-decimals) (ok DECIMALS))
(define-read-only (get-total-supply) (ok (var-get total-supply)))
(define-read-only (get-balance-of (who principal))
  (ok (default-to u0 (map-get? balances who))))
(define-read-only (get-allowance (token-owner principal) (spender principal))
  (ok (default-to u0 (map-get? allowances { owner: token-owner, spender: spender }))))

(define-private (only-owner)
  (if (is-eq tx-sender (var-get owner)) (ok true) (err ERR-NOT-AUTHORIZED)))

(define-private (ensure-not-paused)
  (if (var-get paused) (err ERR-PAUSED) (ok true)))

(define-private (ensure-not-blacklisted (p principal))
  (if (default-to false (map-get? blacklisted p)) (err ERR-BLACKLISTED) (ok true)))

(define-private (increase-balance (p principal) (amount uint))
  (let ((cur (default-to u0 (map-get? balances p))))
    (map-set balances p (+ cur amount))))

(define-private (decrease-balance (p principal) (amount uint))
  (let ((cur (default-to u0 (map-get? balances p))))
    (if (< cur amount)
      (err ERR-INSUFFICIENT-BALANCE)
      (begin (map-set balances p (- cur amount)) (ok true)))))

;; --- admin ---
(define-public (set-owner (new-owner principal))
  (begin
    (try! (only-owner))
    (asserts! (not (is-eq new-owner (var-get owner))) (err ERR-NOT-AUTHORIZED))
    (var-set owner new-owner)
    (ok true)))

(define-public (set-paused (flag bool))
  (begin
    (try! (only-owner))
    (var-set paused flag)
    (print (tuple (type "pause") (paused flag)))
    (ok true)))

(define-public (blacklist (p principal))
  (begin
    (try! (only-owner))
    (asserts! (not (is-eq p (var-get owner))) (err ERR-NOT-AUTHORIZED))
    (map-set blacklisted p true)
    (print (tuple (type "blacklist") (who p)))
    (ok true)))

(define-public (unblacklist (p principal))
  (begin
    (try! (only-owner))
    (map-set blacklisted p false)
    (print (tuple (type "unblacklist") (who p)))
    (ok true)))

;; --- core token logic (SIP-010 surface) ---
(define-public (transfer (amount uint) (sender principal) (recipient principal))
  (begin
    (asserts! (> amount u0) (err ERR-ZERO-AMOUNT))
    (try! (ensure-not-paused))
    (asserts! (is-eq tx-sender sender) (err ERR-NOT-AUTHORIZED))
    (try! (ensure-not-blacklisted sender))
    (try! (ensure-not-blacklisted recipient))
    (try! (decrease-balance sender amount))
    (increase-balance recipient amount)
    (print (tuple (type "transfer") (from sender) (to recipient) (amount amount)))
    (ok true)))

(define-public (approve (spender principal) (amount uint))
  (begin
    (try! (ensure-not-paused))
    (try! (ensure-not-blacklisted tx-sender))
    (try! (ensure-not-blacklisted spender))
    (map-set allowances { owner: tx-sender, spender: spender } amount)
    (print (tuple (type "approval") (owner tx-sender) (spender spender) (amount amount)))
    (ok true)))

(define-public (transfer-from (amount uint) (sender principal) (recipient principal))
  (begin
    (asserts! (> amount u0) (err ERR-ZERO-AMOUNT))
    (try! (ensure-not-paused))
    (try! (ensure-not-blacklisted sender))
    (try! (ensure-not-blacklisted recipient))
    (let (
      (key { owner: sender, spender: tx-sender })
      (allow (default-to u0 (map-get? allowances { owner: sender, spender: tx-sender })))
    )
      (begin
        (asserts! (>= allow amount) (err ERR-INSUFFICIENT-ALLOWANCE))
        (map-set allowances key (- allow amount))
        (try! (decrease-balance sender amount))
        (increase-balance recipient amount)
        (print (tuple (type "transfer-from") (from sender) (to recipient) (spender tx-sender) (amount amount)))
        (ok true)
      )
    )
  ))

;; --- mint/burn ---
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (> amount u0) (err ERR-ZERO-AMOUNT))
    (try! (only-owner))
    (try! (ensure-not-paused))
    (try! (ensure-not-blacklisted recipient))
    (let ((new-supply (+ (var-get total-supply) amount)))
      (asserts! (<= new-supply MAX-SUPPLY) (err ERR-MAX-SUPPLY-EXCEEDED))
      (var-set total-supply new-supply)
      (increase-balance recipient amount)
      (print (tuple (type "mint") (to recipient) (amount amount)))
      (ok true)
    )
  ))

(define-public (burn (amount uint))
  (begin
    (asserts! (> amount u0) (err ERR-ZERO-AMOUNT))
    (try! (ensure-not-blacklisted tx-sender))
    (try! (decrease-balance tx-sender amount))
    (var-set total-supply (- (var-get total-supply) amount))
    (print (tuple (type "burn") (from tx-sender) (amount amount)))
    (ok true)))

(define-public (burn-from (amount uint) (holder principal))
  (begin
    (asserts! (> amount u0) (err ERR-ZERO-AMOUNT))
    (try! (only-owner))
    (try! (ensure-not-blacklisted holder))
    (try! (decrease-balance holder amount))
    (var-set total-supply (- (var-get total-supply) amount))
    (print (tuple (type "burn-from") (from holder) (amount amount)))
    (ok true)))
