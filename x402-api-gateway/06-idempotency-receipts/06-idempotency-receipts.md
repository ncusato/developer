# Lab 6: Verify Idempotency and Payment Receipts

## Introduction

The middleware already includes receipt storage and nonce checks. In this lab you will replay the last payment signature, confirm the API returns data without settling twice, and query the receipt table as a simple revenue dashboard.

### Objectives

- Replay a saved x402 payment signature.
- Confirm duplicate requests return data without duplicate settlement.
- Query receipt records in Autonomous Database.
- Understand how receipt data supports API revenue reporting.

Estimated Time: 5 minutes

## Task 1: Replay the Last Payment

1. In Cloud Shell, run the client in replay mode:

    ```
    <copy>
    cd ~/x402-workshop/x402-client
    PRIVATE_KEY="0xYOUR_TESTNET_PRIVATE_KEY" REPLAY_LAST_PAYMENT=true ./run-client.sh
    </copy>
    ```

2. Confirm the output shows:

    - `Replay status: 200`
    - Returned SH rows
    - A payment response with `replayed: true`, or the same transaction hash from the first run

3. If replay fails, confirm `.last-payment-signature` exists:

    ```
    <copy>
    ls -l .last-payment-signature
    </copy>
    ```

## Task 2: Query the Receipt Dashboard

1. In Database Actions SQL, sign in as `x402_app`.
2. Run:

    ```
    <copy>
    SELECT
      resource_path,
      COUNT(*)                         AS calls,
      COUNT(DISTINCT payer_address)    AS unique_payers,
      SUM(TO_NUMBER(amount)) / 1000000 AS total_usdc
    FROM x402_receipts
    WHERE status = 'settled'
    GROUP BY resource_path
    ORDER BY total_usdc DESC;
    </copy>
    ```

3. Confirm the dashboard shows at least one settled call for the `/sh/sales` path.

## Task 3: Review the Idempotency Pattern

1. Open the middleware receipt logic:

    ```
    <copy>
    cd ~/x402-workshop/x402-middleware
    grep -n "checkExistingReceipt\\|writeReceipt\\|replayed" func.js
    </copy>
    ```

2. The nonce is the payment identifier. If the same nonce appears again with a settled receipt, the middleware skips settlement and returns the resource again.

This protects clients from double charges during retries, network timeouts, or agent orchestration failures.

## Learn more

- [x402 Payment-Identifier idempotency extension](https://docs.x402.org/extensions/payment-identifier)
- [x402 signed offers and receipts](https://docs.x402.org/extensions/offer-receipt)
- [ORDS REST API: Create an OAuth client](https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/24.4/orrst/op-ords-rest-clients-post.html)
- [ORDS Developer's Guide: AutoREST](https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/24.4/orddg/developing-REST-applications.html)
- [Oracle Autonomous AI Database documentation](https://docs.oracle.com/en/cloud/paas/autonomous-database/index.html)

## Acknowledgements

- **Author** - Nicholas Cusato, Senior Cloud Engineer
- **Last Updated** - June 2026
- **References** - x402 specification, Coinbase x402 documentation, OCI API Gateway documentation, OCI Functions documentation, ORDS AutoREST documentation
