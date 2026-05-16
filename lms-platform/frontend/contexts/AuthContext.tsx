/**
 * AuthContext — Global Auth State Excerpt
 * Demonstrates session persistence and role resolution via backend proxy.
 */

import { createContext, useContext, useState, useEffect } from 'react';
import { supabase } from '../supabaseClient';

export const AuthProvider = ({ children }: { children: React.ReactNode }) => {
  const [currentUser, setCurrentUser] = useState<string | null>(null);
  const [currentRole, setCurrentRole] = useState<string | null>(null);

  useEffect(() => {
    // 1. Recover session on mount
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (session?.user) resolveProfile(session.user);
    });

    // 2. Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      if (event === 'SIGNED_IN' && session?.user) resolveProfile(session.user);
      else if (event === 'SIGNED_OUT') {
        setCurrentUser(null);
        setCurrentRole(null);
      }
    });

    return () => subscription.unsubscribe();
  }, []);

  // Fetch role and display name from backend proxy (bypasses RLS recursion)
  const resolveProfile = async (user: any) => {
    const { data: { session } } = await supabase.auth.getSession();
    const res = await fetch('/api/users/me', {
      headers: { 'Authorization': `Bearer ${session?.access_token}` }
    });
    const { profile } = await res.json();
    
    setCurrentRole(profile.role);
    setCurrentUser(user.email);
  };

  return (
    <AuthContext.Provider value={{ currentUser, currentRole }}>
      {children}
    </AuthContext.Provider>
  );
};
