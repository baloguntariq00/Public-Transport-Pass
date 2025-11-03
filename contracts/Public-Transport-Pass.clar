(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_PASS (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_PASS_EXPIRED (err u103))
(define-constant ERR_INVALID_PASS_TYPE (err u104))
(define-constant ERR_ALREADY_USED (err u105))
(define-constant ERR_INVALID_AMOUNT (err u106))
(define-constant ERR_PASS_NOT_FOUND (err u107))
(define-constant ERR_INVALID_ZONE (err u108))
(define-constant ERR_INSUFFICIENT_POINTS (err u109))
(define-constant ERR_INVALID_TIER (err u110))
(define-constant ERR_GROUP_NOT_FOUND (err u111))
(define-constant ERR_NOT_GROUP_ADMIN (err u112))
(define-constant ERR_GROUP_FULL (err u113))
(define-constant ERR_ALREADY_MEMBER (err u114))
(define-constant ERR_NOT_MEMBER (err u115))
(define-constant ERR_INVALID_GROUP_SIZE (err u116))

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

(define-constant POINTS_PER_RIDE u10)
(define-constant BRONZE_TIER_MIN u0)
(define-constant SILVER_TIER_MIN u500)
(define-constant GOLD_TIER_MIN u1500)
(define-constant PLATINUM_TIER_MIN u3000)

(define-data-var contract-owner principal tx-sender)
(define-data-var pass-counter uint u0)
(define-data-var total-revenue uint u0)
(define-data-var group-counter uint u0)

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

(define-map loyalty-points
    principal
    {
        total-points: uint,
        lifetime-points: uint,
        tier: uint,
        last-activity: uint,
    }
)

(define-map tier-benefits
    uint
    {
        discount-percentage: uint,
        bonus-points-multiplier: uint,
        free-rides-monthly: uint,
    }
)

(define-map group-passes
    uint
    {
        admin: principal,
        name: (string-ascii 50),
        description: (string-ascii 200),
        max-members: uint,
        current-members: uint,
        shared-balance: uint,
        created-at: uint,
        active: bool,
    }
)

(define-map group-members
    {
        group-id: uint,
        member: principal,
    }
    {
        joined-at: uint,
        total-rides: uint,
        contribution: uint,
    }
)

(define-map user-groups
    principal
    (list 5 uint)
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

(define-private (calculate-user-tier (lifetime-points uint))
    (if (>= lifetime-points PLATINUM_TIER_MIN)
        u4
        (if (>= lifetime-points GOLD_TIER_MIN)
            u3
            (if (>= lifetime-points SILVER_TIER_MIN)
                u2
                u1
            )
        )
    )
)

(define-private (get-tier-discount (tier uint))
    (if (is-eq tier u4)
        u20
        (if (is-eq tier u3)
            u15
            (if (is-eq tier u2)
                u10
                u0
            )
        )
    )
)

(define-private (get-points-multiplier (tier uint))
    (if (is-eq tier u4)
        u3
        (if (is-eq tier u3)
            u2
            (if (is-eq tier u2)
                u2
                u1
            )
        )
    )
)

(define-private (award-points-for-ride
        (user principal)
        (base-points uint)
    )
    (let (
            (current-data (default-to {
                total-points: u0,
                lifetime-points: u0,
                tier: u1,
                last-activity: u0,
            }
                (map-get? loyalty-points user)
            ))
            (new-lifetime-points (+ (get lifetime-points current-data) base-points))
            (new-tier (calculate-user-tier new-lifetime-points))
            (multiplier (get-points-multiplier new-tier))
            (bonus-points (* base-points multiplier))
            (new-total-points (+ (get total-points current-data) bonus-points))
        )
        (map-set loyalty-points user {
            total-points: new-total-points,
            lifetime-points: new-lifetime-points,
            tier: new-tier,
            last-activity: burn-block-height,
        })
        (ok bonus-points)
    )
)

(define-private (is-group-admin
        (group-id uint)
        (user principal)
    )
    (match (map-get? group-passes group-id)
        group-data (is-eq (get admin group-data) user)
        false
    )
)

(define-private (is-group-member
        (group-id uint)
        (user principal)
    )
    (is-some (map-get? group-members {
        group-id: group-id,
        member: user,
    }))
)

;; Simplified member count - track it in group data
(define-map group-member-counts
    uint
    uint
)

(define-private (add-user-to-group
        (user principal)
        (group-id uint)
    )
    (let ((current-groups (default-to (list) (map-get? user-groups user))))
        (map-set user-groups user
            (unwrap! (as-max-len? (append current-groups group-id) u5) (err u999))
        )
        (ok true)
    )
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

        (begin
            (unwrap-panic (award-points-for-ride tx-sender POINTS_PER_RIDE))
            (ok ride-id)
        )
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

(define-public (redeem-points-for-discount
        (points-to-redeem uint)
        (pass-type uint)
        (zone uint)
    )
    (let (
            (user-data (unwrap! (map-get? loyalty-points tx-sender) ERR_PASS_NOT_FOUND))
            (cost (get-pass-cost pass-type))
            (discount-rate u50)
            (discounted-cost (- cost (/ (* cost discount-rate) u100)))
            (new-pass-id (+ (var-get pass-counter) u1))
            (duration (get-pass-duration pass-type))
            (current-block burn-block-height)
            (expiry-block (+ current-block duration))
        )
        (asserts! (>= (get total-points user-data) points-to-redeem)
            ERR_INSUFFICIENT_POINTS
        )
        (asserts! (>= points-to-redeem (* cost u10)) ERR_INVALID_AMOUNT)
        (asserts! (> cost u0) ERR_INVALID_PASS_TYPE)
        (asserts! (> zone u0) ERR_INVALID_ZONE)

        (try! (stx-transfer? discounted-cost tx-sender (var-get contract-owner)))

        (map-set passes new-pass-id {
            owner: tx-sender,
            pass-type: pass-type,
            balance: cost,
            expiry-block: expiry-block,
            active: true,
            zone: zone,
        })

        (map-set loyalty-points tx-sender
            (merge user-data { total-points: (- (get total-points user-data) points-to-redeem) })
        )

        (try! (add-pass-to-user tx-sender new-pass-id))
        (var-set pass-counter new-pass-id)
        (var-set total-revenue (+ (var-get total-revenue) discounted-cost))

        (ok new-pass-id)
    )
)

(define-public (set-tier-benefits
        (tier uint)
        (discount-percentage uint)
        (bonus-points-multiplier uint)
        (free-rides-monthly uint)
    )
    (begin
        (asserts! (is-owner) ERR_NOT_AUTHORIZED)
        (asserts! (and (>= tier u1) (<= tier u4)) ERR_INVALID_TIER)
        (asserts! (<= discount-percentage u100) ERR_INVALID_AMOUNT)

        (map-set tier-benefits tier {
            discount-percentage: discount-percentage,
            bonus-points-multiplier: bonus-points-multiplier,
            free-rides-monthly: free-rides-monthly,
        })

        (ok true)
    )
)

;; Group Pass Management Functions
(define-public (create-group-pass
        (name (string-ascii 50))
        (description (string-ascii 200))
        (max-members uint)
        (initial-balance uint)
    )
    (let (
            (new-group-id (+ (var-get group-counter) u1))
            (current-block burn-block-height)
        )
        (asserts! (> max-members u0) ERR_INVALID_GROUP_SIZE)
        (asserts! (<= max-members u10) ERR_INVALID_GROUP_SIZE)
        (asserts! (> initial-balance u0) ERR_INVALID_AMOUNT)
        (asserts! (> (len name) u0) ERR_INVALID_AMOUNT)

        (try! (stx-transfer? initial-balance tx-sender (var-get contract-owner)))

        (map-set group-passes new-group-id {
            admin: tx-sender,
            name: name,
            description: description,
            max-members: max-members,
            current-members: u1,
            shared-balance: initial-balance,
            created-at: current-block,
            active: true,
        })

        (map-set group-members {
            group-id: new-group-id,
            member: tx-sender,
        } {
            joined-at: current-block,
            total-rides: u0,
            contribution: initial-balance,
        })

        (try! (add-user-to-group tx-sender new-group-id))
        (var-set group-counter new-group-id)
        (var-set total-revenue (+ (var-get total-revenue) initial-balance))

        (ok new-group-id)
    )
)

(define-public (join-group
        (group-id uint)
        (contribution uint)
    )
    (let (
            (group-data (unwrap! (map-get? group-passes group-id) ERR_GROUP_NOT_FOUND))
            (current-block burn-block-height)
        )
        (asserts! (get active group-data) ERR_INVALID_PASS)
        (asserts! (not (is-group-member group-id tx-sender)) ERR_ALREADY_MEMBER)
        (asserts!
            (< (get current-members group-data) (get max-members group-data))
            ERR_GROUP_FULL
        )
        (asserts! (> contribution u0) ERR_INVALID_AMOUNT)

        (try! (stx-transfer? contribution tx-sender (var-get contract-owner)))

        (map-set group-members {
            group-id: group-id,
            member: tx-sender,
        } {
            joined-at: current-block,
            total-rides: u0,
            contribution: contribution,
        })

        (map-set group-passes group-id
            (merge group-data {
                shared-balance: (+ (get shared-balance group-data) contribution),
                current-members: (+ (get current-members group-data) u1),
            })
        )

        (try! (add-user-to-group tx-sender group-id))
        (var-set total-revenue (+ (var-get total-revenue) contribution))

        (ok true)
    )
)

(define-public (contribute-to-group
        (group-id uint)
        (amount uint)
    )
    (let (
            (group-data (unwrap! (map-get? group-passes group-id) ERR_GROUP_NOT_FOUND))
            (member-data (unwrap!
                (map-get? group-members {
                    group-id: group-id,
                    member: tx-sender,
                })
                ERR_NOT_MEMBER
            ))
        )
        (asserts! (get active group-data) ERR_INVALID_PASS)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)

        (try! (stx-transfer? amount tx-sender (var-get contract-owner)))

        (map-set group-members {
            group-id: group-id,
            member: tx-sender,
        }
            (merge member-data { contribution: (+ (get contribution member-data) amount) })
        )

        (map-set group-passes group-id
            (merge group-data { shared-balance: (+ (get shared-balance group-data) amount) })
        )

        (var-set total-revenue (+ (var-get total-revenue) amount))
        (ok true)
    )
)

(define-public (use-group-balance-for-ride
        (group-id uint)
        (from-zone uint)
        (to-zone uint)
    )
    (let (
            (group-data (unwrap! (map-get? group-passes group-id) ERR_GROUP_NOT_FOUND))
            (member-data (unwrap!
                (map-get? group-members {
                    group-id: group-id,
                    member: tx-sender,
                })
                ERR_NOT_MEMBER
            ))
            (ride-cost (calculate-zone-cost from-zone to-zone))
            (current-block burn-block-height)
            (ride-id (+ (* group-id u10000) current-block))
        )
        (asserts! (get active group-data) ERR_INVALID_PASS)
        (asserts! (>= (get shared-balance group-data) ride-cost)
            ERR_INSUFFICIENT_BALANCE
        )

        (map-set group-passes group-id
            (merge group-data { shared-balance: (- (get shared-balance group-data) ride-cost) })
        )

        (map-set group-members {
            group-id: group-id,
            member: tx-sender,
        }
            (merge member-data { total-rides: (+ (get total-rides member-data) u1) })
        )

        (map-set ride-history {
            pass-id: group-id,
            ride-id: ride-id,
        } {
            timestamp: current-block,
            from-zone: from-zone,
            to-zone: to-zone,
            cost: ride-cost,
        })

        (begin
            (unwrap-panic (award-points-for-ride tx-sender POINTS_PER_RIDE))
            (ok ride-id)
        )
    )
)

(define-public (remove-group-member
        (group-id uint)
        (member principal)
    )
    (let (
            (group-data (unwrap! (map-get? group-passes group-id) ERR_GROUP_NOT_FOUND))
            (member-data (unwrap!
                (map-get? group-members {
                    group-id: group-id,
                    member: member,
                })
                ERR_NOT_MEMBER
            ))
        )
        (asserts! (is-group-admin group-id tx-sender) ERR_NOT_GROUP_ADMIN)
        (asserts! (not (is-eq member tx-sender)) ERR_NOT_AUTHORIZED)

        (map-delete group-members {
            group-id: group-id,
            member: member,
        })

        (map-set group-passes group-id
            (merge group-data { current-members: (- (get current-members group-data) u1) })
        )

        (ok true)
    )
)

(define-public (deactivate-group (group-id uint))
    (let ((group-data (unwrap! (map-get? group-passes group-id) ERR_GROUP_NOT_FOUND)))
        (asserts! (is-group-admin group-id tx-sender) ERR_NOT_GROUP_ADMIN)

        (map-set group-passes group-id (merge group-data { active: false }))

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

(define-read-only (get-user-loyalty-info (user principal))
    (map-get? loyalty-points user)
)

(define-read-only (get-tier-benefits-info (tier uint))
    (map-get? tier-benefits tier)
)

(define-read-only (calculate-discount-for-user
        (user principal)
        (pass-cost uint)
    )
    (match (map-get? loyalty-points user)
        user-data (let ((tier (get tier user-data)))
            (some (/ (* pass-cost (get-tier-discount tier)) u100))
        )
        none
    )
)

(define-read-only (get-user-tier-name (user principal))
    (match (map-get? loyalty-points user)
        user-data (let ((tier (get tier user-data)))
            (if (is-eq tier u4)
                "Platinum"
                (if (is-eq tier u3)
                    "Gold"
                    (if (is-eq tier u2)
                        "Silver"
                        "Bronze"
                    )
                )
            )
        )
        "Unregistered"
    )
)

;; Group Pass Read-Only Functions
(define-read-only (get-group-info (group-id uint))
    (map-get? group-passes group-id)
)

(define-read-only (get-group-member-info
        (group-id uint)
        (member principal)
    )
    (map-get? group-members {
        group-id: group-id,
        member: member,
    })
)

(define-read-only (get-user-groups (user principal))
    (map-get? user-groups user)
)

(define-read-only (is-user-group-member
        (group-id uint)
        (user principal)
    )
    (is-group-member group-id user)
)

(define-read-only (is-user-group-admin
        (group-id uint)
        (user principal)
    )
    (is-group-admin group-id user)
)

(define-read-only (get-group-stats)
    {
        total-groups: (var-get group-counter),
        active-groups: (var-get group-counter),
    }
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

(define-constant ERR_VOUCHER_NOT_FOUND (err u117))
(define-constant ERR_VOUCHER_INACTIVE (err u118))
(define-constant ERR_VOUCHER_EXPIRED (err u119))
(define-constant ERR_VOUCHER_MAXED (err u120))
(define-constant ERR_INVALID_DISCOUNT (err u121))

(define-map vouchers
    (string-ascii 32)
    {
        discount-percentage: uint,
        max-uses: uint,
        used-count: uint,
        expiry-block: uint,
        active: bool,
    }
)

(define-public (create-voucher
        (code (string-ascii 32))
        (discount-percentage uint)
        (max-uses uint)
        (expiry-block uint)
    )
    (begin
        (asserts! (is-owner) ERR_NOT_AUTHORIZED)
        (asserts! (> discount-percentage u0) ERR_INVALID_DISCOUNT)
        (asserts! (<= discount-percentage u100) ERR_INVALID_DISCOUNT)
        (asserts! (> max-uses u0) ERR_INVALID_AMOUNT)
        (asserts! (> expiry-block burn-block-height) ERR_INVALID_AMOUNT)
        (map-set vouchers code {
            discount-percentage: discount-percentage,
            max-uses: max-uses,
            used-count: u0,
            expiry-block: expiry-block,
            active: true,
        })
        (ok true)
    )
)

(define-public (deactivate-voucher (code (string-ascii 32)))
    (let ((v (unwrap! (map-get? vouchers code) ERR_VOUCHER_NOT_FOUND)))
        (asserts! (is-owner) ERR_NOT_AUTHORIZED)
        (map-set vouchers code (merge v { active: false }))
        (ok true)
    )
)

(define-public (purchase-pass-with-voucher
        (pass-type uint)
        (zone uint)
        (code (string-ascii 32))
    )
    (let (
            (v (unwrap! (map-get? vouchers code) ERR_VOUCHER_NOT_FOUND))
            (cost (get-pass-cost pass-type))
            (duration (get-pass-duration pass-type))
            (current-block burn-block-height)
            (new-pass-id (+ (var-get pass-counter) u1))
            (expiry-block (+ current-block duration))
            (discount-amount (/ (* cost (get discount-percentage v)) u100))
            (discounted-cost (- cost discount-amount))
        )
        (asserts! (> cost u0) ERR_INVALID_PASS_TYPE)
        (asserts! (> zone u0) ERR_INVALID_ZONE)
        (asserts! (get active v) ERR_VOUCHER_INACTIVE)
        (asserts! (< current-block (get expiry-block v)) ERR_VOUCHER_EXPIRED)
        (asserts! (< (get used-count v) (get max-uses v)) ERR_VOUCHER_MAXED)
        (try! (stx-transfer? discounted-cost tx-sender (var-get contract-owner)))
        (map-set passes new-pass-id {
            owner: tx-sender,
            pass-type: pass-type,
            balance: cost,
            expiry-block: expiry-block,
            active: true,
            zone: zone,
        })
        (map-set vouchers code
            (merge v { used-count: (+ (get used-count v) u1) })
        )
        (try! (add-pass-to-user tx-sender new-pass-id))
        (var-set pass-counter new-pass-id)
        (var-set total-revenue (+ (var-get total-revenue) discounted-cost))
        (ok new-pass-id)
    )
)

(define-read-only (get-voucher-info (code (string-ascii 32)))
    (map-get? vouchers code)
)
