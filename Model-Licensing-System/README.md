# Decentralized AI Model Trading Platform

A comprehensive smart contract for creating a decentralized marketplace where AI model creators can monetize their models through licensing, and users can purchase time-based access to AI models on the Stacks blockchain.

## Features

- **Model Registration**: Creators can register AI models with metadata, pricing, and technical specifications
- **Licensing System**: Time-based licensing with automatic expiration
- **Revenue Sharing**: Automatic commission distribution between creators and platform
- **License Management**: Purchase, renewal, and transfer capabilities
- **Access Control**: Secure validation of model access rights
- **Analytics**: Comprehensive revenue and usage tracking
- **Batch Operations**: Efficient multi-model license checking
- **Admin Governance**: Platform management and emergency controls

## Core Components

### Data Structures

- **AI Models Registry**: Stores model metadata, pricing, and creator information
- **Active Licenses**: Tracks user licenses with expiration dates
- **Model Specifications**: Technical details including file hash, size, and accuracy
- **Revenue Tracking**: Financial metrics and platform fees

### Key Constants

- **Commission Rate**: 2.5% (250 basis points) - customizable by admin
- **License Duration**: 1 day minimum, 1 year maximum
- **Minimum Price**: 1,000 microSTX
- **Transfer Fee**: 0.05 STX for license transfers

## Installation & Deployment

### Prerequisites

- Clarinet CLI installed
- Stacks wallet configured
- STX tokens for deployment and testing

### Deployment Steps

1. Clone the repository
2. Install dependencies:
   ```bash
   clarinet install
   ```

3. Test the contract:
   ```bash
   clarinet test
   ```

4. Deploy to testnet:
   ```bash
   clarinet deploy --testnet
   ```

## API Reference

### Model Management

#### `register-model`
Register a new AI model in the marketplace.

```clarity
(register-model 
  title description price duration 
  version file-hash file-size accuracy)
```

**Parameters:**
- `title`: Model name (max 64 chars)
- `description`: Model description (max 256 chars)
- `price`: License price in microSTX
- `duration`: License duration in blocks
- `version`: Model version string
- `file-hash`: SHA-256 hash of model file
- `file-size`: File size in bytes
- `accuracy`: Model accuracy (0-10000, representing 0-100%)

#### `update-model-info`
Update model metadata (creator only).

```clarity
(update-model-info model-id title description price)
```

#### `toggle-model-status`
Enable/disable model availability (creator only).

```clarity
(toggle-model-status model-id)
```

### Licensing Operations

#### `buy-license`
Purchase a license for an AI model.

```clarity
(buy-license model-id)
```

**Behavior:**
- Transfers payment to model creator (minus commission)
- Pays platform commission to contract owner
- Creates active license with expiration date
- Updates model sales statistics

#### `renew-license`
Extend an existing license.

```clarity
(renew-license model-id)
```

#### `transfer-license`
Transfer license to another user (requires transfer fee).

```clarity
(transfer-license model-id recipient)
```

### Access Control

#### `check-license-valid`
Verify if a user has valid access to a model.

```clarity
(check-license-valid model-id user)
```

#### `validate-access`
Comprehensive access validation with detailed status.

```clarity
(validate-access model-id user)
```

**Returns:**
- `model-exists`: Boolean
- `model-active`: Boolean
- `has-valid-license`: Boolean
- `is-creator`: Boolean
- `access-granted`: Boolean

### Analytics & Queries

#### `get-model`
Retrieve model information.

```clarity
(get-model model-id)
```

#### `get-model-analytics`
Get comprehensive model analytics.

```clarity
(get-model-analytics model-id)
```

**Returns:**
- Model information
- Revenue data
- Technical specifications
- Average revenue per sale

#### `get-platform-stats`
Get platform-wide statistics.

```clarity
(get-platform-stats)
```

#### `batch-check-licenses`
Check license status for multiple models.

```clarity
(batch-check-licenses (list model-id1 model-id2 ...))
```

### Administrative Functions

#### `set-commission-rate`
Update platform commission rate (admin only).

```clarity
(set-commission-rate new-rate)
```

#### `toggle-marketplace`
Enable/disable the entire marketplace (admin only).

```clarity
(toggle-marketplace)
```

#### `admin-disable-model`
Force disable a model (admin only).

```clarity
(admin-disable-model model-id)
```

#### `emergency-withdraw`
Emergency fund withdrawal (admin only).

```clarity
(emergency-withdraw amount)
```

## Economic Model

### Revenue Distribution

For each license purchase:
1. **Platform Commission**: 2.5% goes to contract owner
2. **Creator Payment**: 97.5% goes to model creator
3. **Transfer Fee**: 0.05 STX for license transfers

### Pricing Structure

- **Minimum License Fee**: 1,000 microSTX (0.001 STX)
- **Maximum Commission**: 10% (adjustable by admin)
- **Duration Limits**: 1 day to 1 year (144 to 52,560 blocks)

## Security Features

### Access Control
- Creator-only model management
- Admin-only platform settings
- License validation checks
- Transfer restrictions

### Validation
- Duplicate license prevention
- Expiration date enforcement
- Parameter bounds checking
- Payment amount verification

### Error Handling
- Comprehensive error constants
- Transaction rollback on failure
- Input validation at every step

## Usage Examples

### For Model Creators

```javascript
// Register a new AI model
const modelId = await contractCall({
  contractAddress: "ST1234...",
  contractName: "ai-marketplace",
  functionName: "register-model",
  functionArgs: [
    "GPT-Style Language Model",
    "High-performance text generation model trained on diverse datasets",
    500000, // 0.5 STX
    1440,   // 10 days
    "v1.0",
    "abc123def456...", // file hash
    1024000, // 1MB
    9500     // 95% accuracy
  ]
});
```

### For License Buyers

```javascript
// Purchase a license
const expirationBlock = await contractCall({
  contractAddress: "ST1234...",
  contractName: "ai-marketplace",
  functionName: "buy-license",
  functionArgs: [1] // model-id
});

// Check license validity
const isValid = await contractCall({
  contractAddress: "ST1234...",
  contractName: "ai-marketplace",
  functionName: "check-license-valid",
  functionArgs: [1, userAddress]
});
```

## Testing

The contract includes comprehensive test coverage for:
- Model registration and management
- License purchasing and validation
- Revenue distribution
- Access control
- Edge cases and error conditions

Run tests with:
```bash
clarinet test
```