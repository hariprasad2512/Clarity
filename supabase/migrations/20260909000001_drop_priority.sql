-- Clarity v2: priorities removed from the app entirely.
-- Sorting is now due-date -> created time only.
alter table if exists public.tasks
  drop column if exists priority;
