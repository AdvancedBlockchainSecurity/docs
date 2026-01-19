# x402 Pay-Per-Scan Credits

**Last Updated**: January 19, 2026

## Overview

BlockSecOps offers x402 pay-per-scan credits as a unique, crypto-native payment option. This allows users to pay with USDC on Base mainnet without committing to a subscription.

**No other competitor in the web3 security market offers this.**

---

## What is x402?

x402 is a crypto-native payment protocol that enables:
- Instant USDC payments on Base mainnet
- No subscription commitment required
- Pay only for what you use
- Wallet-based authentication

---

## Credit Packages

| Package | Credits | Price (USDC) | Per-Scan Cost | Savings |
|---------|---------|--------------|---------------|---------|
| **Starter** | 10 | $30 | $3.00 | - |
| **Builder** | 50 | $125 | $2.50 | 17% |
| **Pro** | 200 | $400 | $2.00 | 33% |
| **Bulk** | 1,000 | $1,500 | $1.50 | 50% |

**Pricing logic**: Team subscription is $299/month for 15 contracts (~$20/contract). x402 credits offer flexibility for occasional users without subscription commitment. For regular scanning, subscriptions provide better value.

---

## How It Works

### 1. Connect Wallet
Connect your wallet (MetaMask, WalletConnect, Coinbase Wallet) to the BlockSecOps dashboard.

### 2. Purchase Credits
Navigate to `/billing` or `/pricing` and select a credit package. Pay with USDC on Base mainnet.

### 3. Use Credits
Each scan deducts 1 credit from your balance. Credits never expire.

### 4. Monitor Balance
View your credit balance on the dashboard. Get notified when running low.

---

## What Counts as a Scan?

One credit = One scan job, which includes:
- Running all selected scanners on your contract/project
- Generating unified results
- Deduplication processing
- Risk scoring

**Note**: Re-scanning the same contract counts as a new scan.

---

## Use Cases

### Occasional Users
- Developers who scan infrequently
- Freelancers working on client projects
- Students and learners

### Supplement Subscription
- Burst usage beyond subscription limits
- One-off projects outside normal workflow
- Testing before committing to subscription

### Crypto-Native Preference
- Users who prefer USDC over fiat
- DAOs and on-chain treasuries
- Anonymous/pseudonymous users

---

## Comparison: Credits vs Subscription

| Aspect | x402 Credits | Subscription |
|--------|--------------|--------------|
| Commitment | None | Monthly/Annual |
| Cost per scan | $1.50-$3.00 | ~$20/contract* |
| Best for | Occasional use | Regular use |
| Payment method | USDC on Base | Credit card, ACH |
| Features | All 25+ scanners | All features + 95% FP reduction |

*Based on Team tier ($299/month for 15 contracts)

**Recommendation**:
- Occasional scanning (< 10 contracts/month) → x402 credits for flexibility
- Regular scanning (10+ contracts/month) → Team subscription ($299/mo) is better value
- Need private repos + FP filtering → Team subscription required

---

## Credit Balance Management

### Checking Balance
- Dashboard: Top-right shows current balance
- API: `GET /api/v1/payments/credits`
- Billing page: Full transaction history

### Low Balance Alerts
- Email notification at 10 credits remaining
- Dashboard warning at 5 credits remaining
- Scan blocked at 0 credits with prompt to purchase

### No Expiration
Credits never expire. Purchase once, use whenever.

---

## Technical Details

### Network
- **Chain**: Base Mainnet (Chain ID: 8453)
- **Token**: USDC (0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913)

### Transaction Flow
1. User initiates purchase on dashboard
2. Wallet prompts USDC approval + transfer
3. Backend verifies on-chain transaction
4. Credits added to user account
5. Confirmation displayed

### API Endpoints

```
GET  /api/v1/payments/credits      # Get current balance
GET  /api/v1/payments/packages     # List credit packages
POST /api/v1/payments/initiate     # Start purchase flow
POST /api/v1/payments/credits/use  # Deduct credit for scan
```

---

## Why x402 Credits?

### For BlockSecOps
- Reduced payment processing fees
- Crypto-native brand alignment
- Lower barrier to entry
- Competitive differentiation

### For Users
- No subscription lock-in
- Privacy-preserving payments
- DAO treasury compatibility
- Instant settlement

---

## FAQ

**Q: Can I combine credits with a subscription?**
A: Yes. Subscription scans are used first; credits are backup.

**Q: What happens if a scan fails?**
A: Credits are only deducted for successful scans.

**Q: Can I get a refund on credits?**
A: Credits are non-refundable but never expire.

**Q: Which wallets are supported?**
A: MetaMask, WalletConnect, Coinbase Wallet, and any EIP-1193 compatible wallet.

**Q: Is there a minimum purchase?**
A: The Starter package (10 credits, $30) is the minimum.

**Q: Can I use credits on testnet?**
A: Free tier includes testnet scans. Credits are for mainnet features.
