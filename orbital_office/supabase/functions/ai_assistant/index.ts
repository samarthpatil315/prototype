// ORBITAL OFFICE — AI Assistant Edge Function
//
// Deploy:  supabase functions deploy ai_assistant
// Secrets: supabase secrets set AI_PROVIDER_API_KEY=... AI_PROVIDER_MODEL=...
//
// The provider key lives ONLY here (server-side). The Flutter app invokes
// this function with the user's Supabase JWT; it never sees the key.
//
// If no provider key is configured the function returns 503 and the app
// falls back to its clearly-labelled offline demo assistant.

import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// Very small in-memory rate limit per user (best-effort, per instance).
const hits = new Map<string, { count: number; resetAt: number }>();
const LIMIT = 30;
const WINDOW_MS = 60_000;

function rateLimited(userId: string): boolean {
  const now = Date.now();
  const entry = hits.get(userId);
  if (!entry || now > entry.resetAt) {
    hits.set(userId, { count: 1, resetAt: now + WINDOW_MS });
    return false;
  }
  entry.count += 1;
  return entry.count > LIMIT;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: req.headers.get("Authorization") ?? "" },
        },
      },
    );

    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();
    if (authError || !user) return json({ error: "Unauthorized" }, 401);
    if (rateLimited(user.id)) {
      return json({ error: "Rate limit exceeded. Try again shortly." }, 429);
    }

    const { prompt } = await req.json().catch(() => ({ prompt: "" }));
    if (typeof prompt !== "string" || prompt.trim() === "") {
      return json({ error: "A non-empty 'prompt' is required." }, 400);
    }
    if (prompt.length > 4000) {
      return json({ error: "Prompt is too long (max 4000 characters)." }, 400);
    }

    const apiKey = Deno.env.get("AI_PROVIDER_API_KEY");
    if (!apiKey) {
      return json(
        { error: "AI provider is not configured on the server." },
        503,
      );
    }

    const model = Deno.env.get("AI_PROVIDER_MODEL") ?? "gpt-4o-mini";
    const res = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        messages: [
          {
            role: "system",
            content:
              "You are the ORBITAL OFFICE assistant by ORBITAL.STUDIO.3. Draft professional office content. Be concise, never claim facts are verified, and ask for missing details instead of inventing them.",
          },
          { role: "user", content: prompt },
        ],
      }),
    });

    if (!res.ok) return json({ error: "AI provider error." }, 502);
    const data = await res.json();
    const text = data?.choices?.[0]?.message?.content ?? "";
    if (!text) return json({ error: "Empty AI response." }, 502);
    return json({ text });
  } catch (_e) {
    return json({ error: "Unexpected server error." }, 500);
  }
});
