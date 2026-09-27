CREATE TABLE IF NOT EXISTS public.project_tasks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  title TEXT NOT NULL, description TEXT, assignee_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  due_date DATE, status TEXT NOT NULL DEFAULT 'to_do' CHECK (status IN ('to_do', 'in_progress', 'completed')),
  priority TEXT NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high')),
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.project_tasks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Project participants manage tasks" ON public.project_tasks;
CREATE POLICY "Project participants manage tasks" ON public.project_tasks FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.projects p WHERE p.id = project_tasks.project_id AND auth.uid() IN (p.client_id, p.freelancer_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM public.projects p WHERE p.id = project_tasks.project_id
    AND auth.uid() IN (p.client_id, p.freelancer_id)
    AND (project_tasks.assignee_id IS NULL OR project_tasks.assignee_id IN (p.client_id, p.freelancer_id))));

CREATE TABLE IF NOT EXISTS public.project_deliverables (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  uploaded_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE, file_path TEXT NOT NULL,
  description TEXT, review_status TEXT NOT NULL DEFAULT 'submitted' CHECK (review_status IN ('submitted', 'approved', 'revision_required')),
  review_note TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.project_deliverables ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Project participants read deliverables" ON public.project_deliverables;
CREATE POLICY "Project participants read deliverables" ON public.project_deliverables FOR SELECT TO authenticated USING
  (EXISTS (SELECT 1 FROM public.projects p WHERE p.id = project_deliverables.project_id AND auth.uid() IN (p.client_id, p.freelancer_id)));
DROP POLICY IF EXISTS "Project participants submit deliverables" ON public.project_deliverables;
CREATE POLICY "Project participants submit deliverables" ON public.project_deliverables FOR INSERT TO authenticated WITH CHECK
  (uploaded_by = auth.uid() AND EXISTS (SELECT 1 FROM public.projects p WHERE p.id = project_deliverables.project_id AND auth.uid() IN (p.client_id, p.freelancer_id)));
DROP POLICY IF EXISTS "Project clients review deliverables" ON public.project_deliverables;
CREATE POLICY "Project clients review deliverables" ON public.project_deliverables FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.projects p WHERE p.id = project_deliverables.project_id AND p.client_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.projects p WHERE p.id = project_deliverables.project_id AND p.client_id = auth.uid()));

CREATE INDEX IF NOT EXISTS project_tasks_project_id_created_at_idx ON public.project_tasks(project_id, created_at DESC);
CREATE INDEX IF NOT EXISTS project_deliverables_project_id_created_at_idx ON public.project_deliverables(project_id, created_at DESC);

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('project-workspace-assets', 'project-workspace-assets', false, 20971520,
  ARRAY['application/pdf', 'image/jpeg', 'image/png', 'text/plain', 'application/zip', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'])
ON CONFLICT (id) DO UPDATE SET public = false, file_size_limit = EXCLUDED.file_size_limit, allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "Project participants read workspace assets" ON storage.objects;
CREATE POLICY "Project participants read workspace assets" ON storage.objects FOR SELECT TO authenticated USING
  (bucket_id = 'project-workspace-assets' AND EXISTS (SELECT 1 FROM public.projects p WHERE p.id::text = (storage.foldername(name))[1] AND auth.uid() IN (p.client_id, p.freelancer_id)));
DROP POLICY IF EXISTS "Project participants upload workspace assets" ON storage.objects;
CREATE POLICY "Project participants upload workspace assets" ON storage.objects FOR INSERT TO authenticated WITH CHECK
  (bucket_id = 'project-workspace-assets' AND (storage.foldername(name))[2] = auth.uid()::text
    AND EXISTS (SELECT 1 FROM public.projects p WHERE p.id::text = (storage.foldername(name))[1] AND auth.uid() IN (p.client_id, p.freelancer_id)));
DROP POLICY IF EXISTS "Project uploaders delete workspace assets" ON storage.objects;
CREATE POLICY "Project uploaders delete workspace assets" ON storage.objects FOR DELETE TO authenticated USING
  (bucket_id = 'project-workspace-assets' AND (storage.foldername(name))[2] = auth.uid()::text
    AND EXISTS (SELECT 1 FROM public.projects p WHERE p.id::text = (storage.foldername(name))[1] AND auth.uid() IN (p.client_id, p.freelancer_id)));
