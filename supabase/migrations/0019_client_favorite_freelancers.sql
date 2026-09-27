CREATE TABLE IF NOT EXISTS public.client_favorite_freelancers (
  client_id UUID NOT NULL REFERENCES public.client_profiles(user_id) ON DELETE CASCADE,
  freelancer_id UUID NOT NULL REFERENCES public.freelancer_profiles(user_id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (client_id, freelancer_id)
);
ALTER TABLE public.client_favorite_freelancers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Clients manage own freelancer favorites" ON public.client_favorite_freelancers;
CREATE POLICY "Clients manage own freelancer favorites" ON public.client_favorite_freelancers FOR ALL TO authenticated
  USING (client_id = auth.uid()) WITH CHECK (client_id = auth.uid());
CREATE INDEX IF NOT EXISTS client_favorite_freelancers_freelancer_idx
  ON public.client_favorite_freelancers(freelancer_id);
