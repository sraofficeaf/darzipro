/// <reference path="../deno.d.ts" />
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { email, code, shopName } = await req.json()

    // SECURITY: API key must be set in Supabase Dashboard → Functions → Environment Variables.
    // Never hardcode API keys in source code.
    const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')

    if (!RESEND_API_KEY) {
      console.error('RESEND_API_KEY environment variable not configured')
      return new Response(JSON.stringify({ success: false, error: 'Email service not configured — contact admin' }), {
        status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${RESEND_API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from: 'Darzi Pro <onboarding@resend.dev>',
        to: [email],
        subject: 'Email Verification — Darzi Pro Registration',
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 24px;">
            <div style="background: linear-gradient(135deg, #F5A623, #D97706); border-radius: 12px; padding: 24px; text-align: center; margin-bottom: 24px;">
              <h1 style="color: white; margin: 0; font-size: 28px;">✂️ Darzi Pro</h1>
              <p style="color: rgba(255,255,255,0.9); margin: 8px 0 0;">Email Verification</p>
            </div>
            <p style="color: #374151; font-size: 16px;">Hello <strong>${shopName}</strong>,</p>
            <p style="color: #6B7280;">Your email verification code is:</p>
            <div style="background: #F8FAFC; border: 2px dashed #E5E7EB; border-radius: 12px; padding: 24px; text-align: center; margin: 24px 0;">
              <span style="font-size: 48px; font-weight: bold; letter-spacing: 12px; color: #0F172A;">${code}</span>
            </div>
            <p style="color: #6B7280; font-size: 14px;">This code expires in <strong>10 minutes</strong>.</p>
            <p style="color: #9CA3AF; font-size: 12px;">If you didn't request this, please ignore this email.</p>
          </div>
        `
      })
    })

    if (!res.ok) {
      const err = await res.text()
      console.error('Resend error:', err)
      return new Response(JSON.stringify({ success: false, error: err }), {
        status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  } catch (error) {
    return new Response(JSON.stringify({ success: false, error: error.message }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
