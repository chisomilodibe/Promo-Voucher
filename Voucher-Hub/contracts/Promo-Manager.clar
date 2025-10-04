;; Promotional Voucher Management System Smart Contract
;; 
;; A blockchain-based voucher platform that enables businesses to create and manage
;; promotional discount campaigns with configurable rules, usage tracking, and 
;; comprehensive analytics. Features include percentage and fixed-value discounts,
;; time-limited campaigns, user access controls, minimum purchase requirements,
;; and complete audit trails for compliance and reporting.

;; Error constants for validation and authorization failures
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-VOUCHER-NOT-FOUND (err u101))
(define-constant ERR-CAMPAIGN-EXPIRED (err u102))
(define-constant ERR-USAGE-LIMIT-REACHED (err u103))
(define-constant ERR-INVALID-PARAMETERS (err u104))
(define-constant ERR-VOUCHER-ALREADY-EXISTS (err u105))
(define-constant ERR-ACCESS-DENIED (err u106))
(define-constant ERR-VOUCHER-INACTIVE (err u107))
(define-constant ERR-MINIMUM-NOT-MET (err u108))

;; Business rule constants
(define-constant DISCOUNT-TYPE-PERCENTAGE u0)
(define-constant DISCOUNT-TYPE-FIXED u1)
(define-constant NO-USAGE-LIMIT u0)
(define-constant MIN-DISCOUNT-VALUE u0)
(define-constant MAX-PERCENTAGE-VALUE u100)
(define-constant BATCH-PROCESSING-LIMIT u200)

;; Platform state variables
(define-data-var contract-owner principal tx-sender)
(define-data-var vouchers-created-count uint u0)
(define-data-var redemptions-completed-count uint u0)

;; Voucher configuration storage with campaign parameters
(define-map voucher-details
  { code: (string-ascii 32) }
  {
    value: uint,
    expires-at-block: uint,
    max-uses: uint,
    times-used: uint,
    min-purchase: uint,
    is-active: bool,
    discount-type: uint,
    started-at-block: uint,
    created-by: principal
  }
)

;; Customer redemption tracking per voucher code
(define-map user-redemption-records
  { user: principal, code: (string-ascii 32) }
  { 
    redemption-count: uint,
    first-used-at: uint,
    last-used-at: uint
  }
)

;; Access control for restricted voucher codes
(define-map voucher-access-control
  { code: (string-ascii 32), user: principal }
  { 
    has-permission: bool,
    granted-at-block: uint,
    granted-by: principal
  }
)

;; Administrative action audit log for compliance
(define-map admin-action-log
  { log-block: uint, admin: principal }
  {
    action-type: (string-ascii 25),
    voucher-code: (string-ascii 32),
    executed-at: uint
  }
)

;; Validation helper to check if voucher exists in registry
(define-private (voucher-exists (code (string-ascii 32)))
  (is-some (map-get? voucher-details {code: code}))
)

;; Validation helper to verify discount type is valid
(define-private (is-valid-discount-type (discount-type uint))
  (or (is-eq discount-type DISCOUNT-TYPE-PERCENTAGE) 
      (is-eq discount-type DISCOUNT-TYPE-FIXED))
)

;; Validation helper to check discount value is within acceptable range
(define-private (is-valid-discount-value (discount-type uint) (value uint))
  (if (is-eq discount-type DISCOUNT-TYPE-PERCENTAGE)
    (and (<= value MAX-PERCENTAGE-VALUE) 
         (> value MIN-DISCOUNT-VALUE))
    (> value MIN-DISCOUNT-VALUE)
  )
)

;; Validation helper to ensure campaign duration is positive
(define-private (is-positive-duration (duration uint))
  (> duration u0)
)

;; Validation helper to check usage limit is acceptable
(define-private (is-valid-usage-limit (limit uint))
  (>= limit NO-USAGE-LIMIT)
)

;; Validation helper to verify minimum purchase threshold
(define-private (is-valid-min-purchase (amount uint))
  (>= amount u0)
)

;; Validation helper to check wallet address format
(define-private (is-valid-wallet (wallet principal))
  (not (is-eq wallet 'SP000000000000000000002Q6VF78))
)

;; Validation helper to verify voucher code format
(define-private (is-valid-code-format (code (string-ascii 32)))
  (and (> (len code) u0) (<= (len code) u32))
)

;; Creates a new promotional voucher campaign with specified parameters
(define-public (create-voucher 
    (code (string-ascii 32))
    (discount-type uint)
    (value uint)
    (duration-blocks uint)
    (max-uses uint)
    (min-purchase uint))
  (begin
    ;; Only contract owner can create vouchers
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    
    ;; Validate all input parameters
    (asserts! (is-valid-code-format code) ERR-INVALID-PARAMETERS)
    (asserts! (is-valid-discount-type discount-type) ERR-INVALID-PARAMETERS)
    (asserts! (is-valid-discount-value discount-type value) ERR-INVALID-PARAMETERS)
    (asserts! (is-positive-duration duration-blocks) ERR-INVALID-PARAMETERS)
    (asserts! (is-valid-usage-limit max-uses) ERR-INVALID-PARAMETERS)
    (asserts! (is-valid-min-purchase min-purchase) ERR-INVALID-PARAMETERS)
    
    ;; Ensure voucher code is unique
    (asserts! (not (voucher-exists code)) ERR-VOUCHER-ALREADY-EXISTS)
    
    ;; Calculate campaign end block
    (let ((end-block (+ block-height duration-blocks)))
      
      ;; Store voucher configuration
      (map-set voucher-details
        {code: code}
        {
          value: value,
          expires-at-block: end-block,
          max-uses: max-uses,
          times-used: u0,
          min-purchase: min-purchase,
          is-active: true,
          discount-type: discount-type,
          started-at-block: block-height,
          created-by: tx-sender
        }
      )
      
      ;; Increment global voucher counter
      (var-set vouchers-created-count (+ (var-get vouchers-created-count) u1))
      
      ;; Log creation action
      (map-set admin-action-log
        {log-block: block-height, admin: tx-sender}
        {
          action-type: "VOUCHER-CREATED",
          voucher-code: code,
          executed-at: block-height
        }
      )
      
      (ok true)
    )
  )
)

;; Grants or revokes access permission for a specific user to a voucher
(define-public (set-user-access 
    (code (string-ascii 32))
    (user principal)
    (grant-access bool))
  (begin
    ;; Only contract owner can modify permissions
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    
    ;; Validate input parameters
    (asserts! (is-valid-wallet user) ERR-INVALID-PARAMETERS)
    (asserts! (voucher-exists code) ERR-VOUCHER-NOT-FOUND)
    
    ;; Update access permissions
    (map-set voucher-access-control
      {code: code, user: user}
      {
        has-permission: grant-access,
        granted-at-block: block-height,
        granted-by: tx-sender
      }
    )
    
    ;; Log permission change
    (map-set admin-action-log
      {log-block: block-height, admin: tx-sender}
      {
        action-type: "ACCESS-MODIFIED",
        voucher-code: code,
        executed-at: block-height
      }
    )
    
    (ok true)
  )
)

;; Deactivates a voucher campaign, preventing further redemptions
(define-public (deactivate-voucher (code (string-ascii 32)))
  (begin
    ;; Only contract owner can deactivate vouchers
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    
    ;; Verify voucher exists
    (asserts! (voucher-exists code) ERR-VOUCHER-NOT-FOUND)
    
    (let ((current-config (unwrap! (map-get? voucher-details {code: code}) ERR-VOUCHER-NOT-FOUND)))
      ;; Update active status to false
      (map-set voucher-details
        {code: code}
        (merge current-config {is-active: false})
      )
      
      ;; Log deactivation action
      (map-set admin-action-log
        {log-block: block-height, admin: tx-sender}
        {
          action-type: "VOUCHER-DEACTIVATED",
          voucher-code: code,
          executed-at: block-height
        }
      )
    )
    
    (ok true)
  )
)

;; Reactivates a previously deactivated voucher campaign
(define-public (reactivate-voucher (code (string-ascii 32)))
  (begin
    ;; Only contract owner can reactivate vouchers
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    
    ;; Verify voucher exists
    (asserts! (voucher-exists code) ERR-VOUCHER-NOT-FOUND)
    
    (let ((current-config (unwrap! (map-get? voucher-details {code: code}) ERR-VOUCHER-NOT-FOUND)))
      ;; Update active status to true
      (map-set voucher-details
        {code: code}
        (merge current-config {is-active: true})
      )
      
      ;; Log reactivation action
      (map-set admin-action-log
        {log-block: block-height, admin: tx-sender}
        {
          action-type: "VOUCHER-REACTIVATED",
          voucher-code: code,
          executed-at: block-height
        }
      )
    )
    
    (ok true)
  )
)

;; Resets the usage counter for a voucher back to zero
(define-public (reset-usage-counter (code (string-ascii 32)))
  (begin
    ;; Only contract owner can reset counters
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    
    ;; Verify voucher exists
    (asserts! (voucher-exists code) ERR-VOUCHER-NOT-FOUND)
    
    (let ((current-config (unwrap! (map-get? voucher-details {code: code}) ERR-VOUCHER-NOT-FOUND)))
      ;; Reset times-used to zero
      (map-set voucher-details
        {code: code}
        (merge current-config {times-used: u0})
      )
      
      ;; Log counter reset action
      (map-set admin-action-log
        {log-block: block-height, admin: tx-sender}
        {
          action-type: "COUNTER-RESET",
          voucher-code: code,
          executed-at: block-height
        }
      )
    )
    
    (ok true)
  )
)

;; Extends the expiration date of a voucher campaign
(define-public (extend-expiration (code (string-ascii 32)) (additional-blocks uint))
  (begin
    ;; Only contract owner can extend campaigns
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    
    ;; Validate extension parameters
    (asserts! (> additional-blocks u0) ERR-INVALID-PARAMETERS)
    (asserts! (voucher-exists code) ERR-VOUCHER-NOT-FOUND)
    
    (let ((current-config (unwrap! (map-get? voucher-details {code: code}) ERR-VOUCHER-NOT-FOUND)))
      ;; Extend expiration block
      (map-set voucher-details
        {code: code}
        (merge current-config {expires-at-block: (+ (get expires-at-block current-config) additional-blocks)})
      )
      
      ;; Log extension action
      (map-set admin-action-log
        {log-block: block-height, admin: tx-sender}
        {
          action-type: "EXPIRATION-EXTENDED",
          voucher-code: code,
          executed-at: block-height
        }
      )
    )
    
    (ok true)
  )
)

;; Updates the minimum purchase requirement for a voucher
(define-public (update-min-purchase (code (string-ascii 32)) (new-minimum uint))
  (begin
    ;; Only contract owner can update requirements
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    
    ;; Validate new minimum value
    (asserts! (is-valid-min-purchase new-minimum) ERR-INVALID-PARAMETERS)
    (asserts! (voucher-exists code) ERR-VOUCHER-NOT-FOUND)
    
    (let ((current-config (unwrap! (map-get? voucher-details {code: code}) ERR-VOUCHER-NOT-FOUND)))
      ;; Update minimum purchase requirement
      (map-set voucher-details
        {code: code}
        (merge current-config {min-purchase: new-minimum})
      )
      
      ;; Log requirement update
      (map-set admin-action-log
        {log-block: block-height, admin: tx-sender}
        {
          action-type: "MIN-PURCHASE-UPDATED",
          voucher-code: code,
          executed-at: block-height
        }
      )
    )
    
    (ok true)
  )
)

;; Transfers contract ownership to a new administrator
(define-public (transfer-ownership (new-owner principal))
  (begin
    ;; Only current owner can transfer ownership
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    
    ;; Validate new owner address
    (asserts! (is-valid-wallet new-owner) ERR-INVALID-PARAMETERS)
    
    ;; Update contract owner
    (var-set contract-owner new-owner)
    
    ;; Log ownership transfer
    (map-set admin-action-log
      {log-block: block-height, admin: tx-sender}
      {
        action-type: "OWNERSHIP-TRANSFERRED",
        voucher-code: "",
        executed-at: block-height
      }
    )
    
    (ok true)
  )
)

;; Redeems a voucher code and returns the calculated discount amount
(define-public (redeem-voucher (code (string-ascii 32)) (purchase-amount uint))
  (begin
    ;; Validate purchase amount is positive
    (asserts! (> purchase-amount u0) ERR-INVALID-PARAMETERS)
    (asserts! (voucher-exists code) ERR-VOUCHER-NOT-FOUND)
    
    (let (
      (config (unwrap! (map-get? voucher-details {code: code}) ERR-VOUCHER-NOT-FOUND))
      (disc-type (get discount-type config))
      (disc-value (get value config))
      (expires-at (get expires-at-block config))
      (max-uses (get max-uses config))
      (times-used (get times-used config))
      (min-purchase (get min-purchase config))
      (is-active (get is-active config))
      (user-record (default-to 
        {redemption-count: u0, first-used-at: u0, last-used-at: u0} 
        (map-get? user-redemption-records {user: tx-sender, code: code})))
      (user-redemptions (get redemption-count user-record))
    )
      (begin
        ;; Verify voucher is active and not expired
        (asserts! is-active ERR-VOUCHER-INACTIVE)
        (asserts! (< block-height expires-at) ERR-CAMPAIGN-EXPIRED)
        (asserts! (or (is-eq max-uses NO-USAGE-LIMIT) 
                     (< times-used max-uses)) ERR-USAGE-LIMIT-REACHED)
        (asserts! (>= purchase-amount min-purchase) ERR-MINIMUM-NOT-MET)
        
        ;; Check user access permissions if configured
        (let ((access-record (map-get? voucher-access-control {code: code, user: tx-sender})))
          (if (is-some access-record)
            (asserts! (get has-permission (default-to {has-permission: false, granted-at-block: u0, granted-by: tx-sender} access-record)) ERR-ACCESS-DENIED)
            true
          )
        )
        
        ;; Calculate discount amount based on type
        (let ((discount-amount 
          (if (is-eq disc-type DISCOUNT-TYPE-PERCENTAGE)
            ;; Percentage discount: (purchase * percentage) / 100
            (/ (* purchase-amount disc-value) u100)
            ;; Fixed discount: capped at purchase amount
            (if (> disc-value purchase-amount) 
                purchase-amount 
                disc-value)
          )))
          
          ;; Update voucher usage counter
          (map-set voucher-details
            {code: code}
            (merge config {times-used: (+ times-used u1)})
          )
          
          ;; Update user redemption record
          (map-set user-redemption-records
            {user: tx-sender, code: code}
            {
              redemption-count: (+ user-redemptions u1),
              first-used-at: (if (is-eq user-redemptions u0) block-height (get first-used-at user-record)),
              last-used-at: block-height
            }
          )
          
          ;; Increment global redemption counter
          (var-set redemptions-completed-count (+ (var-get redemptions-completed-count) u1))
          
          ;; Return calculated discount
          (ok discount-amount)
        )
      )
    )
  )
)

;; Retrieves comprehensive analytics for a voucher campaign
(define-read-only (get-voucher-analytics (code (string-ascii 32)))
  (match (map-get? voucher-details {code: code})
    config 
    (ok {
      code: code,
      discount-type: (get discount-type config),
      value: (get value config),
      expires-at-block: (get expires-at-block config),
      max-uses: (get max-uses config),
      times-used: (get times-used config),
      min-purchase: (get min-purchase config),
      is-active: (get is-active config),
      started-at-block: (get started-at-block config),
      created-by: (get created-by config),
      blocks-until-expiry: (- (get expires-at-block config) block-height),
      usage-percentage: (if (is-eq (get max-uses config) NO-USAGE-LIMIT)
                          u0
                          (/ (* (get times-used config) u100) (get max-uses config)))
    })
    ERR-VOUCHER-NOT-FOUND
  )
)

;; Checks if a user can redeem a voucher with given purchase amount
(define-read-only (check-redemption-eligibility (code (string-ascii 32)) (user principal) (purchase-amount uint))
  (begin
    ;; Validate user address format
    (asserts! (is-valid-wallet user) ERR-INVALID-PARAMETERS)
    
    ;; Perform eligibility check
    (match (map-get? voucher-details {code: code})
      config 
      (let (
        (is-active (get is-active config))
        (expires-at (get expires-at-block config))
        (max-uses (get max-uses config))
        (times-used (get times-used config))
        (min-purchase (get min-purchase config))
        (user-record (default-to 
          {redemption-count: u0, first-used-at: u0, last-used-at: u0} 
          (map-get? user-redemption-records {user: user, code: code})))
        (access-record (map-get? voucher-access-control {code: code, user: user}))
      )
        ;; Return eligibility details
        (ok {
          can-redeem: (and 
            is-active
            (< block-height expires-at)
            (or (is-eq max-uses NO-USAGE-LIMIT) (< times-used max-uses))
            (>= purchase-amount min-purchase)
            (if (is-some access-record)
              (get has-permission (default-to {has-permission: false, granted-at-block: u0, granted-by: tx-sender} access-record))
              true
            )
          ),
          is-active: is-active,
          is-expired: (>= block-height expires-at),
          usage-exceeded: (and (> max-uses NO-USAGE-LIMIT) (>= times-used max-uses)),
          meets-minimum: (>= purchase-amount min-purchase),
          has-access: (if (is-some access-record)
                        (get has-permission (default-to {has-permission: false, granted-at-block: u0, granted-by: tx-sender} access-record))
                        true),
          user-redemptions: (get redemption-count user-record)
        })
      )
      (ok {
        can-redeem: false,
        is-active: false,
        is-expired: true,
        usage-exceeded: true,
        meets-minimum: false,
        has-access: false,
        user-redemptions: u0
      })
    )
  )
)

;; Retrieves redemption history for a specific user and voucher
(define-read-only (get-user-history (code (string-ascii 32)) (user principal))
  (begin
    ;; Validate user address
    (asserts! (is-valid-wallet user) ERR-INVALID-PARAMETERS)
    
    ;; Return user redemption record
    (ok (default-to 
          {redemption-count: u0, first-used-at: u0, last-used-at: u0}
          (map-get? user-redemption-records {user: user, code: code})
        ))
  )
)

;; Calculates and previews the discount without redeeming the voucher
(define-read-only (preview-discount (code (string-ascii 32)) (purchase-amount uint))
  (begin
    ;; Validate purchase amount
    (asserts! (> purchase-amount u0) ERR-INVALID-PARAMETERS)
    
    ;; Calculate discount preview
    (match (map-get? voucher-details {code: code})
      config
      (let (
        (disc-type (get discount-type config))
        (disc-value (get value config))
        (min-purchase (get min-purchase config))
      )
        (ok {
          discount-amount: (if (is-eq disc-type DISCOUNT-TYPE-PERCENTAGE)
                            ;; Percentage calculation
                            (/ (* purchase-amount disc-value) u100)
                            ;; Fixed amount calculation
                            (if (> disc-value purchase-amount) 
                                purchase-amount 
                                disc-value)),
          final-price: (- purchase-amount 
                        (if (is-eq disc-type DISCOUNT-TYPE-PERCENTAGE)
                          (/ (* purchase-amount disc-value) u100)
                          (if (> disc-value purchase-amount) 
                              purchase-amount 
                              disc-value))),
          meets-minimum: (>= purchase-amount min-purchase),
          effective-percentage: (if (is-eq disc-type DISCOUNT-TYPE-PERCENTAGE)
                                 disc-value
                                 (/ (* (if (> disc-value purchase-amount) 
                                           purchase-amount 
                                           disc-value) u100) purchase-amount))
        })
      )
      ERR-VOUCHER-NOT-FOUND
    )
  )
)

;; Retrieves overall platform statistics and status
(define-read-only (get-platform-stats)
  (ok {
    owner: (var-get contract-owner),
    vouchers-created: (var-get vouchers-created-count),
    redemptions-completed: (var-get redemptions-completed-count),
    current-block: block-height
  })
)

;; Retrieves administrative audit log entry for a specific block and admin
(define-read-only (get-audit-log (log-block uint) (admin principal))
  (ok (map-get? admin-action-log {log-block: log-block, admin: admin}))
)