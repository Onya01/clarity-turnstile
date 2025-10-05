
;; title: turnstile-fsm
;; version: 1.0.0
;; summary: Finite state machine implementation for turnstile access control
;; description: Manages locked and unlocked states with proper state transitions for coin-based access

;; constants
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_STATE (err u101))
(define-constant ERR_ALREADY_UNLOCKED (err u102))
(define-constant ERR_ALREADY_LOCKED (err u103))

;; State constants
(define-constant STATE_LOCKED u0)
(define-constant STATE_UNLOCKED u1)

;; data vars
(define-data-var turnstile-state uint STATE_LOCKED)
(define-data-var contract-owner principal tx-sender)
(define-data-var last-unlock-block uint u0)
(define-data-var unlock-duration uint u144) ;; ~24 hours in blocks (assuming 10min blocks)

;; data maps
(define-map authorized-operators principal bool)

;; Authorization functions
(define-private (is-contract-owner (caller principal))
  (is-eq caller (var-get contract-owner)))

(define-private (is-authorized-operator (caller principal))
  (default-to false (map-get? authorized-operators caller)))

(define-private (is-authorized (caller principal))
  (or (is-contract-owner caller) (is-authorized-operator caller)))

;; State management functions
(define-read-only (get-current-state)
  (var-get turnstile-state))

(define-read-only (is-locked)
  (is-eq (var-get turnstile-state) STATE_LOCKED))

(define-read-only (is-unlocked)
  (is-eq (var-get turnstile-state) STATE_UNLOCKED))

(define-read-only (get-unlock-expiry)
  (+ (var-get last-unlock-block) (var-get unlock-duration)))

(define-read-only (is-unlock-expired)
  (> block-height (get-unlock-expiry)))

;; Public functions
(define-public (unlock-turnstile)
  (begin
    (asserts! (is-authorized tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-locked) ERR_ALREADY_UNLOCKED)
    (var-set turnstile-state STATE_UNLOCKED)
    (var-set last-unlock-block block-height)
    (print {action: "unlocked", block: block-height, caller: tx-sender})
    (ok true)))

(define-public (lock-turnstile)
  (begin
    (asserts! (is-authorized tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-unlocked) ERR_ALREADY_LOCKED)
    (var-set turnstile-state STATE_LOCKED)
    (print {action: "locked", block: block-height, caller: tx-sender})
    (ok true)))

(define-public (auto-lock-if-expired)
  (begin
    (asserts! (is-unlocked) ERR_ALREADY_LOCKED)
    (asserts! (is-unlock-expired) ERR_INVALID_STATE)
    (var-set turnstile-state STATE_LOCKED)
    (print {action: "auto-locked", block: block-height, expiry-block: (get-unlock-expiry)})
    (ok true)))

(define-public (add-operator (operator principal))
  (begin
    (asserts! (is-contract-owner tx-sender) ERR_UNAUTHORIZED)
    (map-set authorized-operators operator true)
    (print {action: "operator-added", operator: operator})
    (ok true)))

(define-public (remove-operator (operator principal))
  (begin
    (asserts! (is-contract-owner tx-sender) ERR_UNAUTHORIZED)
    (map-delete authorized-operators operator)
    (print {action: "operator-removed", operator: operator})
    (ok true)))

(define-public (set-unlock-duration (new-duration uint))
  (begin
    (asserts! (is-contract-owner tx-sender) ERR_UNAUTHORIZED)
    (var-set unlock-duration new-duration)
    (print {action: "unlock-duration-updated", new-duration: new-duration})
    (ok true)))

;; Initialize contract with locked state
(begin
  (map-set authorized-operators tx-sender true)
  (print {action: "contract-initialized", owner: tx-sender, initial-state: "locked"}))
