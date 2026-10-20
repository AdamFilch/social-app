import { createClient } from "npm:@supabase/supabase-js@2.118.0";

export const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

export type Call = {
  id: string;
  room_name: string;
  caller_id: string;
  callee_id: string;
  kind: string;
  status: string;
  created_at: string;
  answered_at: string | null;
  ended_at: string | null;
};

export class HttpError extends Error {
  constructor(public status: number, public code: string, public extra: Record<string, unknown> = {}) {
    super(code);
  }
}

export const active = ["ringing", "answered"];

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

export function must<T>({ data, error }: { data: T; error: unknown }): T {
  if (error) throw error;
  return data;
}

export function serve(handler: (me: string, body: Record<string, unknown>) => Promise<unknown>) {
  Deno.serve(async (req) => {
    try {
      if (req.method !== "POST") throw new HttpError(405, "method_not_allowed");
      const jwt = req.headers.get("Authorization")?.replace(/^Bearer /i, "") ?? "";
      const { data, error } = await admin.auth.getUser(jwt);
      if (error || !data.user) throw new HttpError(401, "unauthorized");
      const body = await req.json().catch(() => null);
      if (!body || typeof body !== "object") throw new HttpError(400, "bad_request");
      return json(await handler(data.user.id, body));
    } catch (e) {
      if (e instanceof HttpError) return json({ error: e.code, ...e.extra }, e.status);
      console.error(e);
      return json({ error: "internal" }, 500);
    }
  });
}

export async function loadCall(id: unknown, me: string): Promise<Call> {
  if (typeof id !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)) {
    throw new HttpError(400, "bad_request");
  }
  const call = must(await admin.from("calls").select().eq("id", id).maybeSingle()) as Call | null;
  if (!call || (call.caller_id !== me && call.callee_id !== me)) throw new HttpError(404, "call_not_found");
  return call;
}

export async function transition(id: string, from: string, changes: Partial<Call>): Promise<Call | null> {
  return must(await admin.from("calls").update(changes).eq("id", id).eq("status", from).select().maybeSingle()) as
    | Call
    | null;
}
