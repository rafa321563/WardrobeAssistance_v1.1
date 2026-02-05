# Supabase Setup Guide for Wardrobe Assistant

This guide explains how to configure Supabase for the AI-powered outfit recommendations.

## 1. Database Setup

### Run the SQL Migration

1. Go to your [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project: `jhgmzhrwtbtenbtpjuys`
3. Navigate to **SQL Editor** in the left sidebar
4. Create a new query and paste the contents of `migrations/001_create_profiles.sql`
5. Click **Run** to execute the migration

This creates:
- `profiles` table with `ai_calls_count` and `is_premium` columns
- Automatic profile creation trigger for new users
- Row Level Security policies
- Helper functions for rate limiting

## 2. Enable Anonymous Authentication

1. In Supabase Dashboard, go to **Authentication** > **Providers**
2. Scroll to **Anonymous Sign-In**
3. Toggle it **ON**
4. Click **Save**

This allows the iOS app to authenticate users without requiring email/password.

## 3. Deploy the Edge Function

### Option A: Using Supabase CLI (Recommended)

```bash
# Install Supabase CLI if not already installed
brew install supabase/tap/supabase

# Login to Supabase
supabase login

# Link to your project
cd /path/to/WardrobeAssistance_v1.1/supabase
supabase link --project-ref jhgmzhrwtbtenbtpjuys

# Deploy the function
supabase functions deploy generate-outfit --no-verify-jwt
```

### Option B: Manual Deployment via Dashboard

1. Go to **Edge Functions** in your Supabase Dashboard
2. Click **Create Function**
3. Name it `generate-outfit`
4. Paste the contents of `functions/generate-outfit/index.ts`
5. Click **Deploy**

## 4. Configure Environment Variables

In the Supabase Dashboard:

1. Go to **Edge Functions** > **generate-outfit**
2. Click **Settings** (gear icon)
3. Add the following secrets:

| Secret Name | Description |
|-------------|-------------|
| `OPENAI_API_KEY` | Your OpenAI API key (starts with `sk-...`) |

The following are automatically available:
- `SUPABASE_URL` - Your project URL
- `SUPABASE_SERVICE_ROLE_KEY` - Service role key for admin operations

### Getting an OpenAI API Key

1. Go to [OpenAI Platform](https://platform.openai.com)
2. Navigate to **API Keys**
3. Click **Create new secret key**
4. Copy the key (it starts with `sk-`)
5. Add it to Supabase Edge Function secrets

## 5. Test the Setup

### Test Authentication

```bash
# Test anonymous sign-up
curl -X POST 'https://jhgmzhrwtbtenbtpjuys.supabase.co/auth/v1/signup' \
  -H 'Content-Type: application/json' \
  -H 'apikey: sb_publishable_LewsjD9nZt2V93AIkKKjbA_4DCvnUTd' \
  -d '{}'
```

### Test Edge Function

```bash
# Replace <ACCESS_TOKEN> with the token from sign-up response
curl -X POST 'https://jhgmzhrwtbtenbtpjuys.supabase.co/functions/v1/generate-outfit' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer <ACCESS_TOKEN>' \
  -d '{
    "items": [
      {"id": "test-1", "name": "White T-Shirt", "category": "Tops", "color": "White", "season": "Summer", "style": "Casual", "wear_count": 5, "is_favorite": true}
    ],
    "occasion": "casual",
    "weather": {"temperature": 25, "condition": "sunny", "humidity": 50, "wind_speed": 5}
  }'
```

## 6. iOS App Configuration

The iOS app is already configured with:

- **Supabase URL**: `https://jhgmzhrwtbtenbtpjuys.supabase.co`
- **Anon Key**: `sb_publishable_LewsjD9nZt2V93AIkKKjbA_4DCvnUTd`

These are stored in `Services/AuthService.swift`.

## 7. Rate Limiting

The system enforces these limits:

| User Type | AI Calls Limit |
|-----------|----------------|
| Free | 5 calls total |
| Premium | Unlimited |

To upgrade a user to Premium:

```sql
UPDATE public.profiles
SET is_premium = TRUE, premium_expires_at = NOW() + INTERVAL '1 year'
WHERE id = '<user-uuid>';
```

To reset a user's AI call count:

```sql
UPDATE public.profiles
SET ai_calls_count = 0
WHERE id = '<user-uuid>';
```

## 8. Monitoring

### View AI Usage

```sql
SELECT
  id,
  ai_calls_count,
  is_premium,
  created_at
FROM public.profiles
ORDER BY ai_calls_count DESC
LIMIT 100;
```

### View Edge Function Logs

1. Go to **Edge Functions** > **generate-outfit**
2. Click **Logs** tab
3. View real-time and historical logs

## Troubleshooting

### "Invalid or expired token" Error

The access token has expired. The iOS app automatically refreshes tokens, but if testing manually:

1. Call the token refresh endpoint
2. Or sign up for a new anonymous account

### "AI call limit reached" Error

The user has exceeded their free tier limit. Either:
1. Upgrade the user to Premium
2. Reset their `ai_calls_count` to 0

### "AI service not configured" Error

The `OPENAI_API_KEY` environment variable is not set:
1. Go to Edge Functions settings
2. Add the secret with your OpenAI API key

### Edge Function Not Found

Ensure the function is deployed:
```bash
supabase functions list
```

If not listed, redeploy:
```bash
supabase functions deploy generate-outfit
```
