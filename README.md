# GymKeep — Master Control (development scaffold)

This repository begins the GymKeep multi-gym SaaS rebuild while preserving the supplied prototype as the product reference.

## Current milestone
- Responsive Master Control frontend.
- Gym instance list and create-gym preview.
- Default accent colour editor.
- Feature catalogue and platform settings screens.
- Local browser persistence for UI preview only.

## Important status
The current `index.html` is a frontend milestone, not a production SaaS. Gym creation currently stores preview records in browser localStorage. It does NOT create a Supabase project, database, URL, admin account, or payment subscription. Do not use it for real customer/member data.

## Target architecture
- Control plane: one Supabase project for platform admins, tenant registry, branding configuration, feature flags, billing state and provisioning jobs.
- Tenant isolation: a separate Supabase project/database per gym, provisioned server-side with the Management API. Never expose Management API tokens or service-role keys in browser code.
- Tenant routing: `<gym-slug>.gymkeep.app` after a wildcard domain and hosting are configured.
- Auth: Supabase Auth, platform admin allowlist, gym roles and server-side authorization.
- Payments: Razorpay Orders + signature verification and webhook processing on the server.
- Installability: PWA manifest/service worker after the app shell is connected to production APIs.

## Run locally
Open `index.html` in a modern browser or serve this repository with any static web server.

## Existing prototype
The uploaded `GymKeep_MultiGym_Attendance_Starter` remains the source reference for existing owner/member/front-desk workflows and the attendance foundation. Its README explicitly marks simulated features and its SQL as a starter requiring review.
