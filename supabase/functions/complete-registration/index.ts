// Deploy with `supabase functions deploy complete-registration`.
// The function creates the auth user, stores submitted private files, then lets
// the database trigger persist the complete profile before Supabase sends email verification.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' }
const allowedTypes = new Set(['image/jpeg', 'image/png', 'application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'])

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    const { email, password, profile, documents = [] } = await request.json()
    if (!email || !password || !profile?.full_name || !['client', 'freelancer'].includes(profile.user_type)) {
      return Response.json({ error: 'Incomplete registration details.' }, { status: 400, headers: corsHeaders })
    }
    const anon = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!)
    const { data, error } = await anon.auth.signUp({ email, password, options: { data: profile } })
    if (error) return Response.json({ error: error.message }, { status: 400, headers: corsHeaders })
    if (!data.user) throw new Error('The account could not be created.')
    const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
    for (const document of documents) {
      if (!document?.base64 || !allowedTypes.has(document.mimeType) || document.base64.length > 7_000_000) {
        throw new Error('Each file must be an allowed document type no larger than 5 MB.')
      }
      const extension = document.mimeType === 'application/pdf' ? 'pdf' : document.mimeType === 'application/msword' ? 'doc' : document.mimeType.includes('wordprocessingml') ? 'docx' : document.mimeType === 'image/png' ? 'png' : 'jpg'
      const isResume = document.type === 'resume'
      const path = `${data.user.id}/${document.type}.${extension}`
      const bytes = Uint8Array.from(atob(document.base64), (character) => character.charCodeAt(0))
      const { error: uploadError } = await admin.storage.from(isResume ? 'resumes' : 'verification-documents').upload(path, bytes, { contentType: document.mimeType, upsert: true })
      if (uploadError) throw uploadError
      if (isResume) {
        const { error: resumeError } = await admin.from('freelancer_profiles').update({ resume_url: path }).eq('user_id', data.user.id)
        if (resumeError) throw resumeError
        continue
      }
      const { error: recordError } = await admin.from('verification_documents').upsert({ user_id: data.user.id, document_type: document.type, storage_path: path, file_name: document.name, mime_type: document.mimeType })
      if (recordError) throw recordError
      if (document.type === 'profile_photo') {
        const { error: avatarError } = await admin.from('profiles').update({ avatar_url: path }).eq('id', data.user.id)
        if (avatarError) throw avatarError
      }
    }
    return Response.json({ ok: true }, { headers: corsHeaders })
  } catch (error) {
    return Response.json({ error: error instanceof Error ? error.message : 'Registration failed.' }, { status: 400, headers: corsHeaders })
  }
})
