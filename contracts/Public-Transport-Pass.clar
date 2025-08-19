(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_PASS (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_PASS_EXPIRED (err u103))
(define-constant ERR_INVALID_PASS_TYPE (err u104))
(define-constant ERR_ALREADY_USED (err u105))
(define-constant ERR_INVALID_AMOUNT (err u106))
(define-constant ERR_PASS_NOT_FOUND (err u107))
(define-constant ERR_INVALID_ZONE (err u108))

(define-constant PASS_TYPE_DAILY u1)
(define-constant PASS_TYPE_WEEKLY u2)
(define-constant PASS_TYPE_MONTHLY u3)

(define-constant DAILY_PASS_COST u10)
(define-constant WEEKLY_PASS_COST u60)
(define-constant MONTHLY_PASS_COST u200)
(define-constant RIDE_COST u2)

(define-constant DAILY_DURATION u144)
(define-constant WEEKLY_DURATION u1008)
(define-constant MONTHLY_DURATION u4320)

(define-data-var contract-owner principal tx-sender)
(define-data-var pass-counter uint u0)
(define-data-var total-revenue uint u0)

(define-map passes
    uint
    {
        owner: principal,
        pass-type: uint,
        balance: uint,
        expiry-block: uint,
        active: bool,
        zone: uint,
    }
)

(define-map user-passes
    principal
    (list 10 uint)
)

(define-map ride-history
    {
        pass-id: uint,
        ride-id: uint,
    }
    {
        timestamp: uint,
        from-zone: uint,
        to-zone: uint,
        cost: uint,
    }
)

(define-map zone-rates
    {
        from-zone: uint,
        to-zone: uint,
    }
    uint
)

(define-private (get-pass-cost (pass-type uint))
    (if (is-eq pass-type PASS_TYPE_DAILY)
        DAILY_PASS_COST
        (if (is-eq pass-type PASS_TYPE_WEEKLY)
            WEEKLY_PASS_COST
            (if (is-eq pass-type PASS_TYPE_MONTHLY)
                MONTHLY_PASS_COST
                u0
            )
        )
    )
)

(define-private (get-pass-duration (pass-type uint))
    (if (is-eq pass-type PASS_TYPE_DAILY)
        DAILY_DURATION
        (if (is-eq pass-type PASS_TYPE_WEEKLY)
            WEEKLY_DURATION
            (if (is-eq pass-type PASS_TYPE_MONTHLY)
                MONTHLY_DURATION
                u0
            )
        )
    )
)

(define-private (calculate-zone-cost
        (from-zone uint)
        (to-zone uint)
    )
    (default-to RIDE_COST
        (map-get? zone-rates {
            from-zone: from-zone,
            to-zone: to-zone,
        })
    )
)

(define-private (is-owner)
    (is-eq tx-sender (var-get contract-owner))
)

(define-private (add-pass-to-user
        (user principal)
        (pass-id uint)
    )
    (let ((current-passes (default-to (list) (map-get? user-passes user))))
        (map-set user-passes user
            (unwrap! (as-max-len? (append current-passes pass-id) u10) (err u999))
        )
        (ok true)
    )
)

(define-public (set-zone-rate
        (from-zone uint)
        (to-zone uint)
        (rate uint)
    )
    (begin
        (asserts! (is-owner) ERR_NOT_AUTHORIZED)
        (asserts! (> rate u0) ERR_INVALID_AMOUNT)
        (map-set zone-rates {
            from-zone: from-zone,
            to-zone: to-zone,
        }
            rate
        )
        (ok true)
    )
)

(define-public (purchase-pass
        (pass-type uint)
        (zone uint)
    )
    (let (
            (cost (get-pass-cost pass-type))
            (duration (get-pass-duration pass-type))
            (new-pass-id (+ (var-get pass-counter) u1))
            (current-block burn-block-height)
            (expiry-block (+ current-block duration))
        )
        (asserts! (> cost u0) ERR_INVALID_PASS_TYPE)
        (asserts! (> zone u0) ERR_INVALID_ZONE)

        (try! (stx-transfer? cost tx-sender (var-get contract-owner)))

        (map-set passes new-pass-id {
            owner: tx-sender,
            pass-type: pass-type,
            balance: cost,
            expiry-block: expiry-block,
            active: true,
            zone: zone,
        })

        (try! (add-pass-to-user tx-sender new-pass-id))
        (var-set pass-counter new-pass-id)
        (var-set total-revenue (+ (var-get total-revenue) cost))

        (ok new-pass-id)
    )
)

(define-public (top-up-pass
        (pass-id uint)
        (amount uint)
    )
    (let ((pass-data (unwrap! (map-get? passes pass-id) ERR_PASS_NOT_FOUND)))
        (asserts! (is-eq (get owner pass-data) tx-sender) ERR_NOT_AUTHORIZED)
        (asserts! (get active pass-data) ERR_INVALID_PASS)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)

        (try! (stx-transfer? amount tx-sender (var-get contract-owner)))

        (map-set passes pass-id
            (merge pass-data { balance: (+ (get balance pass-data) amount) })
        )

        (var-set total-revenue (+ (var-get total-revenue) amount))
        (ok true)
    )
)

(define-public (use-pass-for-ride
        (pass-id uint)
        (from-zone uint)
        (to-zone uint)
    )
    (let (
            (pass-data (unwrap! (map-get? passes pass-id) ERR_PASS_NOT_FOUND))
            (current-block burn-block-height)
            (ride-cost (calculate-zone-cost from-zone to-zone))
            (ride-id (+ (* pass-id u1000) current-block))
        )
        (asserts! (is-eq (get owner pass-data) tx-sender) ERR_NOT_AUTHORIZED)
        (asserts! (get active pass-data) ERR_INVALID_PASS)
        (asserts! (< current-block (get expiry-block pass-data)) ERR_PASS_EXPIRED)
        (asserts! (>= (get balance pass-data) ride-cost) ERR_INSUFFICIENT_BALANCE)

        (map-set passes pass-id
            (merge pass-data { balance: (- (get balance pass-data) ride-cost) })
        )

        (map-set ride-history {
            pass-id: pass-id,
            ride-id: ride-id,
        } {
            timestamp: current-block,
            from-zone: from-zone,
            to-zone: to-zone,
            cost: ride-cost,
        })

        (ok ride-id)
    )
)

(define-public (deactivate-pass (pass-id uint))
    (let ((pass-data (unwrap! (map-get? passes pass-id) ERR_PASS_NOT_FOUND)))
        (asserts! (is-eq (get owner pass-data) tx-sender) ERR_NOT_AUTHORIZED)

        (map-set passes pass-id (merge pass-data { active: false }))

        (ok true)
    )
)

(define-public (refund-pass (pass-id uint))
    (let (
            (pass-data (unwrap! (map-get? passes pass-id) ERR_PASS_NOT_FOUND))
            (refund-amount (get balance pass-data))
        )
        (asserts! (is-eq (get owner pass-data) tx-sender) ERR_NOT_AUTHORIZED)
        (asserts! (get active pass-data) ERR_INVALID_PASS)
        (asserts! (> refund-amount u0) ERR_INSUFFICIENT_BALANCE)

        (try! (as-contract (stx-transfer? refund-amount tx-sender (get owner pass-data))))

        (map-set passes pass-id
            (merge pass-data {
                balance: u0,
                active: false,
            })
        )

        (ok refund-amount)
    )
)

(define-public (transfer-pass-ownership
        (pass-id uint)
        (new-owner principal)
    )
    (let ((pass-data (unwrap! (map-get? passes pass-id) ERR_PASS_NOT_FOUND)))
        (asserts! (is-eq (get owner pass-data) tx-sender) ERR_NOT_AUTHORIZED)
        (asserts! (get active pass-data) ERR_INVALID_PASS)

        (map-set passes pass-id (merge pass-data { owner: new-owner }))

        (try! (add-pass-to-user new-owner pass-id))
        (ok true)
    )
)

(define-public (extend-pass
        (pass-id uint)
        (additional-blocks uint)
    )
    (let ((pass-data (unwrap! (map-get? passes pass-id) ERR_PASS_NOT_FOUND)))
        (asserts! (is-owner) ERR_NOT_AUTHORIZED)
        (asserts! (get active pass-data) ERR_INVALID_PASS)
        (asserts! (> additional-blocks u0) ERR_INVALID_AMOUNT)

        (map-set passes pass-id
            (merge pass-data { expiry-block: (+ (get expiry-block pass-data) additional-blocks) })
        )

        (ok true)
    )
)

(define-public (set-contract-owner (new-owner principal))
    (begin
        (asserts! (is-owner) ERR_NOT_AUTHORIZED)
        (var-set contract-owner new-owner)
        (ok true)
    )
)

(define-public (withdraw-revenue (amount uint))
    (begin
        (asserts! (is-owner) ERR_NOT_AUTHORIZED)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (try! (as-contract (stx-transfer? amount tx-sender (var-get contract-owner))))
        (ok true)
    )
)

(define-read-only (get-pass-info (pass-id uint))
    (map-get? passes pass-id)
)

(define-read-only (get-user-passes (user principal))
    (map-get? user-passes user)
)

(define-read-only (get-ride-history
        (pass-id uint)
        (ride-id uint)
    )
    (map-get? ride-history {
        pass-id: pass-id,
        ride-id: ride-id,
    })
)

(define-read-only (get-zone-rate
        (from-zone uint)
        (to-zone uint)
    )
    (map-get? zone-rates {
        from-zone: from-zone,
        to-zone: to-zone,
    })
)

(define-read-only (get-contract-stats)
    {
        total-passes: (var-get pass-counter),
        total-revenue: (var-get total-revenue),
        contract-owner: (var-get contract-owner),
    }
)

(define-read-only (is-pass-valid (pass-id uint))
    (match (map-get? passes pass-id)
        pass-data (and
            (get active pass-data)
            (< burn-block-height (get expiry-block pass-data))
        )
        false
    )
)

(define-read-only (get-pass-balance (pass-id uint))
    (match (map-get? passes pass-id)
        pass-data (some (get balance pass-data))
        none
    )
)

(define-read-only (get-pass-expiry (pass-id uint))
    (match (map-get? passes pass-id)
        pass-data (some (get expiry-block pass-data))
        none
    )
)

(map-set zone-rates {
    from-zone: u1,
    to-zone: u1,
} u1
)
(map-set zone-rates {
    from-zone: u1,
    to-zone: u2,
} u2
)
(map-set zone-rates {
    from-zone: u1,
    to-zone: u3,
} u3
)
(map-set zone-rates {
    from-zone: u2,
    to-zone: u2,
} u1
)
(map-set zone-rates {
    from-zone: u2,
    to-zone: u3,
} u2
)
(map-set zone-rates {
    from-zone: u3,
    to-zone: u3,
} u1
)
