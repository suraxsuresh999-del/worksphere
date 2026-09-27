CREATE TABLE IF NOT EXISTS public.support_tickets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  subject TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('account', 'payments', 'projects', 'jobs', 'technical', 'other')),
  description TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.support_ticket_replies (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ticket_id UUID NOT NULL REFERENCES public.support_tickets(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_ticket_replies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users and admins read support tickets" ON public.support_tickets;
CREATE POLICY "Users and admins read support tickets" ON public.support_tickets FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_platform_admin());
DROP POLICY IF EXISTS "Users create own support tickets" ON public.support_tickets;
CREATE POLICY "Users create own support tickets" ON public.support_tickets FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS "Admins update support ticket status" ON public.support_tickets;
CREATE POLICY "Admins update support ticket status" ON public.support_tickets FOR UPDATE TO authenticated
  USING (public.is_platform_admin()) WITH CHECK (public.is_platform_admin());

DROP POLICY IF EXISTS "Users and admins read ticket replies" ON public.support_ticket_replies;
CREATE POLICY "Users and admins read ticket replies" ON public.support_ticket_replies FOR SELECT TO authenticated
  USING (public.is_platform_admin() OR EXISTS (
    SELECT 1 FROM public.support_tickets t WHERE t.id = ticket_id AND t.user_id = auth.uid()
  ));
DROP POLICY IF EXISTS "Ticket owners and admins reply" ON public.support_ticket_replies;
CREATE POLICY "Ticket owners and admins reply" ON public.support_ticket_replies FOR INSERT TO authenticated
  WITH CHECK (sender_id = auth.uid() AND (public.is_platform_admin() OR EXISTS (
    SELECT 1 FROM public.support_tickets t WHERE t.id = ticket_id AND t.user_id = auth.uid()
  )));

CREATE INDEX IF NOT EXISTS support_tickets_user_updated_idx ON public.support_tickets(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS support_ticket_replies_ticket_created_idx ON public.support_ticket_replies(ticket_id, created_at);
