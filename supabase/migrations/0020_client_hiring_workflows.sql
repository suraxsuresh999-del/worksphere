-- Client hiring actions stay inside the existing job application and project workflow.
CREATE TABLE IF NOT EXISTS public.job_offers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  application_id UUID NOT NULL REFERENCES public.job_applications(id) ON DELETE CASCADE,
  job_id UUID NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES public.client_profiles(user_id) ON DELETE CASCADE,
  freelancer_id UUID NOT NULL REFERENCES public.freelancer_profiles(user_id) ON DELETE CASCADE,
  amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  duration_text TEXT,
  message TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined', 'withdrawn')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  responded_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS job_offers_freelancer_pending_idx ON public.job_offers(freelancer_id, created_at DESC) WHERE status = 'pending';
ALTER TABLE public.job_offers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Hiring participants read offers" ON public.job_offers;
CREATE POLICY "Hiring participants read offers" ON public.job_offers FOR SELECT TO authenticated
  USING (auth.uid() IN (client_id, freelancer_id) OR public.is_platform_admin());

CREATE TABLE IF NOT EXISTS public.job_interviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  application_id UUID NOT NULL REFERENCES public.job_applications(id) ON DELETE CASCADE,
  job_id UUID NOT NULL REFERENCES public.jobs(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES public.client_profiles(user_id) ON DELETE CASCADE,
  freelancer_id UUID NOT NULL REFERENCES public.freelancer_profiles(user_id) ON DELETE CASCADE,
  scheduled_at TIMESTAMPTZ NOT NULL,
  notes TEXT,
  status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'cancelled', 'completed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS job_interviews_client_date_idx ON public.job_interviews(client_id, scheduled_at);
CREATE INDEX IF NOT EXISTS job_interviews_freelancer_date_idx ON public.job_interviews(freelancer_id, scheduled_at);
ALTER TABLE public.job_interviews ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Hiring participants read interviews" ON public.job_interviews;
CREATE POLICY "Hiring participants read interviews" ON public.job_interviews FOR SELECT TO authenticated
  USING (auth.uid() IN (client_id, freelancer_id) OR public.is_platform_admin());

CREATE OR REPLACE FUNCTION public.review_job_application(application_id_input UUID, decision_input TEXT)
RETURNS public.job_applications AS $$
DECLARE saved public.job_applications;
BEGIN
  IF auth.uid() IS NULL OR decision_input NOT IN ('shortlisted', 'rejected') THEN
    RAISE EXCEPTION 'Invalid application decision';
  END IF;
  UPDATE public.job_applications a
  SET status = decision_input::public.application_status
  FROM public.jobs j
  WHERE a.id = application_id_input AND j.id = a.job_id AND j.client_id = auth.uid()
    AND j.status = 'open'
    AND ((decision_input = 'shortlisted' AND a.status = 'pending')
      OR (decision_input = 'rejected' AND a.status IN ('pending', 'shortlisted')))
  RETURNING a.* INTO saved;
  IF saved.id IS NULL THEN RAISE EXCEPTION 'Application is unavailable for review'; END IF;
  INSERT INTO public.notifications(user_id, type, title, body, data)
  VALUES (saved.freelancer_id, CASE WHEN decision_input = 'rejected' THEN 'application_rejected'::public.notification_type ELSE 'application_received'::public.notification_type END,
    CASE WHEN decision_input = 'rejected' THEN 'Application update' ELSE 'You were shortlisted' END,
    CASE WHEN decision_input = 'rejected' THEN 'Your application was declined.' ELSE 'A client shortlisted your application. Check your messages for next steps.' END,
    jsonb_build_object('job_id', saved.job_id, 'application_id', saved.id));
  IF decision_input = 'rejected' THEN
    UPDATE public.job_offers SET status = 'withdrawn', responded_at = now()
      WHERE application_id = saved.id AND status = 'pending';
    UPDATE public.job_interviews SET status = 'cancelled'
      WHERE application_id = saved.id AND status = 'scheduled';
  END IF;
  RETURN saved;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.create_job_offer(application_id_input UUID, amount_input NUMERIC, duration_input TEXT, message_input TEXT DEFAULT NULL)
RETURNS public.job_offers AS $$
DECLARE application_row public.job_applications; job_row public.jobs; offer_row public.job_offers;
BEGIN
  IF amount_input IS NULL OR amount_input <= 0 THEN RAISE EXCEPTION 'Offer amount must be positive'; END IF;
  SELECT a INTO application_row
  FROM public.job_applications a JOIN public.jobs j ON j.id = a.job_id
  WHERE a.id = application_id_input AND j.client_id = auth.uid() AND j.status = 'open'
    AND a.status IN ('pending', 'shortlisted') FOR UPDATE OF a, j;
  IF application_row.id IS NULL THEN RAISE EXCEPTION 'Application is unavailable for an offer'; END IF;
  SELECT * INTO job_row FROM public.jobs WHERE id = application_row.job_id;
  IF EXISTS (SELECT 1 FROM public.job_offers o WHERE o.application_id = application_id_input AND o.status = 'pending') THEN
    RAISE EXCEPTION 'This application already has a pending offer';
  END IF;
  INSERT INTO public.job_offers(application_id, job_id, client_id, freelancer_id, amount, duration_text, message)
  VALUES (application_row.id, application_row.job_id, auth.uid(), application_row.freelancer_id, amount_input, NULLIF(trim(duration_input), ''), NULLIF(trim(message_input), ''))
  RETURNING * INTO offer_row;
  INSERT INTO public.notifications(user_id, type, title, body, data)
  VALUES (offer_row.freelancer_id, 'application_received', 'You received a job offer', 'Review the offer in your applications.',
    jsonb_build_object('offer_id', offer_row.id, 'job_id', offer_row.job_id));
  RETURN offer_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.respond_to_job_offer(offer_id_input UUID, decision_input TEXT)
RETURNS UUID AS $$
DECLARE offer_row public.job_offers; application_row public.job_applications; job_row public.jobs; project_id UUID;
BEGIN
  IF decision_input NOT IN ('accepted', 'declined') THEN RAISE EXCEPTION 'Invalid offer response'; END IF;
  SELECT * INTO offer_row FROM public.job_offers WHERE id = offer_id_input AND freelancer_id = auth.uid() AND status = 'pending' FOR UPDATE;
  IF offer_row.id IS NULL THEN RAISE EXCEPTION 'Offer is unavailable'; END IF;
  SELECT * INTO job_row FROM public.jobs WHERE id = offer_row.job_id FOR UPDATE;
  IF job_row.status <> 'open' THEN RAISE EXCEPTION 'This job is no longer accepting offers'; END IF;
  UPDATE public.job_offers SET status = decision_input, responded_at = now() WHERE id = offer_row.id;
  IF decision_input = 'declined' THEN RETURN NULL; END IF;

  SELECT * INTO application_row FROM public.job_applications WHERE id = offer_row.application_id FOR UPDATE;
  IF application_row.status NOT IN ('pending', 'shortlisted') THEN RAISE EXCEPTION 'Application is no longer eligible'; END IF;
  INSERT INTO public.projects(job_id, client_id, freelancer_id, title, description, total_amount, status)
  VALUES (job_row.id, job_row.client_id, offer_row.freelancer_id, job_row.title, job_row.description, offer_row.amount, 'active')
  RETURNING id INTO project_id;
  UPDATE public.job_applications SET status = 'accepted' WHERE id = application_row.id;
  UPDATE public.jobs SET status = 'in_progress' WHERE id = job_row.id;
  UPDATE public.job_offers SET status = 'withdrawn', responded_at = now()
    WHERE job_id = job_row.id AND id <> offer_row.id AND status = 'pending';
  UPDATE public.job_interviews SET status = 'cancelled'
    WHERE job_id = job_row.id AND status = 'scheduled';
  WITH rejected_applications AS (
    UPDATE public.job_applications SET status = 'rejected'
    WHERE job_id = job_row.id AND id <> application_row.id AND status IN ('pending', 'shortlisted')
    RETURNING freelancer_id
  )
  INSERT INTO public.notifications(user_id, type, title, body, data)
  SELECT freelancer_id, 'application_rejected', 'Job filled', 'The client accepted another offer for this job.',
    jsonb_build_object('job_id', job_row.id)
  FROM rejected_applications;
  INSERT INTO public.notifications(user_id, type, title, body, data)
  VALUES
    (offer_row.client_id, 'application_accepted', 'Offer accepted', 'The freelancer accepted your offer and a project was created.', jsonb_build_object('project_id', project_id, 'job_id', job_row.id)),
    (offer_row.freelancer_id, 'application_accepted', 'Project started', 'Your accepted offer is now an active project.', jsonb_build_object('project_id', project_id, 'job_id', job_row.id));
  RETURN project_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.schedule_job_interview(application_id_input UUID, scheduled_at_input TIMESTAMPTZ, notes_input TEXT DEFAULT NULL)
RETURNS public.job_interviews AS $$
DECLARE application_row public.job_applications; job_row public.jobs; interview_row public.job_interviews;
BEGIN
  IF scheduled_at_input <= now() THEN RAISE EXCEPTION 'Interview time must be in the future'; END IF;
  SELECT a INTO application_row
  FROM public.job_applications a JOIN public.jobs j ON j.id = a.job_id
  WHERE a.id = application_id_input AND j.client_id = auth.uid() AND j.status = 'open'
    AND a.status IN ('pending', 'shortlisted') FOR UPDATE OF a, j;
  IF application_row.id IS NULL THEN RAISE EXCEPTION 'Application is unavailable for scheduling'; END IF;
  SELECT * INTO job_row FROM public.jobs WHERE id = application_row.job_id;
  UPDATE public.job_applications SET status = 'shortlisted' WHERE id = application_row.id AND status = 'pending';
  INSERT INTO public.job_interviews(application_id, job_id, client_id, freelancer_id, scheduled_at, notes)
  VALUES (application_row.id, application_row.job_id, auth.uid(), application_row.freelancer_id, scheduled_at_input, NULLIF(trim(notes_input), ''))
  RETURNING * INTO interview_row;
  INSERT INTO public.notifications(user_id, type, title, body, data)
  VALUES (interview_row.freelancer_id, 'message', 'Interview scheduled', 'A client scheduled an interview. See your calendar for details.', jsonb_build_object('interview_id', interview_row.id, 'job_id', interview_row.job_id));
  RETURN interview_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.review_job_application(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_job_offer(UUID, NUMERIC, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_to_job_offer(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.schedule_job_interview(UUID, TIMESTAMPTZ, TEXT) TO authenticated;
REVOKE ALL ON FUNCTION public.review_job_application(UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_job_offer(UUID, NUMERIC, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.respond_to_job_offer(UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.schedule_job_interview(UUID, TIMESTAMPTZ, TEXT) FROM PUBLIC;
