# Lab 4: Integrate x402 with API Gateway and the SH REST API

## Introduction

You will connect the public API Gateway to the x402 middleware function. The deployment routes SH API requests to the function, and the function decides whether to return a payment challenge or the paid ORDS response.

### Objectives

- Create or update the API Gateway deployment.
- Add routes for the SH AutoREST resources.
- Forward requests to the x402 middleware function.
- Confirm an unpaid request returns HTTP 402.

Estimated Time: 7 minutes

## Task 1: Run the Gateway Route Helper

1. In Cloud Shell, return to your workshop directory:

    ```
    <copy>
    cd ~/x402-workshop
    source workshop.env
    source workshop-outputs.env
    </copy>
    ```

2. Download and run the route helper:

    ```
    <copy>
    curl -fsSLO "$WORKSHOP_FILES_BASE/04-integrate-api-gateway/files/configure-gateway-routes.sh"
    chmod +x configure-gateway-routes.sh
    ./configure-gateway-routes.sh
    </copy>
    ```

3. Reload the generated outputs:

    ```
    <copy>
    source workshop-outputs.env
    echo "$GATEWAY_URL"
    </copy>
    ```

The helper creates or updates `x402-sh-deployment` with routes for `sales`, `products`, `customers`, and `channels`.

## Task 2: Verify the 402 Payment Gate

1. Call the gateway without payment:

    ```
    <copy>
    curl -i "$GATEWAY_URL/sh/sales?limit=5"
    </copy>
    ```

2. Confirm the response includes:

    ```
    <copy>
    HTTP/2 402
    payment-required: eyJ4NDAyVmVyc2lvbiI6Mi...
    </copy>
    ```

3. If you see `502`, check the Functions logs and confirm the API Gateway deployment references the `x402-middleware` function.

## Task 3: Inspect the Routes

1. In the OCI Console, open **Developer Services** > **API Gateway**.
2. Open `x402-api-gateway`, then `x402-sh-deployment`.
3. Confirm these routes use **Oracle Functions** as the backend:

    - `/sh/sales`
    - `/sh/products`
    - `/sh/customers`
    - `/sh/channels`

## Learn more

- [OCI API Gateway documentation](https://docs.oracle.com/en-us/iaas/Content/APIGateway/home.htm)
- [API Gateway concepts](https://docs.oracle.com/en-us/iaas/Content/APIGateway/Concepts/apigatewayconcepts.htm)
- [Adding a Function in OCI Functions as an API Gateway back end](https://docs.oracle.com/en-us/iaas/Content/APIGateway/Tasks/apigatewayusingfunctionsbackend.htm)
- [OCI Functions documentation](https://docs.oracle.com/en-us/iaas/Content/Functions/home.htm)
- [x402 HTTP 402 documentation](https://docs.x402.org/core-concepts/http-402)

## Acknowledgements

- **Author** - Nicholas Cusato, Senior Cloud Engineer
- **Last Updated** - June 2026
- **References** - x402 specification, Coinbase x402 documentation, OCI API Gateway documentation, OCI Functions documentation, ORDS AutoREST documentation
