;; Decentralized AI Model Trading Platform Smart Contract
;; Core on-chain marketplace for AI model licensing and monetization
;; Features: Model registration, licensing, payments, and governance

;; ERROR CONSTANTS
(define-constant contract-owner tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u103))
(define-constant ERR-EXPIRED (err u104))
(define-constant ERR-ACCESS-DENIED (err u105))
(define-constant ERR-INVALID-PARAMS (err u106))
(define-constant ERR-UNAVAILABLE (err u107))
(define-constant ERR-TRANSFER-FAILED (err u108))

;; PLATFORM CONSTANTS
(define-constant default-commission u250) ;; 2.5%
(define-constant min-license-duration u144) ;; 1 day
(define-constant max-license-duration u52560) ;; 1 year
(define-constant max-commission u1000) ;; 10%
(define-constant min-license-fee u1000) ;; minimum price
(define-constant basis-points u10000)

;; CORE DATA STRUCTURES

;; AI Models Registry
(define-map ai-models
  { model-id: uint }
  {
    creator: principal,
    title: (string-ascii 64),
    description: (string-ascii 256),
    price: uint,
    duration: uint,
    active: bool,
    created-at: uint,
    total-sales: uint
  }
)

;; Active Licenses
(define-map licenses
  { model-id: uint, user: principal }
  {
    expires-at: uint,
    purchased-at: uint,
    amount-paid: uint,
    active: bool
  }
)

;; Model Technical Data
(define-map model-specs
  { model-id: uint }
  {
    version: (string-ascii 16),
    file-hash: (string-ascii 64),
    file-size: uint,
    accuracy: uint
  }
)

;; Financial Metrics
(define-map model-revenue
  { model-id: uint }
  {
    total-revenue: uint,
    active-licenses: uint,
    platform-fees: uint
  }
)

;; PLATFORM STATE
(define-data-var next-model-id uint u1)
(define-data-var commission-rate uint default-commission)
(define-data-var marketplace-active bool true)
(define-data-var total-volume uint u0)
(define-data-var total-models uint u0)

;; CORE READ FUNCTIONS

(define-read-only (get-model (model-id uint))
  (map-get? ai-models { model-id: model-id })
)

(define-read-only (get-license (model-id uint) (user principal))
  (map-get? licenses { model-id: model-id, user: user })
)

(define-read-only (get-model-specs (model-id uint))
  (map-get? model-specs { model-id: model-id })
)

(define-read-only (get-revenue (model-id uint))
  (map-get? model-revenue { model-id: model-id })
)

(define-read-only (check-license-valid (model-id uint) (user principal))
  (match (get-license model-id user)
    license-data (and (>= (get expires-at license-data) block-height) (get active license-data))
    false
  )
)

(define-read-only (calculate-commission (amount uint))
  (/ (* amount (var-get commission-rate)) basis-points)
)

(define-read-only (get-platform-stats)
  {
    total-models: (var-get total-models),
    total-volume: (var-get total-volume),
    commission-rate: (var-get commission-rate),
    marketplace-active: (var-get marketplace-active)
  }
)

;; VALIDATION HELPERS

(define-private (is-admin)
  (is-eq tx-sender contract-owner)
)

(define-private (is-model-creator (model-id uint))
  (match (get-model model-id)
    model-data (is-eq tx-sender (get creator model-data))
    false
  )
)

(define-private (validate-duration (duration uint))
  (and (>= duration min-license-duration) (<= duration max-license-duration))
)

(define-private (update-revenue (model-id uint) (amount uint))
  (let (
    (current-revenue (default-to 
      { total-revenue: u0, active-licenses: u0, platform-fees: u0 }
      (get-revenue model-id)))
    (commission-amount (calculate-commission amount))
  )
    (map-set model-revenue
      { model-id: model-id }
      {
        total-revenue: (+ (get total-revenue current-revenue) amount),
        active-licenses: (+ (get active-licenses current-revenue) u1),
        platform-fees: (+ (get platform-fees current-revenue) commission-amount)
      }
    )
    (var-set total-volume (+ (var-get total-volume) amount))
  )
)

;; MODEL REGISTRATION

(define-public (register-model
    (title (string-ascii 64))
    (description (string-ascii 256))
    (price uint)
    (duration uint)
    (version (string-ascii 16))
    (file-hash (string-ascii 64))
    (file-size uint)
    (accuracy uint))
  (let ((model-id (var-get next-model-id)))
    ;; Validations
    (asserts! (var-get marketplace-active) ERR-UNAVAILABLE)
    (asserts! (>= price min-license-fee) ERR-INVALID-PARAMS)
    (asserts! (validate-duration duration) ERR-INVALID-PARAMS)
    (asserts! (> (len title) u0) ERR-INVALID-PARAMS)
    (asserts! (<= accuracy u10000) ERR-INVALID-PARAMS)
    
    ;; Register model
    (map-set ai-models
      { model-id: model-id }
      {
        creator: tx-sender,
        title: title,
        description: description,
        price: price,
        duration: duration,
        active: true,
        created-at: block-height,
        total-sales: u0
      }
    )
    
    ;; Set technical specs
    (map-set model-specs
      { model-id: model-id }
      {
        version: version,
        file-hash: file-hash,
        file-size: file-size,
        accuracy: accuracy
      }
    )
    
    ;; Initialize revenue tracking
    (map-set model-revenue
      { model-id: model-id }
      { total-revenue: u0, active-licenses: u0, platform-fees: u0 }
    )
    
    ;; Update counters
    (var-set next-model-id (+ model-id u1))
    (var-set total-models (+ (var-get total-models) u1))
    
    (ok model-id)
  )
)

;; LICENSE PURCHASE

(define-public (buy-license (model-id uint))
  (let (
    (model-data (unwrap! (get-model model-id) ERR-NOT-FOUND))
    (license-price (get price model-data))
    (commission-amount (calculate-commission license-price))
    (creator-payment (- license-price commission-amount))
    (expires-at (+ block-height (get duration model-data)))
  )
    ;; Validations
    (asserts! (var-get marketplace-active) ERR-UNAVAILABLE)
    (asserts! (get active model-data) ERR-UNAVAILABLE)
    (asserts! (not (check-license-valid model-id tx-sender)) ERR-ALREADY-EXISTS)
    (asserts! (not (is-eq tx-sender (get creator model-data))) ERR-INVALID-PARAMS)
    
    ;; Process payments
    (try! (stx-transfer? creator-payment tx-sender (get creator model-data)))
    (try! (stx-transfer? commission-amount tx-sender contract-owner))
    
    ;; Create license
    (map-set licenses
      { model-id: model-id, user: tx-sender }
      {
        expires-at: expires-at,
        purchased-at: block-height,
        amount-paid: license-price,
        active: true
      }
    )
    
    ;; Update model stats
    (map-set ai-models
      { model-id: model-id }
      (merge model-data { total-sales: (+ (get total-sales model-data) u1) })
    )
    
    ;; Update revenue tracking
    (update-revenue model-id license-price)
    
    (ok expires-at)
  )
)

;; LICENSE RENEWAL

(define-public (renew-license (model-id uint))
  (let (
    (model-data (unwrap! (get-model model-id) ERR-NOT-FOUND))
    (current-license (unwrap! (get-license model-id tx-sender) ERR-NOT-FOUND))
    (renewal-price (get price model-data))
    (commission-amount (calculate-commission renewal-price))
    (creator-payment (- renewal-price commission-amount))
    (new-expires-at (+ block-height (get duration model-data)))
  )
    ;; Validations
    (asserts! (var-get marketplace-active) ERR-UNAVAILABLE)
    (asserts! (get active model-data) ERR-UNAVAILABLE)
    (asserts! (get active current-license) ERR-EXPIRED)
    
    ;; Process payments
    (try! (stx-transfer? creator-payment tx-sender (get creator model-data)))
    (try! (stx-transfer? commission-amount tx-sender contract-owner))
    
    ;; Update license
    (map-set licenses
      { model-id: model-id, user: tx-sender }
      (merge current-license { expires-at: new-expires-at })
    )
    
    ;; Update revenue tracking
    (update-revenue model-id renewal-price)
    
    (ok new-expires-at)
  )
)

;; MODEL MANAGEMENT

(define-public (update-model-info
    (model-id uint)
    (title (string-ascii 64))
    (description (string-ascii 256))
    (price uint))
  (let ((model-data (unwrap! (get-model model-id) ERR-NOT-FOUND)))
    ;; Validations
    (asserts! (is-model-creator model-id) ERR-ACCESS-DENIED)
    (asserts! (>= price min-license-fee) ERR-INVALID-PARAMS)
    (asserts! (> (len title) u0) ERR-INVALID-PARAMS)
    
    ;; Update model
    (map-set ai-models
      { model-id: model-id }
      (merge model-data {
        title: title,
        description: description,
        price: price
      })
    )
    
    (ok true)
  )
)

(define-public (toggle-model-status (model-id uint))
  (let ((model-data (unwrap! (get-model model-id) ERR-NOT-FOUND)))
    (asserts! (is-model-creator model-id) ERR-ACCESS-DENIED)
    
    (map-set ai-models
      { model-id: model-id }
      (merge model-data { active: (not (get active model-data)) })
    )
    
    (ok (not (get active model-data)))
  )
)

;; LICENSE TRANSFER

(define-public (transfer-license (model-id uint) (recipient principal))
  (let (
    (license-data (unwrap! (get-license model-id tx-sender) ERR-NOT-FOUND))
    (transfer-fee u50000) ;; 0.05 STX
  )
    ;; Validations
    (asserts! (get active license-data) ERR-EXPIRED)
    (asserts! (>= (get expires-at license-data) block-height) ERR-EXPIRED)
    (asserts! (not (is-eq tx-sender recipient)) ERR-INVALID-PARAMS)
    (asserts! (is-none (get-license model-id recipient)) ERR-ALREADY-EXISTS)
    
    ;; Pay transfer fee
    (try! (stx-transfer? transfer-fee tx-sender contract-owner))
    
    ;; Transfer license
    (map-delete licenses { model-id: model-id, user: tx-sender })
    (map-set licenses { model-id: model-id, user: recipient } license-data)
    
    (ok true)
  )
)

;; BATCH OPERATIONS

(define-public (batch-check-licenses (model-ids (list 5 uint)))
  (ok (map check-user-license model-ids))
)

(define-private (check-user-license (model-id uint))
  {
    model-id: model-id,
    has-license: (check-license-valid model-id tx-sender)
  }
)

;; ANALYTICS

(define-read-only (get-model-analytics (model-id uint))
  (let (
    (model-data (get-model model-id))
    (revenue-data (get-revenue model-id))
    (specs-data (get-model-specs model-id))
  )
    (if (and (is-some model-data) (is-some revenue-data))
      (some {
        model-info: (unwrap-panic model-data),
        revenue-data: (unwrap-panic revenue-data),
        technical-specs: specs-data,
        avg-revenue-per-sale: (if (> (get total-sales (unwrap-panic model-data)) u0)
                                (/ (get total-revenue (unwrap-panic revenue-data))
                                   (get total-sales (unwrap-panic model-data)))
                                u0)
      })
      none
    )
  )
)

;; ADMIN GOVERNANCE

(define-public (set-commission-rate (new-rate uint))
  (begin
    (asserts! (is-admin) ERR-UNAUTHORIZED)
    (asserts! (<= new-rate max-commission) ERR-INVALID-PARAMS)
    (var-set commission-rate new-rate)
    (ok true)
  )
)

(define-public (toggle-marketplace)
  (begin
    (asserts! (is-admin) ERR-UNAUTHORIZED)
    (var-set marketplace-active (not (var-get marketplace-active)))
    (ok (var-get marketplace-active))
  )
)

(define-public (admin-disable-model (model-id uint))
  (let ((model-data (unwrap! (get-model model-id) ERR-NOT-FOUND)))
    (asserts! (is-admin) ERR-UNAUTHORIZED)
    
    (map-set ai-models
      { model-id: model-id }
      (merge model-data { active: false })
    )
    
    (ok true)
  )
)

(define-public (emergency-withdraw (amount uint))
  (begin
    (asserts! (is-admin) ERR-UNAUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-PARAMS)
    (try! (stx-transfer? amount (as-contract tx-sender) contract-owner))
    (ok true)
  )
)

;; ACCESS VALIDATION

(define-read-only (validate-access (model-id uint) (user principal))
  (let (
    (model-data (get-model model-id))
    (is-creator (if (is-some model-data) 
                   (is-eq user (get creator (unwrap-panic model-data))) 
                   false))
  )
    {
      model-exists: (is-some model-data),
      model-active: (if (is-some model-data) (get active (unwrap-panic model-data)) false),
      has-valid-license: (check-license-valid model-id user),
      is-creator: is-creator,
      access-granted: (or is-creator (check-license-valid model-id user))
    }
  )
)