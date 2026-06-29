-- ============================================================
-- 023: Doppelagent / Codewort-Spiel
--
-- A) codename_words      – Wortpool nach Kategorien
-- B) codename_sessions   – Spielsitzungen mit Code
-- C) codename_players    – Spieler je Sitzung (inkl. Impostor-Flag)
-- D) codename_clues      – Hinweise je Runde (Full-Online-Modus)
-- E) codename_votes      – Abstimmungen je Runde
-- F) RLS-Policies
-- G) codename_create_session  – Session erstellen
-- H) codename_join            – Per Code beitreten
-- I) codename_leave           – Lobby verlassen
-- J) codename_start           – Spiel starten (nur Host)
-- K) codename_submit_clue     – Hinweis einreichen
-- L) codename_submit_vote     – Abstimmung einreichen
-- M) codename_impostor_guess  – Impostor rät das Codewort
-- ============================================================

-- ── A: Wortpool ───────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.codename_words (
  id       uuid NOT NULL DEFAULT gen_random_uuid(),
  word     text NOT NULL,
  category text NOT NULL DEFAULT 'all',
  CONSTRAINT codename_words_pkey PRIMARY KEY (id)
);

-- Startwörter (Agenten-/Thriller-Thema)
INSERT INTO public.codename_words (word, category) VALUES
  ('Tresor',            'agenten'),
  ('Bunker',            'agenten'),
  ('Akte',              'agenten'),
  ('Schalldämpfer',     'agenten'),
  ('Codebuch',          'agenten'),
  ('Safehouse',         'agenten'),
  ('Verhör',            'agenten'),
  ('Kontaktmann',       'agenten'),
  ('Tarnung',           'agenten'),
  ('Lauschangriff',     'agenten'),
  ('Botschaft',         'orte'),
  ('Zollkontrolle',     'orte'),
  ('Flughafen',         'orte'),
  ('Hotel',             'orte'),
  ('Hafen',             'orte'),
  ('Museum',            'orte'),
  ('Kasino',            'orte'),
  ('Bibliothek',        'orte'),
  ('Kanalisation',      'orte'),
  ('Dach',              'orte'),
  ('Revolver',          'objekte'),
  ('Koffer',            'objekte'),
  ('Schlüssel',         'objekte'),
  ('USB-Stick',         'objekte'),
  ('Bombe',             'objekte'),
  ('Nachtsichtbrille',  'objekte'),
  ('Perücke',           'objekte'),
  ('Messer',            'objekte'),
  ('Mikrofon',          'objekte'),
  ('Pass',              'objekte');

-- Weitere Wörter (gemischte Alltagskategorien)
INSERT INTO public.codename_words (word, category) VALUES
  -- Essen
  ('Pizza',             'essen'),
  ('Hamburger',         'essen'),
  ('Eiscreme',          'essen'),
  ('Kaffee',            'essen'),
  ('Spaghetti',         'essen'),
  ('Sandwich',          'essen'),
  ('Schokolade',        'essen'),
  ('Pfannkuchen',       'essen'),
  ('Sushi',             'essen'),
  ('Tacos',             'essen'),
  ('Popcorn',           'essen'),
  ('Banane',            'essen'),
  ('Orangensaft',       'essen'),
  ('Kekse',             'essen'),
  ('Pommes',            'essen'),
  -- Tiere
  ('Elefant',           'tiere'),
  ('Löwe',              'tiere'),
  ('Pinguin',           'tiere'),
  ('Delfin',            'tiere'),
  ('Affe',              'tiere'),
  ('Giraffe',           'tiere'),
  ('Hase',              'tiere'),
  ('Pferd',             'tiere'),
  ('Hai',               'tiere'),
  ('Schmetterling',     'tiere'),
  ('Eule',              'tiere'),
  ('Bär',               'tiere'),
  ('Känguru',           'tiere'),
  -- Alltag (Gegenstände)
  ('Zahnbürste',        'alltag'),
  ('Regenschirm',       'alltag'),
  ('Sonnenbrille',      'alltag'),
  ('Kissen',            'alltag'),
  ('Geldbeutel',        'alltag'),
  ('Spiegel',           'alltag'),
  ('Uhr',               'alltag'),
  ('Lampe',             'alltag'),
  ('Rucksack',          'alltag'),
  ('Kopfhörer',         'alltag'),
  -- Orte (Ergänzung)
  ('Strand',            'orte'),
  ('Krankenhaus',       'orte'),
  ('Fitnessstudio',     'orte'),
  ('Aquarium',          'orte'),
  ('Freizeitpark',      'orte'),
  ('Supermarkt',        'orte'),
  ('Bäckerei',          'orte'),
  -- Konzepte
  ('Déjà-vu',           'konzepte'),
  ('Gruppenzwang',      'konzepte'),
  ('Komfortzone',       'konzepte'),
  ('Guilty Pleasure',   'konzepte'),
  ('Hausaufgaben',      'konzepte'),
  ('Kaffeepause',       'konzepte'),
  ('Deadline',          'konzepte'),
  -- Popkultur
  ('Star Wars',         'popkultur'),
  ('Harry Potter',      'popkultur'),
  ('Der König der Löwen', 'popkultur'),
  ('Jurassic Park',     'popkultur'),
  ('Batman',            'popkultur'),
  ('Die Eiskönigin',    'popkultur'),
  -- Städte & Länder
  ('Paris',             'laender'),
  ('New York',          'laender'),
  ('Tokio',             'laender'),
  ('London',            'laender'),
  ('Italien',           'laender'),
  ('Australien',        'laender'),
  ('Brasilien',         'laender'),
  ('Ägypten',           'laender');

-- ── B: codename_sessions ──────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.codename_sessions (
  id            uuid        NOT NULL DEFAULT gen_random_uuid(),
  code          text        NOT NULL UNIQUE,
  name          text        NOT NULL,
  host_id       uuid        NOT NULL REFERENCES public.profiles(id),
  codename      text,                                   -- NULL bis Start
  word_category text        NOT NULL DEFAULT 'all',
  mode          text        NOT NULL DEFAULT 'online',  -- online | hybrid
  status        text        NOT NULL DEFAULT 'lobby',   -- lobby | active | completed
  phase         text        NOT NULL DEFAULT 'clue',    -- clue | vote  (nur aktiv)
  current_round integer     NOT NULL DEFAULT 1,
  winner        text,                                   -- 'players' | 'impostor'
  created_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT codename_sessions_pkey PRIMARY KEY (id),
  CONSTRAINT codename_sessions_status_check
    CHECK (status IN ('lobby','active','completed')),
  CONSTRAINT codename_sessions_phase_check
    CHECK (phase IN ('clue','vote'))
);

-- ── C: codename_players ───────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.codename_players (
  id           uuid        NOT NULL DEFAULT gen_random_uuid(),
  session_id   uuid        NOT NULL REFERENCES public.codename_sessions(id) ON DELETE CASCADE,
  player_id    uuid        NOT NULL REFERENCES public.profiles(id),
  is_impostor  boolean     NOT NULL DEFAULT false,
  is_eliminated boolean    NOT NULL DEFAULT false,
  turn_order   integer,                               -- gesetzt bei Start
  joined_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT codename_players_pkey PRIMARY KEY (id),
  CONSTRAINT codename_players_session_player_uniq UNIQUE (session_id, player_id)
);

-- ── D: codename_clues ─────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.codename_clues (
  id           uuid        NOT NULL DEFAULT gen_random_uuid(),
  session_id   uuid        NOT NULL REFERENCES public.codename_sessions(id) ON DELETE CASCADE,
  player_id    uuid        NOT NULL REFERENCES public.profiles(id),
  round        integer     NOT NULL,
  clue_text    text        NOT NULL,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT codename_clues_pkey PRIMARY KEY (id),
  CONSTRAINT codename_clues_session_player_round_uniq UNIQUE (session_id, player_id, round)
);

-- ── E: codename_votes ─────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.codename_votes (
  id           uuid        NOT NULL DEFAULT gen_random_uuid(),
  session_id   uuid        NOT NULL REFERENCES public.codename_sessions(id) ON DELETE CASCADE,
  voter_id     uuid        NOT NULL REFERENCES public.profiles(id),
  voted_for_id uuid        NOT NULL REFERENCES public.profiles(id),
  round        integer     NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT codename_votes_pkey PRIMARY KEY (id),
  CONSTRAINT codename_votes_session_voter_round_uniq UNIQUE (session_id, voter_id, round)
);

-- ── F: RLS ───────────────────────────────────────────────────

ALTER TABLE public.codename_words     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.codename_sessions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.codename_players   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.codename_clues     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.codename_votes     ENABLE ROW LEVEL SECURITY;

-- Hilfsfunktion (SECURITY DEFINER → bypasses RLS, verhindert Selbstrekursion)
CREATE OR REPLACE FUNCTION public._codename_is_member(p_session_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.codename_players
    WHERE session_id = p_session_id AND player_id = auth.uid()
  );
$$;

-- Wortpool: jeder eingeloggte User darf lesen
CREATE POLICY "authenticated users can view words"
  ON public.codename_words FOR SELECT TO authenticated USING (true);

-- Sessions: nur Mitspieler dürfen lesen
CREATE POLICY "session members can view sessions"
  ON public.codename_sessions FOR SELECT TO authenticated
  USING (public._codename_is_member(id));

-- Players: SECURITY DEFINER-Funktion verhindert Selbstrekursion
CREATE POLICY "session members can view players"
  ON public.codename_players FOR SELECT TO authenticated
  USING (public._codename_is_member(session_id));

-- Clues: Mitspieler der selben Session
CREATE POLICY "session members can view clues"
  ON public.codename_clues FOR SELECT TO authenticated
  USING (public._codename_is_member(session_id));

-- Votes: Mitspieler der selben Session
CREATE POLICY "session members can view votes"
  ON public.codename_votes FOR SELECT TO authenticated
  USING (public._codename_is_member(session_id));

-- service_role braucht Vollzugriff (Edge Functions / pg_net)
GRANT ALL ON public.codename_words     TO service_role;
GRANT ALL ON public.codename_sessions  TO service_role;
GRANT ALL ON public.codename_players   TO service_role;
GRANT ALL ON public.codename_clues     TO service_role;
GRANT ALL ON public.codename_votes     TO service_role;

-- authenticated braucht SELECT (RLS allein reicht nicht)
GRANT SELECT ON public.codename_words     TO authenticated;
GRANT SELECT ON public.codename_sessions  TO authenticated;
GRANT SELECT ON public.codename_players   TO authenticated;
GRANT SELECT ON public.codename_clues     TO authenticated;
GRANT SELECT ON public.codename_votes     TO authenticated;

-- ── G: codename_create_session ────────────────────────────────

CREATE OR REPLACE FUNCTION public.codename_create_session(
  p_name     text,
  p_category text DEFAULT 'all',
  p_mode     text DEFAULT 'online'
) RETURNS public.codename_sessions LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_code    text;
  v_session public.codename_sessions;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF trim(p_name) = '' THEN RAISE EXCEPTION 'Name cannot be empty'; END IF;

  LOOP
    v_code := upper(substring(md5(random()::text || clock_timestamp()::text), 1, 6));
    EXIT WHEN NOT EXISTS (SELECT 1 FROM codename_sessions WHERE code = v_code);
  END LOOP;

  INSERT INTO codename_sessions (code, name, host_id, word_category, mode)
  VALUES (v_code, trim(p_name), auth.uid(), p_category, p_mode)
  RETURNING * INTO v_session;

  INSERT INTO codename_players (session_id, player_id)
  VALUES (v_session.id, auth.uid());

  RETURN v_session;
END;
$$;
GRANT EXECUTE ON FUNCTION public.codename_create_session TO authenticated;

-- ── H: codename_join ──────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.codename_join(
  p_code text
) RETURNS public.codename_sessions LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_session public.codename_sessions;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  SELECT * INTO v_session
  FROM codename_sessions
  WHERE code = upper(trim(p_code));

  IF NOT FOUND        THEN RAISE EXCEPTION 'Session nicht gefunden'; END IF;
  IF v_session.status != 'lobby' THEN RAISE EXCEPTION 'Spiel bereits gestartet'; END IF;

  -- Bereits Mitglied → einfach zurückgeben
  IF EXISTS (
    SELECT 1 FROM codename_players
    WHERE session_id = v_session.id AND player_id = auth.uid()
  ) THEN RETURN v_session; END IF;

  INSERT INTO codename_players (session_id, player_id)
  VALUES (v_session.id, auth.uid());

  RETURN v_session;
END;
$$;
GRANT EXECUTE ON FUNCTION public.codename_join TO authenticated;

-- ── I: codename_leave ─────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.codename_leave(
  p_session_id uuid
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_session public.codename_sessions;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  SELECT * INTO v_session FROM codename_sessions WHERE id = p_session_id;
  IF NOT FOUND OR v_session.status != 'lobby' THEN RETURN; END IF;

  DELETE FROM codename_players
  WHERE session_id = p_session_id AND player_id = auth.uid();

  -- War es der Host?
  IF v_session.host_id = auth.uid() THEN
    IF NOT EXISTS (SELECT 1 FROM codename_players WHERE session_id = p_session_id) THEN
      DELETE FROM codename_sessions WHERE id = p_session_id;
    ELSE
      UPDATE codename_sessions
      SET host_id = (
        SELECT player_id FROM codename_players
        WHERE session_id = p_session_id ORDER BY joined_at LIMIT 1
      )
      WHERE id = p_session_id;
    END IF;
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.codename_leave TO authenticated;

-- ── J: codename_start ─────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.codename_start(
  p_session_id uuid
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_session    public.codename_sessions;
  v_player_ids uuid[];
  v_cnt        integer;
  v_word       text;
  i            integer;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  SELECT * INTO v_session FROM codename_sessions WHERE id = p_session_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Session nicht gefunden'; END IF;
  IF v_session.host_id != auth.uid() THEN RAISE EXCEPTION 'Nur der Host kann starten'; END IF;
  IF v_session.status  != 'lobby'    THEN RAISE EXCEPTION 'Spiel bereits gestartet'; END IF;

  SELECT array_agg(player_id ORDER BY random()), COUNT(*)
  INTO v_player_ids, v_cnt
  FROM codename_players WHERE session_id = p_session_id;

  IF v_cnt < 3 THEN RAISE EXCEPTION 'Mindestens 3 Spieler erforderlich'; END IF;

  -- Zufälliges Wort aus der gewählten Kategorie
  IF v_session.word_category = 'all' THEN
    SELECT word INTO v_word FROM codename_words ORDER BY random() LIMIT 1;
  ELSE
    SELECT word INTO v_word FROM codename_words
    WHERE category = v_session.word_category ORDER BY random() LIMIT 1;
  END IF;
  IF v_word IS NULL THEN RAISE EXCEPTION 'Keine Wörter für diese Kategorie'; END IF;

  -- Zufälliger Impostor + Rundenreihenfolge
  FOR i IN 1..v_cnt LOOP
    UPDATE codename_players
    SET turn_order  = i,
        is_impostor = (i = 1)   -- erster in zufälliger Reihenfolge = Impostor
    WHERE session_id = p_session_id AND player_id = v_player_ids[i];
  END LOOP;

  UPDATE codename_sessions
  SET status   = 'active',
      phase    = 'clue',
      codename = v_word
  WHERE id = p_session_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.codename_start TO authenticated;

-- ── K: codename_submit_clue ───────────────────────────────────

CREATE OR REPLACE FUNCTION public.codename_submit_clue(
  p_session_id uuid,
  p_clue       text
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_session    public.codename_sessions;
  v_active_cnt integer;
  v_clue_cnt   integer;
  v_turn_owner uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF trim(p_clue) = '' THEN RAISE EXCEPTION 'Hinweis darf nicht leer sein'; END IF;

  SELECT * INTO v_session FROM codename_sessions WHERE id = p_session_id FOR UPDATE;
  IF NOT FOUND OR v_session.status != 'active' THEN RAISE EXCEPTION 'Session nicht aktiv'; END IF;
  IF v_session.phase != 'clue' THEN RAISE EXCEPTION 'Jetzt ist Abstimmungsphase'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM codename_players
    WHERE session_id = p_session_id AND player_id = auth.uid() AND NOT is_eliminated
  ) THEN RAISE EXCEPTION 'Nicht aktiver Spieler'; END IF;

  SELECT COUNT(*) INTO v_active_cnt
  FROM codename_players WHERE session_id = p_session_id AND NOT is_eliminated;

  SELECT COUNT(*) INTO v_clue_cnt
  FROM codename_clues WHERE session_id = p_session_id AND round = v_session.current_round;

  -- Dran? = Spieler an Position (v_clue_cnt + 1) nach turn_order
  SELECT player_id INTO v_turn_owner
  FROM codename_players
  WHERE session_id = p_session_id AND NOT is_eliminated
  ORDER BY turn_order
  LIMIT 1 OFFSET v_clue_cnt;

  IF v_turn_owner IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Du bist nicht dran'; END IF;

  INSERT INTO codename_clues (session_id, player_id, round, clue_text)
  VALUES (p_session_id, auth.uid(), v_session.current_round, trim(p_clue));

  -- Alle aktiven Spieler haben Hinweis gegeben → Abstimmungsphase
  IF v_clue_cnt + 1 >= v_active_cnt THEN
    UPDATE codename_sessions SET phase = 'vote' WHERE id = p_session_id;
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.codename_submit_clue TO authenticated;

-- ── N: _codename_award_impostor (intern) ─────────────────────

CREATE OR REPLACE FUNCTION public._codename_award_impostor(p_session_id uuid, p_impostor_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_cnt integer;
BEGIN
  SELECT COUNT(*) INTO v_cnt FROM public.codename_players WHERE session_id = p_session_id;
  IF v_cnt >= 7 THEN
    INSERT INTO public.user_credits (user_id, bronze_credits)
    VALUES (p_impostor_id, 1)
    ON CONFLICT (user_id) DO UPDATE
    SET bronze_credits = public.user_credits.bronze_credits + 1;
  END IF;
END;
$$;

-- ── L: codename_submit_vote ───────────────────────────────────

CREATE OR REPLACE FUNCTION public.codename_submit_vote(
  p_session_id   uuid,
  p_voted_for_id uuid
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_session    public.codename_sessions;
  v_active_cnt integer;
  v_vote_cnt   integer;
  v_top_id     uuid;
  v_top_cnt    integer;
  v_impostor_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF p_voted_for_id = auth.uid() THEN RAISE EXCEPTION 'Nicht für dich selbst wählen'; END IF;

  SELECT * INTO v_session FROM codename_sessions WHERE id = p_session_id FOR UPDATE;
  IF NOT FOUND OR v_session.status != 'active' THEN RAISE EXCEPTION 'Session nicht aktiv'; END IF;
  IF v_session.phase != 'vote' THEN RAISE EXCEPTION 'Jetzt ist Hinweis-Phase'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM codename_players
    WHERE session_id = p_session_id AND player_id = auth.uid() AND NOT is_eliminated
  ) THEN RAISE EXCEPTION 'Nicht aktiver Spieler'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM codename_players
    WHERE session_id = p_session_id AND player_id = p_voted_for_id AND NOT is_eliminated
  ) THEN RAISE EXCEPTION 'Ziel nicht aktiver Spieler'; END IF;

  -- Upsert: Stimme kann geändert werden
  INSERT INTO codename_votes (session_id, voter_id, voted_for_id, round)
  VALUES (p_session_id, auth.uid(), p_voted_for_id, v_session.current_round)
  ON CONFLICT (session_id, voter_id, round)
  DO UPDATE SET voted_for_id = EXCLUDED.voted_for_id;

  -- Alle aktiven Spieler haben abgestimmt?
  SELECT COUNT(*) INTO v_active_cnt
  FROM codename_players WHERE session_id = p_session_id AND NOT is_eliminated;

  SELECT COUNT(*) INTO v_vote_cnt
  FROM codename_votes WHERE session_id = p_session_id AND round = v_session.current_round;

  IF v_vote_cnt < v_active_cnt THEN RETURN; END IF;

  -- Meistgewählten ermitteln
  SELECT voted_for_id, COUNT(*) INTO v_top_id, v_top_cnt
  FROM codename_votes WHERE session_id = p_session_id AND round = v_session.current_round
  GROUP BY voted_for_id ORDER BY COUNT(*) DESC LIMIT 1;

  -- Keine klare Mehrheit → nächste Runde ohne Eliminierung
  IF v_top_cnt <= v_active_cnt / 2 THEN
    UPDATE codename_sessions
    SET phase = 'clue', current_round = current_round + 1
    WHERE id = p_session_id;
    RETURN;
  END IF;

  -- Spieler eliminieren
  UPDATE codename_players
  SET is_eliminated = true
  WHERE session_id = p_session_id AND player_id = v_top_id;

  -- War es der Impostor? → Spieler gewinnen
  IF EXISTS (
    SELECT 1 FROM codename_players
    WHERE session_id = p_session_id AND player_id = v_top_id AND is_impostor
  ) THEN
    UPDATE codename_sessions SET status = 'completed', winner = 'players' WHERE id = p_session_id;
    RETURN;
  END IF;

  -- Nur noch Impostor übrig? → Impostor gewinnt
  SELECT COUNT(*) INTO v_active_cnt
  FROM codename_players
  WHERE session_id = p_session_id AND NOT is_eliminated AND NOT is_impostor;

  IF v_active_cnt <= 1 THEN
    UPDATE codename_sessions SET status = 'completed', winner = 'impostor' WHERE id = p_session_id;
    SELECT player_id INTO v_impostor_id FROM codename_players
    WHERE session_id = p_session_id AND is_impostor LIMIT 1;
    PERFORM public._codename_award_impostor(p_session_id, v_impostor_id);
    RETURN;
  END IF;

  -- Spiel geht weiter
  UPDATE codename_sessions
  SET phase = 'clue', current_round = current_round + 1
  WHERE id = p_session_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.codename_submit_vote TO authenticated;

-- ── M: codename_impostor_guess ────────────────────────────────

CREATE OR REPLACE FUNCTION public.codename_impostor_guess(
  p_session_id uuid,
  p_guess      text
) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_session public.codename_sessions;
  v_correct boolean;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  SELECT * INTO v_session FROM codename_sessions WHERE id = p_session_id FOR UPDATE;
  IF NOT FOUND OR v_session.status != 'active' THEN RAISE EXCEPTION 'Session nicht aktiv'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM codename_players
    WHERE session_id = p_session_id AND player_id = auth.uid()
      AND is_impostor AND NOT is_eliminated
  ) THEN RAISE EXCEPTION 'Du bist nicht der Impostor'; END IF;

  v_correct := lower(trim(p_guess)) = lower(trim(v_session.codename));

  IF v_correct THEN
    UPDATE codename_sessions
    SET status = 'completed', winner = 'impostor'
    WHERE id = p_session_id;
    PERFORM public._codename_award_impostor(p_session_id, auth.uid());
  END IF;

  RETURN v_correct;
END;
$$;
GRANT EXECUTE ON FUNCTION public.codename_impostor_guess TO authenticated;
