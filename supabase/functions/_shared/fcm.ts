// Firebase Cloud Messaging (HTTP v1) helpers.
//
// Privacy: the push carries NO personal data. Its text is generic and its
// data is an opaque incident id. The app fetches the encrypted alert and
// decrypts it on the phone, so Google learns only that "a push was sent".

export interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const TOKEN_URL = "https://oauth2.googleapis.com/token";

export const ALERT_CHANNEL_ID = "afrisafety_alerts";

/** The FCM message for an SOS alert. Deliberately contains no names,
 * locations or Circle details. */
export function buildSosMessage(token: string, incidentId: string) {
  return {
    message: {
      token,
      notification: {
        title: "AfriSafety emergency alert",
        body: "Someone in your Circle needs help. Open AfriSafety.",
      },
      data: { type: "sos", incident_id: incidentId },
      android: {
        priority: "HIGH",
        notification: {
          channel_id: ALERT_CHANNEL_ID,
          // One notification per incident, however many Circles it hit.
          tag: incidentId,
          default_sound: true,
        },
      },
    },
  };
}

export function parseServiceAccount(b64: string | undefined): ServiceAccount | null {
  if (!b64) return null;
  try {
    const sa = JSON.parse(atob(b64));
    if (!sa.client_email || !sa.private_key || !sa.project_id) return null;
    return sa as ServiceAccount;
  } catch {
    return null;
  }
}

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function pemToDer(pem: string): Uint8Array<ArrayBuffer> {
  const binary = atob(
    pem
      .replace(/-----BEGIN [A-Z ]+-----/, "")
      .replace(/-----END [A-Z ]+-----/, "")
      .replace(/\s+/g, ""),
  );
  const der = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) der[i] = binary.charCodeAt(i);
  return der;
}

/** Signs the OAuth assertion JWT (RS256) for a service account. */
export async function signAssertion(
  sa: ServiceAccount,
  nowSeconds: number,
): Promise<string> {
  const enc = (o: unknown) => base64Url(new TextEncoder().encode(JSON.stringify(o)));
  const unsigned = `${enc({ alg: "RS256", typ: "JWT" })}.${enc({
    iss: sa.client_email,
    scope: FCM_SCOPE,
    aud: TOKEN_URL,
    iat: nowSeconds,
    exp: nowSeconds + 3600,
  })}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned)),
  );
  return `${unsigned}.${base64Url(signature)}`;
}

let cached: { token: string; expiresAt: number } | null = null;

/** OAuth access token for FCM, cached until shortly before it expires. */
export async function accessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cached && cached.expiresAt - 60 > now) return cached.token;
  const res = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: await signAssertion(sa, now),
    }),
  });
  if (!res.ok) throw new Error(`oauth_failed_${res.status}`);
  const body = await res.json();
  cached = { token: body.access_token, expiresAt: now + (body.expires_in ?? 3600) };
  return cached.token;
}

export type SendResult = "sent" | "unregistered" | "failed";

/** Sends one message. 'unregistered' means the token is dead and should
 * be deleted. */
export async function send(
  sa: ServiceAccount,
  message: ReturnType<typeof buildSosMessage>,
): Promise<SendResult> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${await accessToken(sa)}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(message),
    },
  );
  if (res.ok) return "sent";
  const text = await res.text();
  if (res.status === 404 || text.includes("UNREGISTERED")) return "unregistered";
  return "failed";
}
