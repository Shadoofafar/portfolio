# Dobrokhimych LMS — Full-Stack Learning Management System

> **Code excerpts** from a production LMS built for a Ukrainian social education initiative providing free online Chemistry & Biology classes.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENT (Browser)                         │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────────────┐ │
│  │  React SPA  │  │ React Router │  │  Supabase JS Client    │ │
│  │  (Vite+TS)  │──│  (Protected  │──│  (Auth, DB, Storage,   │ │
│  │             │  │   Routes)    │  │   Realtime Broadcast)  │ │
│  └──────┬──────┘  └──────────────┘  └───────────┬────────────┘ │
│         │                                       │              │
│         │  REST (JWT)                            │  Direct      │
└─────────┼───────────────────────────────────────┼──────────────┘
          │                                       │
          ▼                                       ▼
┌─────────────────────┐              ┌──────────────────────────┐
│  Express.js Backend │              │   Supabase Platform       │
│                     │              │                          │
│  • RLS Bypass Proxy │  Service     │  ┌────────────────────┐  │
│  • Zoom OAuth API   │  Role Key    │  │  PostgreSQL (RLS)  │  │
│  • Admin User CRUD  │──────────────│  │  + Auth + Storage  │  │
│  • SMTP Email       │              │  │  + Broadcast       │  │
│  • Rate Limiting    │              │  └────────────────────┘  │
└─────────────────────┘              └──────────────────────────┘
```

### Why an Express Backend Proxy?

Supabase's Row Level Security (RLS) policies caused an **infinite recursion** when user roles were stored in a `user_profiles` table referenced by the policies themselves:

```sql
-- This policy tries to check the user's role from user_profiles...
-- but the SELECT triggers this same policy again → infinite loop
CREATE POLICY "admin_read" ON user_profiles
  FOR SELECT USING (
    (SELECT role FROM user_profiles WHERE id = auth.uid()) = 'admin'
  );
```

**Solution:** An Express server validates JWTs and uses the Service Role Key (server-side only) to bypass RLS for admin operations. Direct Supabase Client queries still go through RLS for non-admin operations — maintaining defense-in-depth.

## Files in This Excerpt

| File | What It Demonstrates |
|------|---------------------|
| `backend/server_proxy.js` | JWT authentication middleware, Supabase Admin SDK usage, Zoom OAuth Server-to-Server flow, rate limiting, CORS, secure user CRUD |
| `frontend/components/SyncYouTubePlayer.tsx` | Real-time video synchronization using Supabase Broadcast channels, event loop prevention with refs |
| `frontend/contexts/AuthContext.tsx` | React Context for global auth state, session lifecycle management, API-based role resolution |
| `frontend/types/types.ts` | TypeScript interfaces defining the entire data model (forms, submissions, groups, learning blocks) |

## Key Technical Decisions

1. **No state management library** — React Context + prop drilling was sufficient for 3 dashboard pages with a predictable data flow
2. **Service Role Key stays server-side** — never exposed to the browser; client uses anon key with RLS
3. **Display name change limit** — enforced via Supabase `app_metadata` (tamper-proof, client cannot modify)
4. **CSTR-style rate limiting** — global (200/15min) + strict routes (15/10min) per IP
