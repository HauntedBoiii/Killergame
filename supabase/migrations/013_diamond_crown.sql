-- ============================================================
-- 013: Diamant-Rarität & Kronenmesser-Würfel
-- Ändert: loot_items CHECK constraint (+ 'diamond')
-- Neu:    loot_items Eintrag 'Kronenmesser' (dice / crown / diamond)
-- Ändert: open_lootbox – Diamant 0.5 %, Gold 9.5 % (war 10 %)
--         Bei bereits besitzendem Diamant-Item → Gold-Credit
-- ============================================================

-- 1. CHECK-Constraint auf loot_items erweitern ---------------

ALTER TABLE public.loot_items
  DROP CONSTRAINT loot_items_rarity_check;

ALTER TABLE public.loot_items
  ADD CONSTRAINT loot_items_rarity_check
  CHECK (rarity IN ('bronze', 'silver', 'gold', 'diamond'));

-- 2. Kronenmesser eintragen ----------------------------------

INSERT INTO public.loot_items (item_type, design_key, name, rarity, sort_order)
VALUES ('dice', 'crown', 'Kronenmesser', 'diamond', 100);

-- 3. open_lootbox mit Diamant-Tier ----------------------------
--    Bronze 70 % | Silber 20 % | Gold 9.5 % | Diamant 0.5 %
--    Diamant hat keine Credits → bei "already owned" → 1 Gold-Credit

CREATE OR REPLACE FUNCTION public.open_lootbox(p_lootbox_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id    uuid := auth.uid();
  v_box        public.user_lootboxes;
  v_roll       float;
  v_rarity     text;
  v_credit_rar text;
  v_item       public.loot_items;
BEGIN
  SELECT * INTO v_box
  FROM public.user_lootboxes
  WHERE id = p_lootbox_id AND user_id = v_user_id AND status != 'opened'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Lootbox nicht gefunden oder bereits geöffnet';
  END IF;

  IF v_box.available_at > now() THEN
    RAISE EXCEPTION 'Lootbox noch nicht verfügbar';
  END IF;

  PERFORM public._ensure_loot_rows(v_user_id);

  v_roll   := random();
  v_rarity := CASE
    WHEN v_roll < 0.700 THEN 'bronze'
    WHEN v_roll < 0.900 THEN 'silver'
    WHEN v_roll < 0.995 THEN 'gold'
    ELSE                      'diamond'
  END;

  SELECT li.* INTO v_item
  FROM public.loot_items li
  WHERE li.rarity = v_rarity
    AND NOT EXISTS (
      SELECT 1 FROM public.user_inventory ui
      WHERE ui.user_id = v_user_id AND ui.item_id = li.id
    )
  ORDER BY random()
  LIMIT 1;

  UPDATE public.user_lootboxes
  SET status = 'opened', opened_at = now()
  WHERE id = p_lootbox_id;

  IF v_item.id IS NULL THEN
    -- Diamant hat keine Credits → Trostpreis: 1 Gold-Credit
    v_credit_rar := CASE WHEN v_rarity = 'diamond' THEN 'gold' ELSE v_rarity END;

    IF v_credit_rar = 'bronze' THEN
      UPDATE public.user_credits SET bronze_credits = bronze_credits + 1 WHERE user_id = v_user_id;
    ELSIF v_credit_rar = 'silver' THEN
      UPDATE public.user_credits SET silver_credits = silver_credits + 1 WHERE user_id = v_user_id;
    ELSE
      UPDATE public.user_credits SET gold_credits = gold_credits + 1 WHERE user_id = v_user_id;
    END IF;

    RETURN jsonb_build_object('type', 'credit', 'rarity', v_credit_rar);
  ELSE
    INSERT INTO public.user_inventory (user_id, item_id) VALUES (v_user_id, v_item.id);

    RETURN jsonb_build_object(
      'type',   'item',
      'rarity', v_rarity,
      'item',   jsonb_build_object(
        'item_id',    v_item.id,
        'design_key', v_item.design_key,
        'item_type',  v_item.item_type,
        'name',       v_item.name,
        'rarity',     v_item.rarity
      )
    );
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.open_lootbox TO authenticated;
