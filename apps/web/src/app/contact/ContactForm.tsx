'use client';

import { useState } from 'react';
import type { FormEvent } from 'react';

const CONTACT_EMAIL = 'privacy@virelloai.online';

const CATEGORIES = [
  'General question',
  'Account & login',
  'Billing & payments',
  'Campaigns & AI growth',
  'Partnerships',
  'Press',
  'Report a safety issue',
];

export default function ContactForm() {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [category, setCategory] = useState(CATEGORIES[0]);
  const [subject, setSubject] = useState('');
  const [message, setMessage] = useState('');

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const mailSubject = `[${category}] ${subject}`;
    const body = [
      `Name: ${name}`,
      `Email: ${email}`,
      `Category: ${category}`,
      '',
      message,
    ].join('\n');
    window.location.href = `mailto:${CONTACT_EMAIL}?subject=${encodeURIComponent(
      mailSubject,
    )}&body=${encodeURIComponent(body)}`;
  }

  return (
    <div className="card">
      <h3 style={{ fontSize: 21, marginBottom: 4 }}>Send a message</h3>
      <p className="mut small" style={{ marginBottom: 22 }}>
        Fill this in — we&apos;ll prepare a ready-to-send message you can open in
        your email app.
      </p>
      <form onSubmit={handleSubmit}>
        <div className="grid grid-2" style={{ gap: 14 }}>
          <div className="field">
            <label htmlFor="cName">Your name</label>
            <input
              id="cName"
              required
              placeholder="Full name"
              value={name}
              onChange={(e) => setName(e.target.value)}
            />
          </div>
          <div className="field">
            <label htmlFor="cEmail">Email</label>
            <input
              id="cEmail"
              type="email"
              required
              placeholder="you@example.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
          </div>
        </div>
        <div className="field">
          <label htmlFor="cCat">Category</label>
          <select
            id="cCat"
            value={category}
            onChange={(e) => setCategory(e.target.value)}
          >
            {CATEGORIES.map((c) => (
              <option key={c} value={c}>
                {c}
              </option>
            ))}
          </select>
        </div>
        <div className="field">
          <label htmlFor="cSubject">Subject</label>
          <input
            id="cSubject"
            required
            placeholder="How can we help?"
            value={subject}
            onChange={(e) => setSubject(e.target.value)}
          />
        </div>
        <div className="field">
          <label htmlFor="cMsg">Message</label>
          <textarea
            id="cMsg"
            rows={5}
            required
            placeholder="Write your message…"
            value={message}
            onChange={(e) => setMessage(e.target.value)}
          />
        </div>
        <button className="btn btn-grad" type="submit" style={{ width: '100%' }}>
          Send Message
        </button>
      </form>
      <p className="small mut" style={{ marginTop: 14 }}>
        Prefer to write directly? Email us at{' '}
        <a
          href={`mailto:${CONTACT_EMAIL}`}
          style={{ color: 'var(--pink)', fontWeight: 600 }}
        >
          {CONTACT_EMAIL}
        </a>
      </p>
    </div>
  );
}
