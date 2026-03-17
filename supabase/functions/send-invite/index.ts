import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { email, fullName, teamId, sendEmail = true } = await req.json()

    if (!email) {
      return new Response(
        JSON.stringify({ error: 'email is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    // ── 1. Find or create the auth user ────────────────────────
    // generateLink works for both new and existing users:
    //   - New email  → creates auth user, handle_new_user trigger fires
    //   - Existing   → returns magic link for existing account
    const { data: linkData, error: linkError } = await supabaseAdmin.auth.admin.generateLink({
      type: 'magiclink',
      email,
      options: {
        data: {
          full_name: fullName ?? email,
        },
      },
    })

    if (linkError) throw linkError

    const userId = linkData.user.id
    const isNew = linkData.user.created_at === linkData.user.updated_at

    // ── 2. Send invite email (optional) ────────────────────────
    if (sendEmail) {
      // Resolve club name from teamId (server-side using service role)
      let clubName = 'your club'
      if (teamId) {
        const { data: teamData } = await supabaseAdmin
          .from('teams')
          .select('divisions(clubs(name))')
          .eq('id', teamId)
          .single()

        const divisions = teamData?.divisions as { clubs?: { name?: string } } | null
        clubName = divisions?.clubs?.name ?? 'your club'
      }

      const actionLink = linkData.properties?.action_link ?? ''
      const resendKey = Deno.env.get('RESEND_API_KEY')

      if (resendKey && actionLink) {
        const resendResponse = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${resendKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            from: 'SquadSync <noreply@squadsync.com>',
            to: email,
            subject: `You've been invited to join ${clubName} on SquadSync`,
            html: `
              <div style="font-family:sans-serif;max-width:480px;margin:0 auto;">
                <h2 style="color:#1E3A5F;">You're invited to SquadSync</h2>
                <p>You've been added to <strong>${clubName}</strong>.</p>
                <p>Click the button below to set up your account:</p>
                <a href="${actionLink}"
                  style="display:inline-block;background:#1E3A5F;color:white;
                    padding:12px 24px;border-radius:8px;text-decoration:none;
                    font-weight:bold;">
                  Accept invitation
                </a>
                <p style="color:#888;font-size:13px;margin-top:24px;">
                  This link expires in 24 hours.
                </p>
              </div>
            `,
          }),
        })

        if (!resendResponse.ok) {
          // Log but don't fail — user was still created
          console.error('Resend failed:', await resendResponse.text())
        }
      }
    }

    return new Response(
      JSON.stringify({ userId, isNew }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (error) {
    console.error('send-invite error:', error)
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
