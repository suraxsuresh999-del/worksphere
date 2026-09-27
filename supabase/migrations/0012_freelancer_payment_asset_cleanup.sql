-- Let freelancers remove only their own QR assets from the private payment bucket.
DROP POLICY IF EXISTS "Freelancers delete own payment assets" ON storage.objects;
CREATE POLICY "Freelancers delete own payment assets"
  ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'freelancer-payment-assets'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
