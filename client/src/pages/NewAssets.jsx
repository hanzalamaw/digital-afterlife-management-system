import { useState } from 'react';
import api, { getApiErrorMessage } from '../utils/api';

const ASSET_TYPES = [
  { value: 'bank_account', label: 'Bank account' },
  { value: 'crypto_wallet', label: 'Crypto wallet' },
  { value: 'social_media', label: 'Social media' },
  { value: 'email', label: 'Email' },
  { value: 'file_storage', label: 'File storage' },
  { value: 'subscription', label: 'Subscription' },
  { value: 'domain', label: 'Domain' },
  { value: 'other', label: 'Other' },
];

const emptyVault = { field_name: '', encrypted_value: '' };
const emptyBeneficiary = {
  full_name: '',
  email: '',
  phone: '',
  relationship: '',
  share_percentage: 100,
  notification_method: 'email',
  special_instructions: '',
};

const splitSharesEqually = (list) => {
  const n = list.length;
  if (n === 0) return list;
  const base = Math.floor((100 / n) * 100) / 100;
  const remainder = +(100 - base * (n - 1)).toFixed(2);
  return list.map((b, i) => ({
    ...b,
    share_percentage: i === n - 1 ? remainder : base,
  }));
};

export default function NewAssets() {
  const [form, setForm] = useState({
    asset_name: '',
    asset_type: 'email',
    description: '',
    instructions: '',
    require_contact_verify: true,
    include_in_estate: true,
  });
  const [vaultEntries, setVaultEntries] = useState([{ ...emptyVault }]);
  const [beneficiaries, setBeneficiaries] = useState([{ ...emptyBeneficiary, share_percentage: 100 }]);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [saving, setSaving] = useState(false);

  const setVaultField = (index, key, value) => {
    setVaultEntries((prev) => prev.map((entry, i) => (i === index ? { ...entry, [key]: value } : entry)));
  };

  const setBeneficiaryField = (index, key, value) => {
    setBeneficiaries((prev) => prev.map((entry, i) => (i === index ? { ...entry, [key]: value } : entry)));
  };

  const addBeneficiary = () => {
    setBeneficiaries((prev) => splitSharesEqually([...prev, { ...emptyBeneficiary }]));
  };

  const removeLastBeneficiary = () => {
    setBeneficiaries((prev) => {
      if (prev.length <= 1) return prev;
      return splitSharesEqually(prev.slice(0, -1));
    });
  };

  const shareTotalNow = beneficiaries
    .filter((b) => b.full_name.trim() && b.email.trim())
    .reduce((s, b) => s + Number(b.share_percentage || 0), 0);

  const onSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setSuccess('');

    const validVault = vaultEntries.filter((v) => v.field_name.trim() && v.encrypted_value.trim());
    const validBeneficiaries = beneficiaries.filter((b) => b.full_name.trim() && b.email.trim());

    if (validBeneficiaries.length > 0) {
      const total = validBeneficiaries.reduce((sum, b) => sum + Number(b.share_percentage || 0), 0);
      if (Math.abs(total - 100) > 0.01) {
        setError(`Beneficiary shares must total exactly 100% (currently ${total.toFixed(2)}%). Adjust and try again.`);
        return;
      }
    }

    setSaving(true);
    try {
      await api.post('/api/assets', {
        ...form,
        description: form.description.trim() || null,
        instructions: form.instructions.trim() || null,
        vault_entries: validVault.map((v) => ({
          field_name: v.field_name.trim(),
          encrypted_value: v.encrypted_value.trim(),
        })),
        beneficiaries: validBeneficiaries.map((b) => ({
          full_name: b.full_name.trim(),
          email: b.email.trim(),
          phone: b.phone.trim() || null,
          relationship: b.relationship.trim() || null,
          share_percentage: Number(b.share_percentage || 0),
          notification_method: b.notification_method,
          special_instructions: b.special_instructions.trim() || null,
        })),
      });

      setForm({
        asset_name: '',
        asset_type: 'email',
        description: '',
        instructions: '',
        require_contact_verify: true,
        include_in_estate: true,
      });
      setVaultEntries([{ ...emptyVault }]);
      setBeneficiaries([{ ...emptyBeneficiary, share_percentage: 100 }]);
      setSuccess('Asset created with vault and beneficiary details.');
    } catch (err) {
      setError(getApiErrorMessage(err, 'Failed to create asset.'));
    } finally {
      setSaving(false);
    }
  };

  const sharesOk = beneficiaries.filter((b) => b.full_name.trim() && b.email.trim()).length === 0
    || Math.abs(shareTotalNow - 100) < 0.01;

  return (
    <>
      <style>{`
        @media (max-width: 767px) {
          .na-root { padding: 16px 12px 24px !important; overflow: auto !important; }
          .na-header { margin-bottom: 12px !important; align-items: center !important; min-height: 55px !important; box-sizing: border-box !important; }
          .na-header h2 { font-size: clamp(15px, 4.3vw, 17px) !important; line-height: 1.25 !important; }
          .na-section { padding: 14px 12px !important; margin-bottom: 12px !important; border-radius: 10px !important; }
          .na-grid-2 { grid-template-columns: 1fr !important; gap: 10px !important; }
          .na-grid-3 { grid-template-columns: 1fr !important; gap: 10px !important; }
          .na-input { padding: 10px 12px !important; font-size: 13px !important; border-radius: 8px !important; }
          .na-label { font-size: 11px !important; margin-bottom: 4px !important; }
          .na-actions { flex-direction: column !important; gap: 8px !important; }
          .na-btn { width: 100% !important; padding: 12px !important; font-size: 13px !important; border-radius: 10px !important; }
        }
      `}</style>

      <div className="na-root" style={{ padding: '19px', fontFamily: "'Poppins', 'Inter', sans-serif", display: 'flex', flexDirection: 'column', minHeight: 0, height: '100%', overflow: 'hidden', boxSizing: 'border-box', background: '#F9FAFB' }}>
        <div className="na-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px', flexShrink: 0, flexWrap: 'wrap', gap: '10px' }}>
          <div>
            <h2 style={{ margin: 0, fontSize: '18px', fontWeight: '600', color: '#333' }}>New Asset</h2>
            <p style={{ margin: '4px 0 0 0', fontSize: '11px', color: '#6B7280' }}>Create an asset and save vault + beneficiaries.</p>
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

        <form onSubmit={onSubmit} style={{ overflow: 'auto' }} autoComplete="off">
          <div className="na-section" style={{ background: '#FFFFFF', borderRadius: '10px', padding: '16px', marginBottom: '16px', boxShadow: '0 1px 3px rgba(0,0,0,0.05)' }}>
            <div style={{ fontSize: '11px', fontWeight: '600', color: '#0A8C6D', marginBottom: '13px', paddingBottom: '8px', borderBottom: '1px solid #e0e0e0' }}>Asset Information</div>

            <div className="na-grid-2" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '13px' }}>
              <div>
                <label className="na-label" style={{ display: 'block', fontSize: '10px', color: '#666', marginBottom: '3px', fontWeight: '500' }}>Asset name <span style={{ color: '#0A8C6D' }}>*</span></label>
                <input className="na-input" name="asset_name" value={form.asset_name} onChange={(e) => setForm((p) => ({ ...p, asset_name: e.target.value }))} required
                  autoComplete="off"
                  style={{ width: '100%', padding: '6px 10px', borderRadius: '6px', border: '1px solid #e0e0e0', fontSize: '11px', outline: 'none', background: '#FFFFFF', boxSizing: 'border-box', fontFamily: 'inherit' }} />
              </div>
              <div>
                <label className="na-label" style={{ display: 'block', fontSize: '10px', color: '#666', marginBottom: '3px', fontWeight: '500' }}>Asset type <span style={{ color: '#0A8C6D' }}>*</span></label>
                <select className="na-input" name="asset_type" value={form.asset_type} onChange={(e) => setForm((p) => ({ ...p, asset_type: e.target.value }))} required
                  autoComplete="off"
                  style={{ width: '100%', padding: '6px 10px', borderRadius: '6px', border: '1px solid #e0e0e0', fontSize: '11px', outline: 'none', background: '#FFFFFF', boxSizing: 'border-box', fontFamily: 'inherit' }}>
                  {ASSET_TYPES.map((t) => <option key={t.value} value={t.value}>{t.label}</option>)}
                </select>
              </div>
              <div>
                <label className="na-label" style={{ display: 'block', fontSize: '10px', color: '#666', marginBottom: '3px', fontWeight: '500' }}>Description</label>
                <input className="na-input" name="description" value={form.description} onChange={(e) => setForm((p) => ({ ...p, description: e.target.value }))} placeholder="Optional"
                  autoComplete="off"
                  style={{ width: '100%', padding: '6px 10px', borderRadius: '6px', border: '1px solid #e0e0e0', fontSize: '11px', outline: 'none', background: '#FFFFFF', boxSizing: 'border-box', fontFamily: 'inherit' }} />
              </div>
              <div>
                <label className="na-label" style={{ display: 'block', fontSize: '10px', color: '#666', marginBottom: '3px', fontWeight: '500' }}>Instructions</label>
                <input className="na-input" name="instructions" value={form.instructions} onChange={(e) => setForm((p) => ({ ...p, instructions: e.target.value }))} placeholder="Optional"
                  autoComplete="off"
                  style={{ width: '100%', padding: '6px 10px', borderRadius: '6px', border: '1px solid #e0e0e0', fontSize: '11px', outline: 'none', background: '#FFFFFF', boxSizing: 'border-box', fontFamily: 'inherit' }} />
              </div>
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginTop: '12px', flexWrap: 'wrap' }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '11px', color: '#666' }}>
                <input type="checkbox" checked={form.require_contact_verify} onChange={(e) => setForm((p) => ({ ...p, require_contact_verify: e.target.checked }))} style={{ width: 14, height: 14, accentColor: '#0A8C6D' }} />
                Require contact verification
              </label>
              <label style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '11px', color: '#666' }}>
                <input type="checkbox" checked={form.include_in_estate} onChange={(e) => setForm((p) => ({ ...p, include_in_estate: e.target.checked }))} style={{ width: 14, height: 14, accentColor: '#0A8C6D' }} />
                Include in estate
              </label>
            </div>
          </div>

          <div className="na-section" style={{ background: '#FFFFFF', borderRadius: '10px', padding: '16px', marginBottom: '16px', boxShadow: '0 1px 3px rgba(0,0,0,0.05)' }}>
            <div style={{ fontSize: '11px', fontWeight: '600', color: '#0A8C6D', marginBottom: '6px' }}>Vault entries</div>
            <div style={{ fontSize: '10px', color: '#6B7280', marginBottom: '12px' }}>Each row stores one secret. Encryption keys & IVs are handled automatically.</div>

            {vaultEntries.map((entry, index) => (
              <div className="na-grid-3" key={`vault-${index}`} style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '13px', marginBottom: '12px' }}>
                <div>
                  <label className="na-label" style={{ display: 'block', fontSize: '10px', color: '#666', marginBottom: '3px', fontWeight: '500' }}>Field name</label>
                  <input className="na-input" value={entry.field_name} onChange={(e) => setVaultField(index, 'field_name', e.target.value)} placeholder="e.g. password"
                    autoComplete="off"
                    style={{ width: '100%', padding: '6px 10px', borderRadius: '6px', border: '1px solid #e0e0e0', fontSize: '11px', outline: 'none', background: '#FFFFFF', boxSizing: 'border-box', fontFamily: 'inherit' }} />
                </div>
                <div>
                  <label className="na-label" style={{ display: 'block', fontSize: '10px', color: '#666', marginBottom: '3px', fontWeight: '500' }}>Value</label>
                  <input className="na-input" value={entry.encrypted_value} onChange={(e) => setVaultField(index, 'encrypted_value', e.target.value)} placeholder="Value"
                    autoComplete="off"
                    style={{ width: '100%', padding: '6px 10px', borderRadius: '6px', border: '1px solid #e0e0e0', fontSize: '11px', outline: 'none', background: '#FFFFFF', boxSizing: 'border-box', fontFamily: 'inherit' }} />
                </div>
              </div>
            ))}

            <div className="na-actions" style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end', flexWrap: 'wrap' }}>
              <button type="button" className="na-btn" onClick={() => setVaultEntries((prev) => [...prev, { ...emptyVault }])}
                style={{ padding: '6px 13px', borderRadius: '6px', border: '1px solid #e0e0e0', background: '#FFFFFF', color: '#666', fontSize: '11px', cursor: 'pointer', fontWeight: '600' }}>
                Add vault row
              </button>
              {vaultEntries.length > 1 ? (
                <button type="button" className="na-btn" onClick={() => setVaultEntries((prev) => prev.slice(0, -1))}
                  style={{ padding: '6px 13px', borderRadius: '6px', border: '1px solid #e0e0e0', background: '#FFFFFF', color: '#666', fontSize: '11px', cursor: 'pointer', fontWeight: '600' }}>
                  Remove last vault row
                </button>
              ) : null}
            </div>
          </div>

          <div className="na-section" style={{ background: '#FFFFFF', borderRadius: '10px', padding: '16px', marginBottom: '16px', boxShadow: '0 1px 3px rgba(0,0,0,0.05)' }}>
            <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', flexWrap: 'wrap', gap: '8px', marginBottom: '6px' }}>
              <div style={{ fontSize: '11px', fontWeight: '600', color: '#0A8C6D' }}>Beneficiaries</div>
              <div style={{ fontSize: '10px', fontWeight: 600, color: sharesOk ? '#0A8C6D' : '#B91C1C' }}>
                Total share: {shareTotalNow.toFixed(2)}% {sharesOk ? '' : '(must be exactly 100%)'}
              </div>
            </div>
            <div style={{ fontSize: '10px', color: '#6B7280', marginBottom: '12px' }}>Shares are auto-split equally when you add a beneficiary; edit any row to override.</div>

            {beneficiaries.map((entry, index) => (
              <div className="na-grid-3" key={`beneficiary-${index}`} style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '13px', marginBottom: '12px' }}>
                <div>
                  <label className="na-label" style={{ display: 'block', fontSize: '10px', color: '#666', marginBottom: '3px', fontWeight: '500' }}>Full name</label>
                  <input className="na-input" value={entry.full_name} onChange={(e) => setBeneficiaryField(index, 'full_name', e.target.value)}
                    autoComplete="off"
                    style={{ width: '100%', padding: '6px 10px', borderRadius: '6px', border: '1px solid #e0e0e0', fontSize: '11px', outline: 'none', background: '#FFFFFF', boxSizing: 'border-box', fontFamily: 'inherit' }} />
                </div>
                <div>
                  <label className="na-label" style={{ display: 'block', fontSize: '10px', color: '#666', marginBottom: '3px', fontWeight: '500' }}>Email</label>
                  <input className="na-input" type="email" value={entry.email} onChange={(e) => setBeneficiaryField(index, 'email', e.target.value)}
                    autoComplete="off"
                    style={{ width: '100%', padding: '6px 10px', borderRadius: '6px', border: '1px solid #e0e0e0', fontSize: '11px', outline: 'none', background: '#FFFFFF', boxSizing: 'border-box', fontFamily: 'inherit' }} />
                </div>
                <div>
                  <label className="na-label" style={{ display: 'block', fontSize: '10px', color: '#666', marginBottom: '3px', fontWeight: '500' }}>Share %</label>
                  <input className="na-input" type="number" min={0} max={100} step="0.01" value={entry.share_percentage}
                    onChange={(e) => setBeneficiaryField(index, 'share_percentage', e.target.value)}
                    autoComplete="off"
                    style={{ width: '100%', padding: '6px 10px', borderRadius: '6px', border: '1px solid #e0e0e0', fontSize: '11px', outline: 'none', background: '#FFFFFF', boxSizing: 'border-box', fontFamily: 'inherit' }} />
                </div>
                <div>
                  <label className="na-label" style={{ display: 'block', fontSize: '10px', color: '#666', marginBottom: '3px', fontWeight: '500' }}>Phone</label>
                  <input className="na-input" value={entry.phone} onChange={(e) => setBeneficiaryField(index, 'phone', e.target.value)}
                    autoComplete="off"
                    style={{ width: '100%', padding: '6px 10px', borderRadius: '6px', border: '1px solid #e0e0e0', fontSize: '11px', outline: 'none', background: '#FFFFFF', boxSizing: 'border-box', fontFamily: 'inherit' }} />
                </div>
                <div>
                  <label className="na-label" style={{ display: 'block', fontSize: '10px', color: '#666', marginBottom: '3px', fontWeight: '500' }}>Relationship</label>
                  <input className="na-input" value={entry.relationship} onChange={(e) => setBeneficiaryField(index, 'relationship', e.target.value)}
                    autoComplete="off"
                    style={{ width: '100%', padding: '6px 10px', borderRadius: '6px', border: '1px solid #e0e0e0', fontSize: '11px', outline: 'none', background: '#FFFFFF', boxSizing: 'border-box', fontFamily: 'inherit' }} />
                </div>
                <div>
                  <label className="na-label" style={{ display: 'block', fontSize: '10px', color: '#666', marginBottom: '3px', fontWeight: '500' }}>Notification method</label>
                  <select className="na-input" value={entry.notification_method} onChange={(e) => setBeneficiaryField(index, 'notification_method', e.target.value)}
                    autoComplete="off"
                    style={{ width: '100%', padding: '6px 10px', borderRadius: '6px', border: '1px solid #e0e0e0', fontSize: '11px', outline: 'none', background: '#FFFFFF', boxSizing: 'border-box', fontFamily: 'inherit' }}>
                    <option value="email">Email</option>
                    <option value="sms">SMS</option>
                    <option value="both">Both</option>
                  </select>
                </div>
              </div>
            ))}

            <div className="na-actions" style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end', flexWrap: 'wrap' }}>
              <button type="button" className="na-btn" onClick={addBeneficiary}
                style={{ padding: '6px 13px', borderRadius: '6px', border: '1px solid #e0e0e0', background: '#FFFFFF', color: '#666', fontSize: '11px', cursor: 'pointer', fontWeight: '600' }}>
                Add beneficiary
              </button>
              {beneficiaries.length > 1 ? (
                <button type="button" className="na-btn" onClick={removeLastBeneficiary}
                  style={{ padding: '6px 13px', borderRadius: '6px', border: '1px solid #e0e0e0', background: '#FFFFFF', color: '#666', fontSize: '11px', cursor: 'pointer', fontWeight: '600' }}>
                  Remove last beneficiary
                </button>
              ) : null}
            </div>
          </div>

          <div className="na-actions" style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end', marginTop: '4px', flexShrink: 0, flexWrap: 'wrap' }}>
            <button type="submit" className="na-btn na-btn-primary" disabled={saving || !sharesOk}
              style={{ padding: '6px 16px', borderRadius: '6px', border: 'none', background: (saving || !sharesOk) ? '#94A3B8' : '#0A8C6D', color: '#FFFFFF', fontSize: '11px', cursor: (saving || !sharesOk) ? 'not-allowed' : 'pointer', fontWeight: '600' }}>
              {saving ? 'Saving…' : 'Create asset'}
            </button>
          </div>
        </form>
      </div>
    </>
  );
}
