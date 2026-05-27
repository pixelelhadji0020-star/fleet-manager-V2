# Créer le bucket Supabase Storage

## Étapes (à faire UNE SEULE FOIS)

1. Aller sur **supabase.com → votre projet → Storage**
2. Cliquer **New bucket**
3. Remplir :
   - Name : `fleet-uploads`
   - Public bucket : **OUI** (cocher)
4. Cliquer **Save**

## Politique d'accès (RLS)

Dans Storage → Policies → fleet-uploads, ajouter ces 2 politiques :

**Lecture publique :**
```sql
CREATE POLICY "Public read" ON storage.objects
FOR SELECT USING (bucket_id = 'fleet-uploads');
```

**Upload authentifié :**
```sql
CREATE POLICY "Authenticated upload" ON storage.objects
FOR INSERT WITH CHECK (bucket_id = 'fleet-uploads');
```

## Une fois le bucket créé

Les images uploadées depuis l'admin auront une URL de type :
`https://zwsfzxiepggjfrbhcnub.supabase.co/storage/v1/object/public/fleet-uploads/vehicle_123.jpg`

Cette URL est stockée directement dans la colonne `image` de la table `vehicles`.
