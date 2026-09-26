/// <reference path="../deno.d.ts" />
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// In-memory sliding window rate limit stores (per IP and per email)
const ipRateLimit = new Map<string, number[]>()
const emailRateLimit = new Map<string, number[]>()

function checkRateLimit(store: Map<string, number[]>, key: string, maxAttempts: number, windowMs: number): boolean {
  const now = Date.now()
  const timestamps = (store.get(key) || []).filter(t => now - t < windowMs)
  if (timestamps.length >= maxAttempts) {
    store.set(key, timestamps)
    return false
  }
  timestamps.push(now)
  store.set(key, timestamps)
  return true
}

function escapeHtml(unsafe: string): string {
  if (typeof unsafe !== 'string') return ''
  return unsafe
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. IP extraction & IP Rate Limit (5 requests per 10 minutes)
    const clientIp = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() || 
                     req.headers.get('cf-connecting-ip') || 
                     req.headers.get('x-real-ip') || 
                     'unknown-ip'

    if (!checkRateLimit(ipRateLimit, clientIp, 5, 10 * 60 * 1000)) {
      return new Response(JSON.stringify({ 
        success: false, 
        error: 'Too many requests from this IP. Please try again after 10 minutes.' 
      }), {
        status: 429, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const { email, code } = await req.json()

    if (!email || typeof email !== 'string' || !code || typeof code !== 'string') {
      return new Response(JSON.stringify({ success: false, error: 'email and code are required' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const cleanEmail = email.trim().toLowerCase()
    const cleanCode = code.trim()

    // 2. Email Rate Limit (3 requests per 10 minutes)
    if (!checkRateLimit(emailRateLimit, cleanEmail, 3, 10 * 60 * 1000)) {
      return new Response(JSON.stringify({ 
        success: false, 
        error: 'Too many requests for this email address. Please try again after 10 minutes.' 
      }), {
        status: 429, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // 3. Tie to registration in progress: Verify pending registration in public_registrations
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || 'http://supabase-kong:8000'
    const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('SERVICE_KEY')

    if (!SERVICE_ROLE_KEY) {
      return new Response(JSON.stringify({ success: false, error: 'Database service key not configured' }), {
        status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Query registration status
    const regRes = await fetch(`${SUPABASE_URL}/rest/v1/public_registrations?email=eq.${encodeURIComponent(cleanEmail)}&email_verified=eq.false&status=eq.pending_email_verification&select=id,email_verification_code,shop_name&order=created_at.desc&limit=1`, {
      headers: {
        'apikey': SERVICE_ROLE_KEY,
        'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
        'Content-Type': 'application/json'
      }
    })

    if (!regRes.ok) {
      return new Response(JSON.stringify({ success: false, error: 'Failed to verify registration state' }), {
        status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const registrations = await regRes.json()
    if (!Array.isArray(registrations) || registrations.length === 0) {
      return new Response(JSON.stringify({ 
        success: false, 
        error: 'Forbidden: No active pending registration found for this email address.' 
      }), {
        status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const reg = registrations[0]
    if (reg.email_verification_code !== cleanCode) {
      return new Response(JSON.stringify({ 
        success: false, 
        error: 'Forbidden: Verification code does not match registered code.' 
      }), {
        status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // 4. Secure HTML Escaping of all interpolated variables
    const safeShopName = escapeHtml(reg.shop_name || 'Tailor')
    const safeCode = escapeHtml(cleanCode)

    const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')
    if (!RESEND_API_KEY) {
      return new Response(JSON.stringify({ success: false, error: 'Email service not configured — contact admin' }), {
        status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${RESEND_API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from: 'Darzi Pro <onboarding@resend.dev>',
        to: [cleanEmail],
        subject: 'Email Verification — Darzi Pro Registration',
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 24px;">
            <div style="background: linear-gradient(135deg, #F5A623, #D97706); border-radius: 12px; padding: 24px; text-align: center; margin-bottom: 24px;">
              <h1 style="color: white; margin: 0; font-size: 28px;">✂️ Darzi Pro</h1>
              <p style="color: rgba(255,255,255,0.9); margin: 8px 0 0;">Email Verification</p>
            </div>
            <p style="color: #374151; font-size: 16px;">Hello <strong>${safeShopName}</strong>,</p>
            <p style="color: #6B7280;">Your email verification code is:</p>
            <div style="background: #F8FAFC; border: 2px dashed #E5E7EB; border-radius: 12px; padding: 24px; text-align: center; margin: 24px 0;">
              <span style="font-size: 48px; font-weight: bold; letter-spacing: 12px; color: #0F172A;">${safeCode}</span>
            </div>
            <p style="color: #6B7280; font-size: 14px;">This code expires in <strong>10 minutes</strong>.</p>
            <p style="color: #9CA3AF; font-size: 12px;">If you didn't request this, please ignore this email.</p>
          </div>
        `
      })
    })

    if (!res.ok) {
      const err = await res.text()
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
