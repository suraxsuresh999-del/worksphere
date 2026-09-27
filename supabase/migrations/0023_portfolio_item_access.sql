-- Portfolio entries are public profile content; only their owner may change them.
CREATE POLICY "Portfolio items are publicly viewable"
  ON public.portfolio_items
  FOR SELECT
  USING (true);

CREATE POLICY "Freelancers manage their own portfolio items"
  ON public.portfolio_items
  FOR ALL
  TO authenticated
  USING (
    auth.uid() = freelancer_id
    AND EXISTS (
      SELECT 1
      FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.user_type = 'freelancer'
    )
  )
  WITH CHECK (
    auth.uid() = freelancer_id
    AND EXISTS (
      SELECT 1
      FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.user_type = 'freelancer'
    )
  );
