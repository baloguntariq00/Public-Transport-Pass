# 🚌 Public Transport Pass Smart Contract

A comprehensive Clarity smart contract for managing public transport passes on the Stacks blockchain. This contract enables users to purchase, manage, and use digital transport passes across multiple zones with automated billing.

## ✨ Features

- 🎫 **Multiple Pass Types**: Daily, Weekly, and Monthly passes
- 🗺️ **Zone-Based Pricing**: Different costs for inter-zone travel
- 💰 **Balance Management**: Top-up functionality and automatic deductions
- 📊 **Usage Tracking**: Complete ride history and analytics
- 🔄 **Pass Transfer**: Transfer ownership between users
- 💸 **Refund System**: Get remaining balance back
- 👑 **Admin Controls**: Zone rate management and revenue tracking

## 🎟️ Pass Types & Pricing

| Pass Type | Duration (blocks) | Cost (STX) |
|-----------|-------------------|------------|
| Daily     | 144               | 10         |
| Weekly    | 1,008             | 60         |
| Monthly   | 4,320             | 200        |

## 🚀 Quick Start

### Purchase a Pass

```clarity
(contract-call? .Public-Transport-Pass purchase-pass u1 u1)
```
- `u1` (first parameter): Pass type (1=Daily, 2=Weekly, 3=Monthly)
- `u1` (second parameter): Zone number

### Use Pass for a Ride

```clarity
(contract-call? .Public-Transport-Pass use-pass-for-ride u1 u1 u2)
```
- `u1` (first parameter): Pass ID
- `u1` (second parameter): From zone
- `u2` (third parameter): To zone

### Top Up Pass Balance

```clarity
(contract-call? .Public-Transport-Pass top-up-pass u1 u50)
```
- `u1`: Pass ID
- `u50`: Amount to add (in STX)

## 📋 Functions

### Public Functions

| Function | Description |
|----------|-------------|
| `purchase-pass` | Buy a new transport pass |
| `top-up-pass` | Add balance to existing pass |
| `use-pass-for-ride` | Deduct cost for a ride |
| `deactivate-pass` | Disable a pass |
| `refund-pass` | Get refund for remaining balance |
| `transfer-pass-ownership` | Transfer pass to another user |

### Admin Functions

| Function | Description |
|----------|-------------|
| `set-zone-rate` | Set pricing between zones |
| `extend-pass` | Extend pass expiry |
| `set-contract-owner` | Transfer admin rights |
| `withdraw-revenue` | Withdraw contract earnings |

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-pass-info` | Get complete pass details |
| `get-user-passes` | List user's passes |
| `get-ride-history` | Get ride transaction details |
| `is-pass-valid` | Check if pass is active and not expired |
| `get-contract-stats` | View contract statistics |

## 🌍 Zone System

The contract supports a flexible zone-based pricing system:

- **Zone 1 ↔ Zone 1**: 1 STX
- **Zone 1 ↔ Zone 2**: 2 STX  
- **Zone 1 ↔ Zone 3**: 3 STX
- **Zone 2 ↔ Zone 2**: 1 STX
- **Zone 2 ↔ Zone 3**: 2 STX
- **Zone 3 ↔ Zone 3**: 1 STX

## 🛠️ Development

### Prerequisites

- [Clarinet](https://docs.hiro.so/clarinet) installed
- Node.js for testing

### Setup

```bash
git clone <repository-url>
cd Public-Transport-Pass
clarinet check
```

### Testing

```bash
npm install
npm test
```

## 📊 Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | ERR_NOT_AUTHORIZED | User lacks permission |
| u101 | ERR_INVALID_PASS | Pass is inactive or invalid |
| u102 | ERR_INSUFFICIENT_BALANCE | Not enough balance for operation |
| u103 | ERR_PASS_EXPIRED | Pass has expired |
| u104 | ERR_INVALID_PASS_TYPE | Invalid pass type specified |
| u105 | ERR_ALREADY_USED | Operation already completed |
| u106 | ERR_INVALID_AMOUNT | Invalid amount specified |
| u107 | ERR_PASS_NOT_FOUND | Pass ID doesn't exist |
| u108 | ERR_INVALID_ZONE | Invalid zone specified |

## 🔐 Security Features

- ✅ Owner-only administrative functions
- ✅ Pass ownership verification
- ✅ Balance validation before transactions
- ✅ Expiry checks for all operations
- ✅ STX transfer protection

## 🚀 Deployment

Deploy using Clarinet:

```bash
clarinet deploy --network testnet
```

## 📝 License

MIT License - feel free to use in your projects!

---

*Built with ❤️ for the Stacks ecosystem*
