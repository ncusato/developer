# Lab 2: Expose SH Data with ORDS AutoREST

## Introduction

ORDS AutoREST exposes database tables and views as REST endpoints without writing controllers. Autonomous Database protects maintained schemas such as `SH`, so this lab does not REST-enable `SH` directly. Instead, you will create a workshop-owned schema named `X402_REST`, grant it read access to selected SH sample tables, create views, and map ORDS to the familiar `/ords/sh/` base path.

### Objectives

- Create the `X402_REST` schema for workshop REST access.
- Expose SH sample data through `X402_REST` views.
- AutoREST-enable the sales, products, customers, and channels views.
- Verify the generated ORDS endpoint and save its base URL.

Estimated Time: 8 minutes

## Task 1: Download the AutoREST SQL Helper

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
    curl -fsSLO "$WORKSHOP_FILES_BASE/02-enable-ords-autorest/files/setup-sh-autorest.sql"
    </copy>
    ```

3. Open the file and replace `ReplaceWithStrongRestPassword#2026` with a strong password. Use `REST_SCHEMA_PASSWORD` if you added it to `workshop.env`; otherwise use the current `SH_PASSWORD` value.

    ```
    <copy>
    vi setup-sh-autorest.sql
    </copy>
    ```

## Task 2: Run the SQL in Database Actions

1. In the OCI Console, open your `x402-monetized-db` Autonomous Database.
2. Click **Database actions** > **SQL** and sign in as `ADMIN`.
3. Paste and run the contents of `setup-sh-autorest.sql`.
4. Confirm the final queries return:

    - `X402_REST` with `OPEN` account status.
    - Four views owned by `X402_REST`: `SALES`, `PRODUCTS`, `CUSTOMERS`, and `CHANNELS`.

The SQL helper leaves `SH` locked. It uses `SH` only as the source for read-only views, then REST-enables those views under the ORDS base path `/ords/sh/`.

## Task 3: Verify the ORDS Endpoint

1. In Database Actions, open **REST**.
2. Select the `X402_REST` schema, then select the `SALES` view.
3. Copy its generated endpoint. It should look like:

    ```
    <copy>
    https://YOUR-ADB-HOST.adb.YOUR-REGION.oraclecloudapps.com/ords/sh/sales/
    </copy>
    ```

4. Test the endpoint from Cloud Shell:

    ```
    <copy>
    curl "https://YOUR-ADB-HOST.adb.YOUR-REGION.oraclecloudapps.com/ords/sh/sales/?limit=5"
    </copy>
    ```

5. Save the ORDS base URLs in `workshop.env`:

    ```
    <copy>
    cat >> workshop.env <<'EOF'
    export UPSTREAM_BASE="https://YOUR-ADB-HOST.adb.YOUR-REGION.oraclecloudapps.com/ords/sh/"
    export ORDS_RECEIPTS_URL="https://YOUR-ADB-HOST.adb.YOUR-REGION.oraclecloudapps.com/ords/x402/"
    EOF
    source workshop.env
    </copy>
    ```

6. Replace `YOUR-ADB-HOST` and `YOUR-REGION` with your real Autonomous Database host values before continuing.

## Learn more

- [Oracle REST Data Services documentation](https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/)
- [ORDS Developer's Guide: Developing REST applications](https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/24.4/orddg/developing-REST-applications.html)
- [ORDS Developer's Guide: AutoREST](https://docs.oracle.com/en/database/oracle/oracle-rest-data-services/24.4/orddg/developing-REST-applications.html)
- [SQL Developer Web: AutoREST page](https://docs.oracle.com/en/database/oracle/sql-developer-web/sdwad/autorest-page.html)
- [Oracle Autonomous AI Database documentation](https://docs.oracle.com/en/cloud/paas/autonomous-database/index.html)

## Acknowledgements

- **Author** - Nicholas Cusato, Senior Cloud Engineer
- **Last Updated** - June 2026
- **References** - x402 specification, Coinbase x402 documentation, OCI API Gateway documentation, OCI Functions documentation, ORDS AutoREST documentation
