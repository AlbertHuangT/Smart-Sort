-- Grant app-admin access to a specific authenticated user.
INSERT INTO public.app_admins (user_id)
VALUES ('24a0f05f-1ea0-42c5-8988-64f7a5cbcbfd')
ON CONFLICT (user_id) DO NOTHING;
