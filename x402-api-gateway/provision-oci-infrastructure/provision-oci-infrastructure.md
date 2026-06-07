# Lab 1: Provision OCI Infrastructure

## Introduction

You will set up an Autonomous Database, an API Gateway, a VCN, and a Functions application. The core workshop services can run on Free Tier eligible resources; optional Generative AI usage in Lab 7 may incur usage-based charges.

### Objectives

- Create the core OCI resources for the workshop.
- Provision an Autonomous Database for SH sample data.
- Create an API Gateway, Functions application, and network path for the x402 flow.
- Configure local OCI and Fn CLI tooling for deployment.

Estimated Time: 10 minutes

## Task 1: Sign Into Oracle Cloud

1. Navigate to [cloud.oracle.com](https://cloud.oracle.com) and sign in.
2. If you do not have an account, create one at [oracle.com/cloud/free](https://oracle.com/cloud/free).
3. Note your home region.

## Task 2: Create an Autonomous Database Instance

1. From the OCI Console, navigate to **Databases** > **Autonomous Database**.
2. Click **Create Autonomous Database**.
3. Fill in:
   - **Workload Type:** Transaction Processing (ATP)
   - **Deployment Type:** Shared Infrastructure
   - **Display Name:** `x402-monetized-db`
   - **Database Name:** `x402db`
   - **Admin Password:** Create a strong password and save it
   - **Network Access:** Allow secure external connectivity
   - **License Type:** License Included
4. Click **Create**. Wait for the database to reach **Available** state (2-3 minutes).

> **Note:** Every Autonomous Database ships with the SH, SSB, CO, OE, HR, and PM sample schemas pre-installed. You will use SH (Sales History) in this workshop - it contains realistic sales transaction data, products, customers, and channels.

## Task 3: Create the Workshop VCN

1. Navigate to **Networking** > **Virtual cloud networks**.
2. Click **Start VCN Wizard**.
3. Select **Create VCN with Internet Connectivity** and click **Start VCN Wizard**.
4. Fill in:
   - **VCN Name:** `x402-workshop-vcn`
   - **VCN CIDR Block:** `10.0.0.0/16`
   - **Public Subnet CIDR Block:** `10.0.1.0/24`
   - **Private Subnet CIDR Block:** `10.0.2.0/24`
5. Click **Next**, review the resources, and click **Create**.
6. Confirm the wizard created an internet gateway, NAT gateway, service gateway, and route tables.

The public subnet hosts the public API Gateway endpoint. The private subnet hosts OCI Functions. The NAT gateway lets the middleware function call the x402 facilitator and your public ORDS URL. The service gateway gives Functions private access to OCI services such as Generative AI.

## Task 4: Create an API Gateway

1. Navigate to **Developer Services** > **API Gateway**.
2. Click **Create API Gateway**.
3. Fill in:
   - **Name:** `x402-api-gateway`
   - **Type:** Public
   - **VCN:** `x402-workshop-vcn`
   - **Subnet:** Public regional subnet, `10.0.1.0/24`
4. Click **Create**. Wait for **Active** state.
5. Note the gateway hostname - you will use it in Lab 4.

## Task 5: Create a Functions Application

1. Navigate to **Developer Services** > **Functions**.
2. Click **Create Application**.
3. Fill in:
   - **Application Name:** `x402-functions`
   - **VCN:** `x402-workshop-vcn`
   - **Subnets:** Private regional subnet, `10.0.2.0/24`
4. Click **Create**.

## Task 6: Set Up Local Tools


1. Follow the instructions below to complete this task.

    Install the OCI CLI and Fn CLI as described in the standard OCI Functions quickstart. Configure both to point at your tenancy and compartment.

        ```bash
        # OCI CLI
        curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh | bash
        oci setup config

        # Fn CLI
        curl -LSs https://raw.githubusercontent.com/fnproject/cli/master/install | sh
        fn use context default
        fn update context oracle.compartment-id YOUR_COMPARTMENT_OCID
        fn update context registry YOUR_REGION_KEY.ocir.io/YOUR_TENANCY_NAMESPACE/x402
        ```

    You will deploy your first function in Lab 3.

## Acknowledgements

- **Author** - Nicholas Cusato, Senior Cloud Engineer
- **Last Updated** - June 2026
- **References** - x402 specification, Coinbase x402 documentation, OCI API Gateway documentation, OCI Functions documentation, ORDS AutoREST documentation
