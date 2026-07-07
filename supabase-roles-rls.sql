-- =====================================================================
-- KingGym — Sécurité par rôle (admin / coach)
-- =====================================================================
-- À exécuter APRÈS le schéma d'origine et le script de corrections.
-- Ce script remplace les politiques RLS génériques de la section 6
-- du script précédent par des politiques précises par rôle.
--
-- Rôles gérés :
--   - admin           : accès total (plannings, inscriptions, paiements, coachs)
--   - coach / assistant_coach : lecture des créneaux qui lui sont assignés,
--                        lecture des membres inscrits à ces créneaux,
--                        gestion des présences UNIQUEMENT sur ses créneaux
-- =====================================================================

-- 0. Nettoyage des anciennes politiques génériques (si le script précédent
--    a été exécuté)
DROP POLICY IF EXISTS app_users_can_read_members ON public.members;
DROP POLICY IF EXISTS app_users_can_read_guardians ON public.guardians;
DROP POLICY IF EXISTS app_users_can_read_memberships ON public.memberships;
DROP POLICY IF EXISTS app_users_can_read_payments ON public.payments;
DROP POLICY IF EXISTS only_admin_accountant_write_payments ON public.payments;


-- =====================================================================
-- 1. Fonctions utilitaires (SECURITY DEFINER pour éviter la récursion RLS)
-- =====================================================================

CREATE OR REPLACE FUNCTION public.my_role()
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM public.app_users WHERE user_id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.my_is_active()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE((SELECT is_active FROM public.app_users WHERE user_id = auth.uid()), false);
$$;

CREATE OR REPLACE FUNCTION public.my_coach_id()
RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT coach_id FROM public.coaches WHERE user_id = auth.uid();
$$;

-- Vrai si le schedule_id donné est bien un créneau du coach connecté
CREATE OR REPLACE FUNCTION public.is_my_schedule(p_schedule_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.schedule_coaches sc
    WHERE sc.schedule_id = p_schedule_id
      AND sc.coach_id = public.my_coach_id()
      AND sc.is_active = true
  );
$$;


-- =====================================================================
-- 2. app_users — chacun lit sa propre fiche, admin gère tout
-- =====================================================================

CREATE POLICY app_users_self_read ON public.app_users
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY app_users_admin_all ON public.app_users
  FOR ALL USING (public.my_role() = 'admin')
  WITH CHECK (public.my_role() = 'admin');


-- =====================================================================
-- 3. sports — lecture pour tout utilisateur actif, écriture admin
-- =====================================================================

CREATE POLICY sports_read_active_users ON public.sports
  FOR SELECT USING (public.my_is_active());

CREATE POLICY sports_admin_write ON public.sports
  FOR ALL USING (public.my_role() = 'admin')
  WITH CHECK (public.my_role() = 'admin');


-- =====================================================================
-- 4. training_schedules — lecture pour tout utilisateur actif, écriture admin
-- =====================================================================

CREATE POLICY schedules_read_active_users ON public.training_schedules
  FOR SELECT USING (public.my_is_active());

CREATE POLICY schedules_admin_write ON public.training_schedules
  FOR ALL USING (public.my_role() = 'admin')
  WITH CHECK (public.my_role() = 'admin');


-- =====================================================================
-- 5. coaches — admin gère tout, coach lit sa propre fiche
-- =====================================================================

CREATE POLICY coaches_self_read ON public.coaches
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY coaches_admin_all ON public.coaches
  FOR ALL USING (public.my_role() = 'admin')
  WITH CHECK (public.my_role() = 'admin');


-- =====================================================================
-- 6. schedule_coaches — admin gère tout, coach lit ses propres affectations
-- =====================================================================

CREATE POLICY schedule_coaches_self_read ON public.schedule_coaches
  FOR SELECT USING (coach_id = public.my_coach_id());

CREATE POLICY schedule_coaches_admin_all ON public.schedule_coaches
  FOR ALL USING (public.my_role() = 'admin')
  WITH CHECK (public.my_role() = 'admin');


-- =====================================================================
-- 7. members — admin gère tout, coach lit les membres de ses créneaux
-- =====================================================================

CREATE POLICY members_admin_all ON public.members
  FOR ALL USING (public.my_role() = 'admin')
  WITH CHECK (public.my_role() = 'admin');

CREATE POLICY members_coach_read ON public.members
  FOR SELECT USING (
    public.my_role() IN ('coach', 'assistant_coach')
    AND EXISTS (
      SELECT 1 FROM public.memberships m
      WHERE m.member_id = members.member_id
        AND m.membership_status = 'active'
        AND public.is_my_schedule(m.schedule_id)
    )
  );


-- =====================================================================
-- 8. guardians / member_guardians — admin uniquement
-- =====================================================================

CREATE POLICY guardians_admin_all ON public.guardians
  FOR ALL USING (public.my_role() = 'admin')
  WITH CHECK (public.my_role() = 'admin');

CREATE POLICY member_guardians_admin_all ON public.member_guardians
  FOR ALL USING (public.my_role() = 'admin')
  WITH CHECK (public.my_role() = 'admin');


-- =====================================================================
-- 9. memberships (inscriptions) — admin gère tout, coach lit celles de ses créneaux
-- =====================================================================

CREATE POLICY memberships_admin_all ON public.memberships
  FOR ALL USING (public.my_role() = 'admin')
  WITH CHECK (public.my_role() = 'admin');

CREATE POLICY memberships_coach_read ON public.memberships
  FOR SELECT USING (
    public.my_role() IN ('coach', 'assistant_coach')
    AND public.is_my_schedule(schedule_id)
  );


-- =====================================================================
-- 10. payments — admin uniquement (les coachs n'ont pas accès à la finance)
-- =====================================================================

CREATE POLICY payments_admin_all ON public.payments
  FOR ALL USING (public.my_role() = 'admin')
  WITH CHECK (public.my_role() = 'admin');


-- =====================================================================
-- 11. attendance — admin gère tout, coach gère UNIQUEMENT ses créneaux
-- =====================================================================

CREATE POLICY attendance_admin_all ON public.attendance
  FOR ALL USING (public.my_role() = 'admin')
  WITH CHECK (public.my_role() = 'admin');

CREATE POLICY attendance_coach_read ON public.attendance
  FOR SELECT USING (
    public.my_role() IN ('coach', 'assistant_coach')
    AND public.is_my_schedule(schedule_id)
  );

CREATE POLICY attendance_coach_insert ON public.attendance
  FOR INSERT WITH CHECK (
    public.my_role() IN ('coach', 'assistant_coach')
    AND public.is_my_schedule(schedule_id)
    AND recorded_by_user_id = auth.uid()
  );

CREATE POLICY attendance_coach_update ON public.attendance
  FOR UPDATE USING (
    public.my_role() IN ('coach', 'assistant_coach')
    AND public.is_my_schedule(schedule_id)
  )
  WITH CHECK (
    public.my_role() IN ('coach', 'assistant_coach')
    AND public.is_my_schedule(schedule_id)
    AND updated_by_user_id = auth.uid()
  );


-- =====================================================================
-- 12. Création automatique de la fiche app_users à l'inscription
-- =====================================================================
-- Un nouveau compte (coach) créé via la page de connexion arrive avec
-- is_active = false : il doit être approuvé et activé par un admin dans
-- l'espace "Utilisateurs" du back-office.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.app_users (user_id, first_name, last_name, phone, role, is_active)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'first_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'last_name', ''),
    NEW.raw_user_meta_data->>'phone',
    COALESCE(NEW.raw_user_meta_data->>'role', 'coach'),
    false
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- =====================================================================
-- 13. IMPORTANT — Créer votre premier compte admin
-- =====================================================================
-- 1) Créez un utilisateur depuis Supabase Dashboard > Authentication > Users
--    > Add user (ou laissez-le s'inscrire depuis la page KingGym).
-- 2) Récupérez son UUID puis exécutez :
--
--    UPDATE public.app_users
--    SET role = 'admin', is_active = true
--    WHERE user_id = 'UUID_DU_COMPTE';
--
-- Sans cette étape, personne ne peut administrer l'application.
