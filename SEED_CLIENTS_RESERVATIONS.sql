-- ════════════════════════════════════════════════════════════════
--  FLEET MANAGER — Données de test : Clients + Réservations
--  À exécuter dans Supabase → SQL Editor → Run
--  ⚠️  Exécuter après avoir créé au moins 1 véhicule via l'admin
-- ════════════════════════════════════════════════════════════════

-- ── 1. SUPPRIMER LES ANCIENS CLIENTS DE TEST (si re-run) ────────
DELETE FROM reservations WHERE user_id IN (
  SELECT id FROM users WHERE email LIKE '%@test-fleet.sn'
);
DELETE FROM users WHERE email LIKE '%@test-fleet.sn';

-- ── 2. INSÉRER LES 5 CLIENTS DE TEST ───────────────────────────

INSERT INTO users (email, password_hash, first_name, last_name, phone, role, doc_status) VALUES

-- Client 1 : Dossier complet et approuvé → peut réserver
('amadou.diallo@test-fleet.sn',
 'pbkdf2:sha256:1000000$swBSTXYV4nUm5FRG$290c3d6278919eccb23c8189087097e22d17a1dbed592747433955c433fc234b',
 'Amadou', 'Diallo', '771234567', 'client', 'approuve'),

-- Client 2 : Dossier approuvé → peut réserver
('fatou.ndiaye@test-fleet.sn',
 'pbkdf2:sha256:1000000$SU5vSkIm5R9xzRtr$4cb9b7ce2968fe3afe30eb32f9571b73b6f855199694f2d1d8e73325c8534dc5',
 'Fatou', 'Ndiaye', '772345678', 'client', 'approuve'),

-- Client 3 : Dossier en attente → en cours de validation
('moussa.ba@test-fleet.sn',
 'pbkdf2:sha256:1000000$fjFrM9MtyY85h6Mk$3cdc6de9942f8d89f0c16764a56496404608e64ef67f826d58d8de930a8c2881',
 'Moussa', 'Ba', '773456789', 'client', 'en_attente'),

-- Client 4 : Dossier approuvé
('aissatou.sow@test-fleet.sn',
 'pbkdf2:sha256:1000000$5sZF55WXtk97x1vz$35248155427e56fe42f131756d59f76b87043e0ae1b7f4aa2898048c95023d14',
 'Aissatou', 'Sow', '774567890', 'client', 'approuve'),

-- Client 5 : Aucun document → nouveau compte
('ibrahima.fall@test-fleet.sn',
 'pbkdf2:sha256:1000000$FYpXwLcSrUGv9N8R$5e74373c4c65485716569eca192fb7f15bd1e57f9c56cb85dabe86d483db2997',
 'Ibrahima', 'Fall', '775678901', 'client', 'aucun');

-- ── 3. INSÉRER DES RÉSERVATIONS ─────────────────────────────────
-- Note : Remplacer les vehicle_id par les vrais IDs de vos véhicules
-- Pour voir les IDs : SELECT id, brand, model FROM vehicles;

-- On récupère les IDs dynamiquement
DO $$
DECLARE
  v1 INT; v2 INT; v3 INT;
  u1 INT; u2 INT; u3 INT; u4 INT;
  r1 INT; r2 INT; r3 INT;
BEGIN
  -- Récupérer les IDs des véhicules (les 3 premiers disponibles)
  SELECT id INTO v1 FROM vehicles WHERE status = 'disponible' ORDER BY id LIMIT 1;
  SELECT id INTO v2 FROM vehicles WHERE status = 'disponible' ORDER BY id OFFSET 1 LIMIT 1;
  SELECT id INTO v3 FROM vehicles WHERE status = 'disponible' ORDER BY id OFFSET 2 LIMIT 1;
  
  -- Si pas assez de véhicules, utiliser le premier pour tous
  IF v2 IS NULL THEN v2 := v1; END IF;
  IF v3 IS NULL THEN v3 := v1; END IF;

  -- Récupérer les IDs des clients de test
  SELECT id INTO u1 FROM users WHERE email = 'amadou.diallo@test-fleet.sn';
  SELECT id INTO u2 FROM users WHERE email = 'fatou.ndiaye@test-fleet.sn';
  SELECT id INTO u3 FROM users WHERE email = 'aissatou.sow@test-fleet.sn';
  SELECT id INTO u4 FROM users WHERE email = 'moussa.ba@test-fleet.sn';

  -- Réservation 1 : Terminée (Amadou - il y a 1 mois)
  IF v1 IS NOT NULL AND u1 IS NOT NULL THEN
    INSERT INTO reservations (user_id, vehicle_id, date_start, date_end, total_price, status, notes)
    VALUES (u1, v1,
      CURRENT_DATE - INTERVAL '35 days',
      CURRENT_DATE - INTERVAL '30 days',
      (SELECT price_per_day * 5 FROM vehicles WHERE id = v1),
      'terminee',
      'Voyage d''affaires Dakar-Thiès')
    RETURNING id INTO r1;

    -- Facture pour la réservation terminée
    IF r1 IS NOT NULL THEN
      INSERT INTO invoices (reservation_id, user_id, amount, status)
      VALUES (r1, u1, (SELECT price_per_day * 5 FROM vehicles WHERE id = v1), 'emise');
    END IF;
  END IF;

  -- Réservation 2 : Confirmée en cours (Fatou - aujourd'hui)
  IF v2 IS NOT NULL AND u2 IS NOT NULL THEN
    INSERT INTO reservations (user_id, vehicle_id, date_start, date_end, total_price, status, notes)
    VALUES (u2, v2,
      CURRENT_DATE,
      CURRENT_DATE + INTERVAL '3 days',
      (SELECT price_per_day * 3 FROM vehicles WHERE id = v2),
      'confirmee',
      'Déplacement familial');
  END IF;

  -- Réservation 3 : En attente de confirmation (Aissatou - demain)
  IF v3 IS NOT NULL AND u3 IS NOT NULL THEN
    INSERT INTO reservations (user_id, vehicle_id, date_start, date_end, total_price, status, notes)
    VALUES (u3, v3,
      CURRENT_DATE + INTERVAL '2 days',
      CURRENT_DATE + INTERVAL '5 days',
      (SELECT price_per_day * 3 FROM vehicles WHERE id = v3),
      'en_attente',
      '');
  END IF;

  -- Réservation 4 : Terminée (Amadou - il y a 2 mois)
  IF v1 IS NOT NULL AND u1 IS NOT NULL THEN
    INSERT INTO reservations (user_id, vehicle_id, date_start, date_end, total_price, status, notes)
    VALUES (u1, v1,
      CURRENT_DATE - INTERVAL '65 days',
      CURRENT_DATE - INTERVAL '62 days',
      (SELECT price_per_day * 3 FROM vehicles WHERE id = v1),
      'terminee',
      'Location weekend')
    RETURNING id INTO r2;

    IF r2 IS NOT NULL THEN
      INSERT INTO invoices (reservation_id, user_id, amount, status)
      VALUES (r2, u1, (SELECT price_per_day * 3 FROM vehicles WHERE id = v1), 'emise');
    END IF;
  END IF;

  -- Réservation 5 : Annulée (Moussa)
  IF v2 IS NOT NULL AND u4 IS NOT NULL THEN
    INSERT INTO reservations (user_id, vehicle_id, date_start, date_end, total_price, status, notes)
    VALUES (u4, v2,
      CURRENT_DATE + INTERVAL '10 days',
      CURRENT_DATE + INTERVAL '14 days',
      (SELECT price_per_day * 4 FROM vehicles WHERE id = v2),
      'annulee',
      'Annulation pour raison personnelle');
  END IF;

END $$;

-- ── 4. VÉRIFICATION ─────────────────────────────────────────────
SELECT '=== CLIENTS CRÉÉS ===' as info;
SELECT id, email, first_name, last_name, phone, doc_status FROM users WHERE email LIKE '%@test-fleet.sn';

SELECT '=== RÉSERVATIONS CRÉÉES ===' as info;
SELECT r.id, u.first_name || ' ' || u.last_name as client, v.brand || ' ' || v.model as vehicule,
       r.date_start, r.date_end, r.total_price, r.status
FROM reservations r
JOIN users u ON u.id = r.user_id
JOIN vehicles v ON v.id = r.vehicle_id
WHERE u.email LIKE '%@test-fleet.sn'
ORDER BY r.created_at DESC;

