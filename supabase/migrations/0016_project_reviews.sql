DROP POLICY IF EXISTS "Project participants view reviews" ON public.reviews;
CREATE POLICY "Project participants view reviews" ON public.reviews
  FOR SELECT TO authenticated USING (EXISTS (
    SELECT 1 FROM public.projects p WHERE p.id = reviews.project_id
      AND auth.uid() IN (p.client_id, p.freelancer_id)
  ));

CREATE OR REPLACE FUNCTION public.submit_project_review(
  project_id_input UUID,
  rating_input NUMERIC,
  comment_input TEXT DEFAULT NULL
)
RETURNS public.reviews AS $$
DECLARE
  project_row public.projects;
  reviewee UUID;
  saved public.reviews;
BEGIN
  IF rating_input < 1 OR rating_input > 5 THEN RAISE EXCEPTION 'Rating must be between 1 and 5'; END IF;
  SELECT * INTO project_row FROM public.projects
  WHERE id = project_id_input AND status = 'completed'
    AND auth.uid() IN (client_id, freelancer_id)
  FOR UPDATE;
  IF project_row.id IS NULL THEN RAISE EXCEPTION 'Completed project not found'; END IF;
  IF EXISTS (SELECT 1 FROM public.reviews r WHERE r.project_id = project_row.id AND r.reviewer_id = auth.uid()) THEN
    RAISE EXCEPTION 'You have already reviewed this project';
  END IF;
  reviewee := CASE WHEN auth.uid() = project_row.client_id THEN project_row.freelancer_id ELSE project_row.client_id END;
  INSERT INTO public.reviews(project_id, reviewer_id, reviewee_id, rating, comment)
  VALUES (project_row.id, auth.uid(), reviewee, rating_input, NULLIF(trim(comment_input), ''))
  RETURNING * INTO saved;

  IF reviewee = project_row.freelancer_id THEN
    UPDATE public.freelancer_profiles fp
    SET rating = (SELECT AVG(r.rating) FROM public.reviews r WHERE r.reviewee_id = reviewee),
        reviews_count = (SELECT COUNT(*)::INTEGER FROM public.reviews r WHERE r.reviewee_id = reviewee)
    WHERE fp.user_id = reviewee;
  ELSE
    UPDATE public.client_profiles cp
    SET rating = (SELECT AVG(r.rating) FROM public.reviews r WHERE r.reviewee_id = reviewee),
        reviews_count = (SELECT COUNT(*)::INTEGER FROM public.reviews r WHERE r.reviewee_id = reviewee)
    WHERE cp.user_id = reviewee;
  END IF;
  RETURN saved;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.submit_project_review(UUID, NUMERIC, TEXT) TO authenticated;
REVOKE ALL ON FUNCTION public.submit_project_review(UUID, NUMERIC, TEXT) FROM PUBLIC;
