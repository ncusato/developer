# Lab 2: Enable ORDS AutoREST on the SH Schema

## Introduction

ORDS (Oracle REST Data Services) is pre-deployed with every Autonomous Database. AutoREST is a feature that exposes any table or view as a fully-functional REST endpoint with one click - no code, no controllers, no plumbing. You will unlock the SH schema, enable REST access on a handful of useful tables, and verify the endpoints respond.

### Objectives

- Unlock the SH sample schema in Autonomous Database.
- Enable ORDS access for the SH schema.
- AutoREST-enable the sales, products, customers, and channels tables.
- Verify generated ORDS endpoints and query options.

Estimated Time: 15 minutes

## Task 1: Unlock the SH Schema

The sample schemas ship locked. You need to set a password to use them.

1. From the OCI Console, open your `x402-monetized-db` Autonomous Database.
2. Click **Database actions** > **SQL** and sign in as `ADMIN` with the password you set in Lab 1.
3. In the SQL Worksheet, run:
    ```sql
       ALTER USER SH IDENTIFIED BY "YourStrongShPassword#2026" ACCOUNT UNLOCK;
       GRANT CONNECT, RESOURCE TO SH;
    ```
4. Confirm SH shows the `OPEN` status:
    ```sql
       SELECT username, account_status FROM dba_users WHERE username = 'SH';
    ```
   Status should be `OPEN`.

## Task 2: Enable ORDS for the SH Schema

1. Return to **Database actions** for your instance.
2. Click **Sign Out** (top right) to leave the ADMIN session.
3. Sign back in as `SH` with the password you set above.
4. In the Database Actions launchpad, click **REST**.
5. You should see a banner offering to enable ORDS for the SH schema. Click **Enable REST**.
6. Fill in:
   - **Schema Alias:** `sh` (this becomes the URL path component)
   - **Authorization Required:** **No** (we will let the API Gateway handle auth via x402)
7. Click **Enable Schema**.

> **Why no schema-level auth?** ORDS supports several auth modes (OAuth2, JWT, basic). For this workshop, we intentionally leave the ORDS endpoint open and put all access control at the API Gateway layer with x402. In production you may want to layer both - ORDS auth as a defense-in-depth backstop, x402 as the user-facing payment gate.

## Task 3: AutoREST-Enable Specific SH Tables

The SH schema contains 14 tables. We will expose four high-value ones that make for compelling monetized endpoints.

1. In Database Actions as SH, click **SQL**.
2. Inspect the schema:
    ```sql
       SELECT table_name, num_rows FROM user_tables ORDER BY num_rows DESC;
    ```
   You will see tables like `SALES`, `CUSTOMERS`, `PRODUCTS`, `CHANNELS`, `COUNTRIES`, `TIMES`, and more. Row counts can vary by Autonomous Database image, so use the query output as your source of truth.

3. Return to the **REST** module in Database Actions.
4. Click **Tables and Views** in the left navigation.
5. For each of the following tables, click the three-dot menu and select **Enable REST**:
   - `SALES`
   - `PRODUCTS`
   - `CUSTOMERS`
   - `CHANNELS`
6. For each, accept the default settings (alias matches table name, auth not required at the ORDS level).

## Task 4: Verify the AutoREST Endpoints

1. In the REST module, click on the `SALES` entry.
2. You will see a generated base URL like:
    ```
       https://YOUR-ADB-HOST.adb.YOUR-REGION.oraclecloudapps.com/ords/sh/sales/
    ```
3. Copy that URL. From a terminal:
    ```bash
       curl "https://YOUR-ADB-HOST.adb.YOUR-REGION.oraclecloudapps.com/ords/sh/sales/?limit=5"
    ```
4. You should get JSON back containing five sales rows with fields like `prod_id`, `cust_id`, `time_id`, `channel_id`, `amount_sold`, and `quantity_sold`.

5. Save the full ORDS base URL for your schema - you will need it in Lab 4:
    ```
       https://YOUR-ADB-HOST.adb.YOUR-REGION.oraclecloudapps.com/ords/sh/
    ```

## Task 5: Explore the AutoREST Query Power


1. Follow the instructions below to complete this task.

    AutoREST gives you a rich query syntax out of the box. Try these from the command line:

        ```bash
        # Filter: sales over $1000
        curl --get "https://YOUR-ADB-HOST.../ords/sh/sales/" \
          --data-urlencode 'q={"amount_sold":{"$gt":1000}}' \
          --data-urlencode "limit=5"

        # Pagination: page 2 with 10 per page
        curl "https://YOUR-ADB-HOST.../ords/sh/sales/?limit=10&offset=10"

        # Specific fields only
        curl "https://YOUR-ADB-HOST.../ords/sh/products/?fields=prod_id,prod_name,prod_list_price&limit=5"

        # Count
        curl "https://YOUR-ADB-HOST.../ords/sh/customers/?count=true&limit=0"
        ```

    If you are using Windows PowerShell, use `curl.exe` instead of the `curl` alias:

        ```powershell
        curl.exe --get "https://YOUR-ADB-HOST.../ords/sh/sales/" `
          --data-urlencode 'q={"amount_sold":{"$gt":1000}}' `
          --data-urlencode "limit=5"
        ```

    You now have a fully-featured REST API over real sales data, generated entirely by ORDS AutoREST. The next step is putting an x402 payment gate in front of it.

## Acknowledgements

- **Author** - Nicholas Cusato, Senior Cloud Engineer
- **Last Updated** - June 2026
- **References** - x402 specification, Coinbase x402 documentation, OCI API Gateway documentation, OCI Functions documentation, ORDS AutoREST documentation
