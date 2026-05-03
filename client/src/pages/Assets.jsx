import { useEffect, useMemo, useState } from 'react';
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

export default function Assets() {
  const [assets, setAssets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [creating, setCreating] = useState(false);
  const [form, setForm] = useState({
    asset_name: '',
    asset_type: 'email',
    description: '',
    instructions: '',
    require_contact_verify: true,
    include_in_estate: true,
  });

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

  const byUpdated = useMemo(() => assets.slice(), [assets]);

  const onChange = (e) => {
    const { name, value, type, checked } = e.target;
    setForm((p) => ({ ...p, [name]: type === 'checkbox' ? checked : value }));
  };

  const onCreate = async (e) => {
    e.preventDefault();
    setCreating(true);
    setError('');
    try {
      await api.post('/api/assets', {
        ...form,
        description: form.description.trim() || null,
        instructions: form.instructions.trim() || null,
      });
      setForm((p) => ({ ...p, asset_name: '', description: '', instructions: '' }));
      await refresh();
    } catch (err) {
      setError(getApiErrorMessage(err, 'Failed to create asset.'));
    } finally {
      setCreating(false);
    }
  };

  const toggle = async (asset, key) => {
    try {
      await api.put(`/api/assets/${asset.asset_id}`, { [key]: !Number(asset[key]) });
      await refresh();
    } catch (err) {
      setError(getApiErrorMessage(err, 'Failed to update asset.'));
    }
  };

  const onDelete = async (asset) => {
    if (!confirm(`Delete asset "${asset.asset_name}"?`)) return;
    setError('');
    try {
      await api.delete(`/api/assets/${asset.asset_id}`);
      await refresh();
    } catch (err) {
      setError(getApiErrorMessage(err, 'Failed to delete asset.'));
    }
  };

  return (
    <div className="stack">
      <div className="page-head">
        <div>
          <h2 className="h2">Assets</h2>
          <p className="muted">Register digital assets and choose per-asset verification behavior.</p>
        </div>
      </div>

      {error ? <div className="alert alert-danger">{error}</div> : null}

      <div className="card">
        <div className="card-title">Add new asset</div>
        <form className="form" onSubmit={onCreate} autoComplete="off">
          <div className="grid-2">
            <div className="field">
              <label>Asset name</label>
              <input name="asset_name" value={form.asset_name} onChange={onChange} placeholder="e.g., Gmail Personal" required autoComplete="off" />
            </div>
            <div className="field">
              <label>Asset type</label>
              <select name="asset_type" value={form.asset_type} onChange={onChange} required autoComplete="off">
                {ASSET_TYPES.map(t => <option key={t.value} value={t.value}>{t.label}</option>)}
              </select>
            </div>
            <div className="field">
              <label>Description</label>
              <input name="description" value={form.description} onChange={onChange} placeholder="Short description (optional)" autoComplete="off" />
            </div>
            <div className="field">
              <label>Instructions</label>
              <input name="instructions" value={form.instructions} onChange={onChange} placeholder="What should happen after confirmed death? (optional)" autoComplete="off" />
            </div>
          </div>

          <div className="rowline">
            <label className="check">
              <input type="checkbox" name="require_contact_verify" checked={form.require_contact_verify} onChange={onChange} />
              <span>Require trusted contact verification before releasing this asset</span>
            </label>
            <label className="check">
              <input type="checkbox" name="include_in_estate" checked={form.include_in_estate} onChange={onChange} />
              <span>Include in estate</span>
            </label>
          </div>

          <div className="actions">
            <button className="btn-primary" disabled={creating}>
              {creating ? 'Adding…' : 'Add asset'}
            </button>
            <button className="btn-ghost" type="button" onClick={() => setForm({
              asset_name: '',
              asset_type: 'email',
              description: '',
              instructions: '',
              require_contact_verify: true,
              include_in_estate: true,
            })}>Reset</button>
          </div>
        </form>
      </div>

      <div className="card">
        <div className="card-title">Your assets</div>
        {loading ? (
          <div className="muted">Loading…</div>
        ) : byUpdated.length === 0 ? (
          <div className="muted">No assets yet.</div>
        ) : (
          <div className="table">
            <div className="trow thead" style={{ '--cols': 5 }}>
              <div>Name</div>
              <div>Type</div>
              <div>Verify</div>
              <div>Estate</div>
              <div className="tright">Actions</div>
            </div>
            {byUpdated.map(a => (
              <div className="trow" style={{ '--cols': 5 }} key={a.asset_id}>
                <div className="tstrong">{a.asset_name}</div>
                <div><span className="pill">{a.asset_type}</span></div>
                <div>
                  <button className={`pill-btn ${Number(a.require_contact_verify) ? 'on' : ''}`} onClick={() => toggle(a, 'require_contact_verify')}>
                    {Number(a.require_contact_verify) ? 'On' : 'Off'}
                  </button>
                </div>
                <div>
                  <button className={`pill-btn ${Number(a.include_in_estate) ? 'on' : ''}`} onClick={() => toggle(a, 'include_in_estate')}>
                    {Number(a.include_in_estate) ? 'Included' : 'Excluded'}
                  </button>
                </div>
                <div className="tright">
                  <button className="btn-danger" onClick={() => onDelete(a)}>Delete</button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

