import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import webpush from "npm:web-push@3";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const VAPID_PUBLIC = Deno.env.get("VAPID_PUBLIC_KEY")!;
const VAPID_PRIVATE = Deno.env.get("VAPID_PRIVATE_KEY")!;

webpush.setVapidDetails("mailto:game@moerderspiel.app", VAPID_PUBLIC, VAPID_PRIVATE);

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

Deno.serve(async (req) => {
  const payload = await req.json();
  const { type, table, record, old_record } = payload;
  console.log('[send-push] received:', JSON.stringify({ type, table, record_id: record?.id, status: record?.status, old_status: old_record?.status }));

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

  } else if (table === "kniffel_games" && type === "UPDATE" && record.status === "completed" && old_record?.status === "in_progress") {
    if (record.user_id === "461045f1-83b6-44a1-bd5e-1d3214533d8d") {
      console.log('[send-push] tester completion, skipping notification');
      return new Response("no-op (tester)", { status: 200 });
    }
    // Leaderboard RPC is SECURITY DEFINER — returns username + rank in one call
    const { data: leaderboard } = await supabase.rpc("kniffel_daily_leaderboard");
    const myEntry = (leaderboard ?? []).find((e: any) => e.user_id === record.user_id);
    const rank: number = myEntry?.rank ?? 1;
    const name: string = myEntry?.username ?? record.user_id?.slice(0, 6) ?? "Jemand";

    const rankStr = rank === 1 ? "🥇 Platz 1" : rank === 2 ? "🥈 Platz 2" : rank === 3 ? "🥉 Platz 3" : `Platz ${rank}`;

    const { data: allSubs } = await supabase.from("push_subscriptions").select("user_id");
    userIds = (allSubs ?? []).map((s: any) => s.user_id as string);
    title = `🎲 ${name} hat Kniffel beendet!`;
    body = `${record.final_score} Punkte · ${rankStr}`;
    url = "/kniffel/leaderboard";

  } else if (table === "kniffel_daily_reset" && type === "daily_reset") {
    const { data: allSubs } = await supabase.from("push_subscriptions").select("user_id");
    userIds = (allSubs ?? []).map((s: any) => s.user_id as string);
    title = "🎲 Neue Runde Kniffel!";
    body = "Neuer Tag, neues Glück – wer wird heute Würfelgottheit?";
    url = "/kniffel";

  } else {
    console.log('[send-push] no-op: no matching branch');
    return new Response("no-op", { status: 200 });
  }

  console.log('[send-push] matched branch, userIds:', userIds);
  if (userIds.length === 0) {
    console.log('[send-push] no recipients');
    return new Response("no recipients", { status: 200 });
  }

  const { data: subs, error: subsError } = await supabase
    .from("push_subscriptions")
    .select("subscription")
    .in("user_id", userIds);

  console.log('[send-push] subscriptions found:', subs?.length ?? 0, subsError ? 'error:' + subsError.message : '');

  await Promise.all(
    (subs ?? []).map(({ subscription }: any) =>
      webpush
        .sendNotification(JSON.parse(subscription), JSON.stringify({ title, body, url }))
        .then(() => console.log('[send-push] sent ok'))
        .catch((err: any) => {
          console.error('[send-push] sendNotification failed:', err.statusCode, err.body, err.message);
        })
    )
  );

  return new Response("ok", { status: 200 });
});
