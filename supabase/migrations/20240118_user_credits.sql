-- Migration: Create user_credits system (Idempotent)
-- Run this in Supabase SQL Editor or via db push

-- 1. Create user_credits table if not exists
CREATE TABLE IF NOT EXISTS public.user_credits (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  looks_balance INTEGER DEFAULT 0 CHECK (looks_balance >= 0),
  total_purchased INTEGER DEFAULT 0,
  total_spent INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Enable RLS
ALTER TABLE public.user_credits ENABLE ROW LEVEL SECURITY;

-- 3. RLS Policies (Drop first to avoid errors)
DROP POLICY IF EXISTS "Users can read own credits" ON public.user_credits;
CREATE POLICY "Users can read own credits" ON public.user_credits
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own credits" ON public.user_credits;
CREATE POLICY "Users can update own credits" ON public.user_credits
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own credits" ON public.user_credits;
CREATE POLICY "Users can insert own credits" ON public.user_credits
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 4. Function to spend 1 credit (atomic)
CREATE OR REPLACE FUNCTION spend_credit(p_user_id UUID)
RETURNS TABLE(success BOOLEAN, new_balance INTEGER) AS $$
DECLARE
  v_balance INTEGER;
BEGIN
  -- Atomic update with check
  UPDATE public.user_credits 
  SET 
    looks_balance = looks_balance - 1,
    total_spent = total_spent + 1,
    updated_at = NOW()
  WHERE user_id = p_user_id AND looks_balance > 0
  RETURNING looks_balance INTO v_balance;
  
  IF FOUND THEN
    RETURN QUERY SELECT TRUE, v_balance;
  ELSE
    -- Check if user exists with 0 balance or doesn't exist
    SELECT looks_balance INTO v_balance FROM public.user_credits WHERE user_id = p_user_id;
    RETURN QUERY SELECT FALSE, COALESCE(v_balance, 0);
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Function to add credits (for purchase)
CREATE OR REPLACE FUNCTION add_credits(p_user_id UUID, p_amount INTEGER)
RETURNS TABLE(success BOOLEAN, new_balance INTEGER) AS $$
DECLARE
  v_balance INTEGER;
BEGIN
  -- Upsert: insert or update
  INSERT INTO public.user_credits (user_id, looks_balance, total_purchased)
  VALUES (p_user_id, p_amount, p_amount)
  ON CONFLICT (user_id) DO UPDATE SET
    looks_balance = public.user_credits.looks_balance + p_amount,
    total_purchased = public.user_credits.total_purchased + p_amount,
    updated_at = NOW()
  RETURNING looks_balance INTO v_balance;
  
  RETURN QUERY SELECT TRUE, v_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Function to get balance
CREATE OR REPLACE FUNCTION get_credits(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
  v_balance INTEGER;
BEGIN
  SELECT looks_balance INTO v_balance FROM public.user_credits WHERE user_id = p_user_id;
  RETURN COALESCE(v_balance, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Grant execute permissions
GRANT EXECUTE ON FUNCTION spend_credit(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION add_credits(UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_credits(UUID) TO authenticated;

-- 8. Index for performance
CREATE INDEX IF NOT EXISTS idx_user_credits_user_id ON public.user_credits(user_id);
