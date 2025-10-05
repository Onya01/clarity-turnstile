# Clarity Turnstile

A coin-based turnstile finite state machine that locks/unlocks based on coin insertion for access control, built on the Stacks blockchain using Clarity smart contracts.

## Overview

This project implements a decentralized turnstile access control system with two main components:

1. **Turnstile FSM Contract** (`turnstile-fsm.clar`) - Manages the locked and unlocked states
2. **Coin Payment Processor Contract** (`coin-payment-processor.clar`) - Handles coin insertion and transaction validation

## Architecture

```
┌─────────────────┐    ┌──────────────────────┐
│   User/Client   │────│  Coin Payment        │
│                 │    │  Processor Contract  │
└─────────────────┘    └──────────────────────┘
                                │
                                │ contract-call
                                ▼
                       ┌──────────────────────┐
                       │  Turnstile FSM       │
                       │  Contract            │
                       └──────────────────────┘
```

## Contracts

### Turnstile FSM Contract

**File**: `contracts/turnstile-fsm.clar`

**Purpose**: Finite state machine implementation managing locked and unlocked states

**Key Features**:
- State management (locked/unlocked)
- Time-based auto-locking
- Authorization system with operators
- Event logging

**Main Functions**:
- `unlock-turnstile()` - Unlocks the turnstile (authorized users only)
- `lock-turnstile()` - Manually locks the turnstile
- `auto-lock-if-expired()` - Automatically locks when time expires
- `get-current-state()` - Returns current state (0=locked, 1=unlocked)
- `is-locked()` / `is-unlocked()` - State checker functions

### Coin Payment Processor Contract

**File**: `contracts/coin-payment-processor.clar`

**Purpose**: Payment processing system that handles coin insertion and validates transactions

**Key Features**:
- STX payment processing
- Integration with turnstile FSM
- Refund system for failed transactions
- Payment history tracking
- Fund collection for authorized users

**Main Functions**:
- `insert-coin()` - Process payment and unlock turnstile
- `process-refund(user)` - Process refunds for failed transactions
- `set-payment-amount(amount)` - Set required payment amount
- `get-payment-amount()` - Get current payment requirement
- `collect-funds(amount)` - Collect accumulated funds

## Usage

### Deployment

1. Deploy the `turnstile-fsm` contract first
2. Deploy the `coin-payment-processor` contract
3. Configure the payment processor to reference the FSM contract

### User Flow

1. **Check Status**: User checks if turnstile is locked
2. **Insert Coin**: User calls `insert-coin()` with sufficient STX
3. **Payment Processing**: Contract validates payment and transfers STX
4. **Turnstile Unlock**: Contract calls FSM to unlock turnstile
5. **Access Granted**: User can pass through
6. **Auto-Lock**: Turnstile automatically locks after timeout

### Example Interaction

```clarity
;; Check current state
(contract-call? .turnstile-fsm get-current-state)

;; Insert coin (user must have >= 1 STX)
(contract-call? .coin-payment-processor insert-coin)

;; Turnstile should now be unlocked
(contract-call? .turnstile-fsm is-unlocked)
```

## Configuration

### Payment Settings

- **Default Payment**: 1 STX (1,000,000 microSTX)
- **Refund Threshold**: 0.5 STX
- **Auto-Lock Duration**: 144 blocks (~24 hours)

### Security Features

- **Authorization**: Only contract owners and operators can manage settings
- **Refund Protection**: Failed transactions trigger automatic refunds
- **Emergency Functions**: Owner can initiate emergency procedures
- **Event Logging**: All actions are logged for audit trails

## Development

### Prerequisites

- [Clarinet](https://docs.hiro.so/clarinet) installed
- Node.js for testing
- Stacks CLI for deployment

### Local Development

```bash
# Install dependencies
npm install

# Run syntax check
clarinet check

# Run tests
npm test

# Deploy locally
clarinet integrate
```

### Testing

The project includes comprehensive test suites for both contracts:

- `tests/turnstile-fsm.test.ts` - FSM contract tests
- `tests/coin-payment-processor.test.ts` - Payment processor tests

## Error Codes

### Turnstile FSM Errors
- `u100` - ERR_UNAUTHORIZED
- `u101` - ERR_INVALID_STATE
- `u102` - ERR_ALREADY_UNLOCKED
- `u103` - ERR_ALREADY_LOCKED

### Payment Processor Errors
- `u200` - ERR_INSUFFICIENT_PAYMENT
- `u201` - ERR_INVALID_AMOUNT
- `u202` - ERR_PAYMENT_FAILED
- `u203` - ERR_UNAUTHORIZED
- `u204` - ERR_TURNSTILE_ERROR
- `u205` - ERR_REFUND_FAILED

## Security Considerations

1. **Access Control**: Only authorized operators can manage turnstile state
2. **Payment Validation**: All payments are validated before processing
3. **Refund Protection**: Users are protected against failed transactions
4. **State Consistency**: FSM ensures valid state transitions only
5. **Fund Security**: Collected funds are protected by authorization checks

## License

This project is open source and available under the MIT License.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## Support

For issues and questions, please create an issue in the GitHub repository.