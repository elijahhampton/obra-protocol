#!/bin/bash

# =================================================================
# IMPORTANT: This script requires a contract_class.json file
# This file must be generated before running this script using:
#   scarb build
# 
# The contract_class.json file should be located in:
#   ./target/dev/conode_protocol_WorkCore.contract_class.json
# 
# After building, you need to copy or move this file to:
#   ./contract_class.json
#
# Commands to prepare:
#   scarb build
#   cp ./target/dev/conode_protocol_WorkCore.contract_class.json ./contract_class.json
# =====================

# Configuration (StarknetDevnet)
ACCOUNT_ADDRESS="0x34ba56f92265f0868c57d3fe72ecab144fc96f97954bbbc4252cef8e8a979ba"
PRIVATE_KEY="0x00000000000000000000000000000000b137668388dbe9acdfa3bc734cc2c469"
RPC_URL="http://localhost:5050"
COMPILER_VERSION="2.8.2"
DEVNET_PID=""

# Check for required commands
if ! command -v starknet-devnet &> /dev/null; then
    echo "Error: starknet-devnet not found. Install with: pip install starknet-devnet"
    exit 1
fi

if ! command -v starkli &> /dev/null; then
    echo "Error: starkli not found. Please install starkli first"
    exit 1
fi

# Start devnet
# echo "Starting Starknet devnet..."
# starknet-devnet --seed 1223945432 &
# DEVNET_PID=$!
# echo "Devnet started with PID: $DEVNET_PID"
# sleep 5

# Clean existing files
rm -rf ~/.starkli-wallets
rm -rf ~/.starknet_accounts

# Create directories
mkdir -p ~/.starkli-wallets/deployer

# Setup account
echo "Setting up account..."
starkli account fetch $ACCOUNT_ADDRESS \
    --output ~/.starkli-wallets/account.json \
    --rpc $RPC_URL

if [ $? -ne 0 ]; then
    echo "Failed to setup account"
    kill $DEVNET_PID
    exit 1
fi

# Declare contract
echo "Declaring contract..."
DECLARATION_OUTPUT=$(starkli declare ./contract_class.json \
    --compiler-version $COMPILER_VERSION \
    --private-key $PRIVATE_KEY \
    --account ~/.starkli-wallets/account.json \
    --rpc $RPC_URL)

if [ $? -ne 0 ]; then
    echo "Contract declaration failed"
    kill $DEVNET_PID
    exit 1
fi

echo "$DECLARATION_OUTPUT"

# Extract class hash
CLASS_HASH=$(echo "$DECLARATION_OUTPUT" | grep -o '0x[0-9a-fA-F]\+' | head -1)

# Deploy contract
echo "Deploying contract with class hash: $CLASS_HASH"
DEPLOY_OUTPUT=$(starkli deploy $CLASS_HASH \
    --private-key $PRIVATE_KEY \
    --account ~/.starkli-wallets/account.json \
    --rpc $RPC_URL \
    "0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7")

if [ $? -ne 0 ]; then
    echo "Contract deployment failed"
    kill $DEVNET_PID
    exit 1
fi

echo "$DEPLOY_OUTPUT"
echo "Deployment completed successfully!"

# Cleanup
kill $DEVNET_PID
wait $DEVNET_PID 2>/dev/null