# Decentralized Insurance Pool (Option E)

## Overview
This project implements a decentralized insurance protocol where users can buy insurance policies and underwriters provide liquidity to cover claims. The system uses Chainlink oracles to detect events and automatically trigger payouts.

## Features
- Buy insurance policies
- Stake collateral as an underwriter
- Automated claim payouts
- Chainlink oracle integration (with stale check)
- ERC-4626 vault for yield
- Role-based access control
- L2 deployment

## Architecture
- InsurancePool.sol — main contract (policies, staking, claims)
- Vault (ERC-4626) — manages underwriter funds
- Chainlink Oracle — triggers insured events
- Frontend (React) — user interaction
- Subgraph — data indexing

## User Flow
1. User buys insurance policy  
2. Underwriters stake funds  
3. Oracle monitors external condition  
4. If event occurs → payout is triggered  

## Team Responsibilities

### Moldir — Core Smart Contracts
- InsurancePool.sol  
- Policy logic (buy, stake, claim)  
- Payout mechanism  
- State management (active → triggered → paid)  
- AccessControl  

### Anel — Oracle + Vault + Testing
- Chainlink oracle integration  
- Trigger conditions and stale checks  
- ERC-4626 vault implementation  
- Smart contract testing (unit + revert tests)  
- Deployment scripts  

### Mansur — Frontend + Data + Docs
- React frontend  
- Wallet connection  
- UI for buy / stake / claim  
- Status display and error handling  
- Subgraph (The Graph)  
- README, diagrams, presentation  

## Testing
Run tests:
```bash
forge test -vv
