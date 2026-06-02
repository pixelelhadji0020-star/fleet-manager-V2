"""
SCRIPT DE MIGRATION DES IMAGES — À exécuter UNE SEULE FOIS sur votre PC

Ce script :
1. Upload chaque image locale vers Supabase Storage (bucket fleet-uploads)
2. Met à jour la colonne 'image' de la table vehicles avec l'URL publique

USAGE :
  pip install supabase python-dotenv
  python migrate_images.py

VARIABLES REQUISES dans .env ou à modifier directement ci-dessous :
  SUPABASE_URL = https://xxxx.supabase.co
  SUPABASE_KEY = votre-service-role-key  (pas anon key — besoin d'écriture)
"""

import os
import sys

# ── CONFIG — modifier si besoin ────────────────────────────────────────────
SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY", "")  # service_role key
BUCKET       = "fleet-uploads"

# Dossier contenant les images locales (relatif à ce script)
UPLOADS_DIR  = os.path.join(os.path.dirname(__file__), "static", "uploads")
# ────────────────────────────────────────────────────────────────────────────

if not SUPABASE_URL or not SUPABASE_KEY:
    print("ERREUR : SUPABASE_URL et SUPABASE_KEY doivent être définis.")
    sys.exit(1)

from supabase import create_client

sb = create_client(SUPABASE_URL, SUPABASE_KEY)

MIME_MAP = {
    "jpg": "image/jpeg", "jpeg": "image/jpeg",
    "png": "image/png",  "gif": "image/gif", "webp": "image/webp"
}

def upload_file(filepath):
    filename = os.path.basename(filepath)
    ext      = filename.rsplit(".", 1)[-1].lower()
    mime     = MIME_MAP.get(ext, f"image/{ext}")
    with open(filepath, "rb") as f:
        data = f.read()
    sb.storage.from_(BUCKET).upload(
        path=filename,
        file=data,
        file_options={"content-type": mime, "upsert": "true"}
    )
    url = sb.storage.from_(BUCKET).get_public_url(filename)
    return url

def get_vehicles():
    r = sb.table("vehicles").select("id,image,brand,model").execute()
    return r.data or []

def update_vehicle_image(vehicle_id, url):
    sb.table("vehicles").update({"image": url}).eq("id", vehicle_id).execute()

def main():
    print(f"\n{'='*55}")
    print(" MIGRATION DES IMAGES — Fleet Manager")
    print(f"{'='*55}\n")

    if not os.path.isdir(UPLOADS_DIR):
        print(f"ERREUR : dossier introuvable : {UPLOADS_DIR}")
        sys.exit(1)

    vehicles = get_vehicles()
    if not vehicles:
        print("Aucun véhicule en base.")
        return

    print(f"{len(vehicles)} véhicule(s) trouvé(s) en base.\n")

    migrated = 0
    skipped  = 0
    errors   = 0

    for v in vehicles:
        vid   = v["id"]
        img   = v.get("image") or ""
        name  = f"{v['brand']} {v['model']} (id={vid})"

        # Déjà une URL Supabase → ignorer
        if img.startswith("http"):
            print(f"  ⏭  {name} — URL déjà complète, ignoré")
            skipped += 1
            continue

        # Nom de fichier local → chercher dans uploads/
        if img:
            local_path = os.path.join(UPLOADS_DIR, img)
        else:
            # Chercher un fichier dont le nom contient l'id
            matches = [f for f in os.listdir(UPLOADS_DIR)
                       if f.startswith(f"vehicle_{vid}_")]
            if not matches:
                print(f"  ⚠  {name} — aucune image locale trouvée, ignoré")
                skipped += 1
                continue
            local_path = os.path.join(UPLOADS_DIR, matches[0])
            img = matches[0]

        if not os.path.exists(local_path):
            print(f"  ⚠  {name} — fichier '{img}' introuvable localement")
            skipped += 1
            continue

        try:
            print(f"  ⬆  {name} — upload de '{img}'...", end=" ", flush=True)
            url = upload_file(local_path)
            update_vehicle_image(vid, url)
            print(f"✓")
            print(f"     → {url}")
            migrated += 1
        except Exception as e:
            print(f"✗ ERREUR : {e}")
            errors += 1

    print(f"\n{'='*55}")
    print(f" Résultat : {migrated} migrés | {skipped} ignorés | {errors} erreurs")
    print(f"{'='*55}\n")

    if errors == 0:
        print("✅ Migration terminée. Pushez app.py et requirements.txt sur GitHub.")
    else:
        print("⚠  Des erreurs sont survenues. Vérifiez votre SUPABASE_KEY.")

if __name__ == "__main__":
    main()
