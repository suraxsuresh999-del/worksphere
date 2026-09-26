-- Preserve explicit roles at registration, while OAuth accounts without an
-- account type always continue through the role-selection onboarding screen.
CREATE OR REPLACE FUNCTION public.reset_unselected_oauth_role()
RETURNS TRIGGER AS $$
BEGIN
  IF COALESCE(NEW.raw_user_meta_data->>'user_type', '') NOT IN ('freelancer', 'client', 'admin') THEN
    DELETE FROM public.freelancer_profiles WHERE user_id = NEW.id;
    DELETE FROM public.client_profiles WHERE user_id = NEW.id;
    UPDATE public.profiles
    SET user_type = 'role_pending', onboarding_status = 'role_pending'
    WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS zzz_reset_unselected_oauth_role ON auth.users;
CREATE TRIGGER zzz_reset_unselected_oauth_role
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.reset_unselected_oauth_role();

-- Private resumes stay in a dedicated bucket, scoped to the owner's folder.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('resumes', 'resumes', false, 5242880,
  ARRAY['application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'])
ON CONFLICT (id) DO UPDATE SET public = false, file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "Owners manage private resumes" ON storage.objects;
CREATE POLICY "Owners manage private resumes" ON storage.objects FOR ALL TO authenticated
USING (bucket_id = 'resumes' AND (storage.foldername(name))[1] = auth.uid()::text)
WITH CHECK (bucket_id = 'resumes' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE OR REPLACE FUNCTION public.save_my_resume(storage_path_input TEXT)
RETURNS VOID AS $$
BEGIN
  IF auth.uid() IS NULL
    OR storage_path_input IS NULL
    OR storage_path_input !~ ('^' || auth.uid()::text || '/resume\\.(pdf|doc|docx)$') THEN
    RAISE EXCEPTION 'Invalid resume upload';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND user_type = 'freelancer') THEN
    RAISE EXCEPTION 'Only freelancer accounts can attach a resume';
  END IF;
  UPDATE public.freelancer_profiles SET resume_url = storage_path_input WHERE user_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.save_my_resume(TEXT) TO authenticated;
