/**
 * SyncYouTubePlayer — Real-Time Video Sync Excerpt
 * Demonstrates teacher-controlled playback synced via Supabase Broadcast.
 */

import React, { useEffect, useRef } from 'react';
import YouTube from 'react-youtube';
import { supabase } from '../supabaseClient';

export const SyncYouTubePlayer: React.FC<any> = ({ attachmentId, videoId, isTeacher }) => {
  const playerRef = useRef<any>(null);
  const channelRef = useRef<any>(null);
  const isInternalChange = useRef(false); // Prevents broadcast loops

  useEffect(() => {
    // 1. Join a dedicated broadcast channel for this video
    const channel = supabase.channel(`youtube_sync_${attachmentId}`);

    // 2. Listen for 'sync' events (Students only)
    channel.on('broadcast', { event: 'sync' }, ({ payload }) => {
      if (isTeacher) return; 
      
      isInternalChange.current = true;
      if (payload.type === 'play') {
        playerRef.current.seekTo(payload.time, true);
        playerRef.current.playVideo();
      } else if (payload.type === 'pause') {
        playerRef.current.pauseVideo();
      }
      setTimeout(() => { isInternalChange.current = false; }, 500);
    }).subscribe();

    channelRef.current = channel;
    return () => { supabase.removeChannel(channel); };
  }, [attachmentId, isTeacher]);

  // --- Teachers broadcast actions ---
  const broadcast = (type: string, time: number) => {
    if (!isTeacher || isInternalChange.current) return;
    channelRef.current.send({ type: 'broadcast', event: 'sync', payload: { type, time } });
  };

  return (
    <div className="relative">
      <YouTube
        videoId={videoId}
        onPlay={(e) => broadcast('play', e.target.getCurrentTime())}
        onPause={(e) => broadcast('pause', e.target.getCurrentTime())}
        onReady={(e) => { playerRef.current = e.target; }}
      />
      {/* Click blocker for students to prevent manual desync */}
      {!isTeacher && <div className="absolute inset-0 z-10 bg-transparent" />}
    </div>
  );
};
