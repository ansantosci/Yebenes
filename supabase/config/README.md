# Supabase configuration boundary

This directory is for **versionable, non-secret configuration metadata/documentation only**.

Allowed: environment-independent defaults, examples, manifests, public identifiers when intentionally publishable, and documentation of required setting names.

Forbidden: database passwords/URLs containing credentials, `service_role` keys, access tokens, CRON secrets, SMTP passwords, private keys, provider tokens, or copied Supabase/GitHub secret values.

Runtime secrets live in GitHub/Supabase secret stores. Only their **names and purpose** may be documented in Git.
