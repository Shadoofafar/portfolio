/**
 * Express Backend Proxy Server
 * 
 * This server acts as a middleware between the React frontend and Supabase,
 * solving the RLS infinite recursion problem by using the Service Role Key
 * for admin operations while keeping it server-side only.
 * 
 * Key responsibilities:
 * - JWT validation for all authenticated routes
 * - User CRUD via Supabase Admin SDK (bypasses RLS)
 * - Zoom meeting lifecycle via OAuth Server-to-Server
 * - Email dispatch via Nodemailer
 * - Rate limiting (global + strict per-route)
 * 
 * NOTE: This is a sanitized excerpt — all credentials have been removed.
 */

import express from 'express';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import { createClient } from '@supabase/supabase-js';
import nodemailer from 'nodemailer';

const app = express();
app.use(express.json());

// --- CORS Configuration ---
// Restrict origins to known frontends in production
const allowedOrigins = process.env.ALLOWED_ORIGIN?.split(',') || ['http://localhost:5173'];
app.use(cors({
  origin: (origin, callback) => {
    if (!origin || allowedOrigins.includes(origin) || allowedOrigins.includes('*')) {
      callback(null, true);
    } else {
      callback(new Error('CORS: Origin not allowed'));
    }
  },
  credentials: true,
}));

// --- Rate Limiting ---
// Global: 200 requests per 15 minutes per IP
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 200,
  standardHeaders: true,
  legacyHeaders: false,
});

// Strict: 15 requests per 10 minutes for sensitive endpoints
const strictLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: 15,
  message: { error: 'Too many requests. Please try again later.' },
});

app.use(globalLimiter);

// --- Supabase Admin Client ---
// Uses Service Role Key to bypass RLS for admin operations
// This key NEVER leaves the server — the frontend uses the anon key
const supabaseAdmin = createClient(
  process.env.VITE_SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  { auth: { autoRefreshToken: false, persistSession: false } }
);

// ============================================================================
// MIDDLEWARE: JWT Authentication
// Validates the Bearer token from the frontend against Supabase Auth
// ============================================================================
async function requireAuth(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid authorization header' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
    if (error || !user) {
      return res.status(401).json({ error: 'Invalid or expired token' });
    }
    req.user = user;
    next();
  } catch (err) {
    return res.status(500).json({ error: 'Authentication service error' });
  }
}

// ============================================================================
// MIDDLEWARE: Admin Role Verification
// After JWT validation, checks if the user has admin role in user_profiles
// ============================================================================
async function requireAdmin(req, res, next) {
  const { data: profile } = await supabaseAdmin
    .from('user_profiles')
    .select('role')
    .eq('id', req.user.id)
    .single();

  if (!profile || profile.role !== 'admin') {
    return res.status(403).json({ error: 'Insufficient permissions' });
  }
  next();
}

// ============================================================================
// ROUTE: GET /api/users/me
// Returns the current user's profile, bypassing RLS
// This solves the infinite recursion problem: the frontend can't query
// user_profiles directly because RLS checks role from the same table
// ============================================================================
app.get('/api/users/me', requireAuth, async (req, res) => {
  try {
    const { data: profile, error } = await supabaseAdmin
      .from('user_profiles')
      .select('*')
      .eq('id', req.user.id)
      .single();

    if (error) {
      return res.status(500).json({ error: 'Failed to fetch profile' });
    }
    res.json({ profile });
  } catch (err) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ============================================================================
// ROUTE: GET /api/users
// Lists all user profiles — admin only
// Used by the admin dashboard for user management
// ============================================================================
app.get('/api/users', requireAuth, requireAdmin, async (req, res) => {
  try {
    const { data: profiles, error } = await supabaseAdmin
      .from('user_profiles')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) throw error;
    res.json({ profiles });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch user list' });
  }
});

// ============================================================================
// ROUTE: POST /api/admin/create-user
// Creates a new user via Supabase Admin SDK
// Bypasses email verification and rate limits
// Also inserts a matching user_profiles row (guarantees profile exists)
// ============================================================================
app.post('/api/admin/create-user', requireAuth, requireAdmin, strictLimiter, async (req, res) => {
  const { email, password, role = 'student' } = req.body;

  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required' });
  }

  try {
    // Step 1: Create user in Supabase Auth (bypasses email verification)
    const { data: authUser, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,  // Auto-confirm email — no verification needed
      app_metadata: { name_changes_left: 3 },
    });

    if (authError) throw authError;

    // Step 2: Insert matching profile row in user_profiles
    // Using upsert to handle edge cases where a trigger may have already created it
    const { error: profileError } = await supabaseAdmin
      .from('user_profiles')
      .upsert({
        id: authUser.user.id,
        email: email.toLowerCase(),
        role,
        password_hash: password, // Admin-visible memo (not a real hash)
        created_at: new Date().toISOString(),
      }, { onConflict: 'id' });

    if (profileError) {
      console.error('Profile insert failed:', profileError);
      // User was created in Auth but profile failed — log but don't fail
    }

    res.json({
      message: `User ${email} created successfully`,
      userId: authUser.user.id,
    });
  } catch (err) {
    console.error('User creation failed:', err);
    res.status(500).json({ error: err.message || 'Failed to create user' });
  }
});

// ============================================================================
// ROUTE: POST /api/users/update-display-name
// Updates the display name with a limited number of attempts (3 max)
// The counter is stored in app_metadata (tamper-proof — client can't modify)
// ============================================================================
app.post('/api/users/update-display-name', requireAuth, async (req, res) => {
  const { newDisplayName } = req.body;
  const userId = req.user.id;

  if (!newDisplayName?.trim()) {
    return res.status(400).json({ error: 'Display name cannot be empty' });
  }

  try {
    // Read the tamper-proof counter from app_metadata
    const appMeta = req.user.app_metadata || {};
    let changesLeft = typeof appMeta.name_changes_left === 'number'
      ? appMeta.name_changes_left
      : 3;

    if (changesLeft <= 0) {
      return res.status(403).json({
        error: 'You have used all 3 name change attempts.',
        name_changes_left: 0,
      });
    }

    changesLeft -= 1;

    // Update display_name in user_profiles table
    const { error: dbError } = await supabaseAdmin
      .from('user_profiles')
      .update({ display_name: newDisplayName.trim() })
      .eq('id', userId);

    if (dbError) throw dbError;

    // Update the counter in app_metadata (only Admin SDK can write this)
    const { error: metaError } = await supabaseAdmin.auth.admin.updateUserById(userId, {
      app_metadata: { name_changes_left: changesLeft },
    });

    if (metaError) throw metaError;

    res.json({
      message: `Display name updated. ${changesLeft} change(s) remaining.`,
      newDisplayName: newDisplayName.trim(),
      name_changes_left: changesLeft,
    });
  } catch (err) {
    console.error('Display name update failed:', err);
    res.status(500).json({ error: 'Failed to update display name' });
  }
});

// ============================================================================
// ROUTE: DELETE /api/admin/delete-user
// Deletes a user from both Supabase Auth and user_profiles
// Protected by master key for the owner account
// ============================================================================
app.delete('/api/admin/delete-user', requireAuth, requireAdmin, async (req, res) => {
  const { userId, masterKey } = req.body;

  if (!userId) {
    return res.status(400).json({ error: 'User ID is required' });
  }

  try {
    // Fetch the target user to check if it's the owner
    const { data: targetProfile } = await supabaseAdmin
      .from('user_profiles')
      .select('role, email')
      .eq('id', userId)
      .single();

    // Protect the owner account — requires master key confirmation
    if (targetProfile?.role === 'admin' && targetProfile?.email === process.env.OWNER_EMAIL) {
      if (masterKey !== process.env.MASTER_KEY) {
        return res.status(403).json({ error: 'Master key required for owner operations' });
      }
    }

    // Step 1: Delete from Supabase Auth
    const { error: authError } = await supabaseAdmin.auth.admin.deleteUser(userId);
    if (authError) throw authError;

    // Step 2: Delete from user_profiles
    await supabaseAdmin.from('user_profiles').delete().eq('id', userId);

    res.json({ message: 'User deleted successfully' });
  } catch (err) {
    console.error('User deletion failed:', err);
    res.status(500).json({ error: 'Failed to delete user' });
  }
});

// ============================================================================
// ZOOM API: OAuth Server-to-Server Integration
// Uses account-level credentials to create meetings on behalf of the org
// ============================================================================

let zoomAccessToken = null;
let zoomTokenExpiry = 0;

/**
 * Fetches a fresh Zoom access token using OAuth Server-to-Server (S2S) flow.
 * Tokens are cached and refreshed only when expired.
 */
async function getZoomToken() {
  if (zoomAccessToken && Date.now() < zoomTokenExpiry) {
    return zoomAccessToken;
  }

  const credentials = Buffer.from(
    `${process.env.ZOOM_CLIENT_ID}:${process.env.ZOOM_CLIENT_SECRET}`
  ).toString('base64');

  const response = await fetch('https://zoom.us/oauth/token', {
    method: 'POST',
    headers: {
      'Authorization': `Basic ${credentials}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'account_credentials',
      account_id: process.env.ZOOM_ACCOUNT_ID,
    }),
  });

  if (!response.ok) {
    throw new Error(`Zoom OAuth failed: ${response.status}`);
  }

  const data = await response.json();
  zoomAccessToken = data.access_token;
  zoomTokenExpiry = Date.now() + (data.expires_in - 60) * 1000; // Refresh 60s early
  return zoomAccessToken;
}

// ============================================================================
// ROUTE: POST /api/zoom/create-meeting
// Creates a Zoom meeting via the API and stores it in the database
// ============================================================================
app.post('/api/zoom/create-meeting', strictLimiter, async (req, res) => {
  const { topic, start_time, duration = 60, agenda = '' } = req.body;

  try {
    const token = await getZoomToken();

    const meetingRes = await fetch('https://api.zoom.us/v2/users/me/meetings', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        topic,
        type: 2, // Scheduled meeting
        start_time,
        duration,
        agenda,
        settings: {
          join_before_host: true,
          waiting_room: false,
          auto_recording: 'none',
        },
      }),
    });

    if (!meetingRes.ok) {
      const errBody = await meetingRes.text();
      throw new Error(`Zoom API error: ${errBody}`);
    }

    const meeting = await meetingRes.json();

    // Persist meeting data in our database
    const { error: dbError } = await supabaseAdmin
      .from('zoom_classes')
      .insert({
        id: String(meeting.id),
        topic: meeting.topic,
        start_time: meeting.start_time,
        duration: meeting.duration,
        join_url: meeting.join_url,
        start_url: meeting.start_url,
      });

    if (dbError) console.error('Failed to save meeting to DB:', dbError);

    res.json({
      message: 'Meeting created',
      meeting: {
        id: meeting.id,
        topic: meeting.topic,
        join_url: meeting.join_url,
        start_url: meeting.start_url,
        start_time: meeting.start_time,
      },
    });
  } catch (err) {
    console.error('Zoom meeting creation failed:', err);
    res.status(500).json({ error: err.message || 'Failed to create meeting' });
  }
});

// ============================================================================
// ROUTE: POST /api/send-email
// Sends an email (OTP verification codes) via SMTP
// Falls back to Ethereal test inbox if SMTP is not configured
// ============================================================================
app.post('/api/send-email', strictLimiter, async (req, res) => {
  const { to, subject, html } = req.body;

  if (!to || !subject || !html) {
    return res.status(400).json({ error: 'Missing required fields: to, subject, html' });
  }

  try {
    let transportConfig;

    if (process.env.SMTP_HOST && process.env.SMTP_USER) {
      // Production: use configured SMTP (e.g., Gmail)
      transportConfig = {
        host: process.env.SMTP_HOST,
        port: parseInt(process.env.SMTP_PORT || '587'),
        secure: process.env.SMTP_SECURE === 'true',
        auth: {
          user: process.env.SMTP_USER,
          pass: process.env.SMTP_PASS,
        },
      };
    } else {
      // Development fallback: Ethereal test inbox
      const testAccount = await nodemailer.createTestAccount();
      transportConfig = {
        host: 'smtp.ethereal.email',
        port: 587,
        auth: { user: testAccount.user, pass: testAccount.pass },
      };
      console.log('Using Ethereal test inbox:', testAccount.user);
    }

    const transporter = nodemailer.createTransport(transportConfig);
    await transporter.sendMail({ from: process.env.SMTP_USER || 'test@example.com', to, subject, html });
    res.json({ message: 'Email sent successfully' });
  } catch (err) {
    console.error('Email sending failed:', err);
    res.status(500).json({ error: 'Failed to send email' });
  }
});

// ============================================================================
// ROUTE: POST /api/auth/register
// Public registration endpoint that bypasses Supabase email verification
// Includes student count limit (100 max) for the platform
// ============================================================================
app.post('/api/auth/register', strictLimiter, async (req, res) => {
  const { email, password } = req.body;
  const MAX_STUDENTS = 100;

  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required' });
  }

  try {
    // Check current student count
    const { count } = await supabaseAdmin
      .from('user_profiles')
      .select('*', { count: 'exact', head: true })
      .eq('role', 'student');

    if (count >= MAX_STUDENTS) {
      return res.status(403).json({ error: 'Student registration limit reached' });
    }

    // Create user with auto-confirmed email
    const { data: authUser, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email: email.toLowerCase(),
      password,
      email_confirm: true,
      app_metadata: { name_changes_left: 3 },
    });

    if (authError) throw authError;

    // Guarantee profile record exists
    await supabaseAdmin.from('user_profiles').upsert({
      id: authUser.user.id,
      email: email.toLowerCase(),
      role: 'student',
      created_at: new Date().toISOString(),
    }, { onConflict: 'id' });

    res.json({
      message: 'Registration successful',
      userId: authUser.user.id,
    });
  } catch (err) {
    console.error('Registration failed:', err);
    res.status(500).json({ error: err.message || 'Registration failed' });
  }
});

// --- Start Server ---
const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`Backend proxy running on port ${PORT}`);
});
