# Lab 5: Test With an Agent Client

## Introduction

You will build a Node.js client that simulates an AI agent: it makes a request, receives a 402, signs a payment payload with a testnet wallet, and retries. This is the canonical x402 client flow.

### Objectives

- Create a Node.js client that can handle an x402 payment challenge.
- Fund a Base Sepolia testnet wallet.
- Sign an EIP-712 payment authorization.
- Retry the paid request and inspect the returned SH sales data.

Estimated Time: 15 minutes

## Task 1: Set Up the Client Project


1. Follow the instructions below to complete this task.

        ```bash
        mkdir x402-client && cd x402-client
        npm init -y
        npm install axios viem
        ```

## Task 2: Fund a Testnet Wallet

1. Generate a new test wallet or use an existing testnet wallet. Save the private key safely (testnet only - never use real funds).
2. Get test ETH from a Base Sepolia faucet (e.g., [coinbase.com/faucets/base-sepolia-faucet](https://www.coinbase.com/faucets/base-sepolia-faucet)).
3. Get test USDC on Base Sepolia from [faucet.circle.com](https://faucet.circle.com).
4. Confirm your wallet has at least 1 USDC and some ETH for gas.

## Task 3: Write the Client


1. Follow the instructions below to complete this task.

    Create `client.js`:

        ```javascript
        const axios = require('axios');
        const crypto = require('crypto');
        const { createWalletClient, http } = require('viem');
        const { privateKeyToAccount } = require('viem/accounts');
        const { baseSepolia } = require('viem/chains');

        const GATEWAY_URL = process.env.GATEWAY_URL;
        const PRIVATE_KEY = process.env.PRIVATE_KEY;

        const account = privateKeyToAccount(PRIVATE_KEY);
        const walletClient = createWalletClient({
          account, chain: baseSepolia, transport: http()
        });

        async function callPaidEndpoint() {
          const filter = encodeURIComponent(JSON.stringify({ amount_sold: { $gt: 1000 } }));
          const targetUrl = `${GATEWAY_URL}/sh/sales/?q=${filter}&limit=10`;

          // Step 1: GET -> 402
          let initial = await axios.get(targetUrl, { validateStatus: () => true });
          if (initial.status !== 402) {
            console.log('Unexpected status:', initial.status);
            return;
          }

          // Step 2: Parse PAYMENT-REQUIRED
          const requirementsB64 = initial.headers['payment-required'];
          const requirements = JSON.parse(Buffer.from(requirementsB64, 'base64').toString());
          const selected = requirements.accepts[0];
          console.log(`Server requires ${selected.maxAmountRequired} of ${selected.asset} on ${selected.network}`);

          // Step 3: Sign EIP-712 transferWithAuthorization
          const nonce = '0x' + crypto.randomBytes(32).toString('hex');
          const validAfter = 0;
          const validBefore = Math.floor(Date.now() / 1000) + 60;

          const domain = {
            name: selected.extra?.name || 'USDC',
            version: selected.extra?.version || '2',
            chainId: Number(selected.network.replace('eip155:', '')),
            verifyingContract: selected.asset
          };

          const types = {
            TransferWithAuthorization: [
              { name: 'from', type: 'address' },
              { name: 'to', type: 'address' },
              { name: 'value', type: 'uint256' },
              { name: 'validAfter', type: 'uint256' },
              { name: 'validBefore', type: 'uint256' },
              { name: 'nonce', type: 'bytes32' }
            ]
          };

          const message = {
            from: account.address,
            to: selected.payTo,
            value: selected.maxAmountRequired,
            validAfter,
            validBefore,
            nonce
          };

          const signature = await walletClient.signTypedData({
            domain, types, primaryType: 'TransferWithAuthorization', message
          });

          const payload = {
            x402Version: 2,
            scheme: 'exact',
            network: selected.network,
            payload: { signature, authorization: message }
          };
          const paymentSignatureHeader = Buffer.from(JSON.stringify(payload)).toString('base64');

          // Step 4: Retry with payment
          const paid = await axios.get(targetUrl, {
            headers: { 'PAYMENT-SIGNATURE': paymentSignatureHeader },
            validateStatus: () => true
          });

          console.log('Status:', paid.status);
          console.log(`Got ${paid.data.items?.length || 0} rows`);
          if (paid.data.items?.[0]) {
            console.log(`First sale: $${paid.data.items[0].amount_sold} on time_id ${paid.data.items[0].time_id}`);
          }
          if (paid.headers['payment-response']) {
            const settlement = JSON.parse(Buffer.from(paid.headers['payment-response'], 'base64').toString());
            console.log('Settlement tx:', settlement.transaction);
          }
        }

        callPaidEndpoint().catch(console.error);
        ```

## Task 4: Run the Client


1. Follow the instructions below to complete this task.

        ```bash
        export GATEWAY_URL="https://YOUR-GATEWAY-URL/v1"
        export PRIVATE_KEY="0xYOUR_TESTNET_PRIVATE_KEY"
        node client.js
        ```

    You should see the initial 402, then a successful response with real SH sales data and an on-chain transaction hash. An AI agent just paid $0.01 in USDC to query an Oracle database.

## Acknowledgements

- **Author** - Nicholas Cusato, Senior Cloud Engineer
- **Last Updated** - June 2026
- **References** - x402 specification, Coinbase x402 documentation, OCI API Gateway documentation, OCI Functions documentation, ORDS AutoREST documentation
