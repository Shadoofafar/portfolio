/**
 * Express Backend Proxy — Key Excerpts
 * Demonstrates JWT authentication, RLS bypass using Supabase Admin SDK,
 * and integration with third-party APIs (Zoom).
 */

import express from 'express';
import { createClient } from '@supabase/supabase-js';

const app = express();
app.use(express.json());

// --- Supabase Admin Client (Server-side ONLY) ---
// Bypasses RLS to solve infinite recursion issues in role-based policies
const supabaseAdmin = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

// --- JWT Authentication Middleware ---
async function requireAuth(req, res, next) {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).send('Unauthorized');

  const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
  if (error || !user) return res.status(401).send('Invalid token');
  
  req.user = user;
  next();
}

// --- Example: Get Profile (Bypassing RLS) ---
app.get('/api/users/me', requireAuth, async (req, res) => {
  const { data: profile } = await supabaseAdmin
    .from('user_profiles')
    .select('*')
    .eq('id', req.user.id)
    .single();
  res.json({ profile });
});

// --- Example: Zoom OAuth Server-to-Server Flow ---
app.post('/api/zoom/create-meeting', requireAuth, async (req, res) => {
  // 1. Get OAuth Token using account credentials
  const tokenRes = await fetch('https://zoom.us/oauth/token?grant_type=account_credentials...', {
    method: 'POST',
    headers: { 'Authorization': `Basic ${Buffer.from(CLIENT_ID + ':' + SECRET).toString('base64')}` }
  });
  const { access_token } = await tokenRes.json();

  // 2. Create meeting on behalf of the organization
  const meetingRes = await fetch('https://api.zoom.us/v2/users/me/meetings', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${access_token}` },
    body: JSON.stringify(req.body)
  });
  res.json(await meetingRes.json());
});

// ... (other routes for user CRUD, email, and rate limiting omitted) ...

app.listen(3001);
