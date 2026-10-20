import { AccessToken, RoomServiceClient } from "npm:livekit-server-sdk@2.19.1";

export const livekitUrl = Deno.env.get("LIVEKIT_URL")!;
const key = Deno.env.get("LIVEKIT_API_KEY")!;
const secret = Deno.env.get("LIVEKIT_API_SECRET")!;
const rooms = new RoomServiceClient(Deno.env.get("LIVEKIT_API_URL") ?? livekitUrl.replace(/^ws/, "http"), key, secret);

export function token(identity: string, room: string) {
  const at = new AccessToken(key, secret, { identity, ttl: "2h" });
  at.addGrant({ room, roomJoin: true, canPublish: true, canSubscribe: true });
  return at.toJwt();
}

export async function roomHasParticipants(room: string) {
  try {
    return (await rooms.listParticipants(room)).length > 0;
  } catch (e) {
    if ((e as { code?: string }).code === "not_found") return false;
    throw e;
  }
}
