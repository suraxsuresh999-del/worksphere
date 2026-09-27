CREATE SEQUENCE IF NOT EXISTS public.project_invoice_number_seq;

CREATE TABLE IF NOT EXISTS public.project_invoices (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id UUID NOT NULL UNIQUE REFERENCES public.projects(id) ON DELETE RESTRICT,
  invoice_number TEXT NOT NULL UNIQUE,
  client_id UUID NOT NULL REFERENCES public.client_profiles(user_id) ON DELETE RESTRICT,
  freelancer_id UUID NOT NULL REFERENCES public.freelancer_profiles(user_id) ON DELETE RESTRICT,
  client_name TEXT NOT NULL,
  freelancer_name TEXT NOT NULL,
  project_title TEXT NOT NULL,
  amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
  currency TEXT NOT NULL DEFAULT 'INR',
  issued_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.project_invoices ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Invoice participants read invoices" ON public.project_invoices;
CREATE POLICY "Invoice participants read invoices" ON public.project_invoices FOR SELECT TO authenticated
  USING (auth.uid() IN (client_id, freelancer_id) OR public.is_platform_admin());

CREATE OR REPLACE FUNCTION public.generate_project_invoice(project_id_input UUID)
RETURNS public.project_invoices AS $$
DECLARE project_row public.projects; invoice_row public.project_invoices;
BEGIN
  SELECT * INTO project_row FROM public.projects p
  WHERE p.id = project_id_input AND auth.uid() IN (p.client_id, p.freelancer_id)
  FOR UPDATE;
  IF project_row.id IS NULL THEN RAISE EXCEPTION 'Project is unavailable'; END IF;
  IF project_row.status <> 'completed' OR project_row.payment_status <> 'verified'
    OR COALESCE(project_row.amount_paid, 0) < project_row.total_amount THEN
    RAISE EXCEPTION 'An invoice is available after project completion and verified full payment';
  END IF;
  SELECT * INTO invoice_row FROM public.project_invoices WHERE project_id = project_row.id;
  IF invoice_row.id IS NOT NULL THEN RETURN invoice_row; END IF;

  INSERT INTO public.project_invoices(
    project_id, invoice_number, client_id, freelancer_id, client_name, freelancer_name,
    project_title, amount, currency
  )
  SELECT project_row.id,
    'WS-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('public.project_invoice_number_seq')::text, 6, '0'),
    project_row.client_id, project_row.freelancer_id,
    COALESCE(NULLIF(cp.company_name, ''), NULLIF(client_profile.full_name, ''), 'Client'),
    COALESCE(NULLIF(freelancer_profile.full_name, ''), NULLIF(fp.title, ''), 'Freelancer'),
    project_row.title, project_row.total_amount, 'INR'
  FROM public.client_profiles cp
  JOIN public.profiles client_profile ON client_profile.id = cp.user_id
  JOIN public.freelancer_profiles fp ON fp.user_id = project_row.freelancer_id
  JOIN public.profiles freelancer_profile ON freelancer_profile.id = fp.user_id
  WHERE cp.user_id = project_row.client_id
  RETURNING * INTO invoice_row;
  IF invoice_row.id IS NULL THEN RAISE EXCEPTION 'Invoice participant profiles are incomplete'; END IF;
  RETURN invoice_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.generate_project_invoice(UUID) TO authenticated;
REVOKE ALL ON FUNCTION public.generate_project_invoice(UUID) FROM PUBLIC;
