# Obra: Decentralized Labor Markets

## Overview

Obra is a decentralized labor market protocol designed to facilitate connections between task providers—individuals or entities outsourcing work—and service providers—those offering skills or labor—in a trustless, efficient, and scalable manner. Built on Starknet, a Layer 2 scaling solution for Ethereum, Obra utilizes STARK proofs and the Cairo programming language to deliver low-cost, high-throughput transactions. This makes it suitable for diverse labor markets, ranging from gig work to software development and creative services.

The protocol comprises a Core Contract, which provides foundational infrastructure, and modular Market Contracts, which enable specialized workflows for specific use cases.

## Core Components

- **Core Contract**: The central infrastructure, managing task registration, user profiles, payment escrow, fee collection, and market integration. It ensures consistency and trust across the ecosystem.
- **Market Contracts**: User-deployed, modular contracts that integrate with the Core Contract to customize completion workflows and optionally handle disputes for specific market types.

## Setup and Usage

### Dependencies
The project relies on the following:
- `starknet`: Version ^2.10.1, for Starknet-specific functionality.
- `openzeppelin`: Sourced from `https://github.com/OpenZeppelin/cairo-contracts.git`, providing reusable contract components.
- `snforge_std`: Version ~0.38.0, for development and testing utilities.

### Installation
1. Clone the repository:
```
git clone https://github.com/elijahhampton/obra-protocol.git
cd conode_protocol
```


2. Install dependencies:
- Ensure `starknet` and `snforge_std` are available via scarb
- OpenZeppelin contracts are fetched from the specified Git repository during compilation.

### Building the Contract
- Compile the contract to Sierra format:
```
snforge build
```

- The output will be generated based on `src/lib.cairo`.

### Testing
- Run the test suite:
```
snforge test
```
- Generate a gas usage report:
```
snforge test --gas-report
```
