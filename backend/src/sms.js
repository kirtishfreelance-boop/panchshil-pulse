/**
 * OTP delivery.
 *
 * Pick a provider with SMS_PROVIDER. With none configured the code is logged
 * and returned in the API response, which is what makes local development
 * possible without a gateway — but it is never done once a provider is set.
 *
 *   SMS_PROVIDER=msg91
 *     MSG91_AUTH_KEY, MSG91_TEMPLATE_ID, MSG91_SENDER_ID
 *
 *   SMS_PROVIDER=twilio
 *     TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM
 *
 *   SMS_PROVIDER=console   (default)
 */

const provider = (process.env.SMS_PROVIDER ?? 'console').toLowerCase();

export const smsProvider = provider;

/** True when codes may be echoed back to the caller. */
export const isDevOtpMode = provider === 'console';

class SmsError extends Error {}

async function sendViaMsg91({ mobile, countryCode, otp }) {
  const authKey = process.env.MSG91_AUTH_KEY;
  const templateId = process.env.MSG91_TEMPLATE_ID;
  if (!authKey || !templateId) {
    throw new SmsError('MSG91_AUTH_KEY and MSG91_TEMPLATE_ID must be set.');
  }

  const digits = String(countryCode ?? '+91').replace(/\D/g, '');
  const response = await fetch('https://control.msg91.com/api/v5/otp', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', authkey: authKey },
    body: JSON.stringify({
      template_id: templateId,
      mobile: `${digits}${mobile}`,
      otp,
      ...(process.env.MSG91_SENDER_ID ? { sender: process.env.MSG91_SENDER_ID } : {}),
    }),
  });

  const body = await response.json().catch(() => ({}));
  if (!response.ok || body?.type === 'error') {
    throw new SmsError(body?.message ?? `MSG91 returned ${response.status}.`);
  }
  return body;
}

async function sendViaTwilio({ mobile, countryCode, otp }) {
  const sid = process.env.TWILIO_ACCOUNT_SID;
  const token = process.env.TWILIO_AUTH_TOKEN;
  const from = process.env.TWILIO_FROM;
  if (!sid || !token || !from) {
    throw new SmsError('TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN and TWILIO_FROM must be set.');
  }

  const params = new URLSearchParams({
    To: `${countryCode ?? '+91'}${mobile}`,
    From: from,
    Body: `${otp} is your Panchshil Pulse verification code. It expires in 10 minutes.`,
  });

  const response = await fetch(
    `https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`,
    {
      method: 'POST',
      headers: {
        Authorization: `Basic ${Buffer.from(`${sid}:${token}`).toString('base64')}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: params,
    }
  );

  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new SmsError(body?.message ?? `Twilio returned ${response.status}.`);
  }
  return body;
}

/**
 * Delivers an OTP. Resolves `{ delivered, echo }` — `echo` is the code when the
 * console provider is in use, and null otherwise.
 */
export async function sendOtp({ mobile, countryCode = '+91', otp }) {
  switch (provider) {
    case 'msg91':
      await sendViaMsg91({ mobile, countryCode, otp });
      return { delivered: true, echo: null };

    case 'twilio':
      await sendViaTwilio({ mobile, countryCode, otp });
      return { delivered: true, echo: null };

    default:
      console.log(`[otp] ${countryCode}${mobile} -> ${otp}`);
      return { delivered: false, echo: otp };
  }
}
