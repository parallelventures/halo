-- ============================================================
-- VERIFICATION UTILISATEUR
-- Remplacez l'ID ci-dessous par celui que vous cherchez
-- ID cible: ca2a6f2a-20d1-44b1-ad03-02f429488e06
-- ============================================================

-- 1. AUTH & PROFIL
-- Vérifie si l'utilisateur existe au niveau authentification et profil public
SELECT 'Auth User' as source, id, email, created_at, last_sign_in_at, raw_user_meta_data 
FROM auth.users 
WHERE id = 'ca2a6f2a-20d1-44b1-ad03-02f429488e06';

SELECT 'Public Profile' as source, * 
FROM public.profiles 
WHERE id = 'ca2a6f2a-20d1-44b1-ad03-02f429488e06';

-- 2. ENTITEMENTS & CREDITS
-- Vérifie le solde de looks et les droits
SELECT 'Entitlements' as source, * 
FROM public.entitlements 
WHERE user_id = 'ca2a6f2a-20d1-44b1-ad03-02f429488e06';

SELECT 'User Credits' as source, * 
FROM public.user_credits 
WHERE user_id = 'ca2a6f2a-20d1-44b1-ad03-02f429488e06';

-- 3. ACTIVITÉ
-- Vérifie les générations et événements
SELECT 'Generations' as source, *
FROM public.generations 
WHERE user_id = 'ca2a6f2a-20d1-44b1-ad03-02f429488e06' 
ORDER BY created_at DESC;

SELECT 'Monetization Events' as source, * 
FROM public.monetization_events 
WHERE user_id = 'ca2a6f2a-20d1-44b1-ad03-02f429488e06' 
ORDER BY created_at DESC;

SELECT 'Onboarding Events' as source, * 
FROM public.onboarding_events 
WHERE user_id = 'ca2a6f2a-20d1-44b1-ad03-02f429488e06';
