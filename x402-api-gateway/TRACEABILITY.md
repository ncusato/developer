# Source Traceability and Publish Review Gaps

Estimated Time: Reference metadata

## Source

- Source markdown: `C:\Users\ncusato\Downloads\x402-oci-livelabs-workshop.md`
- Conversion mode: publish-ready structure
- Technical verification mode: source publish gaps preserved, not independently revalidated

## Generated Structure

| Source section | Generated file |
| --- | --- |
| About this Workshop, Objectives, Prerequisites, Architecture, Labs | `00-introduction/00-introduction.md` |
| Lab 1: Provision OCI Infrastructure | `01-provision-oci-infrastructure/01-provision-oci-infrastructure.md` |
| Lab 2: Create a Market Intelligence API with ORDS AutoREST | `02-enable-ords-autorest/02-enable-ords-autorest.md` |
| Lab 3: Deploy x402 Middleware as an OCI Function | `03-deploy-x402-middleware/03-deploy-x402-middleware.md` |
| Lab 4: Integrate x402 with API Gateway and the Market Intelligence API | `04-integrate-api-gateway/04-integrate-api-gateway.md` |
| Lab 5: Test With an Agent Client | `05-test-agent-client/05-test-agent-client.md` |
| Lab 6: Verify Idempotency and Payment Receipts | `06-idempotency-receipts/06-idempotency-receipts.md` |
| Lab 7: Polish Responses With OCI Generative AI | `07-oci-genai-responses/07-oci-genai-responses.md` |
| Lab 8: Troubleshooting and Next Steps | `08-troubleshooting-next-steps/08-troubleshooting-next-steps.md` |

## Publish Review Status

> Review ledger for the source draft gaps. Resolved items changed in the workshop content. Publish-time items still need live OCI or facilitator validation.

| Gap | Status | Resolution |
| --- | --- | --- |
| API Gateway authorizer-function pattern | Resolved | Lab 4 now uses API Gateway routes with **Oracle Functions** as the backend. The middleware returns the 402 challenge, verifies payment, settles, calls ORDS, and returns the paid body. |
| Function-to-function invocation | Resolved | Lab 7 no longer deploys a second summarizer function or references `invokeFunction()`. The middleware calls OCI Generative AI directly with resource principal authorization. |
| OCI Generative AI pricing and regional availability | Mitigated | Lab 7 now asks learners to confirm model availability and calculate on-demand cost from current pricing. Lab 7 also removes fixed "small fraction of a cent" language. |
| EIP-712 domain for USDC on Base Sepolia | Mitigated | Lab 3 now advertises `USDC_EIP712_NAME` and `USDC_EIP712_VERSION`. Lab 5 reads those values from the challenge. Defaults are `USDC` and `2`; publishers should still confirm live token metadata. |
| x402 spec version | Mitigated | The workshop keeps `x402Version: 2` and uses the current x402 facilitator verify/settle flow. Publishers should confirm v2 support before publication. |
| ORDS AutoREST query syntax | Resolved | Lab 2 now uses `curl --get --data-urlencode` plus a PowerShell `curl.exe` example for JSON filters. |
| Maintained SH schema REST enablement | Resolved | Lab 2 no longer unlocks, grants from, or REST-enables the maintained `SH` schema. It creates a workshop-owned `X402_REST` market intelligence dataset and maps ORDS to `/ords/market/`. |
| Sample schema row counts | Resolved | Lab 2 removed exact row-count claims and tells learners to use `USER_TABLES` output as the source of truth. |
| Network configuration | Resolved | Lab 1 now creates an explicit VCN, public API Gateway subnet, private Functions subnet, NAT gateway, and service gateway. |
| OAuth client setup for `x402_app` | Improved | Lab 3 now adds receipts privilege guidance before OAuth client creation. A production LiveLabs pass can add screenshots. |
| 60-minute core runtime | Implemented | Core labs now use Cloud Shell helper assets for provisioning, SQL setup, middleware generation, gateway routing, and client generation. The core path is 60 minutes, with GenAI optional. |
| OCI Generative AI `GenerateText` deprecation | Remaining SME review | Lab 7 still uses the source draft's `generateText` flow. Oracle docs flag this API path for deprecation, so publishers should migrate the optional lab to the current Chat API before official publication. |
| End-to-end smoke test | Remaining external validation | Run all labs, including optional GenAI, in a clean OCI tenancy before official publication. Local markdown validation cannot complete this step. |

## Verification Evidence

- OCI API Gateway documents **Oracle Functions** as a supported backend type for routes.
- OCI API Gateway authorizer functions return authorization decisions such as `active`, `scope`, and `expiresAt`.
- OCI Functions private access guidance calls for private subnets and a service gateway for private OCI service access.
- OCI Generative AI documentation lists service and model region availability separately from pricing.
- On-demand pricing uses prompt plus response character length.
- Circle lists the Base USDC testnet address that corresponds to the workshop default asset address.

## Remaining Publish Checklist

1. Run the core workshop in a clean OCI tenancy and record gateway, function, ORDS, OAuth, facilitator, and receipt-table outcomes.
2. Run Lab 7 in a region where the selected Generative AI model is available on demand.
3. Confirm the selected x402 facilitator endpoint supports `x402Version: 2`, Base Sepolia, the `exact` scheme, and the configured USDC asset.
4. Confirm the Base Sepolia USDC EIP-712 `name()` and `version()` values before final publication.
5. Add screenshots for the ORDS OAuth client and privilege screen if the official LiveLabs production pass requires screenshot-level guidance.
6. Review Lab 7 against current OCI Generative AI API guidance and migrate from `generateText` if required.

## Acknowledgements

- **Author** - Nicholas Cusato, Senior Cloud Engineer
- **Last Updated** - June 2026
- **References** - x402 specification, Coinbase x402 documentation, OCI API Gateway documentation, OCI Functions documentation, ORDS AutoREST documentation
