# Lab 6: Add Idempotency and Payment Receipts

## Introduction

The receipts table from Lab 3 is already in place. In this lab you will update the middleware to check it before settling (preventing double-charges on client retries) and persist a record after every successful settlement.

### Objectives

- Add ORDS OAuth token handling for receipt writes.
- Check existing receipt nonces before settlement.
- Persist successful settlement receipts.
- Query receipt data as a revenue dashboard.

Estimated Time: 15 minutes

## Task 1: Update the Middleware


1. Follow the instructions below to complete this task.

    Edit `func.js` in `x402-middleware`. Add a helper to get an OAuth token:

        ```javascript
        let cachedToken = null;
        let tokenExpiry = 0;

        async function getOrdsToken() {
          if (cachedToken && Date.now() < tokenExpiry) return cachedToken;
          const resp = await axios.post(
            `${ORDS_RECEIPTS_URL}oauth/token`,
            'grant_type=client_credentials',
            {
              auth: { username: ORDS_CLIENT_ID, password: ORDS_CLIENT_SECRET },
              headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
            }
          );
          cachedToken = resp.data.access_token;
          tokenExpiry = Date.now() + (resp.data.expires_in - 30) * 1000;
          return cachedToken;
        }

        async function checkExistingReceipt(nonce) {
          const token = await getOrdsToken();
          const resp = await axios.get(
            `${ORDS_RECEIPTS_URL}x402_receipts/${nonce}`,
            { headers: { Authorization: `Bearer ${token}` }, validateStatus: () => true }
          );
          return resp.status === 200 ? resp.data : null;
        }

        async function writeReceipt(receipt) {
          const token = await getOrdsToken();
          await axios.post(
            `${ORDS_RECEIPTS_URL}x402_receipts/`,
            receipt,
            { headers: { Authorization: `Bearer ${token}` } }
          );
        }
        ```

    Then update the main handler - after `verifyPayment` succeeds, check the nonce before settling:

        ```javascript
        const nonce = verification.payload.payload.authorization.nonce;
        const existing = await checkExistingReceipt(nonce);

        if (existing && existing.status === 'settled') {
          // Already paid - return the resource again without settling twice.
          const ordsResp = await axios.get(buildOrdsUrl(path), { validateStatus: () => true });
          setStatus(ctx, ordsResp.status);
          setResponseHeader(ctx, 'PAYMENT-RESPONSE',
            Buffer.from(JSON.stringify({ transaction: existing.tx_hash, replayed: true })).toString('base64')
          );
          setResponseHeader(ctx, 'Content-Type', 'application/json');
          return ordsResp.data;
        }

        // ... existing settlement logic ...

        // After successful settlement:
        await writeReceipt({
          nonce,
          payer_address: verification.payload.payload.authorization.from,
          amount: verification.requirements.accepts[0].maxAmountRequired,
          asset: verification.requirements.accepts[0].asset,
          network: verification.requirements.accepts[0].network,
          tx_hash: settlement.data.transaction,
          resource_path: path,
          status: 'settled',
          settled_at: new Date().toISOString()
        });
        ```

    Keep the Lab 3 ORDS fetch-and-return block after the receipt write. The middleware should still return the requested SH data; the receipt logic only prevents duplicate settlement.

    Redeploy:

        ```bash
        fn -v deploy --app x402-functions
        ```

## Task 2: Verify Idempotency


1. Follow the instructions below to complete this task.

    Run the client from Lab 5 twice in quick succession. The second call should short-circuit on the existing receipt without re-settling.

## Task 3: Query Your Revenue Dashboard


1. Follow the instructions below to complete this task.

    As `x402_app` in Database Actions SQL:

        ```sql
        SELECT
          resource_path,
          COUNT(*)                              AS calls,
          COUNT(DISTINCT payer_address)         AS unique_payers,
          SUM(TO_NUMBER(amount)) / 1000000      AS total_usdc
        FROM x402_receipts
        WHERE status = 'settled'
        GROUP BY resource_path
        ORDER BY total_usdc DESC;
        ```

    You now have a queryable revenue dashboard for your monetized API, sitting in the same database as the data being sold.

## Acknowledgements

- **Author** - Nicholas Cusato, Senior Cloud Engineer
- **Last Updated** - June 2026
- **References** - x402 specification, Coinbase x402 documentation, OCI API Gateway documentation, OCI Functions documentation, ORDS AutoREST documentation
