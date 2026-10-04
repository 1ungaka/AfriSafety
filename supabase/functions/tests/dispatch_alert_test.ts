// Run: deno test supabase/functions/tests/
import { assert, assertEquals } from "jsr:@std/assert@1";

import { buildSosMessage, parseServiceAccount, pemToDer, signAssertion } from "../_shared/fcm.ts";
import { parseAlertIds } from "../_shared/validate.ts";

const id = "6f1c2a3e-1b2c-4d5e-8f90-a1b2c3d4e5f6";

Deno.test("parseAlertIds accepts 1-10 UUIDs and dedupes", () => {
  assertEquals(parseAlertIds({ alert_ids: [id, id] }), [id]);
});

Deno.test("parseAlertIds rejects malformed input", () => {
  assertEquals(parseAlertIds(null), null);
  assertEquals(parseAlertIds({}), null);
  assertEquals(parseAlertIds({ alert_ids: [] }), null);
  assertEquals(parseAlertIds({ alert_ids: ["not-a-uuid"] }), null);
  assertEquals(parseAlertIds({ alert_ids: Array(11).fill(id) }), null);
  assertEquals(parseAlertIds({ alert_ids: [id, 42] }), null);
});

Deno.test("the push carries no personal data", () => {
  const msg = buildSosMessage("device-token", id);
  const text = JSON.stringify(msg);
  assertEquals(msg.message.data, { type: "sos", incident_id: id });
  // Only fixed, generic wording: no names, coordinates or Circle names.
  assertEquals(msg.message.notification.title, "AfriSafety emergency alert");
  assert(!/-?\d{1,3}\.\d{3,}/.test(text), "no coordinates");
  assertEquals(msg.message.android.notification.channel_id, "afrisafety_alerts");
  assertEquals(msg.message.android.priority, "HIGH");
});

Deno.test("parseServiceAccount requires the key fields", () => {
  assertEquals(parseServiceAccount(undefined), null);
  assertEquals(parseServiceAccount(btoa("{}")), null);
  assertEquals(parseServiceAccount("not base64 json"), null);
  const sa = { client_email: "a@b.iam.gserviceaccount.com", private_key: "k", project_id: "p" };
  assertEquals(parseServiceAccount(btoa(JSON.stringify(sa)))?.project_id, "p");
});

Deno.test("signAssertion produces a valid RS256 JWT for the FCM scope", async () => {
  const pair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const der = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(String.fromCharCode(...der))}\n-----END PRIVATE KEY-----\n`;
  assertEquals(pemToDer(pem), der);

  const jwt = await signAssertion(
    { client_email: "svc@x.iam.gserviceaccount.com", private_key: pem, project_id: "x" },
    1_800_000_000,
  );
  const [h, c, s] = jwt.split(".");
  const fromB64Url = (v: string) =>
    Uint8Array.from(atob(v.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((v.length + 3) % 4)), (ch) => ch.charCodeAt(0));
  const claims = JSON.parse(new TextDecoder().decode(fromB64Url(c)));
  assertEquals(claims.scope, "https://www.googleapis.com/auth/firebase.messaging");
  assertEquals(claims.exp - claims.iat, 3600);
  const valid = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    pair.publicKey,
    fromB64Url(s),
    new TextEncoder().encode(`${h}.${c}`),
  );
  assert(valid, "signature verifies");
});
