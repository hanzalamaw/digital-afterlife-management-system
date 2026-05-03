import { useEffect, useMemo, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import api from '../utils/api';
import { useAuth } from '../context/AuthContext';

export default function Dashboard() {
  const { user } = useAuth();
  const location = useLocation();
  const navigate = useNavigate();
  const [assets, setAssets] = useState([]);
  const [contacts, setContacts] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!location.state?.successMessage) return;
    navigate(location.pathname, { replace: true });
  }, [location.pathname, location.state, navigate]);

  useEffect(() => {
    let mounted = true;
    (async () => {
      try {
        const [a, c] = await Promise.all([
          api.get('/api/assets'),
          api.get('/api/contacts'),
        ]);
        if (!mounted) return;
        setAssets(a.data.assets || []);
        setContacts(c.data.contacts || []);
      } finally {
        if (mounted) setLoading(false);
      }
    })();
    return () => { mounted = false; };
  }, []);

  const stats = useMemo(() => {
    const total = assets.length;
    const gated = assets.filter(x => Number(x.require_contact_verify) === 1).length;
    const excluded = assets.filter(x => Number(x.include_in_estate) === 0).length;
    return { total, gated, excluded };
  }, [assets]);

  return (
    <div className="stack">
      {location.state?.successMessage ? (
        <div className="alert alert-success">{location.state.successMessage}</div>
      ) : null}

      <div className="page-head">
        <div>
          <h2 className="h2">Welcome, {user?.full_name || 'User'}.</h2>
          <p className="muted">Monitor your estate status and contact verification readiness.</p>
        </div>
      </div>

      {loading ? (
        <div className="card">Loading your estate overview…</div>
      ) : (
        <>
          <div className="grid-3">
            <div className="card">
              <div className="card-kpi">{stats.total}</div>
              <div className="card-label">Total assets</div>
            </div>
            <div className="card">
              <div className="card-kpi">{stats.gated}</div>
              <div className="card-label">Require contact verification</div>
            </div>
            <div className="card">
              <div className="card-kpi">{contacts.length}</div>
              <div className="card-label">Trusted contacts</div>
            </div>
          </div>

          <div className="card">
            <div className="card-title">Asset overview</div>
            <div className="rows">
              <div className="row">
                <div className="row-k">Verification required assets</div>
                <div className="row-v">{stats.gated}</div>
              </div>
              <div className="row">
                <div className="row-k">Excluded from estate</div>
                <div className="row-v">{stats.excluded}</div>
              </div>
              <div className="row">
                <div className="row-k">Total tracked assets</div>
                <div className="row-v">{stats.total}</div>
              </div>
            </div>
          </div>

          <div className="card">
            <div className="card-title">Quick notes</div>
            <ul className="list">
              <li>Contacts can help verify after a trigger, but they can’t start a verification event in this build.</li>
              <li>Logging in counts as a check-in and can reactivate flagged accounts.</li>
              <li>Vault credential rows are saved from the “New Assets” form.</li>
            </ul>
          </div>
        </>
      )}
    </div>
  );
}

