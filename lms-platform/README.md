# Dobrokhimych LMS — Full-Stack Learning Management System

> **Curated code excerpts** from a production-grade Learning Management System built for a Ukrainian social education initiative providing free online Chemistry & Biology classes.

## 🚀 Key Engineering Highlights

### 1. RLS Infinite Recursion Bypass (Express Proxy)
* **The Challenge:** Storing roles inside a `user_profiles` table referenced by Supabase Row-Level Security (RLS) policies caused infinite lookup loops.
* **The Solution:** A lightweight Node.js/Express server that validates client JWTs and uses the administrative **Service Role Key** (stored securely on the server) to execute restricted CRUD operations, successfully bypassing recursion while maintaining strict client-side RLS policies for non-admin queries.

```sql
-- The problematic loop: SELECT triggers policy → policy triggers SELECT
CREATE POLICY "admin_read" ON user_profiles FOR SELECT 
  USING ((SELECT role FROM user_profiles WHERE id = auth.uid()) = 'admin');
```

### 2. Embedded Video Call Suite (Jitsi Integration)
* **The Highlight:** A secure, zero-installation video call environment embedded directly within the application using Jitsi Meet API.
* **The Technical Detail:** Dynamically provisions password-protected rooms for course sections, preventing unauthorized access. Provides full teacher moderation capabilities and real-time room creation without external software dependencies.

### 3. Interactive Collaborative Whiteboard
* **The Highlight:** A real-time whiteboard canvas integrated under learning blocks, allowing teachers and students to draw, annotate, and collaborate during live calls.
* **The Technical Detail:** Built using HTML5 Canvas with state persistence and drawing synchronization, providing teachers with custom brush sizes, color palettes, and clear controls for interactive lecture styling.

### 4. Real-Time Video Sync Player (Supabase Broadcast)
* **The Highlight:** A shared class player utilizing **Supabase Realtime Broadcast channels** to synchronize video states across hundreds of students simultaneously.
* **The Technical Detail:** Implemented strict state reference checks (`useRef`) to decouple YouTube player events from incoming network broadcasts, successfully avoiding event cascade loops and desynchronization. Includes a background click-blocker layer for student clients to prevent manual navigation.

### 5. Dynamic Zoom S2S OAuth Integration
* **The Highlight:** Direct Server-to-Server OAuth integration for automatic video class lifecycle management (create, update, delete meetings).
* **The Technical Detail:** Implemented a zero-migration link storage strategy: both the `join_url` (for attendees) and `start_url` (for the host, containing credentials) are stored as serialized JSON inside a single database column. The frontend dynamically routes teachers/admins to the host URL and students to the participant URL on-click.

### 6. Enforcing Tamper-Proof Business Rules
* **The Highlight:** Restricting display name changes to exactly three per user (to prevent spoofing/spamming).
* **The Technical Detail:** Enforced this state strictly in Supabase `app_metadata`. Since browser-based clients cannot write to `app_metadata`, this implementation is 100% tamper-proof against frontend injection or client-side SDK manipulation.

### 7. Interactive Mouse-Resizable Pinned Chat & Constant-Access Floating Bubble
* **The Highlight:** A highly responsive mouse-resizable sidebar chat and an always-accessible floating contact bubble.
* **The Technical Detail:** Implemented vanilla React mouse event listeners (`mousemove` and `mouseup` attached to `document` on drag start) to track the mouse position, clamp the chat width between `280px` and `80vw`, and persist it to `localStorage`. When the chat is pinned, it applies a matching dynamic `paddingRight` shift to the main layout container (`.app-wrapper`) to seamlessly prevent content overlap, temporarily disabling CSS layout transitions during drag events to ensure 60fps local rendering. Message bubbles employ strict CSS word-wrapping (`word-break: break-word; overflow-wrap: anywhere; white-space: pre-wrap;`) to handle varying chat widths elegantly. The floating chat action bubble stays visible on all page scroll depths for immediate access, fading out only when the drawer is open to maintain visual hygiene.

### 8. Robust OTP Registration & SMTP Email Verification
* **The Highlight:** Secure OTP-based registration and App Password SMTP delivery.
* **The Technical Detail:** Fixed database-level schema constraints by auto-generating unique UUID/string keys for registration submissions on the Express backend before SQL insert. Reconfigured SMTP delivery using a secure Google App Password environment integration to resolve legacy SMTP blocking. Developed a robust client-side routing system that decodes clean URL activation parameters and activates profile profiles via a custom OTP input modal.

### 9. Real-Time Presence & Status Tracking
* **The Highlight:** Direct presence indicator showing user availability in the contacts list.
* **The Technical Detail:** Configured a Supabase Broadcast Presence channel that triggers connection handshakes on drawer mounting, updating client lists in real time when users open or close browser sessions.

### 10. Multi-Format Asset Player & MIME Sniffer
* **The Highlight:** Robust playback of files and lectures from Supabase Storage without browser CORS or byte-range errors.
* **The Technical Detail:** Implemented a MIME-sniffing file parser that overrides generic content types to matching streams (like `video/mp4` or `video/webm`) and embeds custom `playsInline` video elements to support Safari and Chrome mobile browsers. Linked documents to an embedded Google Docs Viewer iframe to prevent file download bypasses.

### 11. High-Fidelity ErrorBoundary Component
* **The Highlight:** A premium dark-mode glossy error recovery panel wrapper.
* **The Technical Detail:** Structured a standard React ErrorBoundary class around the root `<App />` layout tree to intercept compilation, chunk-loading, or runtime state crashes, presenting an elegant recovery panel containing self-diagnostic stack-trace logs and instant navigation reset buttons.

---

## 📁 Selected Files in This Excerpt

| File | Core Technical Demonstration |
| :--- | :--- |
| [`backend/server_proxy.js`](./backend/server_proxy.js) | Express server with JWT validation, Supabase Admin operations, rate limiting, and Zoom OAuth S2S. |
| [`frontend/components/ScheduleView.tsx`](./frontend/components/ScheduleView.tsx) | Clean React scheduler resolving and launching host vs attendee links dynamically. |
| [`frontend/components/SyncYouTubePlayer.tsx`](./frontend/components/SyncYouTubePlayer.tsx) | Real-time state synchronization with loop-prevention references. |
| [`frontend/contexts/AuthContext.tsx`](./frontend/contexts/AuthContext.tsx) | React Context managing active auth sessions and server-side role resolution. |
| [`frontend/types/types.ts`](./frontend/types/types.ts) | TypeScript interfaces ensuring complete type safety for the platform data model. |

---

## 🛠️ Tech Stack

* **Frontend:** React 19, TypeScript, Vite, React Router, TailwindCSS/Vanilla CSS, YouTube IFrame API, Canvas API
* **Backend:** Node.js, Express, Supabase JS Admin SDK, Axios, Nodemailer, Express Rate Limit, Jitsi IFrame API
* **Database & BaaS:** PostgreSQL (with RLS), Supabase Auth, Storage, and Realtime Engine
