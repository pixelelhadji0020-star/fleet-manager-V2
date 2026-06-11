-- ══════════════════════════════════════════════════════════════════════
--  FLEET MANAGER — Seed Demo Complet
--  Supabase / PostgreSQL  ·  SQL Editor → Run
--
--  Contenu :
--    §1  10 véhicules (idempotent sur plate)
--    §2  40 réservations : 15 terminée / 8 confirmée / 7 en_attente
--                          5 annulée / 5 refusée
--        + factures et avis pour toutes les terminées
--    §3  Notifications admin (8 non-lues + 2 lues) + 10 clients
--    §4  Vérification finale (counts)
--
--  Prérequis :
--    • 40+ clients avec email LIKE '%@fleet-demo.sn' dans la table users
--      (ou modifiez le pattern ci-dessous)
--    • L'admin admin@fleet.com doit exister
--
--  Idempotent : peut être rejoué sans créer de doublons
-- ══════════════════════════════════════════════════════════════════════

BEGIN;

-- ══════════════════════════════════════════════════════════════════════
--  §1  VÉHICULES
-- ══════════════════════════════════════════════════════════════════════

INSERT INTO vehicles (brand, model, plate, category, year, color, seats, fuel,
                      transmission, price_per_day, description, status, image, mileage)
SELECT 'Toyota','Land Cruiser V8','DK-2847-AA','SUV',2022,'Blanc Nacré',7,
       'essence','automatique',80000,
       'SUV prestige 7 places, idéal pour safaris et longs trajets. Climatisation bizone, GPS, caméra de recul.','disponible','',38000
WHERE NOT EXISTS (SELECT 1 FROM vehicles WHERE plate='DK-2847-AA');

INSERT INTO vehicles (brand, model, plate, category, year, color, seats, fuel,
                      transmission, price_per_day, description, status, image, mileage)
SELECT 'Mitsubishi','Pajero','DK-1563-AB','SUV',2021,'Gris Métallisé',5,
       'diesel','manuelle',65000,
       '4×4 robuste pour terrains difficiles. Parfait pour la brousse et les longs trajets inter-villes.','disponible','',52000
WHERE NOT EXISTS (SELECT 1 FROM vehicles WHERE plate='DK-1563-AB');

INSERT INTO vehicles (brand, model, plate, category, year, color, seats, fuel,
                      transmission, price_per_day, description, status, image, mileage)
SELECT 'Mercedes-Benz','Classe E','DK-9231-AC','Berline',2023,'Noir Obsidien',5,
       'essence','automatique',75000,
       'Berline de prestige aux finitions premium. Idéale pour voyages d''affaires et occasions spéciales.','disponible','',18000
WHERE NOT EXISTS (SELECT 1 FROM vehicles WHERE plate='DK-9231-AC');

INSERT INTO vehicles (brand, model, plate, category, year, color, seats, fuel,
                      transmission, price_per_day, description, status, image, mileage)
SELECT 'Renault','Duster','DK-4782-AD','SUV',2022,'Gris Ciment',5,
       'diesel','manuelle',30000,
       'Crossover polyvalent au meilleur rapport qualité-prix. Fiable sur routes goudronnées et pistes latéritiques.','disponible','',67000
WHERE NOT EXISTS (SELECT 1 FROM vehicles WHERE plate='DK-4782-AD');

INSERT INTO vehicles (brand, model, plate, category, year, color, seats, fuel,
                      transmission, price_per_day, description, status, image, mileage)
SELECT 'Hyundai','Tucson','DK-6104-AE','SUV',2023,'Bleu Saphir',5,
       'diesel','automatique',40000,
       'SUV moderne avec écran tactile 10'', aide au stationnement et régulateur de vitesse adaptatif.','disponible','',29000
WHERE NOT EXISTS (SELECT 1 FROM vehicles WHERE plate='DK-6104-AE');

INSERT INTO vehicles (brand, model, plate, category, year, color, seats, fuel,
                      transmission, price_per_day, description, status, image, mileage)
SELECT 'Toyota','Hilux Double Cab','DK-3390-AF','Pick-up',2021,'Argent',5,
       'diesel','manuelle',55000,
       'Pick-up professionnel indestructible. Charge utile 1 tonne, idéal pour missions terrain et transport.','disponible','',81000
WHERE NOT EXISTS (SELECT 1 FROM vehicles WHERE plate='DK-3390-AF');

INSERT INTO vehicles (brand, model, plate, category, year, color, seats, fuel,
                      transmission, price_per_day, description, status, image, mileage)
SELECT 'Kia','Sportage','DK-8845-AG','SUV',2023,'Rouge Piment',5,
       'essence','automatique',35000,
       'SUV urbain dynamique avec système d''infodivertissement connecté et pack sécurité complet.','disponible','',21000
WHERE NOT EXISTS (SELECT 1 FROM vehicles WHERE plate='DK-8845-AG');

INSERT INTO vehicles (brand, model, plate, category, year, color, seats, fuel,
                      transmission, price_per_day, description, status, image, mileage)
SELECT 'Honda','CR-V','DK-2271-AH','SUV',2022,'Blanc Platine',7,
       'essence','automatique',45000,
       'Familial 7 places avec vaste coffre modulable. Boîte automatique douce, idéal pour voyages en famille.','disponible','',44000
WHERE NOT EXISTS (SELECT 1 FROM vehicles WHERE plate='DK-2271-AH');

INSERT INTO vehicles (brand, model, plate, category, year, color, seats, fuel,
                      transmission, price_per_day, description, status, image, mileage)
SELECT 'Volkswagen','Tiguan','DK-5529-AI','SUV',2022,'Gris Tungstène',5,
       'diesel','automatique',50000,
       'SUV allemand à tenue de route exemplaire. Fiabilité et confort sur autoroute comme sur piste.','disponible','',36000
WHERE NOT EXISTS (SELECT 1 FROM vehicles WHERE plate='DK-5529-AI');

INSERT INTO vehicles (brand, model, plate, category, year, color, seats, fuel,
                      transmission, price_per_day, description, status, image, mileage)
SELECT 'Peugeot','3008','DK-7763-AJ','SUV',2023,'Vert Olivine',5,
       'essence','automatique',38000,
       'Crossover élégant primé design. Cockpit digital, sièges massants, excellent confort longue distance.','disponible','',14000
WHERE NOT EXISTS (SELECT 1 FROM vehicles WHERE plate='DK-7763-AJ');

-- ══════════════════════════════════════════════════════════════════════
--  §2  RÉSERVATIONS · FACTURES · AVIS
-- ══════════════════════════════════════════════════════════════════════

DO $$
DECLARE
  v   INT[];   -- IDs véhicules [1..10]
  c   INT[];   -- IDs clients   [1..40]
  rid INT;

BEGIN
  -- ── Chargement des véhicules ──────────────────────────────────────
  SELECT ARRAY[
    (SELECT id FROM vehicles WHERE plate='DK-2847-AA'),  -- v[1]  LC V8      80 000
    (SELECT id FROM vehicles WHERE plate='DK-1563-AB'),  -- v[2]  Pajero     65 000
    (SELECT id FROM vehicles WHERE plate='DK-9231-AC'),  -- v[3]  Mercedes   75 000
    (SELECT id FROM vehicles WHERE plate='DK-4782-AD'),  -- v[4]  Duster     30 000
    (SELECT id FROM vehicles WHERE plate='DK-6104-AE'),  -- v[5]  Tucson     40 000
    (SELECT id FROM vehicles WHERE plate='DK-3390-AF'),  -- v[6]  Hilux      55 000
    (SELECT id FROM vehicles WHERE plate='DK-8845-AG'),  -- v[7]  Sportage   35 000
    (SELECT id FROM vehicles WHERE plate='DK-2271-AH'),  -- v[8]  CR-V       45 000
    (SELECT id FROM vehicles WHERE plate='DK-5529-AI'),  -- v[9]  Tiguan     50 000
    (SELECT id FROM vehicles WHERE plate='DK-7763-AJ')   -- v[10] Peugeot    38 000
  ] INTO v;

  IF v[1] IS NULL THEN
    RAISE EXCEPTION '§1 véhicules non trouvés — exécutez d''abord le bloc §1 ci-dessus';
  END IF;

  -- ── Chargement des clients @fleet-demo.sn ─────────────────────────
  SELECT ARRAY_AGG(id ORDER BY created_at) INTO c
  FROM (
    SELECT id, created_at FROM users
    WHERE email LIKE '%@fleet-demo.sn'
    ORDER BY created_at
    LIMIT 40
  ) sub;

  IF c IS NULL OR array_length(c,1) < 15 THEN
    RAISE EXCEPTION 'Pas assez de clients @fleet-demo.sn (trouvés : %). Minimum requis : 15.',
                    COALESCE(array_length(c,1), 0);
  END IF;

  IF array_length(c,1) < 40 THEN
    RAISE NOTICE '⚠  Seulement % clients trouvés (40 idéal). Les réservations au-delà seront ignorées.',
                 array_length(c,1);
  END IF;

  -- ════════════════════════════════════════════════════════════════
  --  §2.1  TERMINÉES (15) — facture + avis pour chacune
  -- ════════════════════════════════════════════════════════════════

  -- [T-01] LC V8 · 5j · 400 000 FCFA · ★★★★★
  IF NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[1] AND vehicle_id=v[1]
                 AND date_start=CURRENT_DATE-INTERVAL'150 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[1],v[1],CURRENT_DATE-INTERVAL'150 days',CURRENT_DATE-INTERVAL'145 days',
            400000,'terminee','Week-end prolongé à Saly Portudal') RETURNING id INTO rid;
    INSERT INTO invoices (reservation_id,user_id,amount,status)
    VALUES (rid,c[1],400000,'emise');
    INSERT INTO reviews (reservation_id,user_id,vehicle_id,comfort_note,cleanliness_note,reliability_note,service_note,comment)
    VALUES (rid,c[1],v[1],5,5,5,5,'Véhicule impeccable, très confortable pour le trajet Dakar–Saly. Je recommande vivement !');
  END IF;

  -- [T-02] Pajero · 7j · 455 000 FCFA · ★★★★★
  IF NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[2] AND vehicle_id=v[2]
                 AND date_start=CURRENT_DATE-INTERVAL'145 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[2],v[2],CURRENT_DATE-INTERVAL'145 days',CURRENT_DATE-INTERVAL'138 days',
            455000,'terminee','Tournée commerciale Saint-Louis — Thiès') RETURNING id INTO rid;
    INSERT INTO invoices (reservation_id,user_id,amount,status)
    VALUES (rid,c[2],455000,'emise');
    INSERT INTO reviews (reservation_id,user_id,vehicle_id,comfort_note,cleanliness_note,reliability_note,service_note,comment)
    VALUES (rid,c[2],v[2],5,5,5,5,'Parfait pour les routes du nord. Climatisation excellente, aucune panne.');
  END IF;

  -- [T-03] Mercedes Classe E · 3j · 225 000 FCFA · ★★★★★
  IF NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[3] AND vehicle_id=v[3]
                 AND date_start=CURRENT_DATE-INTERVAL'140 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[3],v[3],CURRENT_DATE-INTERVAL'140 days',CURRENT_DATE-INTERVAL'137 days',
            225000,'terminee','Réunion d''affaires à Plateau') RETURNING id INTO rid;
    INSERT INTO invoices (reservation_id,user_id,amount,status)
    VALUES (rid,c[3],225000,'emise');
    INSERT INTO reviews (reservation_id,user_id,vehicle_id,comfort_note,cleanliness_note,reliability_note,service_note,comment)
    VALUES (rid,c[3],v[3],5,5,5,5,'Classe et élégance au rendez-vous. Mes clients ont été impressionnés à mon arrivée.');
  END IF;

  -- [T-04] Renault Duster · 10j · 300 000 FCFA · ★★★★★
  IF NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[4] AND vehicle_id=v[4]
                 AND date_start=CURRENT_DATE-INTERVAL'135 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[4],v[4],CURRENT_DATE-INTERVAL'135 days',CURRENT_DATE-INTERVAL'125 days',
            300000,'terminee','Mission ONG — région de Tambacounda') RETURNING id INTO rid;
    INSERT INTO invoices (reservation_id,user_id,amount,status)
    VALUES (rid,c[4],300000,'emise');
    INSERT INTO reviews (reservation_id,user_id,vehicle_id,comfort_note,cleanliness_note,reliability_note,service_note,comment)
    VALUES (rid,c[4],v[4],5,5,5,5,'Excellent sur piste latéritique. Prix imbattable pour ce niveau de robustesse.');
  END IF;

  -- [T-05] Hyundai Tucson · 8j · 320 000 FCFA · ★★★★★
  IF NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[5] AND vehicle_id=v[5]
                 AND date_start=CURRENT_DATE-INTERVAL'125 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[5],v[5],CURRENT_DATE-INTERVAL'125 days',CURRENT_DATE-INTERVAL'117 days',
            320000,'terminee','Vacances famille — Casamance') RETURNING id INTO rid;
    INSERT INTO invoices (reservation_id,user_id,amount,status)
    VALUES (rid,c[5],320000,'emise');
    INSERT INTO reviews (reservation_id,user_id,vehicle_id,comfort_note,cleanliness_note,reliability_note,service_note,comment)
    VALUES (rid,c[5],v[5],5,5,5,5,'Spacieux pour 5 personnes avec bagages. Consommation raisonnable sur longue distance.');
  END IF;

  -- [T-06] Toyota Hilux · 4j · 220 000 FCFA · ★★★★★
  IF NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[6] AND vehicle_id=v[6]
                 AND date_start=CURRENT_DATE-INTERVAL'115 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[6],v[6],CURRENT_DATE-INTERVAL'115 days',CURRENT_DATE-INTERVAL'111 days',
            220000,'terminee','Transport matériel chantier — Thiès') RETURNING id INTO rid;
    INSERT INTO invoices (reservation_id,user_id,amount,status)
    VALUES (rid,c[6],220000,'emise');
    INSERT INTO reviews (reservation_id,user_id,vehicle_id,comfort_note,cleanliness_note,reliability_note,service_note,comment)
    VALUES (rid,c[6],v[6],5,5,5,5,'Charge utile impressionnante. Aucun problème sur les pistes de chantier.');
  END IF;

  -- [T-07] Kia Sportage · 6j · 210 000 FCFA · ★★★★★
  IF NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[7] AND vehicle_id=v[7]
                 AND date_start=CURRENT_DATE-INTERVAL'110 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[7],v[7],CURRENT_DATE-INTERVAL'110 days',CURRENT_DATE-INTERVAL'104 days',
            210000,'terminee','Séjour Mbour — plage et détente') RETURNING id INTO rid;
    INSERT INTO invoices (reservation_id,user_id,amount,status)
    VALUES (rid,c[7],210000,'emise');
    INSERT INTO reviews (reservation_id,user_id,vehicle_id,comfort_note,cleanliness_note,reliability_note,service_note,comment)
    VALUES (rid,c[7],v[7],5,5,5,5,'Voiture agréable à conduire, intérieur propre et bien entretenu.');
  END IF;

  -- [T-08] Honda CR-V · 5j · 225 000 FCFA · ★★★★★
  IF NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[8] AND vehicle_id=v[8]
                 AND date_start=CURRENT_DATE-INTERVAL'100 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[8],v[8],CURRENT_DATE-INTERVAL'100 days',CURRENT_DATE-INTERVAL'95 days',
            225000,'terminee','Voyage familial — Ziguinchor') RETURNING id INTO rid;
    INSERT INTO invoices (reservation_id,user_id,amount,status)
    VALUES (rid,c[8],225000,'emise');
    INSERT INTO reviews (reservation_id,user_id,vehicle_id,comfort_note,cleanliness_note,reliability_note,service_note,comment)
    VALUES (rid,c[8],v[8],5,5,5,5,'7 places pratiques pour toute la famille. Coffre énorme. Parfait !');
  END IF;

  -- [T-09] Volkswagen Tiguan · 3j · 150 000 FCFA · ★★★★★
  IF NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[9] AND vehicle_id=v[9]
                 AND date_start=CURRENT_DATE-INTERVAL'95 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[9],v[9],CURRENT_DATE-INTERVAL'95 days',CURRENT_DATE-INTERVAL'92 days',
            150000,'terminee','Déplacement professionnel rapide') RETURNING id INTO rid;
    INSERT INTO invoices (reservation_id,user_id,amount,status)
    VALUES (rid,c[9],150000,'emise');
    INSERT INTO reviews (reservation_id,user_id,vehicle_id,comfort_note,cleanliness_note,reliability_note,service_note,comment)
    VALUES (rid,c[9],v[9],5,5,5,5,'Très bon véhicule, bien équipé. Service de location professionnel et rapide.');
  END IF;

  -- [T-10] Peugeot 3008 · 7j · 266 000 FCFA · ★★★★☆
  IF NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[10] AND vehicle_id=v[10]
                 AND date_start=CURRENT_DATE-INTERVAL'90 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[10],v[10],CURRENT_DATE-INTERVAL'90 days',CURRENT_DATE-INTERVAL'83 days',
            266000,'terminee','Tour du Sénégal — nord et centre') RETURNING id INTO rid;
    INSERT INTO invoices (reservation_id,user_id,amount,status)
    VALUES (rid,c[10],266000,'emise');
    INSERT INTO reviews (reservation_id,user_id,vehicle_id,comfort_note,cleanliness_note,reliability_note,service_note,comment)
    VALUES (rid,c[10],v[10],4,4,4,4,'Très belle voiture, conduite plaisir. Légère difficulté au démarrage un matin.');
  END IF;

  -- [T-11] LC V8 · 4j · 320 000 FCFA · ★★★★☆
  IF NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[11] AND vehicle_id=v[1]
                 AND date_start=CURRENT_DATE-INTERVAL'80 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[11],v[1],CURRENT_DATE-INTERVAL'80 days',CURRENT_DATE-INTERVAL'76 days',
            320000,'terminee','Délégation officielle — Kaolack') RETURNING id INTO rid;
    INSERT INTO invoices (reservation_id,user_id,amount,status)
    VALUES (rid,c[11],320000,'emise');
    INSERT INTO reviews (reservation_id,user_id,vehicle_id,comfort_note,cleanliness_note,reliability_note,service_note,comment)
    VALUES (rid,c[11],v[1],4,4,4,4,'Véhicule impressionnant et confortable. Climatisation légèrement bruyante.');
  END IF;

  -- [T-12] Pajero · 5j · 325 000 FCFA · ★★★★☆
  IF NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[12] AND vehicle_id=v[2]
                 AND date_start=CURRENT_DATE-INTERVAL'75 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[12],v[2],CURRENT_DATE-INTERVAL'75 days',CURRENT_DATE-INTERVAL'70 days',
            325000,'terminee','Prospection terrain — Fatick') RETURNING id INTO rid;
    INSERT INTO invoices (reservation_id,user_id,amount,status)
    VALUES (rid,c[12],325000,'emise');
    INSERT INTO reviews (reservation_id,user_id,vehicle_id,comfort_note,cleanliness_note,reliability_note,service_note,comment)
    VALUES (rid,c[12],v[2],4,4,4,4,'Robuste et fiable en toutes conditions. Les sièges arrière auraient pu être plus confortables.');
  END IF;

  -- [T-13] Mercedes Classe E · 6j · 450 000 FCFA · ★★★★☆
  IF NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[13] AND vehicle_id=v[3]
                 AND date_start=CURRENT_DATE-INTERVAL'65 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[13],v[3],CURRENT_DATE-INTERVAL'65 days',CURRENT_DATE-INTERVAL'59 days',
            450000,'terminee','Séminaire direction — Hôtel Radisson') RETURNING id INTO rid;
    INSERT INTO invoices (reservation_id,user_id,amount,status)
    VALUES (rid,c[13],450000,'emise');
    INSERT INTO reviews (reservation_id,user_id,vehicle_id,comfort_note,cleanliness_note,reliability_note,service_note,comment)
    VALUES (rid,c[13],v[3],4,4,5,4,'Luxe indéniable. Le GPS a perdu le signal une fois en dehors de Dakar.');
  END IF;

  -- [T-14] Renault Duster · 3j · 90 000 FCFA · ★★★★☆
  IF NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[14] AND vehicle_id=v[4]
                 AND date_start=CURRENT_DATE-INTERVAL'55 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[14],v[4],CURRENT_DATE-INTERVAL'55 days',CURRENT_DATE-INTERVAL'52 days',
            90000,'terminee','Visite chantier périphérie Dakar') RETURNING id INTO rid;
    INSERT INTO invoices (reservation_id,user_id,amount,status)
    VALUES (rid,c[14],90000,'emise');
    INSERT INTO reviews (reservation_id,user_id,vehicle_id,comfort_note,cleanliness_note,reliability_note,service_note,comment)
    VALUES (rid,c[14],v[4],4,4,4,4,'Rapport qualité-prix excellent. Boîte de vitesse un peu dure mais rien de bloquant.');
  END IF;

  -- [T-15] Hyundai Tucson · 4j · 160 000 FCFA · ★★★☆☆
  IF NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[15] AND vehicle_id=v[5]
                 AND date_start=CURRENT_DATE-INTERVAL'45 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[15],v[5],CURRENT_DATE-INTERVAL'45 days',CURRENT_DATE-INTERVAL'41 days',
            160000,'terminee','Déplacement rapide Dakar–Thiès') RETURNING id INTO rid;
    INSERT INTO invoices (reservation_id,user_id,amount,status)
    VALUES (rid,c[15],160000,'emise');
    INSERT INTO reviews (reservation_id,user_id,vehicle_id,comfort_note,cleanliness_note,reliability_note,service_note,comment)
    VALUES (rid,c[15],v[5],3,3,3,3,'Véhicule correct mais présence de légères rayures non signalées. Service acceptable.');
  END IF;

  -- ════════════════════════════════════════════════════════════════
  --  §2.2  CONFIRMÉES (8) — en cours cette semaine
  -- ════════════════════════════════════════════════════════════════

  -- [C-01] Hilux · J-4→J+1 · 5j · 275 000
  IF array_length(c,1) >= 16 AND
     NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[16] AND vehicle_id=v[6]
                 AND date_start=CURRENT_DATE-INTERVAL'4 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[16],v[6],CURRENT_DATE-INTERVAL'4 days',CURRENT_DATE+INTERVAL'1 day',
            275000,'confirmee','Transport logistique — Dakar Industriel');
  END IF;

  -- [C-02] Kia Sportage · J-3→J+2 · 5j · 175 000
  IF array_length(c,1) >= 17 AND
     NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[17] AND vehicle_id=v[7]
                 AND date_start=CURRENT_DATE-INTERVAL'3 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[17],v[7],CURRENT_DATE-INTERVAL'3 days',CURRENT_DATE+INTERVAL'2 days',
            175000,'confirmee','Location week-end prolongé');
  END IF;

  -- [C-03] Honda CR-V · J-2→J+3 · 5j · 225 000
  IF array_length(c,1) >= 18 AND
     NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[18] AND vehicle_id=v[8]
                 AND date_start=CURRENT_DATE-INTERVAL'2 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[18],v[8],CURRENT_DATE-INTERVAL'2 days',CURRENT_DATE+INTERVAL'3 days',
            225000,'confirmee','Voyage famille étendue — Touba');
  END IF;

  -- [C-04] Volkswagen Tiguan · J-1→J+5 · 6j · 300 000
  IF array_length(c,1) >= 19 AND
     NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[19] AND vehicle_id=v[9]
                 AND date_start=CURRENT_DATE-INTERVAL'1 day') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[19],v[9],CURRENT_DATE-INTERVAL'1 day',CURRENT_DATE+INTERVAL'5 days',
            300000,'confirmee','Conférence internationale — CICAD');
  END IF;

  -- [C-05] Peugeot 3008 · J→J+4 · 4j · 152 000
  IF array_length(c,1) >= 20 AND
     NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[20] AND vehicle_id=v[10]
                 AND date_start=CURRENT_DATE) THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[20],v[10],CURRENT_DATE,CURRENT_DATE+INTERVAL'4 days',
            152000,'confirmee','Prise en charge VIP aéroport');
  END IF;

  -- [C-06] LC V8 · J+1→J+5 · 4j · 320 000
  IF array_length(c,1) >= 21 AND
     NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[21] AND vehicle_id=v[1]
                 AND date_start=CURRENT_DATE+INTERVAL'1 day') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[21],v[1],CURRENT_DATE+INTERVAL'1 day',CURRENT_DATE+INTERVAL'5 days',
            320000,'confirmee','Délégation diplomatique — résidence officielle');
  END IF;

  -- [C-07] Pajero · J+2→J+6 · 4j · 260 000
  IF array_length(c,1) >= 22 AND
     NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[22] AND vehicle_id=v[2]
                 AND date_start=CURRENT_DATE+INTERVAL'2 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[22],v[2],CURRENT_DATE+INTERVAL'2 days',CURRENT_DATE+INTERVAL'6 days',
            260000,'confirmee','Expedition terrain — Sine Saloum');
  END IF;

  -- [C-08] Mercedes Classe E · J+3→J+7 · 4j · 300 000
  IF array_length(c,1) >= 23 AND
     NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[23] AND vehicle_id=v[3]
                 AND date_start=CURRENT_DATE+INTERVAL'3 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[23],v[3],CURRENT_DATE+INTERVAL'3 days',CURRENT_DATE+INTERVAL'7 days',
            300000,'confirmee','Mariage VIP — cortège officiel');
  END IF;

  -- ════════════════════════════════════════════════════════════════
  --  §2.3  EN ATTENTE (7) — prochaines 2 semaines
  -- ════════════════════════════════════════════════════════════════

  -- [A-01] Renault Duster · J+7→J+12 · 5j · 150 000
  IF array_length(c,1) >= 24 AND
     NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[24] AND vehicle_id=v[4]
                 AND date_start=CURRENT_DATE+INTERVAL'7 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[24],v[4],CURRENT_DATE+INTERVAL'7 days',CURRENT_DATE+INTERVAL'12 days',
            150000,'en_attente','Mission humanitaire — région Kolda');
  END IF;

  -- [A-02] Hyundai Tucson · J+8→J+14 · 6j · 240 000
  IF array_length(c,1) >= 25 AND
     NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[25] AND vehicle_id=v[5]
                 AND date_start=CURRENT_DATE+INTERVAL'8 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[25],v[5],CURRENT_DATE+INTERVAL'8 days',CURRENT_DATE+INTERVAL'14 days',
            240000,'en_attente','Vacances en famille — Casamance aller-retour');
  END IF;

  -- [A-03] Toyota Hilux · J+9→J+13 · 4j · 220 000
  IF array_length(c,1) >= 26 AND
     NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[26] AND vehicle_id=v[6]
                 AND date_start=CURRENT_DATE+INTERVAL'9 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[26],v[6],CURRENT_DATE+INTERVAL'9 days',CURRENT_DATE+INTERVAL'13 days',
            220000,'en_attente','Approvisionnement chantier BTP');
  END IF;

  -- [A-04] Kia Sportage · J+10→J+14 · 4j · 140 000
  IF array_length(c,1) >= 27 AND
     NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[27] AND vehicle_id=v[7]
                 AND date_start=CURRENT_DATE+INTERVAL'10 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[27],v[7],CURRENT_DATE+INTERVAL'10 days',CURRENT_DATE+INTERVAL'14 days',
            140000,'en_attente','Déplacement personnel — Tambacounda');
  END IF;

  -- [A-05] Honda CR-V · J+11→J+16 · 5j · 225 000
  IF array_length(c,1) >= 28 AND
     NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[28] AND vehicle_id=v[8]
                 AND date_start=CURRENT_DATE+INTERVAL'11 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[28],v[8],CURRENT_DATE+INTERVAL'11 days',CURRENT_DATE+INTERVAL'16 days',
            225000,'en_attente','Séjour groupe — Cap Skirring');
  END IF;

  -- [A-06] Volkswagen Tiguan · J+12→J+17 · 5j · 250 000
  IF array_length(c,1) >= 29 AND
     NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[29] AND vehicle_id=v[9]
                 AND date_start=CURRENT_DATE+INTERVAL'12 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[29],v[9],CURRENT_DATE+INTERVAL'12 days',CURRENT_DATE+INTERVAL'17 days',
            250000,'en_attente','Formation professionnelle — Saint-Louis');
  END IF;

  -- [A-07] Peugeot 3008 · J+14→J+18 · 4j · 152 000
  IF array_length(c,1) >= 30 AND
     NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[30] AND vehicle_id=v[10]
                 AND date_start=CURRENT_DATE+INTERVAL'14 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[30],v[10],CURRENT_DATE+INTERVAL'14 days',CURRENT_DATE+INTERVAL'18 days',
            152000,'en_attente','Réunion de famille — Rufisque');
  END IF;

  -- ════════════════════════════════════════════════════════════════
  --  §2.4  ANNULÉES (5)
  -- ════════════════════════════════════════════════════════════════

  -- [AN-01] LC V8 · J-35→J-30 · 5j · 400 000
  IF array_length(c,1) >= 31 AND
     NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[31] AND vehicle_id=v[1]
                 AND date_start=CURRENT_DATE-INTERVAL'35 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[31],v[1],CURRENT_DATE-INTERVAL'35 days',CURRENT_DATE-INTERVAL'30 days',
            400000,'annulee','Annulée — changement de planning de dernière minute');
  END IF;

  -- [AN-02] Mercedes Classe E · J-28→J-23 · 5j · 375 000
  IF array_length(c,1) >= 32 AND
     NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[32] AND vehicle_id=v[3]
                 AND date_start=CURRENT_DATE-INTERVAL'28 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[32],v[3],CURRENT_DATE-INTERVAL'28 days',CURRENT_DATE-INTERVAL'23 days',
            375000,'annulee','Annulée — événement reporté');
  END IF;

  -- [AN-03] Hyundai Tucson · J-22→J-18 · 4j · 160 000
  IF array_length(c,1) >= 33 AND
     NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[33] AND vehicle_id=v[5]
                 AND date_start=CURRENT_DATE-INTERVAL'22 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[33],v[5],CURRENT_DATE-INTERVAL'22 days',CURRENT_DATE-INTERVAL'18 days',
            160000,'annulee','Annulée par le client avant confirmation');
  END IF;

  -- [AN-04] Kia Sportage · J-16→J-13 · 3j · 105 000
  IF array_length(c,1) >= 34 AND
     NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[34] AND vehicle_id=v[7]
                 AND date_start=CURRENT_DATE-INTERVAL'16 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[34],v[7],CURRENT_DATE-INTERVAL'16 days',CURRENT_DATE-INTERVAL'13 days',
            105000,'annulee','Annulée — problème de disponibilité du conducteur');
  END IF;

  -- [AN-05] Volkswagen Tiguan · J-10→J-5 · 5j · 250 000
  IF array_length(c,1) >= 35 AND
     NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[35] AND vehicle_id=v[9]
                 AND date_start=CURRENT_DATE-INTERVAL'10 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[35],v[9],CURRENT_DATE-INTERVAL'10 days',CURRENT_DATE-INTERVAL'5 days',
            250000,'annulee','Annulée — budget revu à la baisse');
  END IF;

  -- ════════════════════════════════════════════════════════════════
  --  §2.5  REFUSÉES (5)
  -- ════════════════════════════════════════════════════════════════

  -- [R-01] Pajero · J-38→J-32 · 6j · 390 000
  IF array_length(c,1) >= 36 AND
     NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[36] AND vehicle_id=v[2]
                 AND date_start=CURRENT_DATE-INTERVAL'38 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[36],v[2],CURRENT_DATE-INTERVAL'38 days',CURRENT_DATE-INTERVAL'32 days',
            390000,'refusee','Refusée — dossier documentaire incomplet');
  END IF;

  -- [R-02] Renault Duster · J-30→J-26 · 4j · 120 000
  IF array_length(c,1) >= 37 AND
     NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[37] AND vehicle_id=v[4]
                 AND date_start=CURRENT_DATE-INTERVAL'30 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[37],v[4],CURRENT_DATE-INTERVAL'30 days',CURRENT_DATE-INTERVAL'26 days',
            120000,'refusee','Refusée — permis de conduire non valide');
  END IF;

  -- [R-03] Toyota Hilux · J-25→J-19 · 6j · 330 000
  IF array_length(c,1) >= 38 AND
     NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[38] AND vehicle_id=v[6]
                 AND date_start=CURRENT_DATE-INTERVAL'25 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[38],v[6],CURRENT_DATE-INTERVAL'25 days',CURRENT_DATE-INTERVAL'19 days',
            330000,'refusee','Refusée — usage commercial non autorisé déclaré');
  END IF;

  -- [R-04] Honda CR-V · J-18→J-14 · 4j · 180 000
  IF array_length(c,1) >= 39 AND
     NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[39] AND vehicle_id=v[8]
                 AND date_start=CURRENT_DATE-INTERVAL'18 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[39],v[8],CURRENT_DATE-INTERVAL'18 days',CURRENT_DATE-INTERVAL'14 days',
            180000,'refusee','Refusée — antécédent de dommage signalé');
  END IF;

  -- [R-05] Peugeot 3008 · J-13→J-7 · 6j · 228 000
  IF array_length(c,1) >= 40 AND
     NOT EXISTS (SELECT 1 FROM reservations WHERE user_id=c[40] AND vehicle_id=v[10]
                 AND date_start=CURRENT_DATE-INTERVAL'13 days') THEN
    INSERT INTO reservations (user_id,vehicle_id,date_start,date_end,total_price,status,notes)
    VALUES (c[40],v[10],CURRENT_DATE-INTERVAL'13 days',CURRENT_DATE-INTERVAL'7 days',
            228000,'refusee','Refusée — solde débiteur sur compte précédent');
  END IF;

END $$;

-- ══════════════════════════════════════════════════════════════════════
--  §3  NOTIFICATIONS
-- ══════════════════════════════════════════════════════════════════════

-- ── Admin : 5 alertes docs (non lues) + 3 nouvelles réservations (non lues)
--            + 2 locations terminées (lues)
DO $$
DECLARE
  adm_id INT;
BEGIN
  SELECT id INTO adm_id FROM users WHERE role='admin' ORDER BY created_at LIMIT 1;
  IF adm_id IS NULL THEN
    RAISE NOTICE 'Admin introuvable — notifications admin ignorées';
    RETURN;
  END IF;

  -- 5 alertes dossiers en attente (non lues)
  IF NOT EXISTS (SELECT 1 FROM notifications WHERE user_id=adm_id
                 AND title='Nouveau dossier soumis — Vérification requise'
                 AND type='warning') THEN
    INSERT INTO notifications (user_id,title,message,type,read)
    VALUES
      (adm_id,'Nouveau dossier soumis — Vérification requise',
       'Un client a soumis ses documents d''identité. Examen en attente.','warning',false),
      (adm_id,'Dossier incomplet signalé',
       'Le permis de conduire fourni semble expiré. Contacter le client.','warning',false),
      (adm_id,'Document en attente de validation',
       'Justificatif de domicile déposé hier. À examiner avant confirmation.','warning',false),
      (adm_id,'Dossier soumis — CNI illisible',
       'La photo de la CNI est floue. Demander une nouvelle soumission.','warning',false),
      (adm_id,'5 dossiers en attente depuis plus de 48h',
       'Des clients attendent leur validation depuis plus de 2 jours.','warning',false);
  END IF;

  -- 3 nouvelles réservations (non lues)
  IF NOT EXISTS (SELECT 1 FROM notifications WHERE user_id=adm_id
                 AND title='Nouvelle demande de réservation'
                 AND type='info') THEN
    INSERT INTO notifications (user_id,title,message,type,read)
    VALUES
      (adm_id,'Nouvelle demande de réservation',
       'Demande reçue pour le Toyota Land Cruiser V8 — 4 jours.','info',false),
      (adm_id,'Demande urgente — départ demain',
       'Un client souhaite la Mercedes Classe E dès demain matin.','info',false),
      (adm_id,'3 demandes en attente de traitement',
       'Des réservations attendent votre confirmation depuis ce matin.','info',false);
  END IF;

  -- 2 locations terminées (lues)
  IF NOT EXISTS (SELECT 1 FROM notifications WHERE user_id=adm_id
                 AND title='Location terminée — Facture émise'
                 AND type='success') THEN
    INSERT INTO notifications (user_id,title,message,type,read)
    VALUES
      (adm_id,'Location terminée — Facture émise',
       'La location du Pajero a été clôturée. Facture de 325 000 FCFA émise.','success',true),
      (adm_id,'Avis client reçu ★★★★★',
       'Le client a laissé un excellent avis sur le Toyota Hilux.','success',true);
  END IF;
END $$;

-- ── Clients : 1 notification chacun pour les 10 premiers clients
DO $$
DECLARE
  c INT[];
BEGIN
  SELECT ARRAY_AGG(id ORDER BY created_at) INTO c
  FROM (
    SELECT id, created_at FROM users
    WHERE email LIKE '%@fleet-demo.sn'
    ORDER BY created_at
    LIMIT 10
  ) sub;

  IF c IS NULL OR array_length(c,1) < 1 THEN
    RAISE NOTICE 'Aucun client @fleet-demo.sn trouvé — notifications clients ignorées';
    RETURN;
  END IF;

  -- c[1] — location terminée
  IF array_length(c,1)>=1 AND NOT EXISTS(SELECT 1 FROM notifications WHERE user_id=c[1] AND title='Votre location est terminée — Merci !') THEN
    INSERT INTO notifications(user_id,title,message,type,read)
    VALUES(c[1],'Votre location est terminée — Merci !','Laissez un avis sur votre expérience avec le Toyota Land Cruiser V8.','success',false);
  END IF;

  -- c[2] — réservation confirmée
  IF array_length(c,1)>=2 AND NOT EXISTS(SELECT 1 FROM notifications WHERE user_id=c[2] AND title='Réservation confirmée ✓') THEN
    INSERT INTO notifications(user_id,title,message,type,read)
    VALUES(c[2],'Réservation confirmée ✓','Votre Mitsubishi Pajero est prêt. Bonne route !','success',false);
  END IF;

  -- c[3] — rappel départ demain
  IF array_length(c,1)>=3 AND NOT EXISTS(SELECT 1 FROM notifications WHERE user_id=c[3] AND title='Rappel — Votre location commence demain') THEN
    INSERT INTO notifications(user_id,title,message,type,read)
    VALUES(c[3],'Rappel — Votre location commence demain','Pensez à vous munir de votre permis et de votre CNI à la prise en charge.','info',false);
  END IF;

  -- c[4] — document manquant
  IF array_length(c,1)>=4 AND NOT EXISTS(SELECT 1 FROM notifications WHERE user_id=c[4] AND title='Documents manquants') THEN
    INSERT INTO notifications(user_id,title,message,type,read)
    VALUES(c[4],'Documents manquants','Votre justificatif de domicile est absent. Déposez-le pour valider votre dossier.','warning',false);
  END IF;

  -- c[5] — facture disponible
  IF array_length(c,1)>=5 AND NOT EXISTS(SELECT 1 FROM notifications WHERE user_id=c[5] AND title='Facture disponible') THEN
    INSERT INTO notifications(user_id,title,message,type,read)
    VALUES(c[5],'Facture disponible','Votre facture de 320 000 FCFA pour le Hyundai Tucson est disponible.','success',true);
  END IF;

  -- c[6] — location terminée
  IF array_length(c,1)>=6 AND NOT EXISTS(SELECT 1 FROM notifications WHERE user_id=c[6] AND title='Location terminée — Merci pour votre confiance') THEN
    INSERT INTO notifications(user_id,title,message,type,read)
    VALUES(c[6],'Location terminée — Merci pour votre confiance','Votre Toyota Hilux a été restitué avec succès.','success',true);
  END IF;

  -- c[7] — avis enregistré
  IF array_length(c,1)>=7 AND NOT EXISTS(SELECT 1 FROM notifications WHERE user_id=c[7] AND title='Avis enregistré — Merci !') THEN
    INSERT INTO notifications(user_id,title,message,type,read)
    VALUES(c[7],'Avis enregistré — Merci !','Votre évaluation 5 étoiles du Kia Sportage a bien été prise en compte.','success',true);
  END IF;

  -- c[8] — document expiré
  IF array_length(c,1)>=8 AND NOT EXISTS(SELECT 1 FROM notifications WHERE user_id=c[8] AND title='Document expiré') THEN
    INSERT INTO notifications(user_id,title,message,type,read)
    VALUES(c[8],'Document expiré','Votre permis de conduire arrive à expiration. Pensez à le renouveler.','warning',false);
  END IF;

  -- c[9] — demande reçue
  IF array_length(c,1)>=9 AND NOT EXISTS(SELECT 1 FROM notifications WHERE user_id=c[9] AND title='Demande de réservation reçue') THEN
    INSERT INTO notifications(user_id,title,message,type,read)
    VALUES(c[9],'Demande de réservation reçue','Votre demande pour le Renault Duster a bien été transmise à l''équipe.','info',false);
  END IF;

  -- c[10] — bienvenue
  IF array_length(c,1)>=10 AND NOT EXISTS(SELECT 1 FROM notifications WHERE user_id=c[10] AND title='Bienvenue sur Fleet Manager') THEN
    INSERT INTO notifications(user_id,title,message,type,read)
    VALUES(c[10],'Bienvenue sur Fleet Manager','Complétez votre profil et déposez vos documents pour accéder à nos véhicules premium.','info',true);
  END IF;

END $$;

-- ══════════════════════════════════════════════════════════════════════
--  §4  VÉRIFICATION
-- ══════════════════════════════════════════════════════════════════════

SELECT '── VÉHICULES ──' AS section,
       brand || ' ' || model AS vehicle,
       plate,
       price_per_day || ' FCFA/j' AS tarif,
       status
FROM vehicles
WHERE plate LIKE 'DK-%'
ORDER BY price_per_day;

SELECT '── RÉSERVATIONS PAR STATUT ──' AS section,
       status,
       COUNT(*)          AS total,
       SUM(total_price)  AS ca_fcfa
FROM reservations
WHERE vehicle_id IN (SELECT id FROM vehicles WHERE plate LIKE 'DK-%')
GROUP BY status
ORDER BY CASE status
  WHEN 'terminee'   THEN 1
  WHEN 'confirmee'  THEN 2
  WHEN 'en_attente' THEN 3
  WHEN 'annulee'    THEN 4
  WHEN 'refusee'    THEN 5
END;

SELECT '── TOP VÉHICULES ──' AS section,
       v.brand || ' ' || v.model AS vehicle,
       COUNT(r.id)          AS nb_locations,
       SUM(r.total_price)   AS ca_total_fcfa
FROM vehicles v
LEFT JOIN reservations r ON r.vehicle_id = v.id
WHERE v.plate LIKE 'DK-%'
GROUP BY v.id, v.brand, v.model
ORDER BY nb_locations DESC;

SELECT '── FACTURES ──'   AS section, COUNT(*) AS total FROM invoices
UNION ALL
SELECT '── AVIS ──',       COUNT(*) FROM reviews
UNION ALL
SELECT '── NOTIFICATIONS ──', COUNT(*) FROM notifications;

COMMIT;

-- ══════════════════════════════════════════════════════════════════════
--  RÉSUMÉ
-- ══════════════════════════════════════════════════════════════════════
--
--  VÉHICULES (10)
--  ┌─────────────────────────────┬──────────────┬──────────┐
--  │ Véhicule                    │ Plaque       │ Tarif/j  │
--  ├─────────────────────────────┼──────────────┼──────────┤
--  │ Toyota Land Cruiser V8      │ DK-2847-AA   │  80 000  │
--  │ Mercedes-Benz Classe E      │ DK-9231-AC   │  75 000  │
--  │ Mitsubishi Pajero           │ DK-1563-AB   │  65 000  │
--  │ Toyota Hilux Double Cab     │ DK-3390-AF   │  55 000  │
--  │ Volkswagen Tiguan           │ DK-5529-AI   │  50 000  │
--  │ Honda CR-V                  │ DK-2271-AH   │  45 000  │
--  │ Hyundai Tucson              │ DK-6104-AE   │  40 000  │
--  │ Peugeot 3008                │ DK-7763-AJ   │  38 000  │
--  │ Kia Sportage                │ DK-8845-AG   │  35 000  │
--  │ Renault Duster              │ DK-4782-AD   │  30 000  │
--  └─────────────────────────────┴──────────────┴──────────┘
--
--  RÉSERVATIONS (40)
--  ┌────────────────┬───────┐
--  │ Statut         │ Count │
--  ├────────────────┼───────┤
--  │ terminee       │  15   │  ← 9×★★★★★  5×★★★★☆  1×★★★☆☆
--  │ confirmee      │   8   │
--  │ en_attente     │   7   │
--  │ annulee        │   5   │
--  │ refusee        │   5   │
--  └────────────────┴───────┘
--
--  FACTURES : 15 (une par location terminée, statut 'emise')
--  AVIS      : 15 (un par location terminée)
--
--  NOTIFICATIONS ADMIN : 10 (5 warning unread + 3 info unread + 2 success read)
--  NOTIFICATIONS CLIENT: 10 (1 par client c[1..10])
--
--  ACCÈS DÉMO
--  ┌─────────────────────────────────────────────────────┐
--  │ Admin     admin@fleet.com       (mot de passe existant) │
--  │ Client 1  <premier @fleet-demo.sn par created_at>   │
--  │ Client 2  <deuxième @fleet-demo.sn>                 │
--  │  ...      mot de passe : fleet2024 (si seeded avant)│
--  └─────────────────────────────────────────────────────┘
--
-- ══════════════════════════════════════════════════════════════════════
