import { useEffect, useState } from 'react';
import api, { getApiErrorMessage } from '../utils/api';

const inputStyle = {
  width: '100%', padding: '6px 10px', borderRadius: '6px',
  border: '1px solid #e0e0e0', fontSize: '11px', outline: 'none',
  background: '#FFFFFF', boxSizing: 'border-box', fontFamily: 'inherit',
};

const labelStyle = {
  display: 'block', fontSize: '10px', color: '#666',
  marginBottom: '3px', fontWeight: '500',
};

const cardStyle = {
  background: '#FFFFFF', borderRadius: '10px', padding: '16px',
  marginBottom: '16px', boxShadow: '0 1px 3px rgba(0,0,0,0.05)',
};

const sectionTitle = {
  fontSize: '11px', fontWeight: '600', color: '#0A8C6D',
  marginBottom: '13px', paddingBottom: '8px',
  borderBottom: '1px solid #e0e0e0',
};

const btnPrimary = (disabled = false) => ({
  padding: '8px 16px', borderRadius: '6px', border: 'none',
  background: disabled ? '#94A3B8' : '#0A8C6D', color: '#FFFFFF',
  fontSize: '11px', fontWeight: '600',
  cursor: disabled ? 'not-allowed' : 'pointer',
});

const btnGhost = {
  padding: '6px 13px', borderRadius: '6px', border: '1px solid #e0e0e0',
  background: '#FFFFFF', color: '#666', fontSize: '11px',
  cursor: 'pointer', fontWeight: '600',
};

const btnDanger = {
  padding: '6px 13px', borderRadius: '6px', border: '1px solid #fca5a5',
  background: '#FEF2F2', color: '#B91C1C', fontSize: '11px',
  cursor: 'pointer', fontWeight: '600',
};

const ruleNumberBadge = {
  display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
  width: '20px', height: '20px', borderRadius: '50%',
  background: '#0A8C6D', color: '#FFFFFF', fontSize: '10px',
  fontWeight: '700', marginRight: '8px',
};

export default function Contacts() {
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const [contacts, setContacts] = useState([]);
  const [contactForm, setContactForm] = useState({ full_name: '', email: '', phone: '', priority_order: 1 });
  const [savingContact, setSavingContact] = useState(false);

  const [quorum, setQuorum] = useState({ quorum_required: 2, grace_period_days: 7 });
  const [savingQuorum, setSavingQuorum] = useState(false);

  const [inactivity, setInactivity] = useState({ inactivity_days: 60, grace_period_days: 7 });
  const [reminders, setReminders] = useState([]);
  const [savingInactivity, setSavingInactivity] = useState(false);

  const refresh = async () => {
    setError('');
    try {
      const [contactsRes, rulesRes] = await Promise.all([
        api.get('/api/contacts'),
        api.get('/api/death-rules'),
      ]);
      setContacts(contactsRes.data.contacts || []);
      const r = rulesRes.data || {};
      setInactivity({
        inactivity_days: Number(r.inactivity?.inactivity_days ?? 60),
        grace_period_days: Number(r.inactivity?.grace_period_days ?? 7),
      });
      setQuorum({
        quorum_required: Number(r.quorum?.quorum_required ?? 2),
        grace_period_days: Number(r.quorum?.grace_period_days ?? 7),
      });
      setReminders(
        (r.reminders || []).map((x) => ({
          threshold_percent: Number(x.threshold_percent),
          custom_message: x.custom_message || '',
        })),
      );
    } catch (e) {
      setError(getApiErrorMessage(e, 'Failed to load death rules.'));
    }
  };

  useEffect(() => { refresh(); }, []);

  const onContactChange = (e) => {
    const { name, value } = e.target;
    setContactForm((p) => ({ ...p, [name]: name === 'priority_order' ? Number(value) : value }));
  };

  const onCreateContact = async (e) => {
    e.preventDefault();
    setSavingContact(true);
    setError('');
    setSuccess('');
    try {
      await api.post('/api/contacts', {
        ...contactForm,
        phone: contactForm.phone.trim() || null,
      });
      setContactForm({ full_name: '', email: '', phone: '', priority_order: 1 });
      setSuccess('Trusted contact added.');
      await refresh();
    } catch (err) {
      setError(getApiErrorMessage(err, 'Failed to add contact.'));
    } finally {
      setSavingContact(false);
    }
  };

  const onDeleteContact = async (c) => {
    if (!confirm(`Remove trusted contact "${c.full_name}"?`)) return;
    setError('');
    try {
      await api.delete(`/api/contacts/${c.contact_id}`);
      await refresh();
    } catch (err) {
      setError(getApiErrorMessage(err, 'Failed to remove contact.'));
    }
  };

  const onSaveQuorum = async (e) => {
    e.preventDefault();
    setError('');
    setSuccess('');
    setSavingQuorum(true);
    try {
      await api.put('/api/death-rules/quorum', {
        quorum_required: Number(quorum.quorum_required),
        grace_period_days: Number(quorum.grace_period_days),
      });
      setSuccess('Trusted-contacts rule saved.');
      await refresh();
    } catch (err) {
      setError(getApiErrorMessage(err, 'Failed to save trusted-contacts rule.'));
    } finally {
      setSavingQuorum(false);
    }
  };

  const onSaveInactivity = async (e) => {
    e.preventDefault();
    setError('');
    setSuccess('');
    for (const r of reminders) {
      const p = Number(r.threshold_percent);
      if (!Number.isFinite(p) || p < 1 || p > 99) {
        setError('Each reminder threshold must be between 1 and 99 percent.');
        return;
      }
    }
    setSavingInactivity(true);
    try {
      await api.put('/api/death-rules/inactivity', {
        inactivity_days: Number(inactivity.inactivity_days),
        grace_period_days: Number(inactivity.grace_period_days),
        reminders: reminders.map((r) => ({
          threshold_percent: Number(r.threshold_percent),
          custom_message: r.custom_message || null,
        })),
      });
      setSuccess('Inactivity rule saved.');
      await refresh();
    } catch (err) {
      setError(getApiErrorMessage(err, 'Failed to save inactivity rule.'));
    } finally {
      setSavingInactivity(false);
    }
  };

  const addReminder = () => {
    setReminders((prev) => [...prev, { threshold_percent: 50, custom_message: '' }]);
  };

  const updateReminder = (idx, key, val) => {
    setReminders((prev) => prev.map((r, i) => (i === idx ? { ...r, [key]: val } : r)));
  };

  const removeReminder = (idx) => {
    setReminders((prev) => prev.filter((_, i) => i !== idx));
  };

  return (
    <>
      <style>{`
        @media (max-width: 767px) {
          .dr-root { padding: 16px 12px 24px !important; overflow: auto !important; }
          .dr-header h2 { font-size: clamp(15px, 4.3vw, 17px) !important; }
          .dr-grid { grid-template-columns: 1fr !important; gap: 12px !important; }
          .dr-input { padding: 10px 12px !important; font-size: 13px !important; }
          .dr-btn { width: 100% !important; padding: 12px !important; font-size: 13px !important; }
        }
      `}</style>

      <div className="dr-root" style={{ padding: '19px', fontFamily: "'Poppins', 'Inter', sans-serif", display: 'flex', flexDirection: 'column', minHeight: 0, height: '100%', overflow: 'auto', boxSizing: 'border-box', background: '#F9FAFB' }}>
        <div className="dr-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px', flexShrink: 0, flexWrap: 'wrap', gap: '10px' }}>
          <div>
            <h2 style={{ margin: 0, fontSize: '18px', fontWeight: '600', color: '#333' }}>Manage Death Rules</h2>
            <p style={{ margin: '4px 0 0 0', fontSize: '11px', color: '#6B7280' }}>Configure the conditions that initiate posthumous execution of your digital estate.</p>
          </div>
        </div>

        {error ? (
          <div style={{ background: '#FEF2F2', color: '#B91C1C', padding: '8px 11px', borderRadius: '6px', marginBottom: '13px', fontSize: '10px', border: '1px solid #FECACA', flexShrink: 0 }}>
            {error}
          </div>
        ) : null}
        {success ? (
          <div style={{ background: '#F0FDF4', color: '#166534', padding: '8px 11px', borderRadius: '6px', marginBottom: '13px', fontSize: '10px', border: '1px solid #BBF7D0', flexShrink: 0 }}>
            {success}
          </div>
        ) : null}

        {/* ============= RULE 1: TRUSTED CONTACTS ============= */}
        <div style={cardStyle}>
          <div style={{ ...sectionTitle, display: 'flex', alignItems: 'center' }}>
            <span style={ruleNumberBadge}>1</span>
            Trusted Contacts (Quorum vote)
          </div>

          <div className="dr-grid" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
            <div>
              <form onSubmit={onCreateContact} autoComplete="off">
                {[
                  { key: 'full_name', label: 'Full name', type: 'text', placeholder: 'e.g., Ali Muhammad', required: true },
                  { key: 'email', label: 'Email', type: 'email', placeholder: 'e.g., ali@email.com', required: true },
                  { key: 'phone', label: 'Phone (optional)', type: 'text', placeholder: '+92 300 0000000', required: false },
                ].map((f) => (
                  <div key={f.key} style={{ marginBottom: '10px' }}>
                    <label style={labelStyle}>{f.label}{f.required ? <span style={{ color: '#0A8C6D' }}> *</span> : null}</label>
                    <input
                      className="dr-input"
                      type={f.type}
                      name={f.key}
                      value={contactForm[f.key]}
                      onChange={onContactChange}
                      placeholder={f.placeholder}
                      required={f.required}
                      autoComplete="off"
                      style={inputStyle}
                    />
                  </div>
                ))}
                <div style={{ marginBottom: '10px' }}>
                  <label style={labelStyle}>Priority order</label>
                  <input
                    className="dr-input"
                    type="number"
                    min={1}
                    name="priority_order"
                    value={contactForm.priority_order}
                    onChange={onContactChange}
                    autoComplete="off"
                    style={inputStyle}
                  />
                  <div style={{ marginTop: '4px', fontSize: '10px', color: '#6B7280' }}>Lower number = notified first.</div>
                </div>

                <button type="submit" className="dr-btn" disabled={savingContact} style={btnPrimary(savingContact)}>
                  {savingContact ? 'Adding…' : 'Add trusted contact'}
                </button>
              </form>

              <div style={{ height: '1px', background: '#e5e7eb', margin: '14px 0' }} />

              <form onSubmit={onSaveQuorum} autoComplete="off">
                <div style={{ marginBottom: '10px' }}>
                  <label style={labelStyle}>Quorum required (# contacts who must confirm)</label>
                  <input
                    className="dr-input"
                    type="number" min={1} max={50}
                    value={quorum.quorum_required}
                    onChange={(e) => setQuorum((p) => ({ ...p, quorum_required: Number(e.target.value) }))}
                    autoComplete="off"
                    style={inputStyle}
                  />
                </div>
                <div style={{ marginBottom: '10px' }}>
                  <label style={labelStyle}>Grace period after confirmation (days)</label>
                  <input
                    className="dr-input"
                    type="number" min={1} max={3650}
                    value={quorum.grace_period_days}
                    onChange={(e) => setQuorum((p) => ({ ...p, grace_period_days: Number(e.target.value) }))}
                    autoComplete="off"
                    style={inputStyle}
                  />
                </div>
                <button type="submit" className="dr-btn" disabled={savingQuorum} style={btnPrimary(savingQuorum)}>
                  {savingQuorum ? 'Saving…' : 'Save trusted-contacts rule'}
                </button>
              </form>
            </div>

            <div>
              <div style={{ fontSize: '11px', fontWeight: '600', color: '#374151', marginBottom: '8px' }}>Your contacts</div>
              {contacts.length === 0 ? (
                <div style={{ padding: '16px', textAlign: 'center', color: '#666', fontSize: '11px', border: '1px dashed #e5e7eb', borderRadius: '8px' }}>No contacts yet.</div>
              ) : (
                <div style={{ overflow: 'auto', border: '1px solid #e0e0e0', borderRadius: '8px' }}>
                  <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '10px', whiteSpace: 'nowrap' }}>
                    <thead>
                      <tr style={{ background: '#fafafa' }}>
                        <th style={{ padding: '10px 8px', textAlign: 'left', fontWeight: '600', color: '#333', borderBottom: '2px solid #e0e0e0' }}>Name</th>
                        <th style={{ padding: '10px 8px', textAlign: 'left', fontWeight: '600', color: '#333', borderBottom: '2px solid #e0e0e0' }}>Email</th>
                        <th style={{ padding: '10px 8px', textAlign: 'left', fontWeight: '600', color: '#333', borderBottom: '2px solid #e0e0e0' }}>Priority</th>
                        <th style={{ padding: '10px 8px', textAlign: 'left', fontWeight: '600', color: '#333', borderBottom: '2px solid #e0e0e0' }}>Status</th>
                        <th style={{ padding: '10px 8px', textAlign: 'right', fontWeight: '600', color: '#333', borderBottom: '2px solid #e0e0e0' }}>Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      {contacts.map((c) => (
                        <tr key={c.contact_id} style={{ borderBottom: '1px solid #eee' }}>
                          <td style={{ padding: '8px', fontWeight: 600 }}>{c.full_name}</td>
                          <td style={{ padding: '8px', color: '#6B7280' }}>{c.email}</td>
                          <td style={{ padding: '8px' }}>{c.priority_order}</td>
                          <td style={{ padding: '8px' }}><span className="pill">{c.verification_status}</span></td>
                          <td style={{ padding: '8px', textAlign: 'right' }}>
                            <button onClick={() => onDeleteContact(c)} style={btnDanger}>Remove</button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* ============= RULE 2: INACTIVITY ============= */}
        <div style={cardStyle}>
          <div style={{ ...sectionTitle, display: 'flex', alignItems: 'center' }}>
            <span style={ruleNumberBadge}>2</span>
            Inactivity
          </div>

          <form onSubmit={onSaveInactivity} autoComplete="off">
            <div className="dr-grid" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
              <div>
                <label style={labelStyle}>Pronounce me dead after (days)</label>
                <input
                  className="dr-input"
                  type="number" min={7} max={3650}
                  value={inactivity.inactivity_days}
                  onChange={(e) => setInactivity((p) => ({ ...p, inactivity_days: Number(e.target.value) }))}
                  autoComplete="off"
                  style={inputStyle}
                />
                <div style={{ marginTop: '4px', fontSize: '10px', color: '#6B7280' }}>
                  Number of inactive days before the system flags the account as suspected deceased.
                </div>
              </div>
              <div>
                <label style={labelStyle}>Grace period (days)</label>
                <input
                  className="dr-input"
                  type="number" min={1} max={3650}
                  value={inactivity.grace_period_days}
                  onChange={(e) => setInactivity((p) => ({ ...p, grace_period_days: Number(e.target.value) }))}
                  autoComplete="off"
                  style={inputStyle}
                />
                <div style={{ marginTop: '4px', fontSize: '10px', color: '#6B7280' }}>
                  Time to log in and reverse the flag before execution begins.
                </div>
              </div>
            </div>

            <div style={{ height: '1px', background: '#e5e7eb', margin: '14px 0' }} />

            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '8px' }}>
              <div style={{ fontSize: '11px', fontWeight: '600', color: '#374151' }}>Reminders</div>
              <button type="button" onClick={addReminder} style={btnGhost}>+ Add reminder</button>
            </div>
            <div style={{ fontSize: '10px', color: '#6B7280', marginBottom: '10px' }}>
              Reminders fire when this percent of your "pronounce dead" threshold has been consumed by inactivity. Each one fires only once.
            </div>

            {reminders.length === 0 ? (
              <div style={{ padding: '16px', textAlign: 'center', color: '#666', fontSize: '11px', border: '1px dashed #e5e7eb', borderRadius: '8px', marginBottom: '12px' }}>
                No reminders yet. Click "Add reminder" to create one.
              </div>
            ) : (
              reminders.map((r, idx) => (
                <div key={idx} style={{ display: 'grid', gridTemplateColumns: '120px 1fr auto', gap: '10px', alignItems: 'end', marginBottom: '10px', padding: '10px', border: '1px solid #e5e7eb', borderRadius: '8px', background: '#FAFBFC' }}>
                  <div>
                    <label style={labelStyle}>Threshold (%)</label>
                    <input
                      className="dr-input"
                      type="number" min={1} max={99}
                      value={r.threshold_percent}
                      onChange={(e) => updateReminder(idx, 'threshold_percent', Number(e.target.value))}
                      style={inputStyle}
                    />
                  </div>
                  <div>
                    <label style={labelStyle}>Custom message (optional)</label>
                    <input
                      className="dr-input"
                      type="text"
                      value={r.custom_message}
                      onChange={(e) => updateReminder(idx, 'custom_message', e.target.value)}
                      placeholder="e.g., We miss you — please log in to confirm you are okay."
                      style={inputStyle}
                    />
                  </div>
                  <div>
                    <button type="button" onClick={() => removeReminder(idx)} style={btnDanger}>Remove</button>
                  </div>
                </div>
              ))
            )}

            <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
              <button type="submit" className="dr-btn" disabled={savingInactivity} style={btnPrimary(savingInactivity)}>
                {savingInactivity ? 'Saving…' : 'Save inactivity rule'}
              </button>
            </div>
          </form>
        </div>
      </div>
    </>
  );
}
