# KingGym — Application de gestion de salle de sport

Application statique (HTML/CSS/JS, aucun build nécessaire) connectée à Supabase,
hébergeable gratuitement sur GitHub Pages.

## 1. Base de données Supabase

Dans l'éditeur SQL de votre projet Supabase, exécutez **dans cet ordre** :

1. Votre schéma d'origine (tables `sports`, `members`, `memberships`, etc.)
2. `corrections_schema_salle_sport.sql` (contraintes, index, `updated_at`, RLS de base)
3. `supabase-roles-rls.sql` (droits précis admin / coach — **remplace** les
   politiques génériques de l'étape 2)

Puis créez votre premier compte administrateur :

1. Supabase Dashboard → Authentication → Users → **Add user** (email + mot de passe),
   ou laissez-vous vous inscrire depuis la page KingGym (onglet "Demande d'accès coach").
2. Copiez l'UUID de ce compte.
3. Dans l'éditeur SQL :
   ```sql
   UPDATE public.app_users
   SET role = 'admin', is_active = true
   WHERE user_id = 'UUID_DU_COMPTE';
   ```

Sans cette dernière étape, personne ne peut se connecter à l'espace admin.

## 2. Connecter le site à votre projet Supabase

Ouvrez `js/supabaseClient.js` et remplacez :

```js
export const SUPABASE_URL = 'https://VOTRE-PROJET.supabase.co';
export const SUPABASE_ANON_KEY = 'VOTRE_CLE_ANON_PUBLIQUE';
```

par les valeurs de **Project Settings → API** dans Supabase.
La clé `anon` est publique par conception (protégée par les policies RLS) :
elle peut être commitée dans un dépôt GitHub public sans risque, à condition
que les politiques RLS (étape 1) soient bien actives.

## 3. Déployer sur GitHub Pages

```bash
# Depuis le dossier kinggym/
git init
git add .
git commit -m "KingGym - v1"
git branch -M main
git remote add origin https://github.com/VOTRE-COMPTE/kinggym.git
git push -u origin main
```

Puis sur GitHub : **Settings → Pages → Source: Deploy from branch → main / (root)**.
Le site sera disponible à `https://VOTRE-COMPTE.github.io/kinggym/`.

Aucune étape de build n'est nécessaire : les fichiers sont servis tels quels,
et Supabase JS est chargé directement depuis un CDN (`esm.sh`) dans le navigateur.

## 4. Fonctionnement des rôles

- **Inscription libre** (page de connexion, onglet "Demande d'accès coach") crée
  un compte avec le rôle `coach` et `is_active = false`.
- Un **admin** doit l'activer dans l'onglet **Utilisateurs** du back-office
  (et peut changer son rôle si besoin).
- Une fois activé, le coach doit avoir une **fiche coach** créée dans l'onglet
  **Coachs**, puis être **affecté à un ou plusieurs créneaux** — c'est cette
  affectation qui détermine ce qu'il voit dans son espace "Présences".
- L'admin gère tout : sports, plannings, membres, tuteurs, inscriptions,
  paiements, coachs. Le coach ne voit et ne modifie que les présences de ses
  propres créneaux.

## 5. Structure du projet

```
kinggym/
├── index.html              connexion / demande d'accès
├── admin.html               back-office (plannings, inscriptions, paiements...)
├── coach.html                espace coach (présences uniquement)
├── css/styles.css            identité visuelle KingGym
├── js/
│   ├── supabaseClient.js     configuration Supabase (à renseigner)
│   ├── guard.js               vérification de session + rôle
│   ├── admin.js                logique complète du back-office
│   └── coach.js                logique de saisie des présences
└── assets/logo-inline.js      logo SVG (couronne) réutilisable
```

## 6. Pistes d'évolution (non incluses)

- Gestion du lien membre ↔ tuteur depuis l'interface (actuellement en base
  uniquement, via `member_guardians`)
- Génération de reçus de paiement en PDF
- Export CSV des présences et paiements
- Notifications par e-mail (rappels de cotisation, confirmation d'inscription)
