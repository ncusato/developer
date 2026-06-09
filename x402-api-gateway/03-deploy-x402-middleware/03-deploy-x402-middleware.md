# Lab 3: Deploy x402 Middleware as an OCI Function

## Introduction

The x402 middleware is the payment gate for the workshop API. It returns the `402 Payment Required` challenge, verifies and settles the payment, calls ORDS AutoREST, and writes receipts for idempotency. You will use provided assets instead of typing the function by hand.

### Objectives

- Create the receipt table used for payment state.
- Create an ORDS OAuth client for receipt writes.
- Deploy the provided x402 middleware to OCI Functions.
- Configure the function with ORDS, x402, and wallet settings.

Estimated Time: 15 minutes

## Task 1: Create the Receipt Table

1. In Cloud Shell, download the receipt SQL helper:

    ```
    <copy>
    cd ~/x402-workshop
    source workshop.env
    source workshop-outputs.env
    curl -fsSLO "$WORKSHOP_FILES_BASE/03-deploy-x402-middleware/files/setup-receipts.sql"
    </copy>
    ```

2. Open the file and replace `ReplaceWithStrongX402Password#2026` with the `X402_APP_PASSWORD` value from `workshop.env`:

    ```
    <copy>
    vi setup-receipts.sql
    </copy>
    ```

3. In Database Actions SQL, sign in as `ADMIN`.
4. Paste and run `setup-receipts.sql`.
5. Confirm the final query returns `X402_RECEIPTS`.

The receipt table stores the payer address, payment amount, network, asset, transaction hash, resource path, status, and settlement timestamp. The middleware uses the payment nonce as the primary key so retries do not settle twice.

## Task 2: Create the ORDS OAuth Client

1. In Database Actions, sign in as `x402_app`.
2. Open **REST** > **Security** > **OAuth Clients**.
3. Create a privilege for the receipt endpoint if Database Actions prompts for one:

    - Privilege name: `x402_receipts_privilege`
    - Protected pattern: `/x402/x402_receipts/*`

4. Create an OAuth client:

    - Name: `x402-middleware-client`
    - Grant type: `Client Credentials`
    - Privileges: `x402_receipts_privilege` or the generated privilege for `X402_RECEIPTS`

5. Save the generated client ID and client secret in `workshop.env`:

    ```
    <copy>
    cat >> workshop.env <<'EOF'
    export ORDS_CLIENT_ID="paste-client-id"
    export ORDS_CLIENT_SECRET="paste-client-secret"
    EOF
    source workshop.env
    </copy>
    ```

## Task 3: Deploy the Middleware Asset

1. Download and run the middleware project helper:

    ```
    <copy>
    curl -fsSLO "$WORKSHOP_FILES_BASE/03-deploy-x402-middleware/files/create-middleware-project.sh"
    chmod +x create-middleware-project.sh
    ./create-middleware-project.sh
    </copy>
    ```

2. The script downloads the provided `func.js`, `package.json`, and `func.yaml`, installs dependencies, deploys the function, and writes function configuration from `workshop.env`.
3. Confirm the function exists:

    ```
    <copy>
    fn list functions x402-functions
    </copy>
    ```

4. Invoke the function without a payment header:

    ```
    <copy>
    echo '{}' | fn invoke x402-functions x402-middleware
    </copy>
    ```

5. Confirm the response includes `Payment Required` and a base64 `paymentRequired` value.

## Task 4: Understand the Middleware Flow

1. Open the generated function:

    ```
    <copy>
    sed -n '1,220p' x402-middleware/func.js
    </copy>
    ```

2. Notice the four key sections:

    - `buildPaymentRequired()` creates the x402 challenge.
    - `verifyPayment()` calls the facilitator `/verify` endpoint.
    - `settlePayment()` calls the facilitator `/settle` endpoint.
    - Receipt helpers check and write `x402_receipts` records through ORDS OAuth.

The important behavior is now deployed. Later labs focus on routing, payment testing, and receipt verification.

## Learn more

- [x402 documentation](https://docs.x402.org/introduction)
- [x402 HTTP 402 documentation](https://docs.x402.org/core-concepts/http-402)
- [x402 facilitator documentation](https://docs.x402.org/core-concepts/facilitator)
- [x402 exact payment scheme](https://docs.x402.org/schemes/exact)
- [OCI Functions documentation](https://docs.oracle.com/en-us/iaas/Content/Functions/home.htm)
- [Creating functions using the Fn Project CLI](https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionscreatingfunctions-usingfncli.htm)
- [Creating and deploying functions](https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionsuploading.htm)
- [ORDS REST API: Create an OAuth client](https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/24.4/orrst/op-ords-rest-clients-post.html)

## Acknowledgements

- **Author** - Nicholas Cusato, Senior Cloud Engineer
- **Last Updated** - June 2026
- **References** - x402 specification, Coinbase x402 documentation, OCI API Gateway documentation, OCI Functions documentation, ORDS AutoREST documentation
