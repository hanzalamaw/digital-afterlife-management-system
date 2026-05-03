import { useEffect, useState } from 'react';
import api, { getApiErrorMessage } from '../utils/api';

const RULES = [
  {
    value: 'inactivity_timer',
    title: 'Inactivity timer',
    desc: 'Triggers if you don’t log in for X days.',
  },
  {
    value: 'quorum_vote',
    title: 'Trusted contact quorum',
    desc: 'Triggers after N trusted contacts confirm death (after initiation by system).',
  },
  {
    value: 'combined_and',
    title: 'Combined (AND)',
    desc: 'Requires both inactivity AND quorum to proceed.',
  },
];

export default function Rules() {
  const [rules, setRules] = useState([]);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [form, setForm] = useState({
    rule_type: 'combined_and',
    inactivity_days: 60,
    quorum_required: 2,
    grace_period_days: 7,
  });

  const refresh = async () => {
    setError('');
    const res = await api.get('/api/rules');
    setRules(res.data.rules || []);
    const active = (res.data.rules || []).find(x => Number(x.is_active) === 1);
    if (active) {
      setForm({
        rule_type: active.rule_type,
        inactivity_days: active.inactivity_days ?? 60,
        quorum_required: active.quorum_required ?? 2,
        grace_period_days: active.grace_period_days ?? 7,
      });
    }
  };

  useEffect(() => {
    refresh().catch((err) => setError(getApiErrorMessage(err, 'Failed to load rules.')));
  }, []);

  const onChange = (e) => {
    const { name, value } = e.target;
    setForm((p) => ({ ...p, [name]: name.endsWith('_days') || name.endsWith('_required') ? Number(value) : value }));
  };

  const save = async (e) => {
    e.preventDefault();
    setSaving(true);
    setError('');
    try {
      await api.put('/api/rules/active', form);
      await refresh();
    } catch (err) {
      setError(getApiErrorMessage(err, 'Failed to save rule.'));
    } finally {
      setSaving(false);
    }
  };

  const selected = RULES.find(r => r.value === form.rule_type);
  const needsInactivity = form.rule_type === 'inactivity_timer' || form.rule_type === 'combined_and';
  const needsQuorum = form.rule_type === 'quorum_vote' || form.rule_type === 'combined_and';

  return (
    <div className="stack">
      <div className="page-head">
        <div>
          <h2 className="h2">Death rules</h2>
          <p className="muted">
            Choose how the system should initiate death verification. Manual contact-started declarations are intentionally not included.
          </p>
        </div>
      </div>

      {error ? <div className="alert alert-danger">{error}</div> : null}

      <div className="grid-2">
        <div className="card">
          <div className="card-title">Select active rule</div>
          <form className="form" onSubmit={save} autoComplete="off">
            <div className="field">
              <label>Rule type</label>
              <select name="rule_type" value={form.rule_type} onChange={onChange} autoComplete="off">
                {RULES.map(r => <option key={r.value} value={r.value}>{r.title}</option>)}
              </select>
              <div className="help">{selected?.desc}</div>
            </div>

            {needsInactivity ? (
              <div className="field">
                <label>Inactivity threshold (days)</label>
                <input name="inactivity_days" type="number" min={7} max={3650} value={form.inactivity_days} onChange={onChange} autoComplete="off" />
                <div className="help">If you don’t log in for this many days, the account can be flagged.</div>
              </div>
            ) : null}

            {needsQuorum ? (
              <div className="field">
                <label>Quorum required</label>
                <input name="quorum_required" type="number" min={1} max={50} value={form.quorum_required} onChange={onChange} autoComplete="off" />
                <div className="help">How many trusted contacts must confirm.</div>
              </div>
            ) : null}

            <div className="field">
              <label>Grace period (days)</label>
              <input name="grace_period_days" type="number" min={1} max={3650} value={form.grace_period_days} onChange={onChange} autoComplete="off" />
              <div className="help">How long you have to intervene after a declaration/trigger.</div>
            </div>

            <div className="actions">
              <button className="btn-primary" disabled={saving}>{saving ? 'Saving…' : 'Save active rule'}</button>
              <span className="muted">This applies globally to your account and all assets.</span>
            </div>
          </form>
        </div>

        <div className="card">
          <div className="card-title">Rule history</div>
          {rules.length === 0 ? (
            <div className="muted">No rules saved yet.</div>
          ) : (
            <div className="table">
              <div className="trow thead" style={{ '--cols': 4 }}>
                <div>Type</div>
                <div>Inactivity</div>
                <div>Quorum</div>
                <div>Status</div>
              </div>
              {rules.map(r => (
                <div className="trow" style={{ '--cols': 4 }} key={r.rule_id}>
                  <div className="tstrong">{r.rule_type}</div>
                  <div>{r.inactivity_days ?? '—'}</div>
                  <div>{r.quorum_required ?? '—'}</div>
                  <div>
                    {Number(r.is_active) === 1 ? <span className="pill ok">Active</span> : <span className="pill">Inactive</span>}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

