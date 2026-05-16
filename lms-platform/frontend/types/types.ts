/**
 * TypeScript Type Definitions — Dobrokhimych LMS
 *
 * Complete data model for the platform covering:
 * - User roles and profiles
 * - Dynamic form builder with multiple field types
 * - Form submissions and response tracking
 * - Study groups with teacher assignments
 * - Zoom meeting scheduling
 * - Hierarchical content library (Blocks → Topics → Attachments)
 */

// User roles in the system
export type Role = 'admin' | 'teacher' | 'student' | null;

// User profile stored in user_profiles table
export interface UserProfile {
  id: string;                  // Maps to Supabase Auth user ID
  email: string;
  role: Role;
  display_name?: string | null;
  password_hash?: string;      // Admin-visible memo (not an actual hash)
  created_at?: string;
}

// ============================================================================
// DYNAMIC FORM BUILDER
// Forms are composed of configurable fields with different input types
// ============================================================================

// Supported field types for the form builder
export type FieldType = 'text' | 'longtext' | 'checkbox' | 'radio' | 'multicheckbox';

// Individual form field definition
export interface FormField {
  id: string;              // UUID for this field
  label: string;           // Display label (e.g., "Your full name")
  type: FieldType;
  options?: string[];      // For radio/multicheckbox — list of option labels
  required?: boolean;      // Whether the field must be filled
}

// Form template (the structure, not a submission)
export interface FormTemplate {
  id: string;
  title: string;
  description?: string;
  fields: FormField[];
}

// A student's response to a form
export interface FormSubmission {
  id: string;
  form_id: string;
  student_email: string;
  date: string;            // ISO date string of submission
  responses: Record<string, any>; // { fieldId: answer }
}

// ============================================================================
// STUDY GROUPS
// Groups organize students and teachers by class/subject
// ============================================================================

// Teacher-subject assignment within a group
export interface TeacherAssignment {
  email: string;
  subjects: string[];      // e.g., ["Chemistry", "Biology"]
  classes: string[];       // e.g., ["7", "8", "9"]
}

// Study group definition
export interface StudyGroup {
  id: string;
  name: string;                           // e.g., "10-A"
  teacher_emails: string[];               // All teacher emails in this group
  teacher_assignments?: TeacherAssignment[]; // Detailed subject/class mapping
  student_emails: string[];               // All student emails in this group
}

// ============================================================================
// ZOOM MEETINGS
// Scheduled video classes with join/start URLs
// ============================================================================

export interface ZoomClass {
  id: string;
  topic: string;
  start_time: string;      // ISO timestamp (stored in UTC, displayed in Kiev TZ)
  duration: number;         // Duration in minutes
  join_url?: string;        // URL for students to join
  start_url?: string;       // URL for the host to start
}

// ============================================================================
// DOCUMENT LIBRARY (HIERARCHICAL CONTENT)
// Learning Blocks → Topics → Attachments (3-tier structure)
// ============================================================================

// Content types for attachments within a topic
export type AttachmentType = 'message' | 'file' | 'youtube';

// Base attachment fields shared by all types
interface BaseAttachment {
  id: string;
  type: AttachmentType;
  created_at?: string;
  is_pinned?: boolean;      // Pinned items appear at the top
}

// Rich-text message (HTML from Quill editor)
export interface MessageAttachment extends BaseAttachment {
  type: 'message';
  content: string;           // Sanitized HTML
}

// Uploaded file (PDF, DOCX, XLSX, etc.)
export interface FileAttachment extends BaseAttachment {
  type: 'file';
  file_name: string;
  file_url: string;          // Supabase Storage public URL
  file_size?: number;        // Bytes
}

// Embedded YouTube video with sync playback options
export interface YouTubeAttachment extends BaseAttachment {
  type: 'youtube';
  video_url: string;         // Full YouTube URL
  video_id: string;          // Extracted video ID
  start_sec?: number;        // Clip start time
  end_sec?: number;          // Clip end time
  hide_controls?: boolean;   // Hide player controls for students
  disable_kb?: boolean;      // Disable keyboard shortcuts
  hide_fullscreen?: boolean; // Hide fullscreen button
}

// Union type for all attachment kinds
export type Attachment = MessageAttachment | FileAttachment | YouTubeAttachment;

// A topic is a named group of attachments within a block
export interface Topic {
  id: string;
  name: string;
  attachments: Attachment[];
  created_at?: string;
}

// A learning block is the top-level content container
export interface LearningBlock {
  id: string;
  title: string;
  description?: string;
  subject: string;           // "Chemistry" | "Biology" | etc.
  created_by: string;        // Email of the creator
  topics: Topic[];
  attachments: Attachment[]; // Block-level attachments (outside any topic)
  created_at?: string;
  is_pinned?: boolean;
}

// ============================================================================
// APPLICATION SETTINGS
// Key-value store for platform-wide configuration
// ============================================================================

export interface AppSetting {
  key: string;               // e.g., "require_email_verification"
  value: string;             // e.g., "true" | "false"
}
