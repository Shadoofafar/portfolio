/**
 * TypeScript Interfaces — Key Excerpts
 * Core data model for the LMS platform.
 */

export type Role = 'admin' | 'teacher' | 'student';

export interface UserProfile {
  id: string;
  email: string;
  role: Role;
  display_name?: string;
}

// Hierarchical content library (3-tier structure)
export interface LearningBlock {
  id: string;
  title: string;
  subject: string;
  topics: Topic[];
}

export interface Topic {
  id: string;
  name: string;
  attachments: Attachment[];
}

// Dynamic attachment system
export type AttachmentType = 'message' | 'file' | 'youtube';

export interface Attachment {
  id: string;
  type: AttachmentType;
  content?: string;     // HTML for messages
  file_url?: string;    // Supabase Storage URL
  video_id?: string;    // YouTube ID for sync player
}
