// Supabase Edge Function: analyze-clothing
// Uses HydraAI (Gemini 2.5 Flash vision) to analyze a clothing photo
// and return structured metadata (category, color, brand, etc.)

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

    // Verify JWT via Supabase
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

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

    // Get HydraAI key
    const hydraKey = Deno.env.get("HYDRA_API_KEY");
    if (!hydraKey) {
      console.error("HYDRA_API_KEY not configured");
      return new Response(
        JSON.stringify({ error: "Analysis service not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Convert image to base64
    const imageBytes = new Uint8Array(await imageFile.arrayBuffer());
    let binary = "";
    const chunkSize = 8192;
    for (let i = 0; i < imageBytes.length; i += chunkSize) {
      binary += String.fromCharCode(...imageBytes.subarray(i, i + chunkSize));
    }
    const base64Image = btoa(binary);
    const mimeType = imageFile.type || "image/jpeg";

    const prompt = `Analyze this clothing item photo. Return ONLY a valid JSON object with these fields — no markdown, no code fences, no explanation:

{
  "category": one of "Tops", "Bottoms", "Shoes", "Accessories", "Outerwear", "Dresses", "Activewear",
  "brand": detected brand name as string, or "" if unknown,
  "name": short descriptive name like "Blue Denim Jacket" or "White Sneakers",
  "color": one of "Black", "White", "Gray", "Navy", "Blue", "Red", "Green", "Yellow", "Orange", "Purple", "Pink", "Brown", "Beige", "Multicolor",
  "season": one of "Summer", "Winter", "Spring", "Fall", "All Season",
  "style": one of "Casual", "Smart Casual", "Formal", "Business", "Streetwear", "Sportswear", "Athleisure", "Minimalist", "Classic", "Bohemian", "Vintage", "Preppy", "Romantic", "Evening",
  "material": detected material like "Cotton", "Leather", "Polyester", or "" if unknown,
  "size": detected size label like "M", "42", "XL", or "" if not visible,
  "tags": array of 2-4 short descriptive tags like ["lightweight", "everyday", "versatile"]
}

Return ONLY the JSON object.`;

    const hydraResponse = await fetch("https://api.hydraai.ru/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${hydraKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gemini-2.5-flash",
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
        temperature: 0.2,
      }),
    });

    if (!hydraResponse.ok) {
      const errText = await hydraResponse.text();
      console.error("HydraAI API error:", hydraResponse.status, errText);
      return new Response(
        JSON.stringify({ error: "Clothing analysis failed" }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const hydraResult = await hydraResponse.json();
    const content = hydraResult?.choices?.[0]?.message?.content;

    if (!content) {
      console.error("HydraAI: empty response", JSON.stringify(hydraResult));
      return new Response(
        JSON.stringify({ error: "Analysis returned no result" }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Extract JSON from response (handle possible markdown fences)
    let jsonStr = content.trim();
    const jsonMatch = jsonStr.match(/```(?:json)?\s*([\s\S]*?)```/);
    if (jsonMatch) {
      jsonStr = jsonMatch[1].trim();
    }

    let analysis;
    try {
      analysis = JSON.parse(jsonStr);
    } catch {
      console.error("Failed to parse AI response as JSON:", jsonStr);
      return new Response(
        JSON.stringify({ error: "Failed to parse analysis result" }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify(analysis),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Edge function error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
