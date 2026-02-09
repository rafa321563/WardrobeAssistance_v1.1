// Supabase Edge Function: process-image
// Two-tier image processing:
//   mode=standard → Remove.bg (background removal)
//   mode=magic    → HydraAI / Gemini (Ghost Mannequin / 3D catalog look)

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

    // Parse multipart form data
    const formData = await req.formData();
    const imageFile = formData.get("image");
    const mode = (formData.get("mode") as string) || "standard";

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

    if (mode === "magic") {
      // Magic: HydraAI (Gemini) — Ghost Mannequin / 3D catalog effect
      const hydraKey = Deno.env.get("HYDRA_API_KEY");
      if (!hydraKey) {
        console.error("HYDRA_API_KEY not configured");
        return new Response(
          JSON.stringify({ error: "Image processing service not configured" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Convert uploaded file to base64 (chunked to avoid stack overflow)
      const imageBytes = new Uint8Array(await imageFile.arrayBuffer());
      let binary = "";
      const chunkSize = 8192;
      for (let i = 0; i < imageBytes.length; i += chunkSize) {
        binary += String.fromCharCode(...imageBytes.subarray(i, i + chunkSize));
      }
      const base64Image = btoa(binary);
      const mimeType = imageFile.type || "image/png";

      const prompt = `Professional e-commerce catalog photo. Take this clothing item with transparent background and render it as a ghost mannequin / invisible mannequin product shot. Give the garment realistic 3D volume and shape as if worn on an invisible body form. Add subtle fabric wrinkle smoothing and light retouching to clean up texture noise. Place on a clean pure white (#ffffff) background with a soft, natural drop shadow underneath for depth. The lighting should be even studio softbox lighting, slightly from above. Keep the original colors and proportions perfectly accurate. Final result should look like a high-end fashion catalog product image ready for an online store.`;

      const hydraResponse = await fetch("https://api.hydraai.ru/v1/chat/completions", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${hydraKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "gemini-2.5-flash-image",
          messages: [
            {
              role: "user",
              content: [
                { type: "text", text: prompt },
                {
                  type: "image_url",
                  image_url: { url: `data:${mimeType};base64,${base64Image}` },
                },
              ],
            },
          ],
          temperature: 0.4,
        }),
      });

      if (!hydraResponse.ok) {
        const errText = await hydraResponse.text();
        console.error("HydraAI API error:", hydraResponse.status, errText);
        return new Response(
          JSON.stringify({ error: "Image enhancement failed" }),
          { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const hydraResult = await hydraResponse.json();
      const content = hydraResult?.choices?.[0]?.message?.content;
      if (!content) {
        console.error("HydraAI: empty response", JSON.stringify(hydraResult));
        return new Response(
          JSON.stringify({ error: "Image enhancement returned no result" }),
          { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Extract base64 image from markdown: ![...](data:image/...;base64,XXXXX)
      const b64Match = content.match(/data:image\/[^;]+;base64,([A-Za-z0-9+/=]+)/);
      if (!b64Match) {
        console.error("HydraAI: no image in response content:", content.substring(0, 500));
        return new Response(
          JSON.stringify({ error: "Image enhancement returned no image" }),
          { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Decode base64 to blob
      const imgBase64 = b64Match[1];
      const imgMime = content.match(/data:(image\/[^;]+);base64/)?.[1] || "image/png";
      const binaryStr = atob(imgBase64);
      const bytes = new Uint8Array(binaryStr.length);
      for (let i = 0; i < binaryStr.length; i++) {
        bytes[i] = binaryStr.charCodeAt(i);
      }
      resultBlob = new Blob([bytes], { type: imgMime });
    } else {
      // Standard: remove.bg basic removal
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
          JSON.stringify({ error: "Background removal failed" }),
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
        "X-Processing-Mode": mode,
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
