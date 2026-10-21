import { assert, assertEquals } from "jsr:@std/assert@1";
import { createClient } from "npm:@supabase/supabase-js@2.118.0";

const url = Deno.env.get("API_URL")!;
const anonKey = Deno.env.get("ANON_KEY")!;
const admin = createClient(url, Deno.env.get("SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

const ADAM = "11111111-1111-1111-1111-111111111111";
const PARTNER = "22222222-2222-2222-2222-222222222222";

async function signIn(email: string) {
  const client = createClient(url, anonKey, { auth: { persistSession: false } });
  const { data, error } = await client.auth.signInWithPassword({ email, password: "password" });
  if (error) throw error;
  return data.session!.access_token;
}

const adam = await signIn("adam@example.com");
const partner = await signIn("partner@example.com");
const stranger = await signIn("stranger@example.com");

async function call(fn: string, jwt: string, body: unknown) {
  const res = await fetch(`${url}/functions/v1/${fn}`, {
    method: "POST",
    headers: { Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  return { status: res.status, body: await res.json() };
}

function jwtPayload(token: string) {
  const part = token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
  return JSON.parse(atob(part.padEnd(part.length + (4 - part.length % 4) % 4, "=")));
}

async function reset() {
  const { error } = await admin.from("calls").delete().neq("room_name", "seed-room-1");
  if (error) throw error;
}

async function ringing() {
  const res = await call("start-call", adam, { kind: "video" });
  assertEquals(res.status, 200);
  return res.body.call;
}

async function answered() {
  const c = await ringing();
  assertEquals((await call("answer-call", partner, { call_id: c.id })).status, 200);
  return c;
}

Deno.test("AC3: start-call returns a ringing call and a token for its room", async () => {
  await reset();
  const res = await call("start-call", adam, { kind: "video" });
  assertEquals(res.status, 200);
  assertEquals(res.body.call.status, "ringing");
  assertEquals(res.body.call.room_name, res.body.call.id);
  assertEquals(res.body.call.caller_id, ADAM);
  assertEquals(res.body.call.callee_id, PARTNER);
  assertEquals(res.body.livekit_url, "ws://127.0.0.1:7880");
  const payload = jwtPayload(res.body.token);
  assertEquals(payload.video.room, res.body.call.id);
  assertEquals(payload.sub, ADAM);
  const retry = await call("start-call", adam, { kind: "video" });
  assertEquals(retry.body.call.id, res.body.call.id);
  assert(retry.body.token);
});

Deno.test("AC4: stranger is not_paired; partner calling while Adam rings gets incoming", async () => {
  await reset();
  const s = await call("start-call", stranger, { kind: "audio" });
  assertEquals(s.status, 403);
  assertEquals(s.body.error, "not_paired");
  const c = await ringing();
  const p = await call("start-call", partner, { kind: "audio" });
  assertEquals(p.status, 200);
  assertEquals(p.body.incoming, true);
  assertEquals(p.body.call.id, c.id);
  assertEquals(p.body.token, undefined);
});

Deno.test("AC5: answer-call by callee, by caller, and on a cancelled call", async () => {
  await reset();
  const c = await ringing();
  const byCaller = await call("answer-call", adam, { call_id: c.id });
  assertEquals(byCaller.status, 404);
  assertEquals(byCaller.body.error, "call_not_found");
  const res = await call("answer-call", partner, { call_id: c.id });
  assertEquals(res.status, 200);
  assertEquals(res.body.call.status, "answered");
  assert(res.body.call.answered_at);
  assertEquals(jwtPayload(res.body.token).video.room, c.id);
  assertEquals(jwtPayload(res.body.token).sub, PARTNER);
  const again = await call("answer-call", partner, { call_id: c.id });
  assertEquals(again.status, 200);
  assertEquals(again.body.call.answered_at, res.body.call.answered_at);

  await reset();
  const d = await ringing();
  assertEquals((await call("end-call", adam, { call_id: d.id, reason: "cancelled" })).status, 200);
  const late = await call("answer-call", partner, { call_id: d.id });
  assertEquals(late.status, 409);
  assertEquals(late.body.error, "call_not_ringing");
  assertEquals(late.body.status, "cancelled");
});

Deno.test("AC6: end-call follows the state machine and is idempotent", async () => {
  const allowed: [string, () => Promise<{ id: string }>, string][] = [
    ["declined", ringing, partner],
    ["cancelled", ringing, adam],
    ["missed", ringing, adam],
    ["ended", answered, adam],
    ["ended", answered, partner],
  ];
  for (const [reason, setup, jwt] of allowed) {
    await reset();
    const c = await setup();
    const res = await call("end-call", jwt, { call_id: c.id, reason });
    assertEquals(res.status, 200, reason);
    assertEquals(res.body.call.status, reason);
    assert(res.body.call.ended_at);
    const repeat = await call("end-call", jwt, { call_id: c.id, reason });
    assertEquals(repeat.status, 200);
    assertEquals(repeat.body.call, res.body.call);
  }

  await reset();
  const c = await ringing();
  const declinedByCaller = await call("end-call", adam, { call_id: c.id, reason: "declined" });
  assertEquals(declinedByCaller.status, 409);
  assertEquals(declinedByCaller.body.error, "invalid_transition");
  const endedWhileRinging = await call("end-call", partner, { call_id: c.id, reason: "ended" });
  assertEquals(endedWhileRinging.status, 409);
  assertEquals(endedWhileRinging.body.error, "invalid_transition");
  const outsider = await call("end-call", stranger, { call_id: c.id, reason: "ended" });
  assertEquals(outsider.status, 404);
});

Deno.test("AC7: an answered call with an empty room is ended and a new call starts", async () => {
  await reset();
  const old = await answered();
  const res = await call("start-call", partner, { kind: "audio" });
  assertEquals(res.status, 200);
  assert(res.body.call.id !== old.id);
  assertEquals(res.body.call.status, "ringing");
  assertEquals(res.body.call.caller_id, PARTNER);
  const { data } = await admin.from("calls").select().eq("id", old.id).single();
  assertEquals(data.status, "ended");
  assert(data.ended_at);
  await reset();
});

Deno.test("AC8: the start-call token joins the LiveKit room, and start-call is busy while it is occupied", async () => {
  await reset();
  const start = await call("start-call", adam, { kind: "video" });
  const ws = new WebSocket(
    `${start.body.livekit_url}/rtc?access_token=${start.body.token}&protocol=15&auto_subscribe=1`,
  );
  await new Promise((resolve, reject) => {
    ws.onmessage = resolve;
    ws.onerror = reject;
  });
  await call("answer-call", partner, { call_id: start.body.call.id });
  const busy = await call("start-call", partner, { kind: "audio" });
  const closed = new Promise((resolve) => ws.onclose = resolve);
  ws.close();
  await closed;
  assertEquals(busy.status, 409);
  assertEquals(busy.body.error, "busy");
  await reset();
});
