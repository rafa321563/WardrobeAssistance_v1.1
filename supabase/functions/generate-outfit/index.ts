// Supabase Edge Function: generate-outfit
// Validates JWT, enforces rate limits, and calls Gemini API

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Allowed origins for CORS (add your app's domains)
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

interface WardrobeItem {
  id: string;
  name: string;
  category: string;
  color: string;
  season: string;
  style: string;
  brand?: string;
  material?: string;
  tags?: string[];
  wear_count: number;
  is_favorite: boolean;
}

interface WeatherData {
  temperature: number;
  condition: string;
  humidity: number;
  wind_speed: number;
}

interface OutfitRequest {
  items: WardrobeItem[];
  occasion?: string;
  weather?: WeatherData;
  style_preference?: string;
  message?: string;
  history?: { role: string; content: string }[];
}

interface UserProfile {
  id: string;
  ai_calls_count: number;
  is_premium: boolean;
  created_at: string;
  updated_at: string;
}

const FREE_TIER_LIMIT = 5;
const MAX_ITEMS_LIMIT = 200;
const MAX_MESSAGE_LENGTH = 2000;
const MAX_HISTORY_LENGTH = 20;

serve(async (req) => {
  const origin = req.headers.get("Origin");
  const corsHeaders = getCorsHeaders(origin);

  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // Get authorization header
    const authHeader = req.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({ error: "Missing or invalid authorization header" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const token = authHeader.replace("Bearer ", "");

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Verify JWT and get user
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Invalid or expired token" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Atomic rate limit check and increment using RPC
    const { data: rpcResult, error: rpcError } = await supabase.rpc(
      "increment_ai_calls_if_allowed",
      { user_id: user.id, call_limit: FREE_TIER_LIMIT }
    );

    if (rpcError) {
      console.error("RPC error:", rpcError);
      // Fallback to non-atomic check
      const { data: profile } = await supabase
        .from("profiles")
        .select("ai_calls_count, is_premium")
        .eq("id", user.id)
        .single();

      if (profile && !profile.is_premium && profile.ai_calls_count >= FREE_TIER_LIMIT) {
        return new Response(
          JSON.stringify({
            error: "AI call limit reached. Upgrade to Premium for unlimited access.",
            remaining_calls: 0,
          }),
          {
            status: 429,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }
    } else if (rpcResult && !rpcResult.allowed) {
      return new Response(
        JSON.stringify({
          error: "AI call limit reached. Upgrade to Premium for unlimited access.",
          remaining_calls: rpcResult.remaining_calls ?? 0,
        }),
        {
          status: 429,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const remainingCalls = rpcResult?.remaining_calls ?? null;

    // Parse request body
    const body: OutfitRequest = await req.json();

    if (!body.items || body.items.length === 0) {
      return new Response(
        JSON.stringify({ error: "No wardrobe items provided" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Validate request size limits
    if (body.items.length > MAX_ITEMS_LIMIT) {
      return new Response(
        JSON.stringify({ error: `Too many items. Maximum is ${MAX_ITEMS_LIMIT}` }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    if (body.message && body.message.length > MAX_MESSAGE_LENGTH) {
      return new Response(
        JSON.stringify({ error: `Message too long. Maximum is ${MAX_MESSAGE_LENGTH} characters` }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    if (body.history && body.history.length > MAX_HISTORY_LENGTH) {
      body.history = body.history.slice(-MAX_HISTORY_LENGTH);
    }

    // Build prompt for Gemini (with sanitized input)
    const sanitizedRequest = sanitizeRequest(body);
    const prompt = buildPrompt(sanitizedRequest);
    const systemInstruction = buildSystemInstruction();

    // Get Gemini API key
    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiKey) {
      console.error("GEMINI_API_KEY not configured");
      return new Response(
        JSON.stringify({ error: "AI service not configured" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Build conversation contents for Gemini
    const contents = buildGeminiContents(sanitizedRequest, prompt);

    // Call Gemini API
    const geminiResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${geminiKey}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          contents: contents,
          systemInstruction: {
            parts: [{ text: systemInstruction }],
          },
          generationConfig: {
            temperature: 0.7,
            maxOutputTokens: 1000,
            responseMimeType: "application/json",
          },
        }),
      }
    );

    if (!geminiResponse.ok) {
      const errorText = await geminiResponse.text();
      console.error("Gemini API error:", errorText);
      return new Response(
        JSON.stringify({ error: "AI service temporarily unavailable" }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const geminiData = await geminiResponse.json();
    const aiMessage = geminiData.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!aiMessage) {
      return new Response(
        JSON.stringify({ error: "No response from AI" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Parse AI response
    let parsedResponse;
    try {
      // Extract JSON from potential markdown code blocks
      const jsonMatch = aiMessage.match(/```json\n?([\s\S]*?)\n?```/) ||
        aiMessage.match(/\{[\s\S]*\}/);
      const jsonStr = jsonMatch ? (jsonMatch[1] || jsonMatch[0]) : aiMessage;
      parsedResponse = JSON.parse(jsonStr);
    } catch {
      // If parsing fails, return as text response
      parsedResponse = {
        text: aiMessage,
        suggested_items: [],
        reasoning: aiMessage,
      };
    }

    // Return response
    return new Response(
      JSON.stringify({
        suggested_items: parsedResponse.suggested_items || [],
        text: parsedResponse.text || parsedResponse.reasoning,
        reasoning: parsedResponse.reasoning || "",
        score: parsedResponse.score,
        weather_suitability: parsedResponse.weather_suitability,
        color_harmony: parsedResponse.color_harmony,
        style_consistency: parsedResponse.style_consistency,
        remaining_calls: remainingCalls,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Edge function error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});

function buildSystemInstruction(): string {
  return `You are a professional fashion stylist assistant. You help users create outfits from their wardrobe.

IMPORTANT: Always respond in Russian language.

When recommending outfits:
1. Consider the weather, occasion, and user's style preference
2. Select items that complement each other in color and style
3. Return your response as valid JSON with the following structure:
{
  "suggested_items": ["item-uuid-1", "item-uuid-2", ...],
  "reasoning": "Your explanation in Russian",
  "score": 0.85,
  "weather_suitability": 0.9,
  "color_harmony": 0.8,
  "style_consistency": 0.85
}

CRITICAL: The "suggested_items" array must contain ONLY item IDs from the provided wardrobe. Do not invent new items.`;
}

function buildGeminiContents(
  request: OutfitRequest,
  prompt: string
): { role: string; parts: { text: string }[] }[] {
  const contents: { role: string; parts: { text: string }[] }[] = [];

  // Add conversation history if present
  if (request.history && request.history.length > 0) {
    for (const msg of request.history) {
      contents.push({
        role: msg.role === "user" ? "user" : "model",
        parts: [{ text: msg.content }],
      });
    }
  }

  // Add current user prompt
  contents.push({
    role: "user",
    parts: [{ text: prompt }],
  });

  return contents;
}

function buildPrompt(request: OutfitRequest): string {
  const { items, occasion, weather, style_preference, message } = request;

  let prompt = "";

  // Add user's wardrobe
  prompt += "User's wardrobe items:\n";
  for (const item of items) {
    prompt += `- ID: ${item.id}, Name: ${item.name}, Category: ${item.category}, `;
    prompt += `Color: ${item.color}, Season: ${item.season}, Style: ${item.style}`;
    if (item.brand) prompt += `, Brand: ${item.brand}`;
    if (item.material) prompt += `, Material: ${item.material}`;
    if (item.is_favorite) prompt += ` (Favorite)`;
    prompt += `\n`;
  }

  // Add context
  if (weather) {
    prompt += `\nCurrent weather: ${weather.temperature}°C, ${weather.condition}, `;
    prompt += `humidity: ${weather.humidity}%, wind: ${weather.wind_speed} m/s\n`;
  }

  if (occasion) {
    prompt += `\nOccasion: ${occasion}\n`;
  }

  if (style_preference) {
    prompt += `Style preference: ${style_preference}\n`;
  }

  // Add the actual request
  if (message) {
    prompt += `\nUser request: ${message}\n`;
  } else {
    prompt += `\nPlease recommend an outfit from this wardrobe.\n`;
  }

  prompt += "\nRespond with a JSON object containing suggested_items (array of item IDs), reasoning, and scores.";

  return prompt;
}

// Sanitize user input to prevent prompt injection
function sanitizeRequest(request: OutfitRequest): OutfitRequest {
  const sanitize = (str: string | undefined): string | undefined => {
    if (!str) return str;
    // Remove potential prompt injection patterns
    return str
      .replace(/```/g, "")
      .replace(/\bsystem\s*:/gi, "")
      .replace(/\bassistant\s*:/gi, "")
      .replace(/\buser\s*:/gi, "")
      .replace(/\bmodel\s*:/gi, "")
      .replace(/\bignore\s+(previous|above|all)\s+instructions?\b/gi, "")
      .replace(/\bforget\s+(previous|above|all)\s+instructions?\b/gi, "")
      .slice(0, MAX_MESSAGE_LENGTH);
  };

  return {
    ...request,
    message: sanitize(request.message),
    occasion: sanitize(request.occasion),
    style_preference: sanitize(request.style_preference),
    history: request.history?.map((h) => ({
      role: h.role === "user" ? "user" : "assistant",
      content: sanitize(h.content) || "",
    })),
  };
}
