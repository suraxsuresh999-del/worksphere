-- Allow a signed-in member to replace only their own profile photo. Other
-- verification documents remain private and are still written by the
-- registration Edge Function.
DROP POLICY IF EXISTS "Owners manage their profile photo" ON storage.objects;
CREATE POLICY "Owners manage their profile photo" ON storage.objects
  FOR ALL TO authenticated
  USING (
    bucket_id = 'verification-documents'
    AND name ~ ('^' || auth.uid()::text || '/profile_photo[.](jpg|jpeg|png)$')
  )
  WITH CHECK (
    bucket_id = 'verification-documents'
    AND name ~ ('^' || auth.uid()::text || '/profile_photo[.](jpg|jpeg|png)$')
  );

DROP POLICY IF EXISTS "Users update own profile photo record" ON public.verification_documents;
CREATE POLICY "Users update own profile photo record" ON public.verification_documents
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid() AND document_type = 'profile_photo')
  WITH CHECK (user_id = auth.uid() AND document_type = 'profile_photo');

DROP POLICY IF EXISTS "Users insert own profile photo record" ON public.verification_documents;
CREATE POLICY "Users insert own profile photo record" ON public.verification_documents
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() AND document_type = 'profile_photo');
