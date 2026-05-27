/**
 * ScheduleView Excerpt — React/TypeScript Frontend Component
 * Demonstrates role-based URL resolution for Zoom API meetings,
 * automatically routing instructors/admins to the host 'start_url'
 * while routing students to the attendee 'join_url'.
 */

import React, { useState } from 'react';
import type { VideoClass } from '../types/types';

interface ScheduleViewProps {
  classes: VideoClass[];
  role?: 'admin' | 'teacher' | 'student' | null;
  onEdit?: (cls: VideoClass) => void;
  onDelete?: (id: string) => void;
}

const ScheduleView: React.FC<ScheduleViewProps> = ({ 
  classes, 
  role = 'student', 
  onEdit, 
  onDelete 
}) => {
  const [viewDate, setViewDate] = useState(new Date());
  const [viewMode, setViewMode] = useState<'calendar' | 'table'>('calendar');

  /**
   * Safe Zoom / External URL Resolution
   * Bypasses the need for complex server-side session mappings by storing both the
   * join_url (students) and start_url (instructor, containing host token) in a single
   * database field (external_url) serialized as JSON for Zoom meetings.
   */
  const getZoomOrExternalUrl = (cls: VideoClass) => {
    if (!cls.external_url) return '';
    
    if (cls.platform === 'zoom') {
      try {
        const parsed = JSON.parse(cls.external_url);
        if (parsed.join_url || parsed.start_url) {
          // Instructors/Admins get the start_url to take ownership as host, students get the standard join_url
          return (role === 'admin' || role === 'teacher')
            ? (parsed.start_url || parsed.join_url)
            : (parsed.join_url || parsed.start_url);
        }
      } catch (e) {
        // Fallback for custom user-provided URL strings
        return cls.external_url;
      }
    }
    return cls.external_url;
  };

  const handleJoinClass = (cls: VideoClass) => {
    if (cls.platform && cls.platform !== 'jitsi') {
      const targetUrl = getZoomOrExternalUrl(cls);
      if (targetUrl) {
        window.open(targetUrl, '_blank', 'noopener,noreferrer');
      } else {
        alert('Посилання відсутнє (Link not found).');
      }
    } else {
      // Handle standard Jitsi in-app video calls
      window.location.href = `/video-class?roomId=${cls.room_id}`;
    }
  };

  // ... (calendar grid generation, date filtering, and table formatting omitted for brevity) ...

  return (
    <div className="bg-white dark:bg-slate-900 border border-slate-200 rounded-3xl p-6">
      <div className="flex justify-between items-center mb-6">
        <h3 className="text-xl font-bold">Розклад занять (Schedule)</h3>
        <div className="flex gap-2">
          <button 
            onClick={() => setViewMode('calendar')}
            className={`px-4 py-2 rounded-xl text-xs font-bold ${viewMode === 'calendar' ? 'bg-[#0052CC] text-white' : 'bg-slate-100'}`}
          >
            Календар (Calendar)
          </button>
          <button 
            onClick={() => setViewMode('table')}
            className={`px-4 py-2 rounded-xl text-xs font-bold ${viewMode === 'table' ? 'bg-[#0052CC] text-white' : 'bg-slate-100'}`}
          >
            Список (List)
          </button>
        </div>
      </div>

      {viewMode === 'table' ? (
        <div className="flex flex-col gap-4">
          {classes.map(cls => (
            <div key={cls.id} className="p-4 border rounded-2xl flex justify-between items-center hover:bg-slate-50 transition-all">
              <div>
                <h4 className="font-extrabold text-slate-800">{cls.title}</h4>
                <span className="text-xs text-slate-500">{cls.start_time} • {cls.duration} хв</span>
              </div>
              <div className="flex gap-2">
                {role === 'admin' && (
                  <button onClick={() => onEdit?.(cls)} className="p-2 bg-amber-50 text-amber-600 rounded-xl hover:bg-amber-100">Редагувати</button>
                )}
                <button 
                  onClick={() => handleJoinClass(cls)}
                  className="px-6 py-2 bg-[#0052CC] hover:bg-[#0066FF] text-white text-xs font-bold rounded-xl shadow-md transition-all"
                >
                  Приєднатися (Join)
                </button>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div>{/* Calendar Component Grid View */}</div>
      )}
    </div>
  );
};

export default ScheduleView;
