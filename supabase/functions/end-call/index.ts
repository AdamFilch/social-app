import { active, HttpError, loadCall, serve, transition } from "../_shared/supabase.ts";

const rules: Record<string, [from: string, role: "caller_id" | "callee_id" | null]> = {
  declined: ["ringing", "callee_id"],
  cancelled: ["ringing", "caller_id"],
  missed: ["ringing", "caller_id"],
  ended: ["answered", null],
};

serve(async (me, { call_id, reason }) => {
  if (typeof reason !== "string" || !Object.hasOwn(rules, reason)) throw new HttpError(400, "bad_request");
  const call = await loadCall(call_id, me);
  if (!active.includes(call.status)) return { call };
  const [from, role] = rules[reason];
  if (call.status !== from || (role && call[role] !== me)) throw new HttpError(409, "invalid_transition");
  const updated = await transition(call.id, from, { status: reason, ended_at: new Date().toISOString() });
  if (updated) return { call: updated };
  const latest = await loadCall(call_id, me);
  if (!active.includes(latest.status)) return { call: latest };
  throw new HttpError(409, "invalid_transition");
});
