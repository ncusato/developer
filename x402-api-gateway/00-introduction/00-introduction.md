# Introduction

## Introduction

In this workshop, you will build a production-ready x402 payment gateway on Oracle Cloud Infrastructure that monetizes a real database API. You will take the **SH (Sales History)** sample schema that ships pre-loaded in every Autonomous Database, expose it as REST endpoints using ORDS AutoREST, and put it behind an x402 payment gate. The core path uses Oracle Cloud Shell helper assets so you can focus on the architecture, payment flow, and verification checkpoints.

x402 is an open, HTTP-native payment standard that enables APIs to charge for access per-request, without API keys, subscriptions, or account creation. Settlement happens directly on blockchain using stablecoins.

The economic reason for this pattern is changing fast. "Dead internet theory" is often used as shorthand for a web where more activity feels automated than human. Treat that as a warning signal, not a literal claim: the measurable part is bot pressure. In June 2026, Cloudflare Radar and Cloudflare CEO Matthew Prince reported that automated HTTP requests had crossed human requests for the first time, at roughly 57.4%-57.5% bot requests versus 42.5%-42.6% human requests. Prince said the shift arrived sooner than expected because agentic AI traffic grew quickly.

When AI agents scrape, summarize, or repackage data instead of sending humans to pages, traditional ad targeting and referral models lose power. This workshop shows a different path: expose valuable data through APIs, require payment at the HTTP layer, and let agents pay for access instead of extracting value for free.

By the end of this workshop, you will have:
- A REST API auto-generated from the SH schema using ORDS AutoREST
- An x402 payment gateway deployed on OCI API Gateway that protects the API
- An OCI Function backend that returns the 402 challenge, validates payment signatures, settles transactions, and fetches the paid ORDS response
- A Cloud Shell agent client that pays per query
- Idempotency and receipt tracking inside the same Autonomous Database
- (Optional) OCI Generative AI summarization that turns raw rows into agent-ready insights

This pattern - database table -> REST endpoint -> monetized x402 API -> AI-polished response - is the fastest path from "I have data" to "agents pay me for answers."

Estimated Time: 60 minutes (80 with optional Gen AI lab)

### Objectives

- Enable ORDS AutoREST on the pre-loaded SH (Sales History) schema in ADB
- Generate REST endpoints for SH tables and views without writing code
- Provision OCI API Gateway and Functions with Cloud Shell automation
- Deploy x402 middleware as an OCI Function from provided helper assets
- Wire the gateway to charge per database query
- Test end-to-end with a Node.js agent client
- Persist payment receipts in the same ADB instance
- Optionally enrich responses with OCI Generative AI

### Prerequisites

- An Oracle Cloud Account (Free Tier eligible)
- Basic familiarity with REST APIs, HTTP status codes, and SQL
- Oracle Cloud Shell access
- A Base Sepolia test wallet with test ETH and test USDC

## Architecture

![Architecture diagram showing API Gateway, x402 middleware, ORDS AutoREST, Autonomous Database, optional OCI Generative AI, and external x402 settlement services](images/x402-oci-lab-architecture.png)

The request path starts with an AI agent or Node.js client calling OCI API Gateway. API Gateway invokes the x402 middleware function. The function returns the 402 challenge, verifies and settles the payment, writes receipts to Autonomous Database, fetches ORDS AutoREST data from the SH schema, and can optionally call OCI Generative AI before returning the paid response.

## Labs

1. **Lab 1:** Provision OCI Infrastructure (10 minutes)
2. **Lab 2:** Enable ORDS AutoREST on the SH Schema (8 minutes)
3. **Lab 3:** Deploy x402 Middleware as an OCI Function (15 minutes)
4. **Lab 4:** Integrate x402 with API Gateway and the SH REST API (7 minutes)
5. **Lab 5:** Test With an Agent Client (10 minutes)
6. **Lab 6:** Verify Idempotency and Payment Receipts (5 minutes)
7. **Lab 7 (Optional):** Polish Responses With OCI Generative AI (20 minutes)
8. **Lab 8:** Troubleshooting and Next Steps (5 minutes)

---

## Learn more

- [Cloudflare Radar: Bot Traffic Worldwide](https://radar.cloudflare.com/bots)
- [Cloudflare Blog: Moving past bots vs. humans](https://blog.cloudflare.com/past-bots-and-humans/)
- [Tom's Hardware: Cloudflare bot traffic report, June 2026](https://www.tomshardware.com/tech-industry/artificial-intelligence/bots-have-now-passed-human-traffic-online-cloudflare-boss-laments-says-agentic-traffic-wasnt-expected-to-eclipse-real-people-until-next-year)
- [x402 documentation](https://docs.x402.org/)
- [x402 facilitator documentation](https://docs.x402.org/core-concepts/facilitator)
- [Oracle Autonomous Database documentation](https://docs.oracle.com/en/cloud/paas/autonomous-database/index.html)
- [Oracle REST Data Services documentation](https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/)
- [OCI API Gateway documentation](https://docs.oracle.com/en-us/iaas/Content/APIGateway/)
- [OCI Functions documentation](https://docs.oracle.com/en-us/iaas/Content/Functions/)

## Acknowledgements

- **Author** - Nicholas Cusato, Senior Cloud Engineer
- **Last Updated** - June 2026
- **References** - x402 specification, Coinbase x402 documentation, OCI API Gateway documentation, OCI Functions documentation, ORDS AutoREST documentation
