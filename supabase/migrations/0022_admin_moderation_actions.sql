CREATE OR REPLACE FUNCTION public.admin_set_account_status(user_id_input UUID, status_input TEXT, reason_input TEXT DEFAULT NULL)
RETURNS VOID AS $$
DECLARE old_status TEXT;
BEGIN
  IF NOT public.is_platform_admin() OR status_input NOT IN ('active', 'suspended') OR user_id_input = auth.uid() THEN
    RAISE EXCEPTION 'Invalid administrator account action';
  END IF;
  UPDATE public.profiles SET account_status = status_input
  WHERE id = user_id_input AND user_type <> 'admin'
  RETURNING account_status INTO old_status;
  IF old_status IS NULL THEN RAISE EXCEPTION 'User is unavailable for this action'; END IF;
  -- Prevent new sign-ins and token refresh while suspended. Existing short-lived
  -- access JWTs expire normally; the profile status remains the audit source.
  UPDATE auth.users SET banned_until = CASE WHEN status_input = 'suspended'
    THEN now() + interval '100 years' ELSE NULL END
  WHERE id = user_id_input;
  INSERT INTO public.notifications(user_id, type, title, body, data)
  VALUES (user_id_input, 'system', CASE WHEN status_input = 'suspended' THEN 'Account suspended' ELSE 'Account reactivated' END,
    COALESCE(NULLIF(trim(reason_input), ''), CASE WHEN status_input = 'suspended' THEN 'An administrator suspended your account.' ELSE 'An administrator reactivated your account.' END),
    jsonb_build_object('account_status', status_input));
  INSERT INTO public.admin_logs(admin_id, action, target_type, target_id, metadata)
  VALUES (auth.uid(), 'set_account_status', 'profile', user_id_input,
    jsonb_build_object('status', status_input, 'reason', NULLIF(trim(reason_input), '')));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.admin_moderate_job(job_id_input UUID, status_input TEXT, reason_input TEXT DEFAULT NULL)
RETURNS VOID AS $$
DECLARE old_status public.job_status;
BEGIN
  IF NOT public.is_platform_admin() OR status_input NOT IN ('open', 'paused', 'closed') THEN
    RAISE EXCEPTION 'Invalid administrator job action';
  END IF;
  UPDATE public.jobs SET status = status_input::public.job_status
  WHERE id = job_id_input AND status IN ('open', 'paused')
  RETURNING status INTO old_status;
  IF old_status IS NULL THEN RAISE EXCEPTION 'Job is unavailable or has moved into hiring'; END IF;
  INSERT INTO public.notifications(user_id, type, title, body, data)
  SELECT j.client_id, 'system', 'Job moderation update',
    COALESCE(NULLIF(trim(reason_input), ''), 'An administrator changed the job status to ' || status_input || '.'),
    jsonb_build_object('job_id', j.id, 'status', status_input)
  FROM public.jobs j WHERE j.id = job_id_input;
  INSERT INTO public.admin_logs(admin_id, action, target_type, target_id, metadata)
  VALUES (auth.uid(), 'moderate_job', 'job', job_id_input,
    jsonb_build_object('status', status_input, 'reason', NULLIF(trim(reason_input), '')));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.admin_review_project(project_id_input UUID, status_input TEXT, reason_input TEXT DEFAULT NULL)
RETURNS VOID AS $$
DECLARE old_status public.project_status;
BEGIN
  IF NOT public.is_platform_admin() OR status_input NOT IN ('active', 'on_hold', 'disputed') THEN
    RAISE EXCEPTION 'Invalid administrator project action';
  END IF;
  UPDATE public.projects SET status = status_input::public.project_status
  WHERE id = project_id_input AND status IN ('active', 'on_hold', 'disputed')
  RETURNING status INTO old_status;
  IF old_status IS NULL THEN RAISE EXCEPTION 'Project is unavailable for review'; END IF;
  INSERT INTO public.notifications(user_id, type, title, body, data)
  SELECT participant_id, 'system', 'Project status update',
    COALESCE(NULLIF(trim(reason_input), ''), 'An administrator changed the project status to ' || status_input || '.'),
    jsonb_build_object('project_id', project_id_input, 'status', status_input)
  FROM public.projects p CROSS JOIN LATERAL (VALUES (p.client_id), (p.freelancer_id)) participants(participant_id)
  WHERE p.id = project_id_input;
  INSERT INTO public.admin_logs(admin_id, action, target_type, target_id, metadata)
  VALUES (auth.uid(), 'review_project', 'project', project_id_input,
    jsonb_build_object('status', status_input, 'reason', NULLIF(trim(reason_input), '')));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.get_admin_dashboard_summary()
RETURNS JSONB AS $$
BEGIN
  IF NOT public.is_platform_admin() THEN RAISE EXCEPTION 'Administrator access is required'; END IF;
  RETURN jsonb_build_object(
    'total_users', (SELECT COUNT(*) FROM public.profiles WHERE user_type <> 'admin'),
    'freelancers', (SELECT COUNT(*) FROM public.profiles WHERE user_type = 'freelancer'),
    'clients', (SELECT COUNT(*) FROM public.profiles WHERE user_type = 'client'),
    'open_jobs', (SELECT COUNT(*) FROM public.jobs WHERE status = 'open'),
    'active_projects', (SELECT COUNT(*) FROM public.projects WHERE status = 'active'),
    'completed_projects', (SELECT COUNT(*) FROM public.projects WHERE status = 'completed'),
    'pending_verifications', (SELECT COUNT(*) FROM public.profiles WHERE verification_status = 'pending'),
    'total_transactions', (SELECT COUNT(*) FROM public.project_payment_transactions),
    'verified_revenue', COALESCE((SELECT SUM(amount) FROM public.project_payment_transactions WHERE payment_status = 'verified'), 0),
    'reports_disputes', (SELECT COUNT(*) FROM public.reports WHERE status IN ('open', 'in_progress'))
      + (SELECT COUNT(*) FROM public.projects WHERE status = 'disputed')
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.admin_set_account_status(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_moderate_job(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_project(UUID, TEXT, TEXT) TO authenticated;
REVOKE ALL ON FUNCTION public.admin_set_account_status(UUID, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_moderate_job(UUID, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_review_project(UUID, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_admin_dashboard_summary() TO authenticated;
