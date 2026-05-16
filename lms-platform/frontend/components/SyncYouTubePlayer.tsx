/**
 * SyncYouTubePlayer — Real-Time Synchronized YouTube Player
 *
 * This component enables teacher-controlled synchronized video playback:
 * - Teachers control playback (play/pause/seek) and broadcast events to all students
 * - Students receive events and mirror the teacher's player state in real-time
 * - Uses Supabase Realtime Broadcast channels for low-latency synchronization
 *
 * Key techniques:
 * - `isInternalChange` ref prevents event loop (broadcast → receive → broadcast)
 * - Click-blocker overlay prevents students from desyncing when controls are hidden
 * - Each attachment gets a unique broadcast channel via `attachmentId`
 */

import React, { useEffect, useRef, useState } from 'react';
import YouTube, { type YouTubeProps } from 'react-youtube';
import { supabase } from '../supabaseClient';

interface SyncYouTubePlayerProps {
  attachmentId: string;    // Unique ID used as the broadcast channel name
  videoId: string;         // YouTube video ID (extracted from URL)
  isTeacher: boolean;      // Whether the current user can control playback for everyone
  startSec?: number;       // Optional playback start time (seconds)
  endSec?: number;         // Optional playback end time (seconds)
  hideControls?: boolean;  // Hide YouTube player controls
  disableKb?: boolean;     // Disable keyboard controls
  hideFullscreen?: boolean;// Hide fullscreen button
}

type SyncEvent = {
  type: 'play' | 'pause' | 'seek';
  time: number; // Current playback time in seconds
};

export const SyncYouTubePlayer: React.FC<SyncYouTubePlayerProps> = ({
  attachmentId,
  videoId,
  isTeacher,
  startSec,
  endSec,
  hideControls,
  disableKb,
  hideFullscreen
}) => {
  const playerRef = useRef<any>(null);       // Reference to YouTube Player API instance
  const channelRef = useRef<any>(null);      // Reference to Supabase Realtime channel
  const [_playerReady, setPlayerReady] = useState(false);
  const isInternalChange = useRef(false);    // Flag to prevent broadcast loops

  useEffect(() => {
    // 1. Create a Supabase Realtime channel for this specific video attachment
    const channel = supabase.channel(`youtube_sync_${attachmentId}`);

    // 2. Listen for 'sync' broadcast events from the teacher
    channel
      .on('broadcast', { event: 'sync' }, (payload) => {
        // Teachers ignore sync events — they are the source of truth
        if (isTeacher) return;

        const data = payload.payload as SyncEvent;
        const player = playerRef.current;
        if (!player) return;

        // Set the internal change flag to prevent re-broadcasting this action
        isInternalChange.current = true;

        if (data.type === 'play') {
          player.seekTo(data.time, true);
          player.playVideo();
        } else if (data.type === 'pause') {
          player.seekTo(data.time, true);
          player.pauseVideo();
        } else if (data.type === 'seek') {
          player.seekTo(data.time, true);
        }

        // Reset the flag after 500ms to allow the YouTube API to process
        // the state change without triggering false onPlay/onPause events
        setTimeout(() => {
          isInternalChange.current = false;
        }, 500);
      })
      .subscribe();

    channelRef.current = channel;

    // Cleanup: remove the channel on component unmount
    return () => {
      supabase.removeChannel(channel);
    };
  }, [attachmentId, isTeacher]);

  /**
   * Broadcasts a sync event to all connected students.
   * Only fires when the current user is a teacher.
   */
  const broadcastEvent = (type: SyncEvent['type'], time: number) => {
    if (!isTeacher || !channelRef.current) return;
    channelRef.current.send({
      type: 'broadcast',
      event: 'sync',
      payload: { type, time }
    });
  };

  const onReady: YouTubeProps['onReady'] = (event) => {
    playerRef.current = event.target;
    setPlayerReady(true);
  };

  const onPlay: YouTubeProps['onPlay'] = (event) => {
    if (isInternalChange.current) return; // Ignore if triggered by auto-sync
    broadcastEvent('play', event.target.getCurrentTime());
  };

  const onPause: YouTubeProps['onPause'] = (event) => {
    if (isInternalChange.current) return; // Ignore if triggered by auto-sync
    broadcastEvent('pause', event.target.getCurrentTime());
  };

  // YouTube IFrame API configuration
  const opts: YouTubeProps['opts'] = {
    width: '100%',
    height: '100%',
    playerVars: {
      autoplay: 0,
      start: startSec,
      end: endSec,
      controls: hideControls ? 0 : 1,
      disablekb: disableKb ? 1 : 0,
      fs: hideFullscreen ? 0 : 1,
      modestbranding: 1,
      rel: 0, // Don't show related videos at the end
    },
  };

  return (
    <div className="sync-player-container">
      <YouTube
        videoId={videoId}
        opts={opts}
        onReady={onReady}
        onPlay={onPlay}
        onPause={onPause}
        className="sync-player"
        iframeClassName="sync-player-iframe"
      />

      {/* Click blocker overlay for students:
          When controls are hidden and the user is a student,
          a transparent div covers the player to prevent interaction,
          ensuring students can't desync from the teacher's playback. */}
      {!isTeacher && hideControls && (
        <div
          className="click-blocker-overlay"
          title="Synchronized playback — controlled by teacher"
          onClick={(e) => {
            e.preventDefault();
            e.stopPropagation();
          }}
        />
      )}
    </div>
  );
};
