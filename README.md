# Decentralized Insurance Protocol — RiskShield

<p align="center">
  <img src="https://img.shields.io/badge/Solidity-0.8.24-black?style=for-the-badge&logo=solidity" />
  <img src="https://img.shields.io/badge/Foundry-Framework-orange?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Arbitrum-Sepolia-blue?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Chainlink-Oracles-375BD2?style=for-the-badge" />
  <img src="https://img.shields.io/badge/ERC4626-Vault-green?style=for-the-badge" />
  <img src="https://img.shields.io/badge/TheGraph-Indexed-purple?style=for-the-badge" />
</p>

---

# 📖 Overview

RiskShield is a production-grade decentralized insurance protocol deployed on **Arbitrum Sepolia**.

The protocol enables users to:

- Purchase decentralized insurance coverage against predefined risks.
- Stake liquidity as underwriters through an ERC-4626 vault.
- Earn premiums from active policies.
- Submit trustless claims validated using Chainlink oracles.
- Participate in DAO governance through ERC20Votes.

The system demonstrates modern smart contract architecture using:

- ERC-4626 vault standards
- UUPS upgradeability
- Chainlink oracle security
- OpenZeppelin governance
- Foundry fuzz/invariant testing
- The Graph indexing
- React + Wagmi frontend integration

---

# 🚀 Key Features

## 🛡 Insurance Policies

Users can purchase policies for multiple risk categories:

- DEPEG
- WEATHER
- LIQUIDATION

Policies are tokenized as NFTs and stored on-chain.

---

## 💰 ERC-4626 Underwriter Vault

Liquidity providers deposit stable tokens into the underwriting vault.

Features:

- ERC-4626 compliant
- Share-based accounting
- Yield distribution from premiums
- Withdrawable liquidity
- Standardized DeFi integration

---

## 🔮 Chainlink Oracle Validation

Claims are validated using Chainlink price feeds.

Security protections include:

- Heartbeat validation
- Staleness checks
- Oracle freshness validation
- Trustless trigger logic

---

## 🏛 DAO Governance

Governance uses OpenZeppelin Governor + Timelock.

Token holders can:

- Delegate voting power
- Vote on proposals
- Upgrade contracts
- Modify protocol parameters

---

## ⚡ Gas Optimization

The protocol uses:

- Custom errors
- Packed storage
- Inline Yul assembly
- Optimized loops
- Efficient calldata usage

---

## 🔄 Upgradeability

The system supports UUPS upgrades with governance control.

Features:

- Timelock controlled upgrades
- Transparent governance execution
- Secure proxy architecture

---

# 🏗 System Architecture

## Core Contracts

| Contract            | Description                  |
| ------------------- | ---------------------------- |
| InsurancePool.sol   | Core insurance engine        |
| InsuranceVault.sol  | ERC-4626 underwriting vault  |
| PolicyNFT.sol       | ERC-721 policy ownership     |
| GovernanceToken.sol | ERC20Votes governance token  |
| Oracle.sol          | Chainlink oracle integration |
| AMM.sol             | Risk token swaps/liquidity   |
| Governor.sol        | DAO governance               |
| Treasury.sol        | Treasury management          |

---

# ⚙ Protocol Flow

```text
User
  ↓
Buy Policy
  ↓
InsurancePool
  ↓
PolicyNFT Minted
  ↓
Premium Sent To Vault
  ↓
Underwriters Earn Yield

If Risk Event Happens:
  ↓
Oracle Validation
  ↓
Claim Approved
  ↓
Vault Liquidity Pays User
```

---

# 📦 Smart Contract Addresses (Arbitrum Sepolia)

## Deployment Metadata

```env
DEPLOYER=0xfc8506484B8b79349284b423aD8354f3f41b8f2b
```

---

## Core Protocol Contracts

```env
STABLE_TOKEN=0xAb71a7c9d52056925652d5C65607A91Fe5D7D750
GOVERNANCE_TOKEN=0xE702422e215AEc71Db454590cBAe7b9570A775C6
MOCK_AGGREGATOR=0xE37814bC21466Af2881B00F7150aC34bc62e4115
ORACLE=0x9Bd58302FC22B1801Ae2602C90B82320b8D16cbE
VAULT=0xD2B179a3a8206845de14f627009D02F17ae04cE8
POLICY_NFT=0x778aa3d56d284BdBA96350306D0B8a02BF9B9250
INSURANCE_POOL=0x1e485606B0806Ea72508119Af2B132dc8F26E2B0
AMM=0x9cF2362C438F8eE98746f68f03Ff54d514307c92
```

---

## Governance

```env
TIMELOCK=0x43683ad2312868720022d74b9C6E2FCfc57e463A
GOVERNOR=0xA5c868efEe2d45961B0eA069EC8a3fa5f15b8Abb
TREASURY_IMPLEMENTATION=0xF146023136a3E87Ac1FEFE501AD6edd02a86a7c1
TREASURY_PROXY=0x8D53317322B4b7559d82b5dbA36a2DB3Db52Ec81
```

---

## Utilities

```env
FACTORY=0x366a89cC4f309677A38D3CF4024390046Cc3e911
PREMIUM_MATH=0xC4bd40F4242FDBd8F6659177c774bd563fd462ED
```

---

# 🖥 Frontend Stack

The frontend was developed using:

- React
- Ethers.js v6
- Wagmi
- WalletConnect
- MetaMask
- Vite

---

# 🌐 Frontend Features

## Dashboard

Displays:

- Stable token balance
- Governance token balance
- Voting power
- Vault liquidity
- Total assets

---

## Insurance Interface

Users can:

- Select risk type
- Purchase policy
- Submit claims
- Monitor policy state

---

## Underwriter Vault

Users can:

- Deposit liquidity
- Earn premiums
- Withdraw funds
- Track vault shares

---

## AMM Interface

Features:

- Add liquidity
- Swap risk tokens
- View swap quotes

---

## Governance Interface

Users can:

- Vote on proposals
- Delegate governance power
- Monitor proposal states

---

# 🔗 Chainlink Oracle Integration

The protocol uses Chainlink feeds for secure risk validation.

Security checks include:

```solidity
if (block.timestamp - updatedAt > HEARTBEAT) {
    revert StalePrice();
}
```

The oracle ensures:

- Fresh data
- Manipulation resistance
- Trustless payouts

---

# 📊 The Graph Integration

The project uses a custom subgraph for decentralized indexing.

## Indexed Entities

| Entity            | Purpose                 |
| ----------------- | ----------------------- |
| Policy            | Tracks policy lifecycle |
| LiquidityPosition | Tracks vault deposits   |
| Swap              | Tracks AMM swaps        |
| RiskType          | Tracks risk statistics  |

---

## Example Query

```graphql
{
  policies(where: { active: true }, first: 10) {
    id
    policyholder
    riskType
    expiry
  }
}
```

---

# 🧪 Testing

Testing implemented with Foundry includes:

## Unit Tests

- Policy creation
- Premium calculation
- Claim validation
- Vault deposits
- Governance voting

---

## Fuzz Tests

Randomized testing for:

- Liquidity operations
- Claim edge cases
- Oracle boundaries
- Vault accounting

---

## Invariant Tests

Ensures:

- Solvency preservation
- Vault accounting correctness
- No liquidity corruption
- Share-price consistency

---

# 🔒 Security Features

## Access Control

Uses OpenZeppelin roles:

- ADMIN_ROLE
- GOVERNOR_ROLE
- ORACLE_ROLE

---

## Reentrancy Protection

Critical functions use:

```solidity
nonReentrant
```

---

## Custom Errors

Gas-efficient revert handling:

```solidity
error PolicyExpired();
error TriggerNotMet();
error NotPolicyOwner();
```

---

# ⚡ Gas Optimizations

Optimizations include:

- Storage packing
- Cached variables
- Inline assembly
- Custom errors
- Immutable variables

Example:

```solidity
assembly {
    result := add(x, y)
}
```

---

# 🏛 Governance System

Governance architecture:

```text
GovernanceToken
        ↓
Governor
        ↓
Timelock
        ↓
Upgradeable Contracts
```

Features:

- Proposal voting
- Delayed execution
- Decentralized upgrades
- Treasury control

---

# 📂 Project Structure

```text
contracts/
 ├── core/
 ├── governance/
 ├── interfaces/
 ├── libraries/
 ├── mocks/
 ├── oracle/
 └── vault/

frontend/
 ├── src/
 ├── components/
 ├── hooks/
 └── pages/

subgraph/
 ├── schema.graphql
 ├── mappings.ts
 └── subgraph.yaml

test/
 ├── unit/
 ├── fuzz/
 └── invariant/
```

---

# 🛠 Installation

## Clone Repository

```bash
git clone https://github.com/your-repo/riskshield.git
cd riskshield
```

---

## Install Dependencies

### Smart Contracts

```bash
forge install
```

### Frontend

```bash
cd frontend
npm install
```

---

# ▶ Running Frontend

```bash
npm run dev
```

Frontend will run on:

```text
http://localhost:5173
```

---

# 🔨 Build Frontend

```bash
npm run build
```

---

# 🧪 Run Tests

```bash
forge test -vvv
```

---

# 🚀 Deploy Contracts

```bash
forge script script/Deploy.s.sol \
--rpc-url $RPC_URL \
--private-key $PRIVATE_KEY \
--broadcast
```

---

# 🔍 Verify Contracts

```bash
forge verify-contract <ADDRESS> <CONTRACT_NAME>
```

---

# 📈 Future Improvements

Planned upgrades:

- Dynamic premium pricing
- Cross-chain insurance
- Real-world asset protection
- Multi-oracle consensus
- AI-based risk scoring
- Automated reinsurance markets

---

# 👥 Team Contributions

## Moldir — Core Smart Contracts

- Insurance logic
- State machine architecture
- Claim processing
- Access control implementation
- Governance integration

---

## Anel — Oracle + Vault + Testing

- Chainlink integration
- Heartbeat validation
- ERC-4626 vault system
- Fuzz testing
- Invariant testing

---

## Mansur — Frontend + Data + Docs

- React/Wagmi frontend
- Wallet integration
- Subgraph deployment
- Documentation
- Architecture diagrams

---

# 🎓 Academic Context

This project was developed as the final capstone project for:

```text
Blockchain Technologies 2
```

Topics integrated from the course:

- Solidity security
- ERC standards
- Oracle systems
- Upgradeable contracts
- DAO governance
- Layer 2 deployment
- Decentralized indexing
- Smart contract testing

---

# 📜 License

```text
MIT License
```

---

# 🙌 Acknowledgements

Special thanks to:

- OpenZeppelin
- Chainlink
- Arbitrum
- Foundry
- The Graph
- Ethereum Community

---

# 🌟 Conclusion

RiskShield demonstrates a modern decentralized insurance architecture combining:

- Secure smart contracts
- Oracle-based automation
- ERC-4626 vault mechanics
- DAO governance
- Advanced testing methodologies
- Layer 2 scalability

The protocol showcases how decentralized finance can provide transparent, automated, and trustless insurance infrastructure for the next generation of Web3 applications.
