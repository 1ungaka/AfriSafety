// dispatch-alert: pushes a panic alert to the phones of everyone in the
// sender's Circles.
//
// Called by the sender's app right after its encrypted alert is stored.
// Security:
// * The caller's JWT is verified (verify_jwt) and the alerts are looked up
//   WITH THE CALLER'S TOKEN, so RLS proves they're the sender's own.
// * Each alert is pushed at most once (dispatched_at), within 10 minutes of
//   being raised, so this can't be used to spam members.
// * Only the service role can read push tokens, and only here.
// * The push itself contains no personal data (see _shared/fcm.ts).
import { createClient } from "npm:@supabase/supabase-js@2";

import {
  buildSosMessage,
  parseServiceAccount,
  send,
  type SendResult,
} from "../_shared/fcm.ts";
import { parseAlertIds } from "../_shared/validate.ts";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const auth = req.headers.get("Authorization");
  if (!auth) return json({ error: "unauthorized" }, 401);

  const alertIds = parseAlertIds(await req.json().catch(() => null));
  if (!alertIds) return json({ error: "invalid_request" }, 400);

  const url = Deno.env.get("SUPABASE_URL")!;
  const asCaller = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: auth } },
  });
  const { data: userData } = await asCaller.auth.getUser();
  const user = userData?.user;
  if (!user) return json({ error: "unauthorized" }, 401);

  const recent = new Date(Date.now() - 10 * 60 * 1000).toISOString();
  const { data: alerts, error: alertsError } = await asCaller
    .from("alerts")
    .select("id, circle_id, incident_id")
    .in("id", alertIds)
    .eq("sender_id", user.id)
    .is("resolved_at", null)
    .is("dispatched_at", null)
    .gte("created_at", recent);
  if (alertsError) return json({ error: "lookup_failed" }, 500);
  if (!alerts || alerts.length === 0) return json({ sent: 0 });

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  // Claim the alerts first so concurrent calls can't double-push.
  const { data: claimed } = await admin
    .from("alerts")
    .update({ dispatched_at: new Date().toISOString() })
    .in("id", alerts.map((a) => a.id))
    .is("dispatched_at", null)
    .select("id, circle_id, incident_id");
  if (!claimed || claimed.length === 0) return json({ sent: 0 });

  const sa = parseServiceAccount(Deno.env.get("FCM_SERVICE_ACCOUNT_B64"));
  if (!sa) {
    // Not configured: members with the app open still get the alert via
    // Realtime. Say so clearly rather than failing silently.
    return json({ error: "push_not_configured" }, 503);
  }

  const circleIds = [...new Set(claimed.map((a) => a.circle_id))];
  const { data: members } = await admin
    .from("circle_members")
    .select("circle_id, user_id")
    .in("circle_id", circleIds)
    .neq("user_id", user.id);

  // incident per recipient (one notification per person per incident)
  const incidentByUser = new Map<string, string>();
  for (const m of members ?? []) {
    const alert = claimed.find((a) => a.circle_id === m.circle_id)!;
    incidentByUser.set(m.user_id, alert.incident_id);
  }
  if (incidentByUser.size === 0) return json({ sent: 0 });

  const { data: tokens } = await admin
    .from("device_push_tokens")
    .select("device_id, user_id, token, devices!inner(revoked_at)")
    .in("user_id", [...incidentByUser.keys()])
    .is("devices.revoked_at", null);

  const results: SendResult[] = await Promise.all(
    (tokens ?? []).map(async (t) => {
      const result = await send(
        sa,
        buildSosMessage(t.token, incidentByUser.get(t.user_id)!),
      ).catch((): SendResult => "failed");
      if (result === "unregistered") {
        await admin.from("device_push_tokens").delete().eq("device_id", t.device_id);
      }
      return result;
    }),
  );

  return json({
    sent: results.filter((r) => r === "sent").length,
    failed: results.filter((r) => r === "failed").length,
  });
});
