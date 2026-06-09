# Lab 5: Test With an Agent Client

## Introduction

You will run a provided Node.js client that behaves like an AI agent. It calls the paid API, receives a 402 challenge, signs a payment authorization with a Base Sepolia wallet, retries the request, and prints the paid SH sales data.

### Objectives

- Prepare a testnet wallet for the x402 payment.
- Generate the Node.js agent client from workshop assets.
- Pay for one SH sales query through API Gateway.
- Inspect the payment response and returned data.

Estimated Time: 10 minutes

## Task 1: Prepare a Testnet Wallet

1. Use a dedicated testnet wallet. Do not use a wallet that holds real funds.
2. Add ETH on Base Sepolia from a Base faucet.
3. Add test USDC on Base Sepolia from the Circle faucet.
4. Confirm the wallet has:

    - A small ETH balance for gas.
    - At least 1 test USDC.

5. Keep the private key available in Cloud Shell only for this testnet lab.

## Task 2: Generate the Client Project

1. In Cloud Shell, return to the workshop directory:

    ```
    <copy>
    cd ~/x402-workshop
    source workshop.env
    source workshop-outputs.env
    </copy>
    ```

2. Download and run the client helper:

    ```
    <copy>
    curl -fsSLO "$WORKSHOP_FILES_BASE/05-test-agent-client/files/create-agent-client.sh"
    chmod +x create-agent-client.sh
    ./create-agent-client.sh
    </copy>
    ```

3. The helper creates `x402-client`, downloads `client.js` and `package.json`, installs dependencies, and creates `run-client.sh`.

## Task 3: Run the Paid Query

1. Run the client with your testnet private key:

    ```
    <copy>
    cd ~/x402-workshop/x402-client
    PRIVATE_KEY="0xYOUR_TESTNET_PRIVATE_KEY" ./run-client.sh
    </copy>
    ```

2. Confirm the output shows:

    - The server payment requirement.
    - `Paid status: 200`.
    - The number of returned SH sales rows.
    - A settlement response or transaction value from the facilitator.

The client saved the payment signature in `.last-payment-signature`. You will use that file in Lab 6 to test idempotent replay.

## Task 4: Review the Agent Flow

1. Open the client:

    ```
    <copy>
    sed -n '1,180p' client.js
    </copy>
    ```

2. Notice the four agent actions:

    - Call the API without payment.
    - Decode the `PAYMENT-REQUIRED` header.
    - Sign an EIP-712 transfer authorization.
    - Retry with `PAYMENT-SIGNATURE`.

## Learn more

- [x402 quickstart for buyers](https://docs.x402.org/getting-started/quickstart-for-buyers)
- [x402 HTTP 402 documentation](https://docs.x402.org/core-concepts/http-402)
- [x402 networks and token support](https://docs.x402.org/core-concepts/network-and-token-support)
- [Viem signTypedData documentation](https://viem.sh/docs/actions/wallet/signTypedData)
- [Base network faucets](https://docs.base.org/base-chain/network-information/network-faucets)
- [Circle testnet faucet](https://faucet.circle.com/)
- [Coinbase Developer Platform faucet API](https://docs.cdp.coinbase.com/api-reference/v2/rest-api/faucets/request-funds-on-evm-test-networks)

## Acknowledgements

- **Author** - Nicholas Cusato, Senior Cloud Engineer
- **Last Updated** - June 2026
- **References** - x402 specification, Coinbase x402 documentation, OCI API Gateway documentation, OCI Functions documentation, ORDS AutoREST documentation
