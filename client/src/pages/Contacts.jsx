import { useEffect, useState } from 'react';
import api, { getApiErrorMessage } from '../utils/api';

export default function Contacts() {
  const [contacts, setContacts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState({ full_name: '', email: '', phone: '', priority_order: 1 });

  const refresh = async () => {
    setLoading(true);
    setError('');
    try {
      const res = await api.get('/api/contacts');
      setContacts(res.data.contacts || []);
    } catch (e) {
      setError(getApiErrorMessage(e, 'Failed to load contacts.'));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { refresh(); }, []);

  const onChange = (e) => {
    const { name, value } = e.target;
    setForm((p) => ({ ...p, [name]: name === 'priority_order' ? Number(value) : value }));
  };

  const onCreate = async (e) => {
    e.preventDefault();
    setSaving(true);
    setError('');
    try {
      await api.post('/api/contacts', {
        ...form,
        phone: form.phone.trim() || null,
      });
      setForm({ full_name: '', email: '', phone: '', priority_order: 1 });
      await refresh();
    } catch (err) {
      setError(getApiErrorMessage(err, 'Failed to add contact.'));
    } finally {
      setSaving(false);
    }
  };

  const onDelete = async (c) => {
    if (!confirm(`Remove trusted contact "${c.full_name}"?`)) return;
    setError('');
    try {
      await api.delete(`/api/contacts/${c.contact_id}`);
      await refresh();
    } catch (err) {
      setError(getApiErrorMessage(err, 'Failed to remove contact.'));
    }
  };

  return (
    <>
      <style>{`
        @media (max-width: 767px) {
          .tc-root { padding: 16px 12px 24px !important; overflow: auto !important; }
          .tc-header { margin-bottom: 12px !important; align-items: center !important; min-height: 55px !important; box-sizing: border-box !important; }
          .tc-header h2 { font-size: clamp(15px, 4.3vw, 17px) !important; line-height: 1.25 !important; }
          .tc-grid { grid-template-columns: 1fr !important; gap: 12px !important; }
          .tc-section { padding: 14px 12px !important; border-radius: 10px !important; }
          .tc-input { padding: 10px 12px !important; font-size: 13px !important; border-radius: 8px !important; }
          .tc-label { font-size: 11px !important; margin-bottom: 4px !important; }
          .tc-btn { width: 100% !important; padding: 12px !important; font-size: 13px !important; border-radius: 10px !important; }
        }
      `}</style>

      <div className="tc-root" style={{ padding: '19px', fontFamily: "'Poppins', 'Inter', sans-serif", display: 'flex', flexDirection: 'column', minHeight: 0, height: '100%', overflow: 'hidden', boxSizing: 'border-box', background: '#F9FAFB' }}>
        <div className="tc-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px', flexShrink: 0, flexWrap: 'wrap', gap: '10px' }}>
          <div>
            <h2 style={{ margin: 0, fontSize: '18px', fontWeight: '600', color: '#333' }}>Trusted Contacts</h2>
            <p style={{ margin: '4px 0 0 0', fontSize: '11px', color: '#6B7280' }}>People who can verify after a trigger fires (quorum voting).</p>
          </div>
        </div>

        {error ? (
          <div style={{ background: '#FFF5F2', color: '#0A8C6D', padding: '8px 11px', borderRadius: '6px', marginBottom: '13px', fontSize: '10px', border: '1px solid #D9EFE7', flexShrink: 0 }}>
            {error}
          </div>
        ) : null}

        <div className="tc-grid" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', overflow: 'auto' }}>
          {/* Add form */}
          <div className="tc-section" style={{ background: '#FFFFFF', borderRadius: '10px', padding: '16px', boxShadow: '0 1px 3px rgba(0,0,0,0.05)' }}>
            <div style={{ fontSize: '11px', fontWeight: '600', color: '#0A8C6D', marginBottom: '13px', paddingBottom: '8px', borderBottom: '1px solid #e0e0e0' }}>Add trusted contact</div>
            <form onSubmit={onCreate} autoComplete="off">
              {[
                { key: 'full_name', label: 'Full name', type: 'text', placeholder: 'e.g., Ali Muhammad', required: true },
                { key: 'email', label: 'Email', type: 'email', placeholder: 'e.g., ali@email.com', required: true },
                { key: 'phone', label: 'Phone (optional)', type: 'text', placeholder: '+92 300 0000000', required: false },
              ].map((f) => (
                <div key={f.key} style={{ marginBottom: '12px' }}>
                  <label className="tc-label" style={{ display: 'block', fontSize: '10px', color: '#666', marginBottom: '3px', fontWeight: '500' }}>{f.label}{f.required ? <span style={{ color: '#0A8C6D' }}> *</span> : null}</label>
                  <input
                    className="tc-input"
                    type={f.type}
                    name={f.key}
                    value={form[f.key]}
                    onChange={onChange}
                    placeholder={f.placeholder}
                    required={f.required}
                    autoComplete="off"
                    style={{ width: '100%', padding: '6px 10px', borderRadius: '6px', border: '1px solid #e0e0e0', fontSize: '11px', outline: 'none', background: '#FFFFFF', boxSizing: 'border-box', fontFamily: 'inherit' }}
                  />
                </div>
              ))}

              <div style={{ marginBottom: '12px' }}>
                <label className="tc-label" style={{ display: 'block', fontSize: '10px', color: '#666', marginBottom: '3px', fontWeight: '500' }}>Priority order</label>
                <input
                  className="tc-input"
                  type="number"
                  min={1}
                  name="priority_order"
                  value={form.priority_order}
                  onChange={onChange}
                  autoComplete="off"
                  style={{ width: '100%', padding: '6px 10px', borderRadius: '6px', border: '1px solid #e0e0e0', fontSize: '11px', outline: 'none', background: '#FFFFFF', boxSizing: 'border-box', fontFamily: 'inherit' }}
                />
                <div style={{ marginTop: '6px', fontSize: '10px', color: '#6B7280' }}>Lower number = notified first.</div>
              </div>

              <button
                type="submit"
                className="tc-btn"
                disabled={saving}
                style={{ width: '100%', padding: '8px 16px', borderRadius: '6px', border: 'none', background: saving ? '#94A3B8' : '#0A8C6D', color: '#FFFFFF', fontSize: '11px', fontWeight: '600', cursor: saving ? 'not-allowed' : 'pointer' }}
              >
                {saving ? 'Adding…' : 'Add contact'}
              </button>
            </form>
          </div>

          {/* Contacts table */}
          <div className="tc-section" style={{ background: '#FFFFFF', borderRadius: '10px', padding: '16px', boxShadow: '0 1px 3px rgba(0,0,0,0.05)', overflow: 'hidden' }}>
            <div style={{ fontSize: '11px', fontWeight: '600', color: '#0A8C6D', marginBottom: '13px', paddingBottom: '8px', borderBottom: '1px solid #e0e0e0' }}>Your contacts</div>
            {loading ? (
              <div style={{ padding: '16px', textAlign: 'center', color: '#666', fontSize: '11px' }}>Loading…</div>
            ) : contacts.length === 0 ? (
              <div style={{ padding: '16px', textAlign: 'center', color: '#666', fontSize: '11px' }}>No contacts yet.</div>
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
                          <button className="tc-btn" onClick={() => onDelete(c)}
                            style={{ padding: '6px 13px', borderRadius: '6px', border: '1px solid #fca5a5', background: '#FEF2F2', color: '#B91C1C', fontSize: '11px', cursor: 'pointer', fontWeight: '600' }}>
                            Remove
                          </button>
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
    </>
  );
}

