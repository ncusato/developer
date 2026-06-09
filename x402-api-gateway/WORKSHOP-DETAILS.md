# Workshop Details: Monetize Your APIs for the Agentic Web: Build an x402 Payment Gateway on OCI

Estimated Time: Reference metadata

## Short Description

Build an x402 payment gateway on Oracle Cloud Infrastructure that monetizes ORDS AutoREST endpoints over a realistic market intelligence dataset in a 60-minute Cloud Shell path.

## Long Description

This workshop shows how to turn database-backed REST endpoints into paid, per-request data products. Learners use Cloud Shell helpers to provision Autonomous Database, seed an agent market intelligence dataset in `X402_REST`, expose it through ORDS AutoREST, deploy an OCI Function that handles x402 payment challenges, connect it to OCI API Gateway, and test the paid flow with a Node.js agent client. They verify receipt storage for idempotency and can optionally enrich paid responses with OCI Generative AI summaries.

## Duration

- Core workshop: 60 minutes
- Optional OCI Generative AI lab: 20 minutes
- Full path: 80 minutes

## Audience

- Developers building REST APIs on OCI
- Data product teams exploring agent-facing monetization
- Architects evaluating payment-gated API patterns

## Prerequisites

- Oracle Cloud Account, Free Tier eligible
- Basic familiarity with REST APIs, HTTP status codes, and SQL
- Oracle Cloud Shell access
- Base Sepolia test wallet with test ETH and test USDC

## Workshop Outline

1. Lab 1: Provision OCI Infrastructure - 10 minutes
2. Lab 2: Create a Market Intelligence API with ORDS AutoREST - 8 minutes
3. Lab 3: Deploy x402 Middleware as an OCI Function - 15 minutes
4. Lab 4: Integrate x402 with API Gateway and the Market Intelligence API - 7 minutes
5. Lab 5: Test With an Agent Client - 10 minutes
6. Lab 6: Verify Idempotency and Payment Receipts - 5 minutes
7. Lab 7 (Optional): Polish Responses With OCI Generative AI - 20 minutes
8. Lab 8: Troubleshooting and Next Steps - 5 minutes

## Acknowledgements

- **Author** - Nicholas Cusato, Senior Cloud Engineer
- **Last Updated** - June 2026
- **References** - x402 specification, Coinbase x402 documentation, OCI API Gateway documentation, OCI Functions documentation, ORDS AutoREST documentation
