# Lab 2: Create a Market Intelligence API with ORDS AutoREST

## Introduction

ORDS AutoREST exposes database tables and views as REST endpoints. In this lab, you create a realistic paid data product for AI agents. The API serves market signals, API product metadata, buyer segments, and pricing benchmarks. The dataset lives in a workshop-owned schema named `X402_REST`, so it avoids maintained-schema restrictions.

### Objectives

- Create the `X402_REST` schema for workshop REST access.
- Seed realistic market intelligence data for agent-facing API monetization.
- AutoREST-enable the signals, products, segments, and pricing endpoints.
- Verify the generated ORDS endpoint and save its base URL.

Estimated Time: 8 minutes

## Task 1: Download the Market API SQL Helper

1. In Cloud Shell, return to your workshop directory:

    ```
    <copy>
    cd ~/x402-workshop
    source workshop.env
    source workshop-outputs.env
    </copy>
    ```

2. Download the helper SQL:

    ```
    <copy>
    curl -fsSLO "$WORKSHOP_FILES_BASE/02-enable-ords-autorest/files/setup-market-autorest.sql"
    </copy>
    ```

3. Replace the schema-password placeholder from `workshop.env`:

    ```
    <copy>
    python3 - <<'PY'
    import os
    from pathlib import Path

    password = os.environ.get("REST_SCHEMA_PASSWORD") or os.environ.get("SH_PASSWORD")
    if not password:
        raise SystemExit("Set REST_SCHEMA_PASSWORD in workshop.env, then rerun this command.")

    path = Path("setup-market-autorest.sql")
    path.write_text(path.read_text().replace("ReplaceWithStrongRestPassword#2026", password))
    PY
    </copy>
    ```

    The fallback to `SH_PASSWORD` supports older `workshop.env` files created before the market dataset update.

## Task 2: Run the SQL in Database Actions

1. In the OCI Console, open your `x402-monetized-db` Autonomous Database.
2. Click **Database actions** > **SQL** and sign in as `ADMIN`.
3. Paste and run the contents of `setup-market-autorest.sql`.
4. Confirm the final queries return:

    - `X402_REST` with `OPEN` account status.
    - Four tables owned by `X402_REST`: `API_PRODUCTS`, `BUYER_SEGMENTS`, `MARKET_SIGNALS`, and `PRICING_BENCHMARKS`.

The SQL helper maps ORDS to `/ords/market/` and exposes these endpoints:

- `/ords/market/signals/`
- `/ords/market/products/`
- `/ords/market/segments/`
- `/ords/market/pricing/`

The helper is safe to rerun. If an earlier attempt enabled `X402_REST` with another ORDS base path, the script disables that mapping before enabling `/ords/market/`.

## Task 3: Verify the ORDS Endpoint

1. In Database Actions, open **REST**.
2. Select the `X402_REST` schema, then select the `MARKET_SIGNALS` table.
3. Copy its generated endpoint. It should look like:

    ```
    <copy>
    https://YOUR-ADB-HOST.adb.YOUR-REGION.oraclecloudapps.com/ords/market/signals/
    </copy>
    ```

4. Test the endpoint from Cloud Shell:

    ```
    <copy>
    curl "https://YOUR-ADB-HOST.adb.YOUR-REGION.oraclecloudapps.com/ords/market/signals/?limit=5"
    </copy>
    ```

5. Save the ORDS base URLs in `workshop.env`:

    ```
    <copy>
    cat >> workshop.env <<'EOF'
    export UPSTREAM_BASE="https://YOUR-ADB-HOST.adb.YOUR-REGION.oraclecloudapps.com/ords/market/"
    export ORDS_RECEIPTS_URL="https://YOUR-ADB-HOST.adb.YOUR-REGION.oraclecloudapps.com/ords/x402/"
    EOF
    source workshop.env
    </copy>
    ```

6. Replace `YOUR-ADB-HOST` and `YOUR-REGION` with your real Autonomous Database host values before continuing.

## Learn more

- [Oracle REST Data Services documentation](https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/)
- [ORDS Developer Guide: Developing REST applications](https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/24.4/orddg/developing-REST-applications.html)
- [ORDS Developer Guide: AutoREST](https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/24.4/orddg/developing-REST-applications.html)
- [SQL Developer Web: AutoREST page](https://docs.oracle.com/en/database/oracle/sql-developer-web/sdwad/autorest-page.html)
- [Oracle Autonomous AI Database documentation](https://docs.oracle.com/en/cloud/paas/autonomous-database/index.html)

## Acknowledgements

- **Author** - Nicholas Cusato, Senior Cloud Engineer
- **Last Updated** - June 2026
- **References** - x402 specification, Coinbase x402 documentation, OCI API Gateway documentation, OCI Functions documentation, ORDS AutoREST documentation
