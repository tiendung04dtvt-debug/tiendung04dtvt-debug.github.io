# Ôn thi CNTT cơ bản

Static GitHub Pages site. Publish all files in this folder from the repository root (or set the Pages source to this folder).

- Entry point: `index.html`
- No build step or external dependencies are required.
- Quiz progress is stored in each learner's browser local storage, so learners on different devices do not share results.
- To enable the in-page “Gửi yêu cầu / góp ý” inbox, run `supabase-feedback.sql` once in Supabase SQL Editor. Submitted items are stored in the private `app_private.site_feedback` table; review them in Supabase Table Editor.
