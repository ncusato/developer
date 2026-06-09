# Lab 7 (Optional): Polish Responses With OCI Generative AI

## Introduction

Raw JSON rows work for traditional API consumers. AI agents often need a model call to interpret the data. You can deliver more value in one paid request by summarizing query results with OCI Generative AI.

This lab adds optional summarization inside the x402 middleware function. After ORDS returns rows, the function calls OCI Generative AI. It returns the raw data and summary in the same paid response.

> **Publish review note:** Oracle Generative AI APIs and model interfaces change over time. Before official publication, confirm whether this optional lab should use the current Chat API instead of the source draft's `generateText` pattern.

## Architecture Change

```
<copy>
[Client] -> [API Gateway] -> [x402 Middleware Function]
                                  |
                                  | verified + settled
                                  v
                          [ORDS AutoREST -> SH data]
                                  |
                                  | optional enrichment
                                  v
                          [OCI Generative AI]
                                  |
                                  v
                          [Combined response]
</copy>
```

### Objectives

- Enable OCI Generative AI for optional response summarization.
- Grant the middleware function access to Generative AI.
- Update the middleware to summarize successful ORDS responses.
- Return raw ORDS rows plus a concise generated summary.

Estimated Time: 20 minutes

## Task 1: Confirm OCI Generative AI Availability

1. Navigate to **Analytics & AI** > **Generative AI** in the OCI Console.
2. Accept the terms if this is your first time.
3. Confirm a chat model is available in your selected region. If your workshop region does not offer the model you want, use a supported Generative AI region or choose a model available in your current region.
4. For this lab, use the model alias `cohere.command-latest` when available.
5. The alias tracks the current model in the Command family. That keeps the lab from pinning an older model ID.

## Task 2: Grant the Middleware Function Access to Gen AI

1. Navigate to **Identity & Security** > **Domains** > **Default Domain** > **Dynamic Groups**.
2. Create `x402-functions-dg` with matching rule:

    ```
    <copy>
       ALL {resource.type = 'fnfunc', resource.compartment.id = 'YOUR_COMPARTMENT_OCID'}
    </copy>
    ```

3. Navigate to **Policies** and create `x402-functions-genai-policy`:

    ```
    <copy>
       allow dynamic-group x402-functions-dg to use generative-ai-family in compartment YOUR_COMPARTMENT
    </copy>
    ```

## Task 3: Add Gen AI Dependencies to the Middleware

1. In the `x402-middleware` project from Lab 3, update `package.json`:

    ```
    <copy>
    {
      "name": "x402-middleware",
      "version": "1.0.0",
      "description": "x402 payment middleware for OCI",
      "main": "func.js",
      "dependencies": {
        "@fnproject/fdk": ">=0.0.20",
        "axios": "^1.7.0",
        "oci-common": "^2.95.0",
        "oci-generativeaiinference": "^2.95.0",
        "viem": "^2.21.0"
      }
    }
    </copy>
    ```

2. At the top of `func.js`, add the OCI SDK imports and configuration:

    ```
    <copy>
    const common = require('oci-common');
    const genai = require('oci-generativeaiinference');

    const COMPARTMENT_ID = process.env.COMPARTMENT_ID;
    const MODEL_ID = process.env.MODEL_ID || 'cohere.command-latest';
    const SUMMARIZE_ENABLED = process.env.SUMMARIZE_ENABLED === 'true';

    const provider = new common.ResourcePrincipalAuthenticationDetailsProvider();
    const genAiClient = new genai.GenerativeAiInferenceClient({
      authenticationDetailsProvider: provider
    });
    </copy>
    ```

## Task 4: Add a Summarization Helper

1. Add this helper below `buildOrdsUrl()` in `func.js`:

    ```
    <copy>
    function buildPrompt(ordsData, resourcePath) {
      const items = ordsData.items || [];
      const sample = items.slice(0, 20);
      const resource = resourcePath.split('/').filter(Boolean).pop() || 'records';

      return `You are a data analyst. The user queried the ${resource} endpoint of a sales database and received ${items.length} ${resource} records. Below are the first ${sample.length} as JSON.

    Write a concise 2-3 sentence summary highlighting notable patterns, outliers, or trends in this data. Reference actual numbers from the records. Do not restate the schema; provide insight.

    Records:
    ${JSON.stringify(sample, null, 2)}`;
    }

    async function summarizeResponse(ordsData, resourcePath) {
      if (!ordsData || !Array.isArray(ordsData.items) || ordsData.items.length === 0) {
        return {
          ...ordsData,
          summary: 'No records returned for this query.',
          summaryModel: MODEL_ID
        };
      }

      const response = await genAiClient.generateText({
        generateTextDetails: {
          compartmentId: COMPARTMENT_ID,
          servingMode: { servingType: 'ON_DEMAND', modelId: MODEL_ID },
          inferenceRequest: {
            runtimeType: 'COHERE',
            prompt: buildPrompt(ordsData, resourcePath),
            maxTokens: 200,
            temperature: 0.3
          }
        }
      });

      const summary = response.generateTextResult
        ?.inferenceResponse
        ?.generatedTexts?.[0]
        ?.text
        ?.trim();

      return {
        ...ordsData,
        summary: summary || null,
        summaryModel: MODEL_ID,
        summaryGeneratedAt: new Date().toISOString()
      };
    }
    </copy>
    ```

## Task 5: Enrich Paid Responses

1. In the Lab 3 handler, replace the final `return ordsResp.data;` block with this version:

    ```
    <copy>
    let responseBody = ordsResp.data;

    if (SUMMARIZE_ENABLED && ordsResp.status >= 200 && ordsResp.status < 300) {
      try {
        responseBody = await summarizeResponse(ordsResp.data, path);
      } catch (err) {
        responseBody = { ...ordsResp.data, summary: null, summaryError: err.message };
      }
    }

    setStatus(ctx, ordsResp.status);
    setResponseHeader(ctx, 'PAYMENT-RESPONSE', paymentResponseHeader);
    setResponseHeader(ctx, 'Content-Type', 'application/json');
    return responseBody;
    </copy>
    ```

2. Configure and redeploy the middleware:

    ```
    <copy>
    fn config function x402-functions x402-middleware COMPARTMENT_ID "YOUR_COMPARTMENT_OCID"
    fn config function x402-functions x402-middleware MODEL_ID "cohere.command-latest"
    fn config function x402-functions x402-middleware SUMMARIZE_ENABLED "true"
    fn -v deploy --app x402-functions
    </copy>
    ```

## Task 6: Bump the Price for Summarized Responses (Optional)

1. Update `priceFor()` if you want summarized responses to cost more than raw rows:

    ```
    <copy>
    function priceFor(path) {
      const summarizeEnabled = process.env.SUMMARIZE_ENABLED === 'true';
      const base = path.includes('/customers') ? 20000
                 : path.includes('/sales')     ? 10000
                 : 5000;
      return summarizeEnabled ? String(base * 5) : String(base);
    }
    </copy>
    ```

    A raw sales query stays at $0.01. A summarized one becomes $0.05.

## Task 7: Test the Summarized Response

1. Re-run the client from Lab 5. The response now includes a natural-language summary:

    ```
    <copy>
    {
      "items": [
        { "prod_id": 13, "cust_id": 987, "amount_sold": 1782.32 }
      ],
      "summary": "A small set of product IDs drives these high-value sales records, with the largest visible transaction above $1,700. Several rows share the same channel pattern, which suggests a useful follow-up query by channel_id.",
      "summaryModel": "cohere.command-latest",
      "summaryGeneratedAt": "2026-05-16T18:42:11.812Z"
    }
    </copy>
    ```

## Task 8: Review Cost Considerations

1. Review the cost guidance before using summarized responses in production.

OCI Generative AI on-demand inferencing charges by character length for chat prompts and responses. Oracle pricing pages list transactions, where one transaction equals one character.

Before publishing or moving to mainnet, check the current pricing page. Calculate cost from the prompt plus response character count for your selected model and region.

## Task 9: Understand the Value of Enriched Paid Responses

1. Review how response enrichment can change the value of the paid API.

Agents spend tokens whether you summarize for them or not. Somewhere upstream, a model will inspect this data. By running inference at your edge, on your data, you capture that value.

It also showcases the OCI stack in a single request. API Gateway exposes the paid endpoint. Functions verifies payment and orchestrates the call. Autonomous Database serves data through ORDS. Generative AI adds the insight layer.

## Learn more

- [OCI Generative AI documentation](https://docs.oracle.com/en-us/iaas/Content/generative-ai/home.htm)
- [Offered pretrained foundational models in OCI Generative AI](https://docs.oracle.com/en-us/iaas/Content/generative-ai/generate-models.htm)
- [Use model aliases in OCI Generative AI](https://docs.oracle.com/en-us/iaas/releasenotes/generative-ai/model-alias.htm)
- [Calculating cost in Generative AI](https://docs.oracle.com/en-us/iaas/Content/generative-ai/calculate-cost.htm)
- [Paying for on-demand inferencing](https://docs.oracle.com/en-us/iaas/Content/generative-ai/pay-on-demand.htm)
- [OCI TypeScript SDK: Generative AI Inference module](https://docs.oracle.com/en-us/iaas/tools/typescript/latest/modules/_generativeaiinference_index_.html)
- [Managing dynamic groups](https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/managingdynamicgroups.htm)
- [Writing policies for dynamic groups](https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/callingservicesfrominstances.htm)

## Acknowledgements

- **Author** - Nicholas Cusato, Senior Cloud Engineer
- **Last Updated** - June 2026
- **References** - x402 specification, Coinbase x402 documentation, OCI API Gateway documentation, OCI Functions documentation, ORDS AutoREST documentation
