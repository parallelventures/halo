-- Create bucket for user hairstyle photos
INSERT INTO storage.buckets (id, name, public)
VALUES ('hairstyles', 'hairstyles', false)
ON CONFLICT (id) DO NOTHING;

-- Enable RLS on the storage.objects table
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only upload to their own folder
CREATE POLICY "Users can upload to own folder"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'hairstyles' 
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Users can only read their own files
CREATE POLICY "Users can read own files"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'hairstyles' 
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Users can delete their own files
CREATE POLICY "Users can delete own files"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'hairstyles' 
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Users can update their own files
CREATE POLICY "Users can update own files"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'hairstyles' 
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Create a table to store hairstyle generation metadata
CREATE TABLE IF NOT EXISTS public.hairstyle_generations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    style_name TEXT NOT NULL,
    style_category TEXT,
    image_path TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Enable RLS on hairstyle_generations
ALTER TABLE public.hairstyle_generations ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own generations
CREATE POLICY "Users can view own generations"
ON public.hairstyle_generations
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Policy: Users can insert their own generations
CREATE POLICY "Users can insert own generations"
ON public.hairstyle_generations
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- Policy: Users can delete their own generations
CREATE POLICY "Users can delete own generations"
ON public.hairstyle_generations
FOR DELETE
TO authenticated
USING (user_id = auth.uid());

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_generations_user_id 
ON public.hairstyle_generations(user_id);

CREATE INDEX IF NOT EXISTS idx_generations_created_at 
ON public.hairstyle_generations(created_at DESC);
