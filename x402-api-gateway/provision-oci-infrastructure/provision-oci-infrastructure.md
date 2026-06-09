# Lab 1: Provision OCI Infrastructure

## Introduction

You will use Oracle Cloud Shell to create the core OCI resources for the workshop. The helper script creates or reuses a VCN, public and private subnets, an Autonomous Database, an API Gateway, and a Functions application. You will still inspect the generated outputs so you know what the later labs use.

### Objectives

- Prepare a Cloud Shell working directory for the workshop.
- Configure the required workshop variables.
- Create or reuse the core OCI resources.
- Save the generated resource OCIDs and gateway endpoint for later labs.

Estimated Time: 10 minutes

## Task 1: Open Cloud Shell and Prepare the Workspace

1. Sign in to [cloud.oracle.com](https://cloud.oracle.com).
2. Open **Cloud Shell** from the OCI Console header.
3. Create a workshop directory and download the environment template:

    ```
    <copy>
    mkdir -p x402-workshop
    cd x402-workshop

    export WORKSHOP_FILES_BASE="https://raw.githubusercontent.com/oracle-livelabs/developer/main/x402-api-gateway"
    curl -fsSLO "$WORKSHOP_FILES_BASE/provision-oci-infrastructure/files/workshop.env.example"
    cp workshop.env.example workshop.env
    </copy>
    ```

4. Edit `workshop.env`:

    ```
    <copy>
    vi workshop.env
    </copy>
    ```

5. Set your compartment OCID, region, tenancy namespace, passwords, and test wallet address. Keep the defaults for names unless you need to avoid a naming collision. If you use `us-phoenix-1`, set `REGION_KEY` to `phx`; if you use `us-ashburn-1`, set `REGION_KEY` to `iad`.
6. If your tenancy already uses its Always Free Autonomous Database quota, choose one recovery path:

    - Reuse an existing Autonomous Database by setting `ADB_OCID` in `workshop.env`.
    - Set `ADB_ALLOW_PAID_FALLBACK="true"` in `workshop.env` to create a billable Autonomous Database if the Always Free create fails.

    The paid fallback uses `ADB_PAID_COMPUTE_COUNT`, `ADB_PAID_STORAGE_GBS`, and `ADB_DB_VERSION` from `workshop.env`.
7. To list existing Autonomous Databases in the compartment, run:

    ```
    <copy>
    source workshop.env
    oci db autonomous-database list \
      --compartment-id "$COMPARTMENT_OCID" \
      --all \
      --query 'data[].{"display-name":"display-name",id:id,"lifecycle-state":"lifecycle-state"}' \
      --output table
    </copy>
    ```

8. Validate the file before continuing:

    ```
    <copy>
    bash -n workshop.env
    </copy>
    ```

    If this command reports an unexpected end of file, one of the `export` lines is missing a closing double quote.

## Task 2: Run the Core Bootstrap Script

1. Download and run the bootstrap script:

    ```
    <copy>
    curl -fsSLO "$WORKSHOP_FILES_BASE/provision-oci-infrastructure/files/bootstrap-core.sh"
    chmod +x bootstrap-core.sh
    ./bootstrap-core.sh
    </copy>
    ```

    The script prints `START` and `DONE` lines for each resource. If a command fails, rerun the script after fixing the reported issue; it reuses completed resources by display name.

2. When the script finishes, load the generated outputs:

    ```
    <copy>
    source workshop-outputs.env
    env | grep -E 'ADB_OCID|API_GATEWAY|FUNCTIONS_APP|SUBNET|VCN'
    </copy>
    ```

3. Confirm the output includes:

    - `ADB_OCID`
    - `API_GATEWAY_OCID`
    - `API_GATEWAY_ENDPOINT`
    - `FUNCTIONS_APP_OCID`
    - `PUBLIC_SUBNET_OCID`
    - `PRIVATE_SUBNET_OCID`

## Task 3: Review What the Script Created

1. In the OCI Console, confirm these resources exist:

    - VCN: `x402-workshop-vcn`
    - Public subnet: `x402-public-subnet`
    - Private subnet: `x402-private-subnet`
    - Autonomous Database: `x402-monetized-db`
    - API Gateway: `x402-api-gateway`
    - Functions application: `x402-functions`

2. Check the network shape:

    - API Gateway uses the public subnet.
    - Functions uses the private subnet.
    - The private subnet has NAT access for x402 facilitator calls.
    - The private subnet has service gateway access for OCI services.

3. Keep Cloud Shell open. You will use the same `x402-workshop` directory for the remaining core labs.

## Learn more

- [Oracle Autonomous AI Database documentation](https://docs.oracle.com/en/cloud/paas/autonomous-database/index.html)
- [OCI Networking overview](https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/overview.htm)
- [OCI Virtual Networking wizards](https://docs.oracle.com/en-us/iaas/Content/Network/Tasks/quickstartnetworking.htm)
- [OCI API Gateway documentation](https://docs.oracle.com/en-us/iaas/Content/APIGateway/home.htm)
- [OCI Functions documentation](https://docs.oracle.com/en-us/iaas/Content/Functions/home.htm)
- [OCI Functions QuickStart on Local Host](https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionsquickstartlocalhost.htm)

## Acknowledgements

- **Author** - Nicholas Cusato, Senior Cloud Engineer
- **Last Updated** - June 2026
- **References** - x402 specification, Coinbase x402 documentation, OCI API Gateway documentation, OCI Functions documentation, ORDS AutoREST documentation
