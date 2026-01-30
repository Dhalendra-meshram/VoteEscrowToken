# VeToken — Vote-Escrowed Governance Token

## Overview

This project implements a **vote-escrowed token (veToken)** system inspired by governance models used in protocols like **Curve**.  
Instead of using simple token balances for voting, users must **lock their tokens for a fixed time period**.  
Their voting power is proportional to both the **amount locked** and the **remaining lock duration**.

Voting power **decays linearly over time**, encouraging long-term commitment and preventing short-term governance manipulation.

---

## Why Vote-Escrowed Tokens?

Traditional token-based governance suffers from several issues:

- Flash-loan governance attacks  
- Short-term speculation influencing long-term decisions  
- Low-cost governance capture  
- Lack of long-term alignment  

This system solves those problems by:

- Making voting power **time-weighted**
- Requiring **long-term token commitment**
- Introducing **linear decay** of voting power
- Making manipulation **economically expensive**

---

## Core Concepts

| Concept | Description |
|------|------------|
| Lock | Tokens are locked until a user-defined unlock timestamp |
| Bias | Initial voting power when lock is created |
| Slope | Rate at which voting power decays |
| Decay | Voting power decreases linearly over time |
| Checkpointing | System stores historical power snapshots |
| Epochs | Used for efficient historical queries |

---

## Architecture

Each user lock is represented as a linear function:


voting_power(t) = max(bias - slope × t, 0)


Where:

bias = initial voting power

slope = rate of decay

t = time

The system tracks:

Per-user history → individual voting power

Global history → total system voting power

Scheduled slope changes → future decay

This design allows efficient queries without iterating over all users, keeping gas costs predictable.

---

## Features

Time-locked voting power

Linear decay of voting power

Historical balance queries

Global supply tracking

Weekly time rounding

Slope scheduling for gas efficiency

Governance-focused design

Flash-loan resistant

---

## Security Design

This contract was designed with governance security as a primary goal.

Threats Considered

| Threat                        | Mitigation                              |
| ----------------------------- | --------------------------------------- |
| Flash-loan governance attacks | Time-locking prevents instant voting    |
| Short-term manipulation       | Voting power decays gradually over time |
| Timestamp manipulation        | Weekly rounding limits precision abuse  |
| Supply recomputation attacks  | Checkpointing avoids full iteration     |
| Griefing via micro-locks      | Aggregated slope logic prevents spam    |

---

## Why Linear Decay?

Linear decay creates predictable and fair governance behavior:

Earlier lock → more influence

Longer lock → more influence

Voting power always trends toward zero

No sudden cliffs or discontinuities

This results in smoother governance dynamics and long-term alignment.

---

## Gas Optimization

This contract is optimized for long-term gas efficiency:

Uses slope scheduling instead of loops

Avoids iterating over all users

Uses checkpoint-based history

Compiled with Solidity optimizer + IR mode

Optimized for frequent read operations

---

## Tech Stack

Solidity

Foundry (Forge, Cast, Anvil)

Optimizer + IR compilation

Modular storage design

---

### Build

```shell
$ forge build

```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

## Author

Dhalendra Meshram
Smart Contract Developer
Solidity • DeFi • Governance Systems