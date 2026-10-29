LMIS - Legal Management Information System
==========================================

FOLDER
  public/index.html        the app
  public/config.js         generated from .env (do not edit by hand)
  database/lmis_schema.sql run this once in Supabase
  .env                     your Supabase URL and anon key
  .env.example             blank copy of .env
  build.js                 turns .env into public/config.js
  package.json, vercel.json  for running locally / deploying on Vercel
  notes/                   photos of your original notes

SETUP
1. Supabase > SQL Editor: paste all of database/lmis_schema.sql and run it.
2. Supabase > Project Settings > API: copy the Project URL and the anon/public key.
3. Open .env and paste them in (no quotes needed).
4. Run:  node build.js      (this writes public/config.js)
5. Open public/index.html in your browser. Sign up. The first account becomes admin.

PROFILE PICTURES AND DETAILS DOWNLOADS
  The updated schema adds profile_image_path to cases and lawyers. If the
  database was already created, rerun lmis_schema.sql (the ALTER TABLE
  statements are safe to run on an existing database). Case, lawyer, and
  project detail modals include a Download details button. Case and lawyer
  pictures are selected in the form and uploaded when Save is pressed.

IF SIGN-UP FAILS
  - Supabase > Authentication > Sign In / Providers > Email: turn OFF "Confirm email"
    while testing (the free email sender has a very low hourly limit).

DEPLOY ON VERCEL
  - Import the folder/repo. Add environment variables SUPABASE_URL and
    SUPABASE_ANON_KEY in the Vercel project settings. vercel.json does the rest.
  - Then add your live link in Supabase > Authentication > URL Configuration > Site URL.
  - Do not commit .env to GitHub (it is already in .gitignore).
