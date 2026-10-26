'use client';

import type { CSSProperties, ReactNode } from 'react';

/**
 * Shared bits for the Creator Hub panels. Inline styles use the site's
 * CSS variables (globals.css) so the Hub follows the light/dark theme.
 * Buttons/chips reuse the global `.btn` / `.chip` classes (`.chip.active`
 * is the selected state in the Next shell; legacy used `.chip.on`).
 */

export const panelStyle: CSSProperties = {
  background: 'var(--surface)',
  border: '1px solid var(--line)',
  borderRadius: 16,
  padding: 22,
  marginTop: 18,
};

export const inputStyle: CSSProperties = {
  width: '100%',
  background: 'var(--surface)',
  border: '1px solid var(--line2)',
  color: 'var(--txt)',
  borderRadius: 10,
  padding: '12px 14px',
  font: 'inherit',
  fontSize: 15,
};

export const rowStyle: CSSProperties = {
  display: 'flex',
  gap: 10,
  marginTop: 12,
  flexWrap: 'wrap',
  alignItems: 'center',
};

export const outStyle: CSSProperties = {
  background: '#F7F8FC',
  border: '1px solid #ECECF1',
  borderRadius: 16,
  padding: 20,
  color: '#374151',
  fontSize: '0.93rem',
  lineHeight: 1.65,
  whiteSpace: 'pre-wrap',
  marginTop: 14,
};

export const errorStyle: CSSProperties = {
  marginTop: 14,
  padding: '13px 16px',
  borderRadius: 10,
  border: '1px solid rgba(248,113,113,.5)',
  background: 'rgba(248,113,113,.1)',
  color: 'var(--bad)',
  fontSize: '14.5px',
};

export const spinnerStyle: CSSProperties = {
  display: 'inline-block',
  width: 16,
  height: 16,
  border: '2px solid rgba(249,81,119,.25)',
  borderTopColor: '#F95177',
  borderRadius: '50%',
  animation: 'creator-spin 0.8s linear infinite',
  verticalAlign: '-3px',
  marginRight: 8,
};

export function Spinner() {
  return <span style={spinnerStyle} aria-hidden="true" />;
}

export function PanelShell(props: {
  title: string;
  desc: string;
  onBack: () => void;
  children: ReactNode;
}) {
  return (
    <div style={panelStyle}>
      <button
        type="button"
        className="btn btn-ghost btn-sm"
        onClick={props.onBack}
        style={{ marginBottom: 14 }}
      >
        ← Back to Creator Hub
      </button>
      <h3 style={{ margin: '0 0 6px', fontSize: '1.15rem' }}>{props.title}</h3>
      <p className="mut small" style={{ margin: '0 0 6px' }}>
        {props.desc}
      </p>
      {props.children}
    </div>
  );
}
