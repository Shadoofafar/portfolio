/**
 * AuthContext — Global Authentication State Provider
 *
 * Manages the entire authentication lifecycle:
 * - Session persistence and auto-recovery on page refresh
 * - Role resolution via backend proxy (bypasses RLS)
 * - Display name management with limited change attempts
 * - Coordinates login/logout state transitions
 *
 * Key design decisions:
 * - Role is fetched from the backend proxy (not direct Supabase query)
 *   because RLS policies on user_profiles cause infinite recursion
 * - Display name changes are tracked in app_metadata (tamper-proof)
 * - All state updates happen synchronously to prevent race conditions
 *   (e.g., App.tsx redirecting with role=null before it's resolved)
 */

import { createContext, useContext, useState, useEffect, type ReactNode } from 'react';
import { supabase } from '../supabaseClient';
import type { Role } from '../types';

interface AuthContextType {
  currentUser: string | null;      // User email
  currentUserId: string | null;    // Supabase Auth user ID
  currentRole: Role;               // 'admin' | 'teacher' | 'student' | null
  displayName: string | null;      // Human-readable display name
  nameChangesLeft: number;         // Remaining name change attempts (max 3)
  setCurrentRole: (role: Role) => void;
  handleLogout: () => Promise<void>;
  updateDisplayName: (newName: string) => Promise<{ success: boolean; error?: string; message?: string }>;
  isLoading: boolean;              // True during session initialization
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider = ({ children }: { children: ReactNode }) => {
  const [currentUser, setCurrentUser] = useState<string | null>(null);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);
  const [currentRole, setCurrentRole] = useState<Role>(null);
  const [displayName, setDisplayName] = useState<string | null>(null);
  const [nameChangesLeft, setNameChangesLeft] = useState<number>(3);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // 1. Check for existing session on initial page load
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (session?.user) {
        setupUser(session.user);
      } else {
        setIsLoading(false);
      }
    });

    // 2. Subscribe to auth state changes (sign-in, sign-out, token refresh)
    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, session) => {
      if (event === 'SIGNED_IN' && session?.user) {
        setupUser(session.user);
      } else if (event === 'SIGNED_OUT') {
        // Clear all state on logout
        setCurrentUser(null);
        setCurrentUserId(null);
        setCurrentRole(null);
        setDisplayName(null);
        setNameChangesLeft(3);
        setIsLoading(false);
      }
    });

    return () => subscription.unsubscribe();
  }, []);

  /**
   * Resolves the user's role and profile via the backend proxy.
   * Sets all state synchronously to prevent race conditions where
   * App.tsx might redirect before the role is known.
   */
  const setupUser = async (user: any) => {
    setIsLoading(true);

    let resolvedRole: Role = 'student';
    let resolvedDisplayName: string | null = null;

    // Fetch role from the backend proxy (bypasses RLS)
    try {
      const sessionRes = await supabase.auth.getSession();
      const token = sessionRes.data.session?.access_token;

      if (token) {
        const res = await fetch(
          `${import.meta.env.VITE_API_URL || 'http://localhost:3001'}/api/users/me`,
          { headers: { 'Authorization': `Bearer ${token}` } }
        );

        if (res.ok) {
          const { profile } = await res.json();
          if (profile) {
            resolvedRole = profile.role as Role;
            resolvedDisplayName = profile.display_name || null;
          }
        }
      }
    } catch (err) {
      console.error('Failed to fetch profile from backend:', err);
    }

    // Read tamper-proof name change counter from app_metadata
    const appMeta = user.app_metadata || {};
    const changesLeft = typeof appMeta.name_changes_left === 'number'
      ? appMeta.name_changes_left
      : 3;

    // Apply all state updates synchronously to avoid race conditions
    // Setting email LAST ensures App.tsx won't trigger a redirect
    // while role is still null
    setCurrentRole(resolvedRole);
    setDisplayName(resolvedDisplayName);
    setNameChangesLeft(changesLeft);
    setCurrentUserId(user.id);
    setCurrentUser(user.email);

    setIsLoading(false);
  };

  /**
   * Updates the user's display name via the backend API.
   * Requires a valid JWT for identity verification.
   */
  const updateDisplayName = async (newName: string) => {
    try {
      const sessionRes = await supabase.auth.getSession();
      const token = sessionRes.data.session?.access_token;
      if (!token) throw new Error('Session expired. Please log in again.');

      const res = await fetch(
        `${import.meta.env.VITE_API_URL || 'http://localhost:3001'}/api/users/update-display-name`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${token}`
          },
          body: JSON.stringify({ newDisplayName: newName })
        }
      );

      const data = await res.json();

      if (!res.ok || data.error) {
        return { success: false, error: data.error || 'Failed to update display name.' };
      }

      // Update local state to reflect the change immediately
      setDisplayName(data.newDisplayName);
      setNameChangesLeft(data.name_changes_left);

      // Refresh the Supabase session to sync the updated app_metadata
      // (the name change counter was decremented server-side)
      await supabase.auth.refreshSession();

      return { success: true, message: data.message };
    } catch (err: any) {
      return { success: false, error: err.message || 'Connection error.' };
    }
  };

  const handleLogout = async () => {
    await supabase.auth.signOut();
  };

  return (
    <AuthContext.Provider value={{
      currentUser,
      currentUserId,
      currentRole,
      displayName,
      nameChangesLeft,
      setCurrentRole,
      updateDisplayName,
      handleLogout,
      isLoading
    }}>
      {/* Don't render children until session check completes to prevent UI flash */}
      {!isLoading && children}
    </AuthContext.Provider>
  );
};

/**
 * Custom hook for accessing auth context in any component.
 * Throws if used outside of AuthProvider.
 */
export const useAuth = () => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth() must be called within an AuthProvider');
  }
  return context;
};
