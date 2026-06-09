# Lab 8: Troubleshooting and Next Steps

## Introduction

Use this lab to diagnose common issues in the automated 60-minute path and decide how to take the x402 gateway pattern further.

### Objectives

- Diagnose common x402, gateway, ORDS, and wallet issues.
- Identify production hardening work before mainnet use.
- Choose practical extensions for monetized Oracle data APIs.

Estimated Time: 5 minutes

## Task 1: Troubleshoot Common Issues

1. Match the symptom you see to the likely fix below.

    **Bootstrap script fails on a missing variable:** Open `workshop.env`, fill in the placeholder value, and rerun the same script. The helpers are additive and reuse existing resources by display name where practical.

    **Autonomous Database creation returns `adb-free-count`:** Your tenancy already uses its Always Free Autonomous Database quota. Set `ADB_OCID` in `workshop.env` to reuse an existing Autonomous Database, remove an unused Free Tier database, or set `ADB_ALLOW_PAID_FALLBACK="true"` to create a billable fallback database.

    **Gateway returns 502 instead of 402:** Confirm the `x402-middleware` function exists and check the Functions logs in the OCI Console.

    **ORDS returns 404:** Confirm `UPSTREAM_BASE` ends in `/ords/market/` and that the `X402_REST` tables `MARKET_SIGNALS`, `API_PRODUCTS`, `BUYER_SEGMENTS`, and `PRICING_BENCHMARKS` are REST-enabled.

    **Facilitator verification fails:** Confirm the wallet has Base Sepolia test USDC, the `NETWORK` value is `eip155:84532`, and the `ASSET_ADDRESS` value matches the Base Sepolia USDC contract.

    **Receipt writes fail:** Confirm the ORDS OAuth client has the receipt privilege and that `ORDS_CLIENT_ID`, `ORDS_CLIENT_SECRET`, and `ORDS_RECEIPTS_URL` are set in `workshop.env`.

## Task 2: Choose Next Steps

1. Review these extension paths before moving from a testnet workshop to a production design.

    - **More data products:** Add industry-specific tables for security, travel, finance, healthcare, or retail media signals.
    - **Custom REST modules:** Use ORDS modules with SQL or PL/SQL handlers behind the same x402 gate.
    - **Tiered pricing:** Add pricing rules by endpoint, row count, or response enrichment.
    - **MCP integration:** Wrap this as an MCP server so agents discover tools and pay through x402.
    - **Mainnet:** Swap to Base mainnet and coordinate finance, compliance, observability, and key management.

## Learn more

- [x402 documentation](https://docs.x402.org/introduction)
- [x402 facilitators](https://docs.x402.org/dev-tools/facilitators)
- [x402 networks and token support](https://docs.x402.org/core-concepts/network-and-token-support)
- [OCI API Gateway troubleshooting and documentation](https://docs.oracle.com/en-us/iaas/Content/APIGateway/home.htm)
- [OCI Functions troubleshooting and documentation](https://docs.oracle.com/en-us/iaas/Content/Functions/home.htm)
- [ORDS Developer's Guide: Developing REST applications](https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/24.4/orddg/developing-REST-applications.html)
- [Base network faucets](https://docs.base.org/base-chain/network-information/network-faucets)
- [Circle testnet faucet](https://faucet.circle.com/)

## Acknowledgements

- **Author** - Nicholas Cusato, Senior Cloud Engineer
- **Last Updated** - June 2026
- **References** - x402 specification, Coinbase x402 documentation, OCI API Gateway documentation, OCI Functions documentation, ORDS AutoREST documentation
