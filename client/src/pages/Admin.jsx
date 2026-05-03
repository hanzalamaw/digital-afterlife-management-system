import { useEffect, useState } from 'react';
import api, { getApiErrorMessage } from '../utils/api';

export default function Admin() {
  const [tab, setTab] = useState('users');
  const [users, setUsers] = useState([]);
  const [jobs, setJobs] = useState([]);
  const [verifications, setVerifications] = useState([]);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let mounted = true;
    (async () => {
      setLoading(true);
      setError('');
      try {
        const [u, j, v] = await Promise.all([
          api.get('/api/admin/users'),
          api.get('/api/admin/pending-executions'),
          api.get('/api/admin/death-verifications'),
        ]);
        if (!mounted) return;
        setUsers(u.data.users || []);
        setJobs(j.data.jobs || []);
        setVerifications(v.data.verifications || []);
      } catch (e) {
        if (!mounted) return;
        setError(getApiErrorMessage(e, 'Failed to load admin data.'));
      } finally {
        if (mounted) setLoading(false);
      }
    })();
    return () => { mounted = false; };
  }, []);

  return (
    <div className="stack">
      <div className="page-head">
        <div>
          <h2 className="h2">Admin</h2>
          <p className="muted">Monitor users, verifications, and pending executions (read-only dashboard).</p>
        </div>
      </div>

      {error ? <div className="alert alert-danger">{error}</div> : null}
      {loading ? <div className="card">Loading…</div> : null}

      {!loading ? (
        <>
          <div className="tabs">
            <button className={`tab ${tab === 'users' ? 'active' : ''}`} onClick={() => setTab('users')}>Users</button>
            <button className={`tab ${tab === 'verifications' ? 'active' : ''}`} onClick={() => setTab('verifications')}>Verifications</button>
            <button className={`tab ${tab === 'jobs' ? 'active' : ''}`} onClick={() => setTab('jobs')}>Pending executions</button>
          </div>

          {tab === 'users' ? (
            <div className="card">
              <div className="card-title">User estate summary</div>
              <div className="table">
                <div className="trow thead" style={{ '--cols': 6 }}>
                  <div>User</div>
                  <div>Status</div>
                  <div>Assets</div>
                  <div>Beneficiaries</div>
                  <div>Pending jobs</div>
                  <div>Days since check-in</div>
                </div>
                {users.map(u => (
                  <div className="trow" style={{ '--cols': 6 }} key={u.user_id}>
                    <div className="tstrong">{u.full_name}</div>
                    <div><span className="pill">{u.account_status}</span></div>
                    <div>{u.total_assets}</div>
                    <div>{u.total_beneficiaries}</div>
                    <div>{u.pending_jobs}</div>
                    <div>{u.days_since_checkin}</div>
                  </div>
                ))}
              </div>
            </div>
          ) : null}

          {tab === 'verifications' ? (
            <div className="card">
              <div className="card-title">Active verifications</div>
              <div className="table">
                <div className="trow thead" style={{ '--cols': 5 }}>
                  <div>User</div>
                  <div>Status</div>
                  <div>Trigger</div>
                  <div>Progress</div>
                  <div>Initiated</div>
                </div>
                {verifications.map(v => (
                  <div className="trow" style={{ '--cols': 5 }} key={v.verification_id}>
                    <div className="tstrong">{v.user_name}</div>
                    <div><span className="pill">{v.verification_status}</span></div>
                    <div>{v.trigger_source}</div>
                    <div>{v.confirmations_received}/{v.confirmations_required} ({v.confirmation_pct}%)</div>
                    <div className="muted">{v.initiated_at}</div>
                  </div>
                ))}
              </div>
            </div>
          ) : null}

          {tab === 'jobs' ? (
            <div className="card">
              <div className="card-title">Pending executions</div>
              <div className="table">
                <div className="trow thead" style={{ '--cols': 5 }}>
                  <div>User</div>
                  <div>Asset</div>
                  <div>Beneficiary</div>
                  <div>Status</div>
                  <div>Share</div>
                </div>
                {jobs.map(j => (
                  <div className="trow" style={{ '--cols': 5 }} key={j.job_id}>
                    <div className="tstrong">{j.user_name}</div>
                    <div>{j.asset_name} <span className="pill">{j.asset_type}</span></div>
                    <div>{j.beneficiary_name}</div>
                    <div><span className="pill">{j.job_status}</span></div>
                    <div>{j.share_percentage}%</div>
                  </div>
                ))}
              </div>
            </div>
          ) : null}
        </>
      ) : null}
    </div>
  );
}

