<p align="center">
  <strong>Konstantin Zhuravel — Portfolio</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/React-19-61DAFB?style=flat-square&logo=react&logoColor=white" alt="React 19" />
  <img src="https://img.shields.io/badge/TypeScript-6.0-3178C6?style=flat-square&logo=typescript&logoColor=white" alt="TypeScript" />
  <img src="https://img.shields.io/badge/Node.js-Express-339933?style=flat-square&logo=nodedotjs&logoColor=white" alt="Node.js" />
  <img src="https://img.shields.io/badge/Supabase-Backend-3ECF8E?style=flat-square&logo=supabase&logoColor=white" alt="Supabase" />
  <img src="https://img.shields.io/badge/MATLAB-Simulation-E16737?style=flat-square&logo=mathworks&logoColor=white" alt="MATLAB" />
</p>

---

This repository contains curated code excerpts from two production-grade projects, demonstrating proficiency in **full-stack web development** and **scientific computing / numerical methods**.

> **Note:** These are selected code snippets for portfolio demonstration purposes. All secrets, credentials, and environment variables have been removed.

---

## 📁 Projects

### 1. [LMS Platform](./lms-platform/) — Full-Stack Learning Management System

A production **Learning Management System** built for a Ukrainian educational non-profit. Supports three roles (Admin, Teacher, Student) with real-time features.

**Tech Stack:** React 19 · TypeScript · Vite · Supabase (Auth, DB, Storage, Realtime) · Express.js · Zoom API · YouTube IFrame API

**Key Highlights:**
- 🔐 **Backend proxy** for Supabase RLS bypass — solves infinite recursion in role-based policies
- 🔄 **Real-time YouTube synchronization** — teacher-controlled playback synced across all students via Supabase Broadcast channels
- 📋 **Dynamic form builder** — configurable field types with submission analytics and Excel export
- 👥 **User management** with JWT auth, rate limiting, and admin SDK operations
- 📅 **Zoom API integration** — OAuth Server-to-Server meeting lifecycle management
- 🏗️ **2,200+ LOC Document Library** with drag-and-drop, WYSIWYG editing, and file storage

**Selected Files:**
| File | Description | Lines |
|------|-------------|-------|
| [`server_proxy.js`](./lms-platform/backend/server_proxy.js) | Express backend — auth proxy, user CRUD, Zoom API, email, rate limiting | 700+ |
| [`SyncYouTubePlayer.tsx`](./lms-platform/frontend/components/SyncYouTubePlayer.tsx) | Real-time video sync via Supabase Broadcast | 170 |
| [`AuthContext.tsx`](./lms-platform/frontend/contexts/AuthContext.tsx) | Global auth state with JWT session management | 200 |
| [`types.ts`](./lms-platform/frontend/types/types.ts) | TypeScript interfaces for the entire data model | 130+ |

---

### 2. [Catalysis Simulation GUI](./catalysis-simulation-gui/) — MATLAB Scientific Computing Tool

A MATLAB App Designer GUI for simulating **template-directed autocatalytic reaction networks**. Developed during an MSc research internship in computational chemistry.

**Tech Stack:** MATLAB (App Designer GUI, ODE solvers, multi-dimensional tensor algebra)

**Key Highlights:**
- 🧪 **6D tensor ODE system** — models enzyme (E), nutrient (N), template (T), and complex (ENTT, TT, TTT) species dynamics
- ⚗️ **CSTR reactor mode** — continuous stirred-tank reactor with configurable inlet feeds, dilution rates, and time-phased operation
- 🔢 **Parametric sweeps** — vectorized scenario generation with automated grid search over rate constants
- 🎛️ **Interactive GUI** — pathway builder with redundancy detection and real-time parameter updates
- 📊 **Multi-scenario plotting** — overlaid results with colorblind-friendly palettes and configurable legend formatting
- 💾 **Network persistence** — save/load reaction networks in `.mat` format

**Selected Files:**
| File | Description | Lines |
|------|-------------|-------|
| [`CatalysisSimulationGUI.m`](./catalysis-simulation-gui/CatalysisSimulationGUI.m) | Main GUI — pathway builder, CSTR controls, Rij matrix, keyboard shortcuts | 1,840 |
| [`f3_second_order.m`](./catalysis-simulation-gui/f3_second_order.m) | ODE right-hand side — 6D tensor kinetics with CSTR dilution terms | 141 |
| [`RunNetwork1.m`](./catalysis-simulation-gui/RunNetwork1.m) | Network solver — assembles initial conditions, calls `ode15s`, processes results | 274 |
| [`redundancy.m`](./catalysis-simulation-gui/redundancy.m) | Constraint propagation — horizontal + vertical redundancy elimination | 143 |

---

## 🛠 Technical Skills Demonstrated

| Category | Technologies |
|----------|-------------|
| **Frontend** | React 19, TypeScript, Vite, React Router, Context API, CSS |
| **Backend** | Node.js, Express.js, JWT Authentication, Rate Limiting, CORS |
| **Database** | PostgreSQL (Supabase), Row Level Security, JSONB, Realtime |
| **APIs** | Zoom OAuth (S2S), YouTube IFrame API, Nodemailer SMTP |
| **Scientific** | MATLAB, ODE solvers (ode15s), Tensor algebra, GUI development |
| **DevOps** | Git, Vercel deployment, Environment management |
| **Practices** | TypeScript type safety, XSS prevention (DOMPurify), Input validation |

---

## 📫 Contact

- **LinkedIn:** [linkedin.com/in/zhuravlkostya](https://www.linkedin.com/in/zhuravlkostya/)
- **GitHub:** [github.com/Shadoofafar](https://github.com/Shadoofafar)
