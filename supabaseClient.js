// =====================================================================
// KingGym — Client Supabase
// =====================================================================
// ⚠️ Remplacez les deux valeurs ci-dessous par celles de votre projet
// Supabase : Dashboard > Project Settings > API.
// L'anon key est publique par design (elle est protégée par les
// politiques RLS côté base de données) — elle peut être commitée
// dans un dépôt GitHub Pages public.
// =====================================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

export const SUPABASE_URL = 'https://VOTRE-PROJET.supabase.co';
export const SUPABASE_ANON_KEY = 'VOTRE_CLE_ANON_PUBLIQUE';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
  },
});
