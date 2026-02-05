-- Supabase Database Schema for Wardrobe Assistant
-- Run this in the Supabase SQL Editor

-- ============================================
-- 1. Create profiles table
-- ============================================

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    ai_calls_count INTEGER NOT NULL DEFAULT 0,
    is_premium BOOLEAN NOT NULL DEFAULT FALSE,
    premium_expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Add comment
COMMENT ON TABLE public.profiles IS 'User profiles with AI usage tracking';

-- ============================================
-- 2. Enable Row Level Security (RLS)
-- ============================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only read their own profile
CREATE POLICY "Users can read own profile"
    ON public.profiles
    FOR SELECT
    USING (auth.uid() = id);

-- Policy: Users can update their own profile (limited fields)
CREATE POLICY "Users can update own profile"
    ON public.profiles
    FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- ============================================
-- 3. Create trigger function for auto-creating profiles
-- ============================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, ai_calls_count, is_premium, created_at, updated_at)
    VALUES (
        NEW.id,
        0,
        FALSE,
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$$;

-- ============================================
-- 4. Create trigger on auth.users
-- ============================================

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- 5. Create function to update timestamps
-- ============================================

CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- Trigger for auto-updating updated_at
DROP TRIGGER IF EXISTS profiles_updated_at ON public.profiles;

CREATE TRIGGER profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- ============================================
-- 6. Create index for performance
-- ============================================

CREATE INDEX IF NOT EXISTS idx_profiles_ai_calls ON public.profiles(ai_calls_count);
CREATE INDEX IF NOT EXISTS idx_profiles_is_premium ON public.profiles(is_premium);

-- ============================================
-- 7. Grant permissions to service role
-- ============================================

-- Service role needs full access for Edge Functions
GRANT ALL ON public.profiles TO service_role;

-- Authenticated users can read/update their own profile
GRANT SELECT, UPDATE ON public.profiles TO authenticated;

-- ============================================
-- 8. Optional: Reset AI calls monthly (cron job)
-- ============================================
-- If you want to reset AI calls monthly, enable the pg_cron extension
-- and create a scheduled job:

-- CREATE EXTENSION IF NOT EXISTS pg_cron;

-- SELECT cron.schedule(
--     'reset-ai-calls-monthly',
--     '0 0 1 * *', -- At midnight on the 1st of each month
--     $$
--     UPDATE public.profiles
--     SET ai_calls_count = 0, updated_at = NOW()
--     WHERE is_premium = FALSE;
--     $$
-- );

-- ============================================
-- 9. Helper function to check AI call limit
-- ============================================

CREATE OR REPLACE FUNCTION public.check_ai_limit(user_id UUID)
RETURNS TABLE (
    can_call BOOLEAN,
    remaining_calls INTEGER,
    is_premium BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_profile public.profiles%ROWTYPE;
    v_limit INTEGER := 5;
BEGIN
    SELECT * INTO v_profile FROM public.profiles WHERE id = user_id;

    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 0, FALSE;
        RETURN;
    END IF;

    IF v_profile.is_premium THEN
        RETURN QUERY SELECT TRUE, -1, TRUE; -- -1 indicates unlimited
    ELSE
        RETURN QUERY SELECT
            v_profile.ai_calls_count < v_limit,
            GREATEST(0, v_limit - v_profile.ai_calls_count),
            FALSE;
    END IF;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.check_ai_limit(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_ai_limit(UUID) TO service_role;

-- ============================================
-- 10. Atomic increment function for rate limiting
-- ============================================

CREATE OR REPLACE FUNCTION public.increment_ai_calls_if_allowed(
    user_id UUID,
    call_limit INTEGER DEFAULT 5
)
RETURNS TABLE (
    allowed BOOLEAN,
    remaining_calls INTEGER,
    new_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_profile public.profiles%ROWTYPE;
    v_allowed BOOLEAN;
    v_remaining INTEGER;
    v_new_count INTEGER;
BEGIN
    -- Lock the row for update to prevent race conditions
    SELECT * INTO v_profile
    FROM public.profiles
    WHERE id = user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 0, 0;
        RETURN;
    END IF;

    -- Premium users always allowed
    IF v_profile.is_premium THEN
        RETURN QUERY SELECT TRUE, -1, v_profile.ai_calls_count::INTEGER;
        RETURN;
    END IF;

    -- Check if within limit
    IF v_profile.ai_calls_count >= call_limit THEN
        RETURN QUERY SELECT FALSE, 0, v_profile.ai_calls_count::INTEGER;
        RETURN;
    END IF;

    -- Increment the counter atomically
    UPDATE public.profiles
    SET ai_calls_count = ai_calls_count + 1,
        updated_at = NOW()
    WHERE id = user_id
    RETURNING ai_calls_count INTO v_new_count;

    v_remaining := GREATEST(0, call_limit - v_new_count);

    RETURN QUERY SELECT TRUE, v_remaining, v_new_count;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.increment_ai_calls_if_allowed(UUID, INTEGER) TO service_role;
