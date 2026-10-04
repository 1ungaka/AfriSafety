const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Accepts 1–10 distinct UUIDs, else null. */
export function parseAlertIds(body: unknown): string[] | null {
  if (typeof body !== "object" || body === null) return null;
  const ids = (body as { alert_ids?: unknown }).alert_ids;
  if (!Array.isArray(ids) || ids.length < 1 || ids.length > 10) return null;
  if (!ids.every((id) => typeof id === "string" && UUID.test(id))) return null;
  return [...new Set(ids as string[])];
}
