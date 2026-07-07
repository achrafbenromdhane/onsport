-- =====================================================================
-- SCRIPT DE CORRECTIONS - Schéma gestion de salle de sport
-- =====================================================================
-- À exécuter APRES la création des tables d'origine.
-- Chaque section est indépendante, commentée, et idempotente quand possible
-- (IF NOT EXISTS / DROP IF EXISTS avant recréation).
-- =====================================================================


-- =====================================================================
-- 1. CONTRAINTES MANQUANTES
-- =====================================================================

-- 1.1 max_age doit être >= min_age (quand les deux sont renseignés)
ALTER TABLE public.training_schedules
  ADD CONSTRAINT training_schedules_age_check
  CHECK (max_age IS NULL OR min_age IS NULL OR max_age >= min_age);

-- 1.2 end_date doit être postérieure à start_date sur les adhésions
ALTER TABLE public.memberships
  ADD CONSTRAINT memberships_dates_check
  CHECK (end_date IS NULL OR end_date >= start_date);

-- 1.3 assigned_until doit être postérieur à assigned_from pour un coach affecté
ALTER TABLE public.schedule_coaches
  ADD CONSTRAINT schedule_coaches_dates_check
  CHECK (assigned_until IS NULL OR assigned_until >= assigned_from);

-- 1.4 Empêcher le double pointage d'un membre sur un même créneau le même jour
ALTER TABLE public.attendance
  ADD CONSTRAINT attendance_unique_check
  UNIQUE (membership_id, schedule_id, attendance_date);

-- 1.5 Empêcher une double adhésion active d'un même membre sur le même sport
--     (optionnel mais recommandé — décommentez si un membre ne peut avoir
--      qu'une seule adhésion active par sport à la fois)
-- CREATE UNIQUE INDEX memberships_one_active_per_sport
--   ON public.memberships (member_id, sport_id)
--   WHERE membership_status = 'active';


-- =====================================================================
-- 2. COHÉRENCE DES TIMESTAMPS (updated_at manquants)
-- =====================================================================

ALTER TABLE public.guardians
  ADD COLUMN updated_at timestamp with time zone NOT NULL DEFAULT now();

ALTER TABLE public.sports
  ADD COLUMN updated_at timestamp with time zone NOT NULL DEFAULT now();

ALTER TABLE public.training_schedules
  ADD COLUMN updated_at timestamp with time zone NOT NULL DEFAULT now();

ALTER TABLE public.payments
  ADD COLUMN updated_at timestamp with time zone NOT NULL DEFAULT now();

-- 2.1 Fonction générique de mise à jour de updated_at
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- 2.2 Trigger appliqué à toutes les tables concernées
DROP TRIGGER IF EXISTS trg_set_updated_at ON public.guardians;
CREATE TRIGGER trg_set_updated_at
  BEFORE UPDATE ON public.guardians
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_set_updated_at ON public.sports;
CREATE TRIGGER trg_set_updated_at
  BEFORE UPDATE ON public.sports
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_set_updated_at ON public.training_schedules;
CREATE TRIGGER trg_set_updated_at
  BEFORE UPDATE ON public.training_schedules
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_set_updated_at ON public.payments;
CREATE TRIGGER trg_set_updated_at
  BEFORE UPDATE ON public.payments
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_set_updated_at ON public.members;
CREATE TRIGGER trg_set_updated_at
  BEFORE UPDATE ON public.members
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_set_updated_at ON public.memberships;
CREATE TRIGGER trg_set_updated_at
  BEFORE UPDATE ON public.memberships
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_set_updated_at ON public.app_users;
CREATE TRIGGER trg_set_updated_at
  BEFORE UPDATE ON public.app_users
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Note : attendance a déjà updated_by_user_id/updated_at gérés manuellement
-- côté applicatif — pas de trigger automatique ici pour ne pas écraser cette logique.


-- =====================================================================
-- 3. CLAUSES ON DELETE EXPLICITES SUR LES FK
-- =====================================================================
-- Choix : RESTRICT par défaut sur les données financières/historiques
-- (paiements, présences), CASCADE uniquement sur les tables de jointure
-- pures (liens entre entités, pas de valeur propre).

-- 3.1 training_schedules -> sports : on empêche la suppression d'un sport
--     tant qu'il a des créneaux (déjà le comportement par défaut, explicité ici)
ALTER TABLE public.training_schedules
  DROP CONSTRAINT training_schedules_sport_id_fkey,
  ADD CONSTRAINT training_schedules_sport_id_fkey
    FOREIGN KEY (sport_id) REFERENCES public.sports(sport_id)
    ON DELETE RESTRICT;

-- 3.2 member_guardians : liens purs -> CASCADE si le membre ou le tuteur est supprimé
ALTER TABLE public.member_guardians
  DROP CONSTRAINT member_guardians_member_id_fkey,
  ADD CONSTRAINT member_guardians_member_id_fkey
    FOREIGN KEY (member_id) REFERENCES public.members(member_id)
    ON DELETE CASCADE;

ALTER TABLE public.member_guardians
  DROP CONSTRAINT member_guardians_guardian_id_fkey,
  ADD CONSTRAINT member_guardians_guardian_id_fkey
    FOREIGN KEY (guardian_id) REFERENCES public.guardians(guardian_id)
    ON DELETE CASCADE;

-- 3.3 memberships -> members : RESTRICT (ne jamais supprimer un membre
--     ayant un historique d'adhésion ; utiliser le statut 'archived' à la place)
ALTER TABLE public.memberships
  DROP CONSTRAINT memberships_member_id_fkey,
  ADD CONSTRAINT memberships_member_id_fkey
    FOREIGN KEY (member_id) REFERENCES public.members(member_id)
    ON DELETE RESTRICT;

ALTER TABLE public.memberships
  DROP CONSTRAINT memberships_sport_id_fkey,
  ADD CONSTRAINT memberships_sport_id_fkey
    FOREIGN KEY (sport_id) REFERENCES public.sports(sport_id)
    ON DELETE RESTRICT;

-- 3.4 memberships -> training_schedules : SET NULL si le créneau est supprimé
--     (l'adhésion reste valide, juste "sans créneau assigné")
ALTER TABLE public.memberships
  DROP CONSTRAINT memberships_schedule_id_fkey,
  ADD CONSTRAINT memberships_schedule_id_fkey
    FOREIGN KEY (schedule_id) REFERENCES public.training_schedules(schedule_id)
    ON DELETE SET NULL;

-- 3.5 payments -> memberships : RESTRICT (jamais perdre l'historique financier)
ALTER TABLE public.payments
  DROP CONSTRAINT payments_membership_id_fkey,
  ADD CONSTRAINT payments_membership_id_fkey
    FOREIGN KEY (membership_id) REFERENCES public.memberships(membership_id)
    ON DELETE RESTRICT;

-- 3.6 attendance -> memberships / schedules : RESTRICT (historique de présence)
ALTER TABLE public.attendance
  DROP CONSTRAINT attendance_membership_id_fkey,
  ADD CONSTRAINT attendance_membership_id_fkey
    FOREIGN KEY (membership_id) REFERENCES public.memberships(membership_id)
    ON DELETE RESTRICT;

ALTER TABLE public.attendance
  DROP CONSTRAINT attendance_schedule_id_fkey,
  ADD CONSTRAINT attendance_schedule_id_fkey
    FOREIGN KEY (schedule_id) REFERENCES public.training_schedules(schedule_id)
    ON DELETE RESTRICT;

-- 3.7 attendance -> app_users (recorded_by / updated_by) : SET NULL
--     si l'utilisateur est supprimé (on garde le pointage, on perd juste l'auteur)
ALTER TABLE public.attendance
  DROP CONSTRAINT attendance_recorded_by_user_id_fkey,
  ADD CONSTRAINT attendance_recorded_by_user_id_fkey
    FOREIGN KEY (recorded_by_user_id) REFERENCES public.app_users(user_id)
    ON DELETE SET NULL;

ALTER TABLE public.attendance
  DROP CONSTRAINT attendance_updated_by_user_id_fkey,
  ADD CONSTRAINT attendance_updated_by_user_id_fkey
    FOREIGN KEY (updated_by_user_id) REFERENCES public.app_users(user_id)
    ON DELETE SET NULL;

-- 3.8 coaches -> app_users : RESTRICT (un coach lié à un historique de créneaux
--     ne doit pas disparaître silencieusement)
ALTER TABLE public.coaches
  DROP CONSTRAINT coaches_user_id_fkey,
  ADD CONSTRAINT coaches_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES public.app_users(user_id)
    ON DELETE RESTRICT;

-- 3.9 schedule_coaches : liens purs -> CASCADE
ALTER TABLE public.schedule_coaches
  DROP CONSTRAINT schedule_coaches_schedule_id_fkey,
  ADD CONSTRAINT schedule_coaches_schedule_id_fkey
    FOREIGN KEY (schedule_id) REFERENCES public.training_schedules(schedule_id)
    ON DELETE CASCADE;

ALTER TABLE public.schedule_coaches
  DROP CONSTRAINT schedule_coaches_coach_id_fkey,
  ADD CONSTRAINT schedule_coaches_coach_id_fkey
    FOREIGN KEY (coach_id) REFERENCES public.coaches(coach_id)
    ON DELETE CASCADE;


-- =====================================================================
-- 4. GESTION DE LA CAPACITÉ DES CRÉNEAUX
-- =====================================================================
-- Trigger qui empêche de dépasser training_schedules.capacity lors de
-- l'insertion/mise à jour d'une adhésion active liée à un créneau.

CREATE OR REPLACE FUNCTION public.check_schedule_capacity()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_capacity integer;
  v_current_count integer;
BEGIN
  IF NEW.schedule_id IS NULL OR NEW.membership_status <> 'active' THEN
    RETURN NEW;
  END IF;

  SELECT capacity INTO v_capacity
  FROM public.training_schedules
  WHERE schedule_id = NEW.schedule_id;

  IF v_capacity IS NULL THEN
    RETURN NEW; -- pas de limite définie
  END IF;

  SELECT count(*) INTO v_current_count
  FROM public.memberships
  WHERE schedule_id = NEW.schedule_id
    AND membership_status = 'active'
    AND membership_id <> NEW.membership_id;

  IF v_current_count >= v_capacity THEN
    RAISE EXCEPTION 'Capacité maximale atteinte pour ce créneau (capacité: %, inscrits actifs: %)',
      v_capacity, v_current_count;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_schedule_capacity ON public.memberships;
CREATE TRIGGER trg_check_schedule_capacity
  BEFORE INSERT OR UPDATE OF schedule_id, membership_status ON public.memberships
  FOR EACH ROW EXECUTE FUNCTION public.check_schedule_capacity();


-- =====================================================================
-- 5. INDEX SUR LES CLÉS ÉTRANGÈRES (performance des jointures)
-- =====================================================================

CREATE INDEX IF NOT EXISTS idx_training_schedules_sport_id
  ON public.training_schedules (sport_id);

CREATE INDEX IF NOT EXISTS idx_member_guardians_member_id
  ON public.member_guardians (member_id);

CREATE INDEX IF NOT EXISTS idx_member_guardians_guardian_id
  ON public.member_guardians (guardian_id);

CREATE INDEX IF NOT EXISTS idx_memberships_member_id
  ON public.memberships (member_id);

CREATE INDEX IF NOT EXISTS idx_memberships_sport_id
  ON public.memberships (sport_id);

CREATE INDEX IF NOT EXISTS idx_memberships_schedule_id
  ON public.memberships (schedule_id);

CREATE INDEX IF NOT EXISTS idx_memberships_status
  ON public.memberships (membership_status);

CREATE INDEX IF NOT EXISTS idx_payments_membership_id
  ON public.payments (membership_id);

CREATE INDEX IF NOT EXISTS idx_payments_date
  ON public.payments (payment_date);

CREATE INDEX IF NOT EXISTS idx_attendance_membership_id
  ON public.attendance (membership_id);

CREATE INDEX IF NOT EXISTS idx_attendance_schedule_id
  ON public.attendance (schedule_id);

CREATE INDEX IF NOT EXISTS idx_attendance_date
  ON public.attendance (attendance_date);

CREATE INDEX IF NOT EXISTS idx_coaches_user_id
  ON public.coaches (user_id);

CREATE INDEX IF NOT EXISTS idx_schedule_coaches_schedule_id
  ON public.schedule_coaches (schedule_id);

CREATE INDEX IF NOT EXISTS idx_schedule_coaches_coach_id
  ON public.schedule_coaches (coach_id);


-- =====================================================================
-- 6. SÉCURITÉ RLS (Row Level Security) - Supabase
-- =====================================================================
-- Politique de base : lecture/écriture réservée aux utilisateurs authentifiés
-- ayant un rôle dans app_users. À affiner selon vos règles métier exactes
-- (ex: un coach ne voit que ses propres créneaux, un membre ne voit que
-- ses propres données, etc.)

ALTER TABLE public.members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guardians ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_guardians ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coaches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.schedule_coaches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sports ENABLE ROW LEVEL SECURITY;

-- Exemple de politique générique : seuls les utilisateurs actifs et
-- authentifiés référencés dans app_users peuvent lire ces tables.
-- ⚠️ À adapter : ceci est un point de départ, pas une politique de prod complète.

CREATE POLICY app_users_can_read_members
  ON public.members FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.app_users au
      WHERE au.user_id = auth.uid() AND au.is_active = true
    )
  );

CREATE POLICY app_users_can_read_guardians
  ON public.guardians FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.app_users au
      WHERE au.user_id = auth.uid() AND au.is_active = true
    )
  );

CREATE POLICY app_users_can_read_memberships
  ON public.memberships FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.app_users au
      WHERE au.user_id = auth.uid() AND au.is_active = true
    )
  );

CREATE POLICY app_users_can_read_payments
  ON public.payments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.app_users au
      WHERE au.user_id = auth.uid() AND au.is_active = true
    )
  );

-- Politique restrictive pour la modification : uniquement admin/accountant
CREATE POLICY only_admin_accountant_write_payments
  ON public.payments FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.app_users au
      WHERE au.user_id = auth.uid()
        AND au.is_active = true
        AND au.role IN ('admin', 'accountant')
    )
  );

-- NOTE : medical_notes dans members est une donnée de santé sensible (RGPD
-- catégorie spéciale). Envisagez soit une colonne séparée avec RLS dédiée
-- (lecture réservée à admin/coach concerné), soit un chiffrement applicatif
-- côté client avant insertion.


-- =====================================================================
-- 7. RECOMMANDATIONS NON APPLIQUÉES ICI (à décider avec vous)
-- =====================================================================
-- - Table equipment_items si payment_type='equipment' doit suivre un inventaire
-- - Colonne currency sur payments/memberships si multi-devise
-- - Chiffrement applicatif de medical_notes si RGPD santé strict
-- - RLS fine par rôle (coach ne voit que ses créneaux, membre ne voit que
--   ses propres données) — actuellement RLS large "tout utilisateur actif"
