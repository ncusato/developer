# Lab 8: Troubleshooting and Next Steps

## Introduction

Use this lab to diagnose common issues and decide how to take the x402 gateway pattern further. The items here should also guide the final publish review before the workshop moves into an official LiveLabs catalog entry.

### Objectives

- Diagnose common x402, gateway, ORDS, and wallet issues.
- Identify production hardening work before mainnet use.
- Choose practical extensions for monetized Oracle data APIs.

Estimated Time: 10 minutes

## Task 1: Troubleshoot common issues

1. Match the symptom you see to the likely fix below.

    **Gateway returns 502 instead of 402:** Confirm your function has the correct IAM policy so API Gateway can invoke it. Check the Functions logs in the OCI Console.

    **Facilitator verification fails:** The public testnet facilitator can be intermittent. Try the CDP facilitator endpoint or stand up your own using the open-source `x402-facilitator` reference implementation.

    **Wallet has no USDC despite faucet:** Base Sepolia USDC uses a specific contract address. Make sure your wallet uses Base Sepolia (chain ID 84532), not Ethereum Sepolia.

    **Function cold starts feel slow:** Increase the function memory to 512MB and consider provisioned concurrency in production.

    **ORDS returns 401 from the middleware:** Token may have expired without the cache realizing it. Verify the OAuth client has the right privileges and that the `expires_in` math in `getOrdsToken()` accounts for clock skew.

## Task 2: Choose next steps

1. Review these extension paths before moving from a testnet workshop to a production design.

    - **More schemas:** Repeat the AutoREST pattern on SSB, OE, or your own schemas.
    - **Custom REST modules:** ORDS supports hand-crafted REST modules with SQL/PLSQL handlers behind the same x402 gate.
    - **Tiered pricing:** Implement the experimental x402 `upto` scheme to charge based on row count.
    - **MCP integration:** Wrap this as an MCP server. Agents discover the database tools, x402 pays for the queries, ORDS serves the data.
    - **Mainnet:** Swap `NETWORK` to `eip155:8453` (Base mainnet) and use the mainnet USDC contract. Coordinate with finance and compliance.

## Learn More

- [OCI API Gateway documentation](https://docs.oracle.com/en-us/iaas/Content/APIGateway/home.htm)
- [OCI Functions documentation](https://docs.oracle.com/en-us/iaas/Content/Functions/home.htm)
- [ORDS AutoREST documentation](https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/)

## Acknowledgements

- **Author** - Nicholas Cusato, Senior Cloud Engineer
- **Last Updated** - June 2026
- **References** - x402 specification, Coinbase x402 documentation, OCI API Gateway documentation, OCI Functions documentation, ORDS AutoREST documentation
