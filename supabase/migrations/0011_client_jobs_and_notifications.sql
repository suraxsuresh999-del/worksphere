-- Client job publishing is server-validated so a hidden button or direct API
-- call cannot bypass identity verification.
ALTER TABLE public.jobs
  ADD COLUMN IF NOT EXISTS category_label TEXT,
  ADD COLUMN IF NOT EXISTS required_skill_names TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS attachment_paths TEXT[] NOT NULL DEFAULT '{}';

INSERT INTO storage.buckets (id, name, public)
VALUES ('job-attachments', 'job-attachments', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Clients upload own job attachments" ON storage.objects;
CREATE POLICY "Clients upload own job attachments" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'job-attachments'
    AND (storage.foldername(name))[1] = 'jobs'
    AND (storage.foldername(name))[2] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Clients delete own job attachments" ON storage.objects;
CREATE POLICY "Clients delete own job attachments" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'job-attachments'
    AND (storage.foldername(name))[1] = 'jobs'
    AND (storage.foldername(name))[2] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Marketplace users view job attachments" ON storage.objects;
CREATE POLICY "Marketplace users view job attachments" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'job-attachments'
    AND EXISTS (
      SELECT 1 FROM public.jobs j
      WHERE storage.objects.name = ANY(j.attachment_paths)
        AND (j.status = 'open' OR j.client_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "Clients can insert jobs." ON public.jobs;
DROP POLICY IF EXISTS "Verified clients can insert jobs" ON public.jobs;
DROP POLICY IF EXISTS "Verified clients can insert their own jobs." ON public.jobs;
CREATE POLICY "Verified clients can insert their own jobs." ON public.jobs
  FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = client_id
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.user_type = 'client'
        AND p.verification_status = 'approved'
    )
  );

CREATE OR REPLACE FUNCTION public.publish_my_job(
  title_input TEXT,
  description_input TEXT,
  budget_min_input NUMERIC DEFAULT NULL,
  budget_max_input NUMERIC DEFAULT NULL,
  experience_level_input TEXT DEFAULT NULL,
  category_label_input TEXT DEFAULT NULL,
  required_skill_names_input TEXT[] DEFAULT '{}',
  attachment_paths_input TEXT[] DEFAULT '{}'
)
RETURNS public.jobs AS $$
DECLARE
  created_job public.jobs;
BEGIN
  PERFORM public.require_verified_marketplace_user('client');

  IF NULLIF(trim(title_input), '') IS NULL
    OR NULLIF(trim(description_input), '') IS NULL THEN
    RAISE EXCEPTION 'A job title and description are required';
  END IF;
  IF budget_min_input IS NOT NULL AND budget_min_input < 0
    OR budget_max_input IS NOT NULL AND budget_max_input < 0
    OR (budget_min_input IS NOT NULL AND budget_max_input IS NOT NULL AND budget_max_input < budget_min_input) THEN
    RAISE EXCEPTION 'Enter a valid budget range';
  END IF;
  IF EXISTS (
    SELECT 1 FROM unnest(attachment_paths_input) AS attachment(path)
    WHERE position('jobs/' || auth.uid()::TEXT || '/' IN path) <> 1
  ) THEN
    RAISE EXCEPTION 'Invalid job attachment';
  END IF;

  INSERT INTO public.jobs (
    client_id, title, description, budget_min, budget_max, experience_level,
    category_label, required_skill_names, attachment_paths, status
  ) VALUES (
    auth.uid(), trim(title_input), trim(description_input), budget_min_input,
    budget_max_input, NULLIF(trim(experience_level_input), ''),
    NULLIF(trim(category_label_input), ''),
    ARRAY(SELECT DISTINCT trim(skill) FROM unnest(required_skill_names_input) AS skills(skill) WHERE trim(skill) <> ''),
    COALESCE(attachment_paths_input, '{}'),
    'open'
  ) RETURNING * INTO created_job;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    auth.uid(), 'job_posted', 'Job published successfully',
    'Your job "' || created_job.title || '" is now visible to freelancers.',
    jsonb_build_object('job_id', created_job.id)
  );

  RETURN created_job;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.publish_my_job(TEXT, TEXT, NUMERIC, NUMERIC, TEXT, TEXT, TEXT[], TEXT[]) TO authenticated;

-- Replace both historical policy names. PostgreSQL combines multiple INSERT
-- policies with OR, so leaving the previous policy in place would allow a
-- proposal for a closed job through the less restrictive rule.
DROP POLICY IF EXISTS "Freelancers can insert applications." ON public.job_applications;
DROP POLICY IF EXISTS "Verified freelancers can insert applications" ON public.job_applications;
DROP POLICY IF EXISTS "Verified freelancers can insert applications." ON public.job_applications;
CREATE POLICY "Verified freelancers can insert applications" ON public.job_applications
  FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = freelancer_id
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.user_type = 'freelancer'
        AND p.verification_status = 'approved'
    )
    AND EXISTS (
      SELECT 1 FROM public.jobs j
      WHERE j.id = job_id AND j.status = 'open'
    )
  );

CREATE OR REPLACE FUNCTION public.get_discoverable_freelancers()
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  avatar_url TEXT,
  verification_status public.verification_status,
  title TEXT,
  primary_skill TEXT,
  secondary_skills TEXT[],
  languages TEXT[],
  years_experience NUMERIC,
  availability TEXT,
  portfolio_url TEXT
) AS $$
BEGIN
  PERFORM public.require_verified_marketplace_user('client');
  RETURN QUERY
  SELECT p.id, p.full_name, p.avatar_url, p.verification_status, f.title,
         f.primary_skill, f.secondary_skills, f.languages, f.years_experience,
         f.availability, f.portfolio_url
  FROM public.profiles p
  JOIN public.freelancer_profiles f ON f.user_id = p.id
  WHERE p.user_type = 'freelancer'
    AND p.verification_status = 'approved'
  ORDER BY p.created_at DESC;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.get_discoverable_freelancers() TO authenticated;

-- The existing table is reused; this index keeps unread badges and feeds fast.
CREATE INDEX IF NOT EXISTS notifications_user_unread_created_idx
  ON public.notifications (user_id, is_read, created_at DESC);
