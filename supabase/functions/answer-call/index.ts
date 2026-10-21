import { HttpError, loadCall, serve, transition } from "../_shared/supabase.ts";
import { livekitUrl, token } from "../_shared/livekit.ts";

serve(async (me, { call_id }) => {
  let call = await loadCall(call_id, me);
  if (call.callee_id !== me) throw new HttpError(404, "call_not_found");
  if (call.status === "ringing") {
    call = await transition(call.id, "ringing", { status: "answered", answered_at: new Date().toISOString() }) ??
      await loadCall(call_id, me);
  }
  if (call.status !== "answered") throw new HttpError(409, "call_not_ringing", { status: call.status });
  return { call, token: await token(me, call.room_name), livekit_url: livekitUrl };
});
