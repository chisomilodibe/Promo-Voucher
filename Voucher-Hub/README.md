# Promotional Voucher Management System

A blockchain-based voucher platform that enables businesses to create and manage promotional discount campaigns with configurable rules, usage tracking, and comprehensive analytics.

## Overview

This smart contract provides a complete solution for managing promotional vouchers on the Stacks blockchain. It supports percentage and fixed-value discounts, time-limited campaigns, user access controls, minimum purchase requirements, and complete audit trails for compliance and reporting.

## Features

### Core Functionality
- Create and manage promotional voucher campaigns
- Support for percentage-based and fixed-value discounts
- Time-limited campaigns with configurable expiration
- Usage limits and tracking per voucher
- Minimum purchase requirements
- User-specific access controls
- Complete audit trail for all administrative actions

### Campaign Management
- Activate and deactivate vouchers
- Extend campaign expiration dates
- Reset usage counters
- Update minimum purchase requirements
- Transfer contract ownership

### Analytics and Reporting
- Comprehensive voucher analytics
- Redemption eligibility checking
- User redemption history
- Discount preview calculations
- Platform-wide statistics

## Constants

### Error Codes
- `ERR-NOT-AUTHORIZED (u100)` - Unauthorized access attempt
- `ERR-VOUCHER-NOT-FOUND (u101)` - Voucher code does not exist
- `ERR-CAMPAIGN-EXPIRED (u102)` - Campaign has expired
- `ERR-USAGE-LIMIT-REACHED (u103)` - Maximum usage limit reached
- `ERR-INVALID-PARAMETERS (u104)` - Invalid input parameters
- `ERR-VOUCHER-ALREADY-EXISTS (u105)` - Voucher code already exists
- `ERR-ACCESS-DENIED (u106)` - User lacks access permission
- `ERR-VOUCHER-INACTIVE (u107)` - Voucher is not active
- `ERR-MINIMUM-NOT-MET (u108)` - Purchase amount below minimum

### Business Rules
- `DISCOUNT-TYPE-PERCENTAGE (u0)` - Percentage-based discount
- `DISCOUNT-TYPE-FIXED (u1)` - Fixed amount discount
- `NO-USAGE-LIMIT (u0)` - Unlimited redemptions
- `MIN-DISCOUNT-VALUE (u0)` - Minimum discount value
- `MAX-PERCENTAGE-VALUE (u100)` - Maximum percentage (100%)
- `BATCH-PROCESSING-LIMIT (u200)` - Batch operation limit

## Public Functions

### Administrative Functions

#### create-voucher
Creates a new promotional voucher campaign.

**Parameters:**
- `code` (string-ascii 32) - Unique voucher code
- `discount-type` (uint) - Type of discount (0 = percentage, 1 = fixed)
- `value` (uint) - Discount value (percentage or fixed amount)
- `duration-blocks` (uint) - Campaign duration in blocks
- `max-uses` (uint) - Maximum number of redemptions (0 = unlimited)
- `min-purchase` (uint) - Minimum purchase amount required

**Authorization:** Contract owner only

**Returns:** `(ok true)` on success

**Example:**
```clarity
(contract-call? .voucher-system create-voucher "SAVE20" u0 u20 u1440 u100 u1000)
```

#### set-user-access
Grants or revokes access permission for a specific user to a voucher.

**Parameters:**
- `code` (string-ascii 32) - Voucher code
- `user` (principal) - User wallet address
- `grant-access` (bool) - True to grant, false to revoke

**Authorization:** Contract owner only

**Returns:** `(ok true)` on success

#### deactivate-voucher
Deactivates a voucher campaign, preventing further redemptions.

**Parameters:**
- `code` (string-ascii 32) - Voucher code

**Authorization:** Contract owner only

**Returns:** `(ok true)` on success

#### reactivate-voucher
Reactivates a previously deactivated voucher campaign.

**Parameters:**
- `code` (string-ascii 32) - Voucher code

**Authorization:** Contract owner only

**Returns:** `(ok true)` on success

#### reset-usage-counter
Resets the usage counter for a voucher back to zero.

**Parameters:**
- `code` (string-ascii 32) - Voucher code

**Authorization:** Contract owner only

**Returns:** `(ok true)` on success

#### extend-expiration
Extends the expiration date of a voucher campaign.

**Parameters:**
- `code` (string-ascii 32) - Voucher code
- `additional-blocks` (uint) - Number of blocks to extend

**Authorization:** Contract owner only

**Returns:** `(ok true)` on success

#### update-min-purchase
Updates the minimum purchase requirement for a voucher.

**Parameters:**
- `code` (string-ascii 32) - Voucher code
- `new-minimum` (uint) - New minimum purchase amount

**Authorization:** Contract owner only

**Returns:** `(ok true)` on success

#### transfer-ownership
Transfers contract ownership to a new administrator.

**Parameters:**
- `new-owner` (principal) - New owner wallet address

**Authorization:** Contract owner only

**Returns:** `(ok true)` on success

### User Functions

#### redeem-voucher
Redeems a voucher code and returns the calculated discount amount.

**Parameters:**
- `code` (string-ascii 32) - Voucher code
- `purchase-amount` (uint) - Purchase amount before discount

**Returns:** `(ok uint)` - Discount amount on success

**Validations:**
- Voucher must exist and be active
- Campaign must not be expired
- Usage limit must not be reached
- Purchase amount must meet minimum requirement
- User must have access permission (if configured)

**Example:**
```clarity
(contract-call? .voucher-system redeem-voucher "SAVE20" u5000)
```

## Read-Only Functions

### get-voucher-analytics
Retrieves comprehensive analytics for a voucher campaign.

**Parameters:**
- `code` (string-ascii 32) - Voucher code

**Returns:** Object containing:
- `code` - Voucher code
- `discount-type` - Type of discount
- `value` - Discount value
- `expires-at-block` - Expiration block height
- `max-uses` - Maximum redemptions allowed
- `times-used` - Current redemption count
- `min-purchase` - Minimum purchase requirement
- `is-active` - Active status
- `started-at-block` - Campaign start block
- `created-by` - Creator principal
- `blocks-until-expiry` - Blocks remaining until expiration
- `usage-percentage` - Percentage of usage limit consumed

### check-redemption-eligibility
Checks if a user can redeem a voucher with given purchase amount.

**Parameters:**
- `code` (string-ascii 32) - Voucher code
- `user` (principal) - User wallet address
- `purchase-amount` (uint) - Purchase amount

**Returns:** Object containing eligibility details:
- `can-redeem` - Overall eligibility status
- `is-active` - Voucher active status
- `is-expired` - Expiration status
- `usage-exceeded` - Usage limit status
- `meets-minimum` - Minimum purchase status
- `has-access` - Access permission status
- `user-redemptions` - User's redemption count

### get-user-history
Retrieves redemption history for a specific user and voucher.

**Parameters:**
- `code` (string-ascii 32) - Voucher code
- `user` (principal) - User wallet address

**Returns:** Object containing:
- `redemption-count` - Total redemptions by user
- `first-used-at` - Block height of first redemption
- `last-used-at` - Block height of last redemption

### preview-discount
Calculates and previews the discount without redeeming the voucher.

**Parameters:**
- `code` (string-ascii 32) - Voucher code
- `purchase-amount` (uint) - Purchase amount

**Returns:** Object containing:
- `discount-amount` - Calculated discount
- `final-price` - Price after discount
- `meets-minimum` - Minimum purchase status
- `effective-percentage` - Effective discount percentage

### get-platform-stats
Retrieves overall platform statistics and status.

**Returns:** Object containing:
- `owner` - Contract owner address
- `vouchers-created` - Total vouchers created
- `redemptions-completed` - Total redemptions
- `current-block` - Current block height

### get-audit-log
Retrieves administrative audit log entry for a specific block and admin.

**Parameters:**
- `log-block` (uint) - Block height
- `admin` (principal) - Administrator address

**Returns:** Optional object containing:
- `action-type` - Type of action performed
- `voucher-code` - Associated voucher code
- `executed-at` - Execution block height

## Data Structures

### Voucher Details
Stores comprehensive configuration for each voucher:
- Discount value and type
- Expiration block height
- Usage limits and tracking
- Minimum purchase requirement
- Active status
- Campaign metadata

### User Redemption Records
Tracks individual user redemption history:
- Total redemption count
- First and last usage timestamps
- Associated voucher code

### Voucher Access Control
Manages user-specific access permissions:
- Permission status
- Grant timestamp
- Granting administrator

### Admin Action Log
Maintains audit trail of administrative actions:
- Action type and timestamp
- Associated voucher code
- Executing administrator

## Usage Examples

### Creating a Percentage Discount Campaign
```clarity
;; Create a 20% discount voucher valid for 1440 blocks
;; Maximum 100 uses, minimum purchase 1000
(contract-call? .voucher-system create-voucher 
  "SUMMER20" 
  u0 
  u20 
  u1440 
  u100 
  u1000)
```

### Creating a Fixed Discount Campaign
```clarity
;; Create a 500 unit discount voucher valid for 2880 blocks
;; Unlimited uses, no minimum purchase
(contract-call? .voucher-system create-voucher 
  "FIXED500" 
  u1 
  u500 
  u2880 
  u0 
  u0)
```

### Redeeming a Voucher
```clarity
;; Redeem voucher with 5000 unit purchase
(contract-call? .voucher-system redeem-voucher "SUMMER20" u5000)
;; Returns discount amount (e.g., 1000 for 20% of 5000)
```

### Checking Eligibility
```clarity
;; Check if user can redeem voucher
(contract-call? .voucher-system check-redemption-eligibility 
  "SUMMER20" 
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM
  u5000)
```

### Previewing Discount
```clarity
;; Preview discount without redeeming
(contract-call? .voucher-system preview-discount "SUMMER20" u5000)
;; Returns discount breakdown and final price
```

## Security Considerations

### Authorization
- All administrative functions require contract owner authentication
- User-specific access controls can restrict voucher usage
- Ownership transfer requires current owner authorization

### Validation
- Comprehensive input validation on all parameters
- Voucher existence checks before operations
- Discount value range validation
- Wallet address format verification

### Audit Trail
- All administrative actions logged with timestamps
- Immutable blockchain record of all operations
- Complete redemption history per user

## Best Practices

### Campaign Design
- Set appropriate usage limits to control exposure
- Use minimum purchase requirements to ensure profitability
- Configure expiration dates based on campaign goals
- Consider user access controls for exclusive promotions

### Operations
- Monitor usage analytics regularly
- Extend campaigns before expiration if needed
- Deactivate problematic vouchers immediately
- Reset counters only when necessary

### Integration
- Always check eligibility before displaying vouchers to users
- Use preview function to show discount calculations
- Handle all error conditions gracefully
- Implement retry logic for blockchain interactions