# Digital Identity Management System

A comprehensive blockchain-based identity management system built on Stacks using Clarity smart contracts.

## Overview

This system provides secure, decentralized identity management through five interconnected smart contracts:

1. **Identity Verification Contract** - Validates personal identity documents
2. **Credential Storage Contract** - Securely stores identity information
3. **Access Permission Contract** - Controls identity data sharing
4. **Biometric Authentication Contract** - Manages fingerprint and facial recognition
5. **Identity Recovery Contract** - Handles lost or stolen identity restoration

## Architecture

### Core Components

- \`identity-verification.clar\` - Document validation and verification status
- \`credential-storage.clar\` - Encrypted credential storage with access controls
- \`access-permission.clar\` - Granular permission management for data sharing
- \`biometric-auth.clar\` - Biometric data hashing and authentication
- \`identity-recovery.clar\` - Multi-signature recovery mechanisms

### Key Features

- **Decentralized Verification**: No single point of failure for identity validation
- **Privacy-First**: Encrypted storage with user-controlled access permissions
- **Biometric Security**: Secure biometric authentication without storing raw data
- **Recovery Mechanisms**: Multi-signature recovery for lost or compromised identities
- **Granular Permissions**: Fine-grained control over data sharing

## Data Flow

1. Users submit identity documents for verification
2. Verified credentials are encrypted and stored
3. Access permissions are configured for data sharing
4. Biometric authentication provides additional security layer
5. Recovery mechanisms ensure account restoration capabilities

## Security Features

- Hash-based biometric storage (no raw biometric data)
- Multi-signature recovery requirements
- Time-locked operations for sensitive actions
- Encrypted credential storage
- Audit trails for all access attempts

## Getting Started

### Prerequisites

- Clarinet CLI installed
- Node.js and npm
- Stacks wallet for testing

### Installation

\`\`\`bash
npm install
clarinet check
\`\`\`

### Testing

\`\`\`bash
npm test
\`\`\`

### Deployment

\`\`\`bash
clarinet deploy --testnet
\`\`\`

## Contract Interactions

### Identity Verification
- \`submit-document\` - Submit identity document for verification
- \`verify-document\` - Verify submitted document (admin only)
- \`get-verification-status\` - Check verification status

### Credential Storage
- \`store-credential\` - Store encrypted credential data
- \`update-credential\` - Update existing credential
- \`get-credential\` - Retrieve credential (with permissions)

### Access Permissions
- \`grant-access\` - Grant access to specific data
- \`revoke-access\` - Revoke previously granted access
- \`check-permission\` - Verify access permissions

### Biometric Authentication
- \`register-biometric\` - Register biometric hash
- \`authenticate\` - Authenticate using biometric data
- \`update-biometric\` - Update biometric information

### Identity Recovery
- \`initiate-recovery\` - Start identity recovery process
- \`approve-recovery\` - Approve recovery (guardian)
- \`complete-recovery\` - Complete recovery process

## Error Codes

- \`ERR-NOT-AUTHORIZED\` (u100) - Insufficient permissions
- \`ERR-INVALID-INPUT\` (u101) - Invalid input parameters
- \`ERR-NOT-FOUND\` (u102) - Resource not found
- \`ERR-ALREADY-EXISTS\` (u103) - Resource already exists
- \`ERR-VERIFICATION-FAILED\` (u104) - Verification process failed
- \`ERR-RECOVERY-PENDING\` (u105) - Recovery process in progress
- \`ERR-INSUFFICIENT-GUARDIANS\` (u106) - Not enough guardian approvals

## License

MIT License - see LICENSE file for details
