import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import webpush from "npm:web-push@3";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const VAPID_PUBLIC = Deno.env.get("VAPID_PUBLIC_KEY")!;
const VAPID_PRIVATE = Deno.env.get("VAPID_PRIVATE_KEY")!;

webpush.setVapidDetails("mailto:game@moerderspiel.app", VAPID_PUBLIC, VAPID_PRIVATE);

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

Deno.serve(async (req) => {
  const { type, table, record, old_record } = await req.json();

  let userIds: string[] = [];
  let title = "";
  let body = "";
  let url = "/";

  if (table === "eliminations" && type === "INSERT") {
    userIds = [record.victim_id];
    title = "☠️ Jemand ist hinter dir her!";
    body = "Jemand behauptet, dich eliminiert zu haben. Bestätige oder lehne ab!";
    url = `/game/${record.game_id}`;

  } else if (table === "eliminations" && type === "UPDATE" && record.status === "rejected" && old_record?.status === "pending") {
    userIds = [record.killer_id];
    title = "❌ Kill abgelehnt";
    body = "Dein gemeldeter Kill wurde abgelehnt. Du behältst dein aktuelles Ziel.";
    url = `/game/${record.game_id}`;

  } else if (table === "eliminations" && type === "UPDATE" && record.status === "confirmed") {
    const { data: players } = await supabase
      .from("game_players")
      .select("player_id")
      .eq("game_id", record.game_id)
      .eq("is_alive", true);
    userIds = (players ?? [])
      .map((p: any) => p.player_id)
      .filter((id: string) => id !== record.victim_id);
    title = "💀 Ein Spieler wurde eliminiert!";
    body = "Die Jagd geht weiter — wer ist als Nächstes dran?";
    url = `/game/${record.game_id}`;

  } else if (table === "games" && type === "UPDATE" && record.status === "active" && old_record?.status === "lobby") {
    const { data: players } = await supabase
      .from("game_players")
      .select("player_id")
      .eq("game_id", record.id);
    userIds = (players ?? []).map((p: any) => p.player_id);
    title = "🎮 Das Spiel beginnt!";
    body = `${record.name} ist gestartet. Finde dein Ziel!`;
    url = `/game/${record.id}`;

  } else if (table === "games" && type === "UPDATE" && record.status === "finished") {
    const { data: players } = await supabase
      .from("game_players")
      .select("player_id")
      .eq("game_id", record.id);
    userIds = (players ?? []).map((p: any) => p.player_id);
    title = "🏆 Spiel vorbei!";
    body = `${record.name} ist beendet. Wer hat gewonnen?`;
    url = `/game/${record.id}/over`;

  } else {
    return new Response("no-op", { status: 200 });
  }

  if (userIds.length === 0) return new Response("no recipients", { status: 200 });

  const { data: subs } = await supabase
    .from("push_subscriptions")
    .select("subscription")
    .in("user_id", userIds);

  await Promise.all(
    (subs ?? []).map(({ subscription }: any) =>
      webpush
        .sendNotification(JSON.parse(subscription), JSON.stringify({ title, body, url }))
        .catch((err: any) => {
          console.error('sendNotification failed:', err.statusCode, err.body, err.message);
        })
    )
  );

  return new Response("ok", { status: 200 });
});
