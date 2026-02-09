// Supabase Edge Function: process-image
// Proxies image background removal to Photoroom (premium) or remove.bg (free)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ALLOWED_ORIGINS = [
  "capacitor://localhost",
  "ionic://localhost",
  "http://localhost",
  "http://localhost:3000",
];

function getCorsHeaders(origin: string | null): Record<string, string> {
  const allowedOrigin = origin && ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
  return {
    "Access-Control-Allow-Origin": allowedOrigin,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
}

const MAX_IMAGE_SIZE = 10 * 1024 * 1024; // 10MB

serve(async (req) => {
  const origin = req.headers.get("Origin");
  const corsHeaders = getCorsHeaders(origin);

  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // Validate authorization
    const authHeader = req.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({ error: "Missing or invalid authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const token = authHeader.replace("Bearer ", "");

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Verify JWT
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Invalid or expired token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Check premium status
    const { data: profile } = await supabase
      .from("profiles")
      .select("is_premium")
      .eq("id", user.id)
      .single();

    const isPremium = profile?.is_premium ?? false;

    // Parse multipart form data
    const formData = await req.formData();
    const imageFile = formData.get("image");

    if (!imageFile || !(imageFile instanceof File)) {
      return new Response(
        JSON.stringify({ error: "No image provided" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (imageFile.size > MAX_IMAGE_SIZE) {
      return new Response(
        JSON.stringify({ error: "Image too large. Maximum size is 10MB." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let resultBlob: Blob;

    if (isPremium) {
      // Premium: Photoroom API with 3D volume + AI shadows
      const photoroomKey = Deno.env.get("PHOTOROOM_API_KEY");
      if (!photoroomKey) {
        console.error("PHOTOROOM_API_KEY not configured");
        return new Response(
          JSON.stringify({ error: "Image processing service not configured" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const prForm = new FormData();
      prForm.append("imageFile", imageFile);
      prForm.append("background.color", "FFFFFF");
      prForm.append("shadow.mode", "ai.soft");
      prForm.append("padding", "0.1");

      const prResponse = await fetch("https://image-api.photoroom.com/v2/edit", {
        method: "POST",
        headers: { "x-api-key": photoroomKey },
        body: prForm,
      });

      if (!prResponse.ok) {
        const errText = await prResponse.text();
        console.error("Photoroom API error:", prResponse.status, errText);
        return new Response(
          JSON.stringify({ error: "Image processing failed" }),
          { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      resultBlob = await prResponse.blob();
    } else {
      // Free: remove.bg basic removal
      const removeBgKey = Deno.env.get("REMOVE_BG_API_KEY");
      if (!removeBgKey) {
        console.error("REMOVE_BG_API_KEY not configured");
        return new Response(
          JSON.stringify({ error: "Image processing service not configured" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const rbgForm = new FormData();
      rbgForm.append("image_file", imageFile);
      rbgForm.append("size", "auto");

      const rbgResponse = await fetch("https://api.remove.bg/v1.0/removebg", {
        method: "POST",
        headers: { "X-Api-Key": removeBgKey },
        body: rbgForm,
      });

      if (!rbgResponse.ok) {
        const errText = await rbgResponse.text();
        console.error("remove.bg API error:", rbgResponse.status, errText);
        return new Response(
          JSON.stringify({ error: "Image processing failed" }),
          { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      resultBlob = await rbgResponse.blob();
    }

    // Return processed image as PNG blob
    const arrayBuffer = await resultBlob.arrayBuffer();
    return new Response(new Uint8Array(arrayBuffer), {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "image/png",
        "X-Is-Premium": isPremium ? "true" : "false",
      },
    });
  } catch (error) {
    console.error("Edge function error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
