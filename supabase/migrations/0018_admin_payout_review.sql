CREATE OR REPLACE FUNCTION public.review_freelancer_payment_method(
  freelancer_id_input UUID,
  decision_input TEXT
)
RETURNS public.freelancer_payment_methods AS $$
DECLARE saved public.freelancer_payment_methods;
BEGIN
  IF NOT public.is_platform_admin() THEN RAISE EXCEPTION 'Administrator access is required'; END IF;
  IF decision_input NOT IN ('pending', 'verified') THEN RAISE EXCEPTION 'Invalid payout review decision'; END IF;
  UPDATE public.freelancer_payment_methods
  SET status = decision_input
  WHERE user_id = freelancer_id_input
  RETURNING * INTO saved;
  IF saved.user_id IS NULL THEN RAISE EXCEPTION 'Payout account not found'; END IF;
  RETURN saved;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.review_freelancer_payment_method(UUID, TEXT) TO authenticated;
REVOKE ALL ON FUNCTION public.review_freelancer_payment_method(UUID, TEXT) FROM PUBLIC;
