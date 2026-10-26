'use client';

import { useState } from 'react';
import { apiErrorMessage, assembleVideoUrl, notify } from '../../lib/creator';
import { PanelShell, Spinner, errorStyle, inputStyle, rowStyle } from './shared';

/**
 * Story Video — 2–8 photos → free 9:16 MP4 (legacy storyVideoMake,
 * index.html:3676-3701). POST /api/v1/media/assemble-video as FormData
 * (`images`, `seconds_per_scene`, `captions` — keys verbatim from legacy)
 * DIRECT to API_BASE (not a proxy path). Response blob → inline video +
 * "Download MP4" (virello-story-video.mp4). Ken Burns motion, 9:16.
 */

export default function StoryVideo(props: { onBack: () => void }) {
  const [files, setFiles] = useState<File[]>([]);
  const [secs, setSecs] = useState('4');
  const [caps, setCaps] = useState('');
  const [busy, setBusy] = useState(false);
  const [videoUrl, setVideoUrl] = useState('');
  const [error, setError] = useState('');

  function onFiles(list: FileList | null) {
    const arr = list ? Array.from(list) : [];
    setFiles(arr);
    setVideoUrl('');
    setError('');
  }

  const listNote =
    files.length === 0
      ? ''
      : `${files.length} photo(s) selected — ${files.length < 2 || files.length > 8 ? 'need 2 to 8' : 'ready'}`;

  async function make() {
    if (files.length < 2 || files.length > 8) {
      notify('Choose 2 to 8 photos');
      return;
    }
    setBusy(true);
    setError('');
    setVideoUrl('');
    try {
      const fd = new FormData();
      files.forEach((f) => fd.append('images', f));
      fd.append('seconds_per_scene', secs);
      fd.append('captions', caps);
      const res = await fetch(assembleVideoUrl(), { method: 'POST', body: fd });
      if (!res.ok) {
        const j: unknown = await res.json().catch(() => ({}));
        throw new Error(apiErrorMessage(j, 'assembly failed'));
      }
      const blob = await res.blob();
      setVideoUrl(URL.createObjectURL(blob));
      notify('Your video is ready');
    } catch (e) {
      setError(
        `Video assembly failed — ${e instanceof Error ? e.message : 'please try again'}. Nothing fake was created.`,
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <PanelShell
      title="Story Video"
      desc="2 se 8 photos upload karo — free mein asal 9:16 MP4 video ban jayegi (Ken Burns motion + captions)."
      onBack={props.onBack}
    >
      <div style={rowStyle}>
        <label className="btn btn-ghost btn-sm" style={{ cursor: 'pointer' }}>
          Choose Photos (2-8)
          <input
            type="file"
            accept="image/*"
            multiple
            style={{ display: 'none' }}
            onChange={(e) => onFiles(e.target.files)}
          />
        </label>
        <select
          value={secs}
          onChange={(e) => setSecs(e.target.value)}
          style={{ ...inputStyle, width: 'auto' }}
          aria-label="Seconds per photo"
        >
          <option value="3">3s per photo</option>
          <option value="4">4s per photo</option>
          <option value="5">5s per photo</option>
          <option value="6">6s per photo</option>
        </select>
      </div>
      <div style={rowStyle}>
        <input
          value={caps}
          onChange={(e) => setCaps(e.target.value)}
          placeholder="Captions, one per line (optional)"
          style={{ ...inputStyle, flex: 1, minWidth: 220 }}
        />
      </div>
      {listNote !== '' && (
        <div className="tiny mut" style={{ marginTop: 8 }}>
          {listNote}
        </div>
      )}
      <div style={rowStyle}>
        <button
          type="button"
          className="btn btn-grad"
          onClick={() => void make()}
          disabled={busy}
        >
          {busy ? 'Building your video… (up to a minute)' : 'Create MP4 Video'}
        </button>
      </div>

      {busy && (
        <div style={{ marginTop: 14 }}>
          <Spinner />
          <b style={{ color: 'var(--txt)' }}>Assembling MP4 on our server…</b>
          <p style={{ margin: '8px 0 0', fontSize: '0.85rem' }}>
            Free — Ken Burns motion, 9:16 vertical.
          </p>
        </div>
      )}

      {error !== '' && (
        <div style={errorStyle} role="alert">
          {error}
        </div>
      )}

      {videoUrl !== '' && (
        <div style={{ marginTop: 14 }}>
          <video
            src={videoUrl}
            controls
            style={{
              width: '100%',
              maxWidth: 340,
              borderRadius: 14,
              display: 'block',
              background: '#000',
            }}
          />
          <div style={rowStyle}>
            <a
              href={videoUrl}
              download="virello-story-video.mp4"
              className="btn btn-grad btn-sm"
              style={{ textDecoration: 'none' }}
            >
              Download MP4
            </a>
          </div>
        </div>
      )}
    </PanelShell>
  );
}
