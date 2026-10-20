import { active, admin, type Call, HttpError, must, serve, transition } from "../_shared/supabase.ts";
import { livekitUrl, roomHasParticipants, token } from "../_shared/livekit.ts";

serve(async (me, { kind }) => {
  if (kind !== "audio" && kind !== "video") throw new HttpError(400, "bad_request");
  const pair = must(
    await admin.from("pairs").select("user_a, user_b").or(`user_a.eq.${me},user_b.eq.${me}`).maybeSingle(),
  );
  if (!pair) throw new HttpError(403, "not_paired");
  const partner = pair.user_a === me ? pair.user_b : pair.user_a;

  for (let attempt = 0;; attempt++) {
    const current = must(
      await admin.from("calls").select()
        .or(`and(caller_id.eq.${me},callee_id.eq.${partner}),and(caller_id.eq.${partner},callee_id.eq.${me})`)
        .in("status", active).maybeSingle(),
    ) as Call | null;
    if (current?.status === "ringing") {
      if (current.caller_id !== me) return { call: current, incoming: true };
      return { call: current, token: await token(me, current.room_name), livekit_url: livekitUrl };
    }
    if (current) {
      if (await roomHasParticipants(current.room_name)) throw new HttpError(409, "busy");
      await transition(current.id, "answered", { status: "ended", ended_at: new Date().toISOString() });
    }
    const id = crypto.randomUUID();
    const { data: call, error } = await admin.from("calls")
      .insert({ id, room_name: id, caller_id: me, callee_id: partner, kind, status: "ringing" }).select().single();
    if (!error) return { call, token: await token(me, id), livekit_url: livekitUrl };
    if (error.code !== "23505" || attempt > 0) throw error;
  }
});
