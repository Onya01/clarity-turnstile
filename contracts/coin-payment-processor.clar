
;; title: coin-payment-processor
;; version: 1.0.0
;; summary: Payment processing system for coin-based turnstile access
;; description: Handles coin insertion, validates transactions, and integrates with turnstile FSM

;; constants
(define-constant ERR_INSUFFICIENT_PAYMENT (err u200))
(define-constant ERR_INVALID_AMOUNT (err u201))
(define-constant ERR_PAYMENT_FAILED (err u202))
(define-constant ERR_UNAUTHORIZED (err u203))
(define-constant ERR_TURNSTILE_ERROR (err u204))
(define-constant ERR_REFUND_FAILED (err u205))

;; Minimum payment required (in microSTX)
(define-constant MIN_PAYMENT_AMOUNT u1000000) ;; 1 STX
(define-constant REFUND_THRESHOLD u500000) ;; 0.5 STX

;; data vars
(define-data-var contract-owner principal tx-sender)
(define-data-var payment-amount uint MIN_PAYMENT_AMOUNT)
(define-data-var total-collected uint u0)
(define-data-var turnstile-contract principal tx-sender)

;; data maps
(define-map payment-history principal {amount: uint, block: uint, successful: bool})
(define-map pending-refunds principal uint)
(define-map authorized-collectors principal bool)

;; Authorization functions
(define-private (is-contract-owner (caller principal))
  (is-eq caller (var-get contract-owner)))

(define-private (is-authorized-collector (caller principal))
  (default-to false (map-get? authorized-collectors caller)))

;; Payment validation
(define-private (is-valid-payment (amount uint))
  (>= amount (var-get payment-amount)))

;; Turnstile integration
(define-private (unlock-turnstile-internal)
  ;; This will be implemented to call the turnstile contract
  ;; For now, we'll simulate the unlock operation
  (ok true))

;; Read-only functions
(define-read-only (get-payment-amount)
  (var-get payment-amount))

(define-read-only (get-total-collected)
  (var-get total-collected))

(define-read-only (get-payment-history (user principal))
  (map-get? payment-history user))

(define-read-only (get-pending-refund (user principal))
  (map-get? pending-refunds user))

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender)))

;; Public functions
(define-public (insert-coin)
  (let 
    (
      (payment-amt (stx-get-balance tx-sender))
      (required-amt (var-get payment-amount))
    )
    (begin
      ;; Validate payment amount
      (asserts! (is-valid-payment payment-amt) ERR_INSUFFICIENT_PAYMENT)
      
      ;; Transfer payment to contract
      (try! (stx-transfer? required-amt tx-sender (as-contract tx-sender)))
      
      ;; Update total collected
      (var-set total-collected (+ (var-get total-collected) required-amt))
      
      ;; Record payment history
      (map-set payment-history tx-sender 
        {amount: required-amt, block: burn-block-height, successful: true})
      
      ;; Attempt to unlock turnstile
      (unwrap-panic (unlock-turnstile-internal))
      
      ;; If we reach here, the unlock was successful
      (print {action: "payment-successful", user: tx-sender, amount: required-amt, block: burn-block-height})
      (ok true))))

(define-public (process-refund (user principal))
  (let
    (
      (refund-amount (default-to u0 (map-get? pending-refunds user)))
    )
    (begin
      (asserts! (> refund-amount u0) ERR_REFUND_FAILED)
      (asserts! (or (is-contract-owner tx-sender) (is-eq tx-sender user)) ERR_UNAUTHORIZED)
      
      ;; Process refund
      (try! (as-contract (stx-transfer? refund-amount tx-sender user)))
      
      ;; Remove from pending refunds
      (map-delete pending-refunds user)
      
      ;; Update total collected
      (var-set total-collected (- (var-get total-collected) refund-amount))
      
      (print {action: "refund-processed", user: user, amount: refund-amount})
      (ok true))))

(define-public (set-payment-amount (new-amount uint))
  (begin
    (asserts! (is-contract-owner tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> new-amount u0) ERR_INVALID_AMOUNT)
    (var-set payment-amount new-amount)
    (print {action: "payment-amount-updated", new-amount: new-amount})
    (ok true)))

(define-public (set-turnstile-contract (new-contract principal))
  (begin
    (asserts! (is-contract-owner tx-sender) ERR_UNAUTHORIZED)
    (var-set turnstile-contract new-contract)
    (print {action: "turnstile-contract-updated", new-contract: new-contract})
    (ok true)))

(define-public (add-collector (collector principal))
  (begin
    (asserts! (is-contract-owner tx-sender) ERR_UNAUTHORIZED)
    (map-set authorized-collectors collector true)
    (print {action: "collector-added", collector: collector})
    (ok true)))

(define-public (remove-collector (collector principal))
  (begin
    (asserts! (is-contract-owner tx-sender) ERR_UNAUTHORIZED)
    (map-delete authorized-collectors collector)
    (print {action: "collector-removed", collector: collector})
    (ok true)))

(define-public (collect-funds (amount uint))
  (begin
    (asserts! (or (is-contract-owner tx-sender) (is-authorized-collector tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (<= amount (get-contract-balance)) ERR_INSUFFICIENT_PAYMENT)
    
    ;; Transfer funds to collector
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    
    (print {action: "funds-collected", collector: tx-sender, amount: amount})
    (ok true)))

;; Emergency functions
(define-public (emergency-refund-all)
  (begin
    (asserts! (is-contract-owner tx-sender) ERR_UNAUTHORIZED)
    ;; This would need to be implemented with a proper iteration mechanism
    ;; For now, it's a placeholder for emergency situations
    (print {action: "emergency-refund-initiated", caller: tx-sender})
    (ok true)))

;; Initialize contract
(begin
  (map-set authorized-collectors tx-sender true)
  (print {action: "contract-initialized", owner: tx-sender, payment-amount: MIN_PAYMENT_AMOUNT}))
