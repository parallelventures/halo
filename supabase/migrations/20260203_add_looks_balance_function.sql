-- Function to add looks balance (for RevenueCat webhook)
-- This function atomically increments the user's looks_balance

CREATE OR REPLACE FUNCTION add_looks_balance(p_user_id UUID, p_amount INT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Insert or update the entitlements record
    INSERT INTO entitlements (user_id, looks_balance, updated_at)
    VALUES (p_user_id, p_amount, NOW())
    ON CONFLICT (user_id) 
    DO UPDATE SET 
        looks_balance = entitlements.looks_balance + p_amount,
        updated_at = NOW();
END;
$$;

-- Grant execute permission to the service role
GRANT EXECUTE ON FUNCTION add_looks_balance TO service_role;
