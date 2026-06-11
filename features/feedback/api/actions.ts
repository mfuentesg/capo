"use server"

import { Resend } from "resend"
import { z } from "zod"
import { createClient } from "@/lib/supabase/server"
import type { FeedbackPayload, FeedbackResult } from "@/features/feedback"

// Configure via RESEND_API_KEY and RESEND_FROM_EMAIL env vars
// RESEND_FROM_EMAIL defaults to onboarding@resend.dev (works in test mode)
// For production: verify a domain at resend.com and set RESEND_FROM_EMAIL

const feedbackSchema = z.object({
  name: z.string().max(100).optional().nullable(),
  email: z.string().max(254).optional().nullable(),
  message: z.string().max(5000),
  newsletterOptIn: z.boolean()
})

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;")
}

export async function submitFeedback(payload: FeedbackPayload): Promise<FeedbackResult> {
  const parsed = feedbackSchema.safeParse(payload)
  if (!parsed.success) {
    return { success: false, error: "Invalid feedback payload" }
  }
  const { name, email, message, newsletterOptIn } = parsed.data

  if (!message || message.trim().length < 5) {
    return { success: false, error: "Message is too short" }
  }

  try {
    const supabase = await createClient()

    const { error: dbError } = await supabase.from("feedback").insert({
      name: name?.trim() || null,
      email: email?.trim() || null,
      message: message.trim(),
      newsletter_opt_in: newsletterOptIn,
      opt_in_at: newsletterOptIn ? new Date().toISOString() : null
    })

    if (dbError) {
      console.error("[feedback] DB insert failed:", dbError)
      return { success: false, error: "Failed to save feedback" }
    }

    // Send email notification — skip gracefully if API key is missing
    if (process.env.RESEND_API_KEY) {
      const resend = new Resend(process.env.RESEND_API_KEY)
      const fromEmail = process.env.RESEND_FROM_EMAIL ?? "onboarding@resend.dev"
      const subject = name ? `New feedback from ${name}` : "New Capo feedback"

      await resend.emails.send({
        from: `Capo <${fromEmail}>`,
        to: "hello@mfuentesg.dev",
        subject,
        html: `
          <div style="font-family:sans-serif;max-width:600px;margin:0 auto;padding:24px">
            <div><h2 style="margin-top:0"><span>${"New Feedback Received"}</span></h2></div>
            ${name ? `<div><p><strong>Name:</strong> <span>${escapeHtml(name)}</span></p></div>` : ""}
            ${email ? `<div><p><strong>Email:</strong> <span>${escapeHtml(email)}</span></p></div>` : ""}
            <div><p><strong>Message:</strong></p></div>
            <blockquote style="border-left:3px solid #8b5cf6;margin:0;padding:8px 16px;color:#555">
              <div>${escapeHtml(message.trim()).replace(/\n/g, "<br>")}</div>
            </blockquote>
            <div><p><strong>${"Newsletter opt-in:"}</strong> <span>${newsletterOptIn ? "Yes" : "No"}</span></p></div>
            <hr style="border:none;border-top:1px solid #eee;margin:24px 0">
            <div><p style="font-size:12px;color:#999"><span>${"Sent from Capo app"}</span></p></div>
          </div>
        `
      })
    }

    return { success: true }
  } catch (err) {
    console.error("[feedback] Unexpected error:", err)
    return { success: false, error: "Unexpected error" }
  }
}
