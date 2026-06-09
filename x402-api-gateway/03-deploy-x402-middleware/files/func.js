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

let cachedToken = null;
let tokenExpiry = 0;

function priceFor(path) {
  if (path.includes('/pricing')) return '50000';
  if (path.includes('/signals')) return '20000';
  if (path.includes('/segments')) return '15000';
  if (path.includes('/products')) return '10000';
  return '5000';
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
    .replace(/^\/v1\/market\/?/, '')
    .replace(/^\/market\/?/, '')
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

async function getOrdsToken() {
  if (!ORDS_RECEIPTS_URL || !ORDS_CLIENT_ID || !ORDS_CLIENT_SECRET) return null;
  if (cachedToken && Date.now() < tokenExpiry) return cachedToken;
  const resp = await axios.post(
    `${ORDS_RECEIPTS_URL.replace(/\/$/, '/')}oauth/token`,
    'grant_type=client_credentials',
    {
      auth: { username: ORDS_CLIENT_ID, password: ORDS_CLIENT_SECRET },
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
    }
  );
  cachedToken = resp.data.access_token;
  tokenExpiry = Date.now() + ((resp.data.expires_in || 300) - 30) * 1000;
  return cachedToken;
}

async function checkExistingReceipt(nonce) {
  const token = await getOrdsToken();
  if (!token) return null;
  const base = ORDS_RECEIPTS_URL.replace(/\/$/, '/');
  const resp = await axios.get(
    `${base}x402_receipts/${nonce}`,
    { headers: { Authorization: `Bearer ${token}` }, validateStatus: () => true }
  );
  return resp.status === 200 ? resp.data : null;
}

async function writeReceipt(receipt) {
  const token = await getOrdsToken();
  if (!token) return;
  const base = ORDS_RECEIPTS_URL.replace(/\/$/, '/');
  await axios.post(
    `${base}x402_receipts/`,
    receipt,
    { headers: { Authorization: `Bearer ${token}` } }
  );
}

async function returnPaidResource(ctx, path, paymentResponseHeader) {
  const ordsResp = await axios.get(buildOrdsUrl(path), { validateStatus: () => true });
  setStatus(ctx, ordsResp.status);
  setResponseHeader(ctx, 'PAYMENT-RESPONSE', paymentResponseHeader);
  setResponseHeader(ctx, 'Content-Type', 'application/json');
  return ordsResp.data;
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

  const nonce = verification.payload?.payload?.authorization?.nonce;
  if (nonce) {
    const existing = await checkExistingReceipt(nonce);
    if (existing && existing.status === 'settled') {
      const replayHeader = Buffer.from(JSON.stringify({
        transaction: existing.tx_hash,
        replayed: true
      })).toString('base64');
      return returnPaidResource(ctx, path, replayHeader);
    }
  }

  const settlement = await settlePayment(paymentSignature, requirementsHeader);
  if (!settlement.success) {
    setStatus(ctx, 402);
    return { error: 'Settlement Failed', detail: settlement.error || settlement.data };
  }

  if (nonce) {
    await writeReceipt({
      nonce,
      payer_address: verification.payload.payload.authorization.from,
      amount: verification.requirements.accepts[0].maxAmountRequired,
      asset: verification.requirements.accepts[0].asset,
      network: verification.requirements.accepts[0].network,
      tx_hash: settlement.data.transaction,
      resource_path: path,
      status: 'settled',
      settled_at: new Date().toISOString()
    });
  }

  const paymentResponseHeader = Buffer.from(JSON.stringify(settlement.data)).toString('base64');
  return returnPaidResource(ctx, path, paymentResponseHeader);
});
