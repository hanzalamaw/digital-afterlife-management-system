import { useEffect, useMemo, useState } from 'react';
import api, { getApiErrorMessage } from '../utils/api';

const ASSET_TYPE_LABEL = {
  bank_account: 'Bank',
  crypto_wallet: 'Crypto',
  social_media: 'Social',
  email: 'Email',
  file_storage: 'Storage',
  subscription: 'Subscription',
  domain: 'Domain',
  other: 'Other',
};

const STATUS_BADGE = {
  active:            { bg: '#E7F6F1', fg: '#0A8C6D' },
  pending_execution: { bg: '#FEF3C7', fg: '#92400E' },
  executed:          { bg: '#E0E7FF', fg: '#3730A3' },
  cancelled:         { bg: '#F3F4F6', fg: '#6B7280' },
};

function fmtDate(s) {
  if (!s) return '—';
  try {
    return new Date(s).toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: '2-digit' });
  } catch {
    return s;
  }
}

export default function ManageAssets() {
  const [assets, setAssets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [pendingId, setPendingId] = useState(null);
  const [selectedAssetDetails, setSelectedAssetDetails] = useState(null);
  const [detailsLoading, setDetailsLoading] = useState(false);

  const refresh = async () => {
    setLoading(true);
    setError('');
    try {
      const res = await api.get('/api/assets');
      setAssets(res.data.assets || []);
    } catch (e) {
      setError(getApiErrorMessage(e, 'Failed to load assets.'));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { refresh(); }, []);

  // Stable sort by asset_id ASC (insertion order). The server already returns
  // them like this; we sort again defensively so toggles never reorder the UI.
  const orderedAssets = useMemo(
    () => [...assets].sort((a, b) => a.asset_id - b.asset_id),
    [assets],
  );

  // Optimistic toggle: patch the row in local state, fire the API in the
  // background, revert on error. No full refetch → no row jumping.
  const toggle = async (asset, key) => {
    const newVal = Number(asset[key]) ? 0 : 1;
    const prev = assets;
    setAssets((list) => list.map((a) => (a.asset_id === asset.asset_id ? { ...a, [key]: newVal } : a)));
    setPendingId(asset.asset_id);
    try {
      await api.put(`/api/assets/${asset.asset_id}`, { [key]: !!newVal });
    } catch (err) {
      setAssets(prev);
      setError(getApiErrorMessage(err, 'Failed to update asset.'));
    } finally {
      setPendingId(null);
    }
  };

  const onDelete = async (asset) => {
    if (!confirm(`Delete asset "${asset.asset_name}"?`)) return;
    setError('');
    try {
      await api.delete(`/api/assets/${asset.asset_id}`);
      setAssets((list) => list.filter((a) => a.asset_id !== asset.asset_id));
      if (selectedAssetDetails?.asset?.asset_id === asset.asset_id) {
        setSelectedAssetDetails(null);
      }
    } catch (err) {
      setError(getApiErrorMessage(err, 'Failed to delete asset.'));
    }
  };

  const openDetails = async (assetId) => {
    setDetailsLoading(true);
    setError('');
    try {
      const res = await api.get(`/api/assets/${assetId}/details`);
      setSelectedAssetDetails(res.data);
    } catch (err) {
      setError(getApiErrorMessage(err, 'Failed to load asset details.'));
    } finally {
      setDetailsLoading(false);
    }
  };

  return (
    <>
      <style>{`
        @media (max-width: 767px) {
          .ma-root { padding: 16px 12px 24px !important; overflow: auto !important; }
          .ma-header h2 { font-size: clamp(15px, 4.3vw, 17px) !important; }
          .ma-section { padding: 14px 12px !important; margin-bottom: 12px !important; border-radius: 10px !important; }
        }
      `}</style>

      <div className="ma-root" style={{ padding: '19px', fontFamily: "'Poppins', 'Inter', sans-serif", display: 'flex', flexDirection: 'column', minHeight: 0, height: '100%', overflow: 'auto', boxSizing: 'border-box', background: '#F9FAFB' }}>
        <div className="ma-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px', flexShrink: 0, flexWrap: 'wrap', gap: '10px' }}>
          <div>
            <h2 style={{ margin: 0, fontSize: '18px', fontWeight: '600', color: '#333' }}>Asset Management</h2>
            <p style={{ margin: '4px 0 0 0', fontSize: '11px', color: '#6B7280' }}>View, toggle and delete existing assets.</p>
          </div>
        </div>

        {error ? (
          <div style={{ background: '#FEF2F2', color: '#B91C1C', padding: '8px 11px', borderRadius: '6px', marginBottom: '13px', fontSize: '10px', border: '1px solid #FECACA' }}>
            {error}
          </div>
        ) : null}

        <div className="ma-section" style={{ background: '#FFFFFF', borderRadius: '10px', padding: '16px', marginBottom: '16px', boxShadow: '0 1px 3px rgba(0,0,0,0.05)', overflow: 'hidden' }}>
          <div style={{ fontSize: '11px', fontWeight: '600', color: '#0A8C6D', marginBottom: '13px', paddingBottom: '8px', borderBottom: '1px solid #e0e0e0' }}>Your assets</div>

          {loading ? (
            <div style={{ padding: '16px', textAlign: 'center', color: '#666', fontSize: '11px' }}>Loading…</div>
          ) : orderedAssets.length === 0 ? (
            <div style={{ padding: '16px', textAlign: 'center', color: '#666', fontSize: '11px' }}>No assets yet.</div>
          ) : (
            <div style={{ overflow: 'auto', border: '1px solid #e0e0e0', borderRadius: '8px' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '10px', whiteSpace: 'nowrap' }}>
                <thead>
                  <tr style={{ background: '#fafafa' }}>
                    <th style={{ padding: '10px 8px', textAlign: 'left', fontWeight: '600', color: '#333', borderBottom: '2px solid #e0e0e0' }}>Name</th>
                    <th style={{ padding: '10px 8px', textAlign: 'left', fontWeight: '600', color: '#333', borderBottom: '2px solid #e0e0e0' }}>Type</th>
                    <th style={{ padding: '10px 8px', textAlign: 'left', fontWeight: '600', color: '#333', borderBottom: '2px solid #e0e0e0' }}>Status</th>
                    <th style={{ padding: '10px 8px', textAlign: 'left', fontWeight: '600', color: '#333', borderBottom: '2px solid #e0e0e0' }}>Beneficiaries</th>
                    <th style={{ padding: '10px 8px', textAlign: 'left', fontWeight: '600', color: '#333', borderBottom: '2px solid #e0e0e0' }}>Share</th>
                    <th style={{ padding: '10px 8px', textAlign: 'left', fontWeight: '600', color: '#333', borderBottom: '2px solid #e0e0e0' }}>Vault</th>
                    <th style={{ padding: '10px 8px', textAlign: 'left', fontWeight: '600', color: '#333', borderBottom: '2px solid #e0e0e0' }}>Verify</th>
                    <th style={{ padding: '10px 8px', textAlign: 'left', fontWeight: '600', color: '#333', borderBottom: '2px solid #e0e0e0' }}>Estate</th>
                    <th style={{ padding: '10px 8px', textAlign: 'left', fontWeight: '600', color: '#333', borderBottom: '2px solid #e0e0e0' }}>Created</th>
                    <th style={{ padding: '10px 8px', textAlign: 'right', fontWeight: '600', color: '#333', borderBottom: '2px solid #e0e0e0' }}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {orderedAssets.map((a) => {
                    const sb = STATUS_BADGE[a.status] || STATUS_BADGE.cancelled;
                    const share = Number(a.share_total || 0).toFixed(2);
                    const shareOk = Math.abs(Number(a.share_total || 0) - 100) < 0.01 || Number(a.beneficiary_count || 0) === 0;
                    const isPending = pendingId === a.asset_id;
                    return (
                      <tr key={a.asset_id} style={{ borderBottom: '1px solid #eee', opacity: isPending ? 0.6 : 1 }}>
                        <td style={{ padding: '8px', fontWeight: 600, color: '#111827' }}>{a.asset_name}</td>
                        <td style={{ padding: '8px' }}><span className="pill">{ASSET_TYPE_LABEL[a.asset_type] || a.asset_type}</span></td>
                        <td style={{ padding: '8px' }}>
                          <span style={{ display: 'inline-block', padding: '3px 8px', borderRadius: '999px', background: sb.bg, color: sb.fg, fontWeight: 600, fontSize: '9px', textTransform: 'capitalize' }}>
                            {String(a.status || '').replace('_', ' ')}
                          </span>
                        </td>
                        <td style={{ padding: '8px', fontWeight: 600, color: '#0A8C6D' }}>{a.beneficiary_count ?? 0}</td>
                        <td style={{ padding: '8px', color: shareOk ? '#0A8C6D' : '#B91C1C', fontWeight: 600 }}>{share}%</td>
                        <td style={{ padding: '8px', color: '#374151' }}>{a.vault_count ?? 0}</td>
                        <td style={{ padding: '8px' }}>
                          <button className={`pill-btn ${Number(a.require_contact_verify) ? 'on' : ''}`} disabled={isPending} onClick={() => toggle(a, 'require_contact_verify')}>
                            {Number(a.require_contact_verify) ? 'On' : 'Off'}
                          </button>
                        </td>
                        <td style={{ padding: '8px' }}>
                          <button className={`pill-btn ${Number(a.include_in_estate) ? 'on' : ''}`} disabled={isPending} onClick={() => toggle(a, 'include_in_estate')}>
                            {Number(a.include_in_estate) ? 'Included' : 'Excluded'}
                          </button>
                        </td>
                        <td style={{ padding: '8px', color: '#6B7280' }}>{fmtDate(a.created_at)}</td>
                        <td style={{ padding: '8px', textAlign: 'right' }}>
                          <button style={{ padding: '6px 11px', borderRadius: '6px', border: '1px solid #e0e0e0', background: '#FFFFFF', color: '#666', fontSize: '10px', cursor: 'pointer', fontWeight: '600', marginRight: '6px' }} onClick={() => openDetails(a.asset_id)}>Details</button>
                          <button style={{ padding: '6px 11px', borderRadius: '6px', border: '1px solid #fca5a5', background: '#FEF2F2', color: '#B91C1C', fontSize: '10px', cursor: 'pointer', fontWeight: '600' }} onClick={() => onDelete(a)}>Delete</button>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>

        <div className="ma-section" style={{ background: '#FFFFFF', borderRadius: '10px', padding: '16px', marginBottom: '16px', boxShadow: '0 1px 3px rgba(0,0,0,0.05)', overflow: 'hidden' }}>
          <div style={{ fontSize: '11px', fontWeight: '600', color: '#0A8C6D', marginBottom: '13px', paddingBottom: '8px', borderBottom: '1px solid #e0e0e0' }}>Vault & beneficiary details</div>
          {detailsLoading ? <div style={{ color: '#666', fontSize: '11px' }}>Loading details…</div> : null}
          {!detailsLoading && !selectedAssetDetails ? <div style={{ color: '#666', fontSize: '11px' }}>Select an asset and click “Details”.</div> : null}
          {!detailsLoading && selectedAssetDetails ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              <div style={{ background: '#F9FAFB', borderRadius: '8px', border: '1px solid #e5e7eb', padding: '12px', fontSize: '11px', color: '#111827' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', gap: '10px', flexWrap: 'wrap' }}>
                  <div><strong>Asset:</strong> {selectedAssetDetails.asset?.asset_name}</div>
                  <div><strong>Type:</strong> {selectedAssetDetails.asset?.asset_type}</div>
                </div>
              </div>

              <div>
                <div style={{ fontSize: '11px', fontWeight: '600', color: '#0A8C6D', marginBottom: '8px' }}>Vault entries</div>
                {selectedAssetDetails.vault_entries?.length ? (
                  <div style={{ overflow: 'auto', border: '1px solid #e0e0e0', borderRadius: '8px' }}>
                    <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '10px', whiteSpace: 'nowrap' }}>
                      <thead>
                        <tr style={{ background: '#fafafa' }}>
                          <th style={{ padding: '10px 8px', textAlign: 'left', fontWeight: '600', color: '#333', borderBottom: '2px solid #e0e0e0' }}>Field</th>
                          <th style={{ padding: '10px 8px', textAlign: 'left', fontWeight: '600', color: '#333', borderBottom: '2px solid #e0e0e0' }}>Encrypted value</th>
                          <th style={{ padding: '10px 8px', textAlign: 'left', fontWeight: '600', color: '#333', borderBottom: '2px solid #e0e0e0' }}>IV</th>
                        </tr>
                      </thead>
                      <tbody>
                        {selectedAssetDetails.vault_entries.map((v) => (
                          <tr key={v.vault_id} style={{ borderBottom: '1px solid #eee' }}>
                            <td style={{ padding: '8px', fontWeight: 600 }}>{v.field_name}</td>
                            <td style={{ padding: '8px', color: '#6B7280', maxWidth: 280, overflow: 'hidden', textOverflow: 'ellipsis' }}>{v.encrypted_value}</td>
                            <td style={{ padding: '8px', color: '#9CA3AF' }}>{v.iv}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                ) : <div style={{ color: '#666', fontSize: '11px' }}>No vault entries for this asset.</div>}
              </div>

              <div>
                <div style={{ fontSize: '11px', fontWeight: '600', color: '#0A8C6D', marginBottom: '8px' }}>Beneficiaries</div>
                {selectedAssetDetails.beneficiaries?.length ? (
                  <div style={{ overflow: 'auto', border: '1px solid #e0e0e0', borderRadius: '8px' }}>
                    <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '10px', whiteSpace: 'nowrap' }}>
                      <thead>
                        <tr style={{ background: '#fafafa' }}>
                          <th style={{ padding: '10px 8px', textAlign: 'left', fontWeight: '600', color: '#333', borderBottom: '2px solid #e0e0e0' }}>Name</th>
                          <th style={{ padding: '10px 8px', textAlign: 'left', fontWeight: '600', color: '#333', borderBottom: '2px solid #e0e0e0' }}>Email</th>
                          <th style={{ padding: '10px 8px', textAlign: 'left', fontWeight: '600', color: '#333', borderBottom: '2px solid #e0e0e0' }}>Relationship</th>
                          <th style={{ padding: '10px 8px', textAlign: 'left', fontWeight: '600', color: '#333', borderBottom: '2px solid #e0e0e0' }}>Share %</th>
                          <th style={{ padding: '10px 8px', textAlign: 'left', fontWeight: '600', color: '#333', borderBottom: '2px solid #e0e0e0' }}>Notify</th>
                          <th style={{ padding: '10px 8px', textAlign: 'left', fontWeight: '600', color: '#333', borderBottom: '2px solid #e0e0e0' }}>Verified</th>
                        </tr>
                      </thead>
                      <tbody>
                        {selectedAssetDetails.beneficiaries.map((b) => (
                          <tr key={b.asset_beneficiary_id} style={{ borderBottom: '1px solid #eee' }}>
                            <td style={{ padding: '8px', fontWeight: 600 }}>{b.full_name}</td>
                            <td style={{ padding: '8px', color: '#6B7280' }}>{b.email}</td>
                            <td style={{ padding: '8px', color: '#374151' }}>{b.relationship || '—'}</td>
                            <td style={{ padding: '8px' }}>{Number(b.share_percentage).toFixed(2)}%</td>
                            <td style={{ padding: '8px' }}>{b.notification_method}</td>
                            <td style={{ padding: '8px' }}>
                              <span className={`pill ${b.verification_status === 'verified' ? 'ok' : ''}`}>{b.verification_status}</span>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                ) : <div style={{ color: '#666', fontSize: '11px' }}>No beneficiaries linked to this asset.</div>}
              </div>
            </div>
          ) : null}
        </div>
      </div>
    </>
  );
}
