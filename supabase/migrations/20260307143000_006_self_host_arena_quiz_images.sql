-- ============================================================
-- Migration 006: Self-host Arena quiz images and disable dead seeds
-- Date: 2026-03-07
--
-- Updates quiz questions whose legacy Unsplash seed images were
-- successfully copied into Supabase Storage. Legacy seed URLs that
-- now return 404 are disabled so Arena does not serve dead-image
-- questions until replacement assets are provided.
-- ============================================================

UPDATE public.quiz_questions
SET image_url = CASE item_name
    WHEN 'Cardboard Box' THEN 'https://nwhdqiaepwhxepcygsmm.supabase.co/storage/v1/object/public/quiz-images/seed/cardboard-box.jpg'
    WHEN 'Glass Jar' THEN 'https://nwhdqiaepwhxepcygsmm.supabase.co/storage/v1/object/public/quiz-images/seed/glass-jar.jpg'
    WHEN 'Plastic Container' THEN 'https://nwhdqiaepwhxepcygsmm.supabase.co/storage/v1/object/public/quiz-images/seed/plastic-container.jpg'
    WHEN 'Tin Can' THEN 'https://nwhdqiaepwhxepcygsmm.supabase.co/storage/v1/object/public/quiz-images/seed/tin-can.jpg'
    WHEN 'Paper Bag' THEN 'https://nwhdqiaepwhxepcygsmm.supabase.co/storage/v1/object/public/quiz-images/seed/paper-bag.jpg'
    WHEN 'Banana Peel' THEN 'https://nwhdqiaepwhxepcygsmm.supabase.co/storage/v1/object/public/quiz-images/seed/banana-peel.jpg'
    WHEN 'Apple Core' THEN 'https://nwhdqiaepwhxepcygsmm.supabase.co/storage/v1/object/public/quiz-images/seed/apple-core.jpg'
    WHEN 'Salad Leaves' THEN 'https://nwhdqiaepwhxepcygsmm.supabase.co/storage/v1/object/public/quiz-images/seed/salad-leaves.jpg'
    WHEN 'Egg Shells' THEN 'https://nwhdqiaepwhxepcygsmm.supabase.co/storage/v1/object/public/quiz-images/seed/egg-shells.jpg'
    WHEN 'Orange Peel' THEN 'https://nwhdqiaepwhxepcygsmm.supabase.co/storage/v1/object/public/quiz-images/seed/orange-peel.jpg'
    WHEN 'Tea Bag' THEN 'https://nwhdqiaepwhxepcygsmm.supabase.co/storage/v1/object/public/quiz-images/seed/tea-bag.jpg'
    WHEN 'Bread Slice' THEN 'https://nwhdqiaepwhxepcygsmm.supabase.co/storage/v1/object/public/quiz-images/seed/bread-slice.jpg'
    WHEN 'Light Bulb' THEN 'https://nwhdqiaepwhxepcygsmm.supabase.co/storage/v1/object/public/quiz-images/seed/light-bulb.jpg'
    WHEN 'Motor Oil' THEN 'https://nwhdqiaepwhxepcygsmm.supabase.co/storage/v1/object/public/quiz-images/seed/motor-oil.jpg'
    WHEN 'Cleaning Chemicals' THEN 'https://nwhdqiaepwhxepcygsmm.supabase.co/storage/v1/object/public/quiz-images/seed/cleaning-chemicals.jpg'
    WHEN 'Medicine Bottle' THEN 'https://nwhdqiaepwhxepcygsmm.supabase.co/storage/v1/object/public/quiz-images/seed/medicine-bottle.jpg'
    WHEN 'Styrofoam Cup' THEN 'https://nwhdqiaepwhxepcygsmm.supabase.co/storage/v1/object/public/quiz-images/seed/styrofoam-cup.jpg'
    WHEN 'Diaper' THEN 'https://nwhdqiaepwhxepcygsmm.supabase.co/storage/v1/object/public/quiz-images/seed/diaper.jpg'
    WHEN 'Broken Ceramic' THEN 'https://nwhdqiaepwhxepcygsmm.supabase.co/storage/v1/object/public/quiz-images/seed/broken-ceramic.jpg'
    WHEN 'Rubber Gloves' THEN 'https://nwhdqiaepwhxepcygsmm.supabase.co/storage/v1/object/public/quiz-images/seed/rubber-gloves.jpg'
    WHEN 'Candy Wrapper' THEN 'https://nwhdqiaepwhxepcygsmm.supabase.co/storage/v1/object/public/quiz-images/seed/candy-wrapper.jpg'
    ELSE image_url
END
WHERE item_name IN (
    'Cardboard Box',
    'Glass Jar',
    'Plastic Container',
    'Tin Can',
    'Paper Bag',
    'Banana Peel',
    'Apple Core',
    'Salad Leaves',
    'Egg Shells',
    'Orange Peel',
    'Tea Bag',
    'Bread Slice',
    'Light Bulb',
    'Motor Oil',
    'Cleaning Chemicals',
    'Medicine Bottle',
    'Styrofoam Cup',
    'Diaper',
    'Broken Ceramic',
    'Rubber Gloves',
    'Candy Wrapper'
);

UPDATE public.quiz_questions
SET is_active = false
WHERE item_name IN (
    'Plastic Bottle',
    'Aluminum Can',
    'Newspaper',
    'Coffee Grounds',
    'Battery',
    'Paint Can',
    'Aerosol Can',
    'Pesticide',
    'Chip Bag',
    'Plastic Wrap',
    'Used Tissue'
);

DROP POLICY IF EXISTS "Quiz images seed upload (temporary)" ON storage.objects;
