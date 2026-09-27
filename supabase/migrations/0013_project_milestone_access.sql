-- Participant-only access to the existing project milestone workflow.
DROP POLICY IF EXISTS "Project participants view milestones" ON public.milestones;
CREATE POLICY "Project participants view milestones"
  ON public.milestones FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.projects p
    WHERE p.id = milestones.project_id
      AND auth.uid() IN (p.client_id, p.freelancer_id)
  ));

DROP POLICY IF EXISTS "Project clients create milestones" ON public.milestones;
CREATE POLICY "Project clients create milestones"
  ON public.milestones FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.projects p
    WHERE p.id = milestones.project_id AND p.client_id = auth.uid()
  ));

CREATE OR REPLACE FUNCTION public.submit_project_milestone(
  milestone_id_input UUID,
  submission_notes_input TEXT
)
RETURNS public.milestones AS $$
DECLARE saved public.milestones;
BEGIN
  UPDATE public.milestones m
  SET status = 'submitted',
      submission_notes = NULLIF(trim(submission_notes_input), '')
  FROM public.projects p
  WHERE m.id = milestone_id_input
    AND p.id = m.project_id
    AND p.freelancer_id = auth.uid()
    AND m.status IN ('pending', 'in_progress', 'revision_required')
  RETURNING m.* INTO saved;
  IF saved.id IS NULL THEN RAISE EXCEPTION 'Milestone unavailable for submission'; END IF;
  RETURN saved;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.start_project_milestone(milestone_id_input UUID)
RETURNS public.milestones AS $$
DECLARE saved public.milestones;
BEGIN
  UPDATE public.milestones m
  SET status = 'in_progress'
  FROM public.projects p
  WHERE m.id = milestone_id_input
    AND p.id = m.project_id
    AND p.freelancer_id = auth.uid()
    AND m.status = 'pending'
  RETURNING m.* INTO saved;
  IF saved.id IS NULL THEN RAISE EXCEPTION 'Milestone unavailable to start'; END IF;
  RETURN saved;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.review_project_milestone(
  milestone_id_input UUID,
  decision_input TEXT
)
RETURNS public.milestones AS $$
DECLARE saved public.milestones;
BEGIN
  IF decision_input NOT IN ('approved', 'revision_required') THEN
    RAISE EXCEPTION 'Invalid milestone decision';
  END IF;
  UPDATE public.milestones m
  SET status = decision_input::public.milestone_status
  FROM public.projects p
  WHERE m.id = milestone_id_input
    AND p.id = m.project_id
    AND p.client_id = auth.uid()
    AND m.status = 'submitted'
  RETURNING m.* INTO saved;
  IF saved.id IS NULL THEN RAISE EXCEPTION 'Milestone unavailable for review'; END IF;
  RETURN saved;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.submit_project_milestone(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_project_milestone(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.review_project_milestone(UUID, TEXT) TO authenticated;
REVOKE ALL ON FUNCTION public.submit_project_milestone(UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.start_project_milestone(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.review_project_milestone(UUID, TEXT) FROM PUBLIC;
