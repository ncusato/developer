# Lab 3: Deploy x402 Middleware as an OCI Function

## Introduction

The middleware function intercepts every API Gateway request and decides whether to return HTTP 402 or pass the request through to ORDS. It also stores payment receipts in the same Autonomous Database that holds the SH schema. We will set up the receipts table here so the database is ready when Lab 6 wires up idempotency.

### Objectives

- Create the receipts schema and table for payment state.
- Enable ORDS access for the x402 application schema.
- Build the Node.js OCI Function that emits, verifies, and settles x402 payments.
- Deploy and configure the middleware function.

Estimated Time: 20 minutes

## Task 1: Create the Receipts Schema and Table

1. In Database Actions, sign in as ADMIN.
2. Create a dedicated schema for x402 state:
    ```sql
       CREATE USER x402_app IDENTIFIED BY "YourX402Password#2026";
       GRANT CONNECT, RESOURCE, UNLIMITED TABLESPACE TO x402_app;
    ```
3. Sign in as `x402_app` and create the receipts table:
    ```sql
       CREATE TABLE x402_receipts (
         nonce            VARCHAR2(66) PRIMARY KEY,
         payer_address    VARCHAR2(42) NOT NULL,
         amount           VARCHAR2(78) NOT NULL,
         asset            VARCHAR2(42) NOT NULL,
         network          VARCHAR2(50) NOT NULL,
         tx_hash          VARCHAR2(100),
         resource_path    VARCHAR2(500),
         status           VARCHAR2(20) NOT NULL,
         created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
         settled_at       TIMESTAMP
       );

       CREATE INDEX idx_receipts_payer ON x402_receipts(payer_address);
       CREATE INDEX idx_receipts_created ON x402_receipts(created_at);
    ```

## Task 2: Enable ORDS on the x402_app Schema

1. In Database Actions as `x402_app`, navigate to **REST**.
2. Click **Enable REST** with these settings:
   - **Schema Alias:** `x402`
   - **Authorization Required:** **Yes**
3. Click **Tables and Views**, find `X402_RECEIPTS`, and enable REST on it (default settings).
4. Create an OAuth2 client for the middleware function:
   - Navigate to **REST** > **Security** > **OAuth Clients**.
   - If prompted to create a privilege first, create `x402_receipts_privilege` and protect the `/x402/x402_receipts/*` pattern.
   - Click **Create OAuth Client**.
   - **Name:** `x402-middleware-client`
   - **Grant Type:** `Client Credentials`
   - **Privileges:** add `x402_receipts_privilege` or the generated privilege for the `X402_RECEIPTS` AutoREST endpoint.
   - Save the **Client ID** and **Client Secret** - you will need them in Task 6.

## Task 3: Initialize the Function Project


1. Follow the instructions below to complete this task.

        ```bash
        mkdir x402-middleware && cd x402-middleware
        fn init --runtime node x402-middleware
        cd x402-middleware
        ```

    Confirm `func.yaml`:

        ```yaml
        schema_version: 20180708
        name: x402-middleware
        version: 0.0.1
        runtime: node
        build_image: fnproject/node:18-dev
        run_image: fnproject/node:18
        entrypoint: node func.js
        memory: 256
        timeout: 30
        ```

## Task 4: Add Dependencies


1. Follow the instructions below to complete this task.

    Replace `package.json`:

        ```json
        {
          "name": "x402-middleware",
          "version": "1.0.0",
          "description": "x402 payment middleware for OCI",
          "main": "func.js",
          "dependencies": {
            "@fnproject/fdk": ">=0.0.20",
            "axios": "^1.7.0",
            "viem": "^2.21.0"
          }
        }
        ```

## Task 5: Write the Middleware Logic


1. Follow the instructions below to complete this task.

    Replace `func.js`:

        ```javascript
        const fdk = require('@fnproject/fdk');
        const axios = require('axios');

        const PAY_TO_ADDRESS = process.env.PAY_TO_ADDRESS;
        const FACILITATOR_URL = process.env.FACILITATOR_URL || 'https://x402.org/facilitator';
        const NETWORK = process.env.NETWORK || 'eip155:84532';
        const ASSET_ADDRESS = process.env.ASSET_ADDRESS || '0x036CbD53842c5426634e7929541eC2318f3dCF7e';
        const USDC_EIP712_NAME = process.env.USDC_EIP712_NAME || 'USDC';
        const USDC_EIP712_VERSION = process.env.USDC_EIP712_VERSION || '2';
        const UPSTREAM_BASE = process.env.UPSTREAM_BASE;
        const ORDS_RECEIPTS_URL = process.env.ORDS_RECEIPTS_URL;
        const ORDS_CLIENT_ID = process.env.ORDS_CLIENT_ID;
        const ORDS_CLIENT_SECRET = process.env.ORDS_CLIENT_SECRET;

        function priceFor(path) {
          if (path.includes('/customers')) return '20000'; // $0.02
          if (path.includes('/sales'))     return '10000'; // $0.01
          return '5000';                                   // $0.005 default
        }

        function getHeader(headers, name) {
          const wanted = name.toLowerCase();
          for (const [key, value] of Object.entries(headers || {})) {
            if (key.toLowerCase() === wanted) return Array.isArray(value) ? value[0] : value;
          }
          return null;
        }

        function getRequestPath(ctx) {
          return ctx.httpGateway?.requestUrl
              || ctx.httpGateway?.requestURL
              || ctx.httpGateway?.requestPath
              || '/';
        }

        function setStatus(ctx, statusCode) {
          if (ctx.httpGateway) ctx.httpGateway.statusCode = statusCode;
        }

        function setResponseHeader(ctx, name, value) {
          if (ctx.httpGateway?.setResponseHeader) {
            ctx.httpGateway.setResponseHeader(name, value);
          }
        }

        function buildOrdsUrl(requestPath) {
          const [rawPath, query = ''] = requestPath.split('?');
          let resourcePath = rawPath
            .replace(/^\/v1\/sh\/?/, '')
            .replace(/^\/sh\/?/, '');
          if (resourcePath && !resourcePath.endsWith('/')) resourcePath += '/';
          const base = UPSTREAM_BASE.replace(/\/$/, '/');
          const url = `${base}${resourcePath}`;
          return query ? `${url}?${query}` : url;
        }

        function buildPaymentRequired(resourcePath) {
          const requirements = {
            x402Version: 2,
            accepts: [{
              scheme: 'exact',
              network: NETWORK,
              maxAmountRequired: priceFor(resourcePath),
              resource: resourcePath,
              description: 'Pay-per-call API access',
              mimeType: 'application/json',
              payTo: PAY_TO_ADDRESS,
              maxTimeoutSeconds: 60,
              asset: ASSET_ADDRESS,
              extra: { name: USDC_EIP712_NAME, version: USDC_EIP712_VERSION }
            }]
          };
          return Buffer.from(JSON.stringify(requirements)).toString('base64');
        }

        async function verifyPayment(signatureHeader, requirementsHeader) {
          try {
            const payload = JSON.parse(Buffer.from(signatureHeader, 'base64').toString());
            const requirements = JSON.parse(Buffer.from(requirementsHeader, 'base64').toString());
            const response = await axios.post(`${FACILITATOR_URL}/verify`, {
              x402Version: 2,
              paymentPayload: payload,
              paymentRequirements: requirements.accepts[0]
            }, { timeout: 10000 });
            return { valid: response.data.isValid === true, data: response.data, payload, requirements };
          } catch (err) {
            return { valid: false, error: err.message };
          }
        }

        async function settlePayment(signatureHeader, requirementsHeader) {
          try {
            const payload = JSON.parse(Buffer.from(signatureHeader, 'base64').toString());
            const requirements = JSON.parse(Buffer.from(requirementsHeader, 'base64').toString());
            const response = await axios.post(`${FACILITATOR_URL}/settle`, {
              x402Version: 2,
              paymentPayload: payload,
              paymentRequirements: requirements.accepts[0]
            }, { timeout: 30000 });
            return { success: response.data.success === true, data: response.data };
          } catch (err) {
            return { success: false, error: err.message };
          }
        }

        fdk.handle(async (input, ctx) => {
          const headers = ctx.httpGateway?.headers || {};
          const path = getRequestPath(ctx);
          const paymentSignature = getHeader(headers, 'PAYMENT-SIGNATURE');

          const requirementsHeader = buildPaymentRequired(path);

          if (!paymentSignature) {
            setStatus(ctx, 402);
            setResponseHeader(ctx, 'PAYMENT-REQUIRED', requirementsHeader);
            setResponseHeader(ctx, 'Content-Type', 'application/json');
            return {
              error: 'Payment Required',
              message: 'This endpoint requires payment via x402. See PAYMENT-REQUIRED header.',
              paymentRequired: requirementsHeader,
              x402Version: 2
            };
          }

          const verification = await verifyPayment(paymentSignature, requirementsHeader);
          if (!verification.valid) {
            setStatus(ctx, 402);
            setResponseHeader(ctx, 'PAYMENT-REQUIRED', requirementsHeader);
            return { error: 'Invalid Payment', detail: verification.error || verification.data };
          }

          const settlement = await settlePayment(paymentSignature, requirementsHeader);
          if (!settlement.success) {
            setStatus(ctx, 402);
            return { error: 'Settlement Failed', detail: settlement.error || settlement.data };
          }

          const paymentResponseHeader = Buffer.from(JSON.stringify(settlement.data)).toString('base64');
          const ordsResp = await axios.get(buildOrdsUrl(path), { validateStatus: () => true });

          setStatus(ctx, ordsResp.status);
          setResponseHeader(ctx, 'PAYMENT-RESPONSE', paymentResponseHeader);
          setResponseHeader(ctx, 'Content-Type', 'application/json');

          return ordsResp.data;
        });
        ```

## Task 6: Deploy and Configure


1. Follow the instructions below to complete this task.

        ```bash
        fn -v deploy --app x402-functions

        fn config function x402-functions x402-middleware PAY_TO_ADDRESS "0xYourTestAddress"
        fn config function x402-functions x402-middleware FACILITATOR_URL "https://x402.org/facilitator"
        fn config function x402-functions x402-middleware NETWORK "eip155:84532"
        fn config function x402-functions x402-middleware ASSET_ADDRESS "0x036CbD53842c5426634e7929541eC2318f3dCF7e"
        fn config function x402-functions x402-middleware USDC_EIP712_NAME "USDC"
        fn config function x402-functions x402-middleware USDC_EIP712_VERSION "2"
        fn config function x402-functions x402-middleware UPSTREAM_BASE "https://YOUR-ADB-HOST.../ords/sh/"
        fn config function x402-functions x402-middleware ORDS_RECEIPTS_URL "https://YOUR-ADB-HOST.../ords/x402/"
        fn config function x402-functions x402-middleware ORDS_CLIENT_ID "your_client_id"
        fn config function x402-functions x402-middleware ORDS_CLIENT_SECRET "your_client_secret"
        ```

    Test that the function returns 402 when invoked without a payment header:

        ```bash
        echo '{}' | fn invoke x402-functions x402-middleware
        ```

## Acknowledgements

- **Author** - Nicholas Cusato, Senior Cloud Engineer
- **Last Updated** - June 2026
- **References** - x402 specification, Coinbase x402 documentation, OCI API Gateway documentation, OCI Functions documentation, ORDS AutoREST documentation
