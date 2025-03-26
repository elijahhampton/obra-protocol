/**
 * Deployment script to setup a local development environment with markets, task and providers. Values
 * are based on the DEVNET_SEED.
 */

const { RpcProvider, Account, Contract, json, CairoCustomEnum, CallData } = require("starknet");
const fs = require("fs");
const exec = require("child_process").exec;
const { v4: uuidv4 } = require('uuid')
const { shortString, felt } = require('starknet')

const DEVNET_PORT = 5050;
const DEVNET_SEED = 2253143690;
const ETH_ADDRESS = "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7";
const PREDEPLOYED_ACCOUNT = "0x0343fc2ae5175a17fe413a09212282e1dd5bc05e58b2f258f4f3de827581247c";
const PRIVATE_KEY = "0x00000000000000000000000a713968afc767b35dd56887ea3e310f8";

const provider = new RpcProvider({ nodeUrl: `http://127.0.0.1:${DEVNET_PORT}` });

const account = new Account(provider, PREDEPLOYED_ACCOUNT, PRIVATE_KEY);

const payoutToken = "0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7";
const taskFeePercentage = 1;
const rewardPercentage = 1;
const coreCalldata = [
    payoutToken,
    taskFeePercentage.toString(),
    rewardPercentage.toString()
];


// For short strings (up to 31 chars)
function encodeStringToFelt(str) {
  return shortString.encodeShortString(str);
}

// For longer strings
function encodeLongString(str) {
  // Split the string into chunks and encode each chunk
  const chunks = [];
  for (let i = 0; i < str.length; i += 31) {
    const chunk = str.substring(i, i + 31);
    chunks.push(shortString.encodeShortString(chunk));
  }
  return chunks;
}

async function deployContracts() {
    try {
        // Load compiled contracts
        const compiledCoreSierra = json.parse(
            fs.readFileSync("../target/dev/conode_protocol_Core.contract_class.json").toString("ascii")
        );
        const compiledCoreCasm = json.parse(
            fs.readFileSync("../target/dev/conode_protocol_Core.compiled_contract_class.json").toString("ascii")
        );

        const compiledMarketSierra = json.parse(
            fs.readFileSync("../target/dev/conode_protocol_DefaultMarket.contract_class.json").toString("ascii")
        );
        const compiledMarketCasm = json.parse(
            fs.readFileSync("../target/dev/conode_protocol_DefaultMarket.compiled_contract_class.json").toString("ascii")
        );

        // Deploy Core contract
        const coreDeploy = await account.declareAndDeploy({
            contract: compiledCoreSierra,
            casm: compiledCoreCasm,
            constructorCalldata: coreCalldata
        });

        const coreAddress = coreDeploy.deploy.contract_address;
        const marketType = 0;
        const marketCalldata = [
            coreAddress,
            marketType.toString()
        ];

        // Deploy DefaultMarket contract
        const marketDeploy = await account.declareAndDeploy({
            contract: compiledMarketSierra,
            casm: compiledMarketCasm,
            constructorCalldata: marketCalldata
        });

        // Create contract instances
        const coreContract = new Contract(
            compiledCoreSierra.abi,
            coreDeploy.deploy.contract_address,
            account
        );

        const marketContract = new Contract(
            compiledMarketSierra.abi,
            marketDeploy.deploy.contract_address,
            provider
        );

        // Log deployment details
        console.log("Core Contract Class Hash =", coreDeploy.declare.class_hash);
        console.log("Core Contract deployed at =", coreContract.address);
        const deployedClassHash = await provider.getClassHashAt(coreDeploy.deploy.contract_address);
        console.log("Deployed Class Hash:", deployedClassHash);
        console.log("Market Contract Class Hash =", marketDeploy.declare.class_hash);
        console.log("Market Contract deployed at =", marketContract.address);

        // Register market
        const nonce = await account.getNonce();
        const marketAddress = marketContract.address;

        // Test with Basic (index 0)
        const myCustomEnumBasic = new CairoCustomEnum({ Basic: {} });
        const marketTitle = new CairoCustomEnum({ DString: shortString.encodeShortString("Default Market 1") });
        const marketMetadata = new CairoCustomEnum({ DString: shortString.encodeShortString("https://www.yahoo.com") });
        const metadataType = new CairoCustomEnum({ HTTP: {} });
        const marketState = new CairoCustomEnum({ Active: {} })
        const rawArgsBasic = {
            id: 0,
            title: marketTitle,
            metadata: marketMetadata,
            metadata_type: metadataType,
            state: marketState,
            m_type: myCustomEnumBasic,
            addr: marketAddress,
        };
        const calldataBasic = CallData.compile(rawArgsBasic);
        console.log("Calldata (Basic):", calldataBasic);

        try {
            const responseBasic = await coreContract.invoke(
                "register_market",
                calldataBasic,
                { nonce, version: "0x3" }
            );
            console.log("✅ Market registered (Basic), tx hash:", responseBasic.transaction_hash);
            await provider.waitForTransaction(responseBasic.transaction_hash);
            console.log("✅ Transaction confirmed (Basic)");
        } catch (error) {
            console.error("Failed with Basic:", error.message);
        }

        // const myCustomEnumRealTime = new CairoCustomEnum({ realTime: {} });
        // const rawArgsRealTime = {
        //     market: marketAddress,
        //     market_type: myCustomEnumRealTime
        // };
        // const calldataRealTime = CallData.compile(rawArgsRealTime);

        // const register_market_realtime_nonce = await account.getNonce();
        // const responseRealTime = await coreContract.invoke(
        //     "register_market",
        //     calldataRealTime,
        //     { nonce: register_market_realtime_nonce, version: "0x3" } 
        // );
        // console.log("✅ Market registered (RealTime), tx hash:", responseRealTime.transaction_hash);
        // await provider.waitForTransaction(responseRealTime.transaction_hash);
        // console.log("✅ Transaction confirmed (RealTime)");

        console.log('Returning registered markets...')
        const marketsResponse = await coreContract.call('get_all_markets', [])
        console.log(marketsResponse)

    } catch (error) {
        console.error("Deployment failed:", error);
    }
}

deployContracts();