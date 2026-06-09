const axios = require('axios');
const crypto = require('crypto');
const fs = require('fs');
const { createWalletClient, http } = require('viem');
const { privateKeyToAccount } = require('viem/accounts');
const { baseSepolia } = require('viem/chains');

const GATEWAY_URL = process.env.GATEWAY_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const PAYMENT_SIGNATURE_FILE = process.env.PAYMENT_SIGNATURE_FILE || '.last-payment-signature';
const REPLAY_LAST_PAYMENT = process.env.REPLAY_LAST_PAYMENT === 'true';

if (!GATEWAY_URL || !PRIVATE_KEY) {
  console.error('Set GATEWAY_URL and PRIVATE_KEY before running the client.');
  process.exit(1);
}

const account = privateKeyToAccount(PRIVATE_KEY);
const walletClient = createWalletClient({
  account,
  chain: baseSepolia,
  transport: http()
});

async function callPaidEndpoint() {
  const filter = encodeURIComponent(JSON.stringify({ amount_sold: { $gt: 1000 } }));
  const targetUrl = `${GATEWAY_URL}/sh/sales?q=${filter}&limit=10`;

  if (REPLAY_LAST_PAYMENT) {
    const savedHeader = fs.readFileSync(PAYMENT_SIGNATURE_FILE, 'utf8').trim();
    const replayed = await axios.get(targetUrl, {
      headers: { 'PAYMENT-SIGNATURE': savedHeader },
      validateStatus: () => true
    });
    console.log('Replay status:', replayed.status);
    console.log(`Rows returned: ${replayed.data.items?.length || 0}`);
    if (replayed.headers['payment-response']) {
      const response = JSON.parse(Buffer.from(replayed.headers['payment-response'], 'base64').toString());
      console.log('Payment response:', response);
    }
    return;
  }

  const initial = await axios.get(targetUrl, { validateStatus: () => true });
  if (initial.status !== 402) {
    console.log('Unexpected initial status:', initial.status);
    console.log(initial.data);
    return;
  }

  const requirementsB64 = initial.headers['payment-required'];
  const requirements = JSON.parse(Buffer.from(requirementsB64, 'base64').toString());
  const selected = requirements.accepts[0];
  console.log(`Server requires ${selected.maxAmountRequired} units of ${selected.asset} on ${selected.network}`);

  const nonce = `0x${crypto.randomBytes(32).toString('hex')}`;
  const validAfter = 0;
  const validBefore = Math.floor(Date.now() / 1000) + 60;

  const domain = {
    name: selected.extra?.name || 'USDC',
    version: selected.extra?.version || '2',
    chainId: Number(selected.network.replace('eip155:', '')),
    verifyingContract: selected.asset
  };

  const types = {
    TransferWithAuthorization: [
      { name: 'from', type: 'address' },
      { name: 'to', type: 'address' },
      { name: 'value', type: 'uint256' },
      { name: 'validAfter', type: 'uint256' },
      { name: 'validBefore', type: 'uint256' },
      { name: 'nonce', type: 'bytes32' }
    ]
  };

  const message = {
    from: account.address,
    to: selected.payTo,
    value: selected.maxAmountRequired,
    validAfter,
    validBefore,
    nonce
  };

  const signature = await walletClient.signTypedData({
    domain,
    types,
    primaryType: 'TransferWithAuthorization',
    message
  });

  const payload = {
    x402Version: 2,
    scheme: 'exact',
    network: selected.network,
    payload: { signature, authorization: message }
  };

  const paymentSignatureHeader = Buffer.from(JSON.stringify(payload)).toString('base64');
  fs.writeFileSync(PAYMENT_SIGNATURE_FILE, paymentSignatureHeader);

  const paid = await axios.get(targetUrl, {
    headers: { 'PAYMENT-SIGNATURE': paymentSignatureHeader },
    validateStatus: () => true
  });

  console.log('Paid status:', paid.status);
  console.log(`Rows returned: ${paid.data.items?.length || 0}`);
  if (paid.data.items?.[0]) {
    console.log(`First sale amount: ${paid.data.items[0].amount_sold}`);
  }
  if (paid.headers['payment-response']) {
    const settlement = JSON.parse(Buffer.from(paid.headers['payment-response'], 'base64').toString());
    console.log('Settlement response:', settlement);
  }
}

callPaidEndpoint().catch((err) => {
  console.error(err.response?.data || err.message);
  process.exit(1);
});
