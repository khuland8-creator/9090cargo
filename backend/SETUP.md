# 9090 CARGO — Supabase setup

## Current state
- GitHub Pages index.html is a localStorage demo only.
- backend/schema.sql is a draft PostgreSQL schema, NOT production-ready.
- No Supabase project, database connection, or real login has been created.
- Export a JSON backup from the demo Report screen before migration.

## Create the Supabase project
1. Open https://supabase.com/dashboard and sign in as the project owner.
2. Select New project and name it 9090cargo.
3. Save the database password in a password manager; never send it in chat or commit it to GitHub.
4. Keep service_role, secret keys, database password, and JWT secrets on the server only.
5. Review backups, usage limits, domain, monitoring and billing before production.

## Username + password login
- Staff use unique names such as Admin9090 and Admin9090-2.
- Supabase Auth does not natively sign in by username. A secure server-side auth gateway must map username to an internal Auth identity and verify the password with Supabase Auth.
- Do not expose username-to-email mapping in an anonymous database table or public endpoint.
- Implement login rate limits, generic error messages, audit logs, password reset and optional MFA.
- Never place passwords or privileged keys in the GitHub Pages client.
- Both admins have separate identities with equal permissions.

## Data and authorization
- Review backend/schema.sql before applying migrations. Existing broad warehouse UPDATE policies are not sufficient for production.
- Enforce field-level authorization on the server for finance, payment, delivery and status changes.
- Keep shipment event history immutable and record actor identity.
- Store shipment images in private storage with authenticated access.
- Keep trip codes unique; never attach new cargo to departed trips.

## Rollout checklist
1. Owner creates Supabase project.
2. Review schema and build migrations, test row-level security.
3. Implement username authentication gateway and bootstrap two admins.
4. Test Mongolian and Chinese staff roles across devices.
5. Preview and validate imported JSON backup without overwriting demo data.
6. Switch to production only after permissions, backups and audit trails pass tests.

IMPORTANT: A static GitHub Pages site alone cannot provide secure authentication or a central writable database.