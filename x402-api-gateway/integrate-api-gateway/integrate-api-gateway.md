# Lab 4: Integrate x402 with API Gateway and the SH REST API

## Introduction

You will create an API Gateway deployment that sends incoming SH API requests to the x402 middleware function as an Oracle Functions backend. The function returns HTTP 402 when payment is missing, then verifies payment, calls ORDS AutoREST, and returns the paid response.

### Objectives

- Create an OCI API Gateway deployment for the SH API.
- Attach the x402 middleware as an Oracle Functions backend.
- Let the function orchestrate payment verification and ORDS AutoREST calls.
- Confirm the gateway returns HTTP 402 when payment is missing.

Estimated Time: 15 minutes

## Task 1: Create a Deployment in API Gateway

1. Navigate to your `x402-api-gateway`.
2. Click **Deployments** > **Create Deployment** > **From Scratch**.
3. Fill in:
   - **Name:** `x402-sh-deployment`
   - **Path Prefix:** `/v1`
4. Click **Next**.

## Task 2: Keep authentication disabled at the gateway

1. On the **Authentication** step, select **No Authentication** for this workshop deployment.
2. Keep authentication and payment enforcement inside the `x402-middleware` function.
3. Click **Next**.

## Task 3: Add routes that invoke the x402 middleware

1. Click **Add Route** for each of the following:

   **Sales:**
   - Path: `/sh/sales`
   - Methods: `GET`
   - Backend type: `Oracle Functions`
   - Application: `x402-functions`
   - Function: `x402-middleware`

   **Products:**
   - Path: `/sh/products`
   - Backend type: `Oracle Functions`
   - Application: `x402-functions`
   - Function: `x402-middleware`

   **Customers:**
   - Path: `/sh/customers`
   - Backend type: `Oracle Functions`
   - Application: `x402-functions`
   - Function: `x402-middleware`

   **Channels:**
   - Path: `/sh/channels`
   - Backend type: `Oracle Functions`
   - Application: `x402-functions`
   - Function: `x402-middleware`

2. For each route, enable **Forward query parameters** so the middleware receives the AutoREST filter syntax and can pass it to ORDS.
3. Click **Next**, review, and **Create**. Wait for **Active** state.

## Task 4: Test the Payment Gate


1. Follow the instructions below to complete this task.

        ```bash
        curl -i "https://YOUR-GATEWAY-URL/v1/sh/sales?limit=5"
        ```

    Expected:

        ```
        HTTP/2 402
        content-type: application/json
        payment-required: eyJ4NDAyVmVyc2lvbiI6Mi...

        {"error":"Payment Required",...}
        ```

    The API Gateway route now invokes the x402 middleware, and the middleware can return the x402 `402 Payment Required` response directly to the client.

## Acknowledgements

- **Author** - Nicholas Cusato, Senior Cloud Engineer
- **Last Updated** - June 2026
- **References** - x402 specification, Coinbase x402 documentation, OCI API Gateway documentation, OCI Functions documentation, ORDS AutoREST documentation
