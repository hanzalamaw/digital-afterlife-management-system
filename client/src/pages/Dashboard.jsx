import { useEffect, useMemo, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import api from '../utils/api';
import { useAuth } from '../context/AuthContext';

const card = {
  background: '#FFFFFF', borderRadius: '10px', padding: '16px',
  boxShadow: '0 1px 3px rgba(0,0,0,0.05)',
  border: '1px solid #EEF2F5',
};

const sectionTitle = {
  fontSize: '11px', fontWeight: '600', color: '#0A8C6D',
  marginBottom: '13px', paddingBottom: '8px',
  borderBottom: '1px solid #e0e0e0',
};

const kpiCard = {
  ...card,
  display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
  minHeight: '92px',
};

const kpiTitle = { fontSize: '10px', fontWeight: '600', color: '#6B7280', textTransform: 'uppercase', letterSpacing: '0.4px' };
const kpiValue = { fontSize: '22px', fontWeight: '700', color: '#0A8C6D', marginTop: '6px', lineHeight: 1.1 };
const kpiSub = { fontSize: '10px', color: '#6B7280', marginTop: '4px' };

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

const STATUS_COLORS = {
  Active: '#0A8C6D',
  Flagged: '#D97706',
  Pending_Verification: '#2563EB',
  Deceased: '#B91C1C',
  Executed: '#6B7280',
};

const CATEGORY_LABEL = {
  reminder: 'Reminders',
  suspect_death: 'Suspect-death',
  confirmed_death: 'Confirmed-death',
  beneficiary_grant: 'Grants',
  contact_request: 'Contact requests',
  other: 'Other',
};

function fmt(d) {
  if (!d) return '—';
  try {
    return new Date(d).toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' });
  } catch { return d; }
}

function fmtDate(d) {
  if (!d) return '—';
  try {
    return new Date(d).toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: '2-digit' });
  } catch { return d; }
}

export default function Dashboard() {
  const { user } = useAuth();
  const location = useLocation();
  const navigate = useNavigate();
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!location.state?.successMessage) return;
    navigate(location.pathname, { replace: true });
  }, [location.pathname, location.state, navigate]);

  useEffect(() => {
    let mounted = true;
    (async () => {
      try {
        const res = await api.get('/api/dashboard/summary');
        if (!mounted) return;
        setData(res.data || null);
      } finally {
        if (mounted) setLoading(false);
      }
    })();
    return () => { mounted = false; };
  }, []);

  // ---- Derived values --------------------------------------------------------
  const accountStatus = data?.user?.account_status || 'Active';
  const statusColor = STATUS_COLORS[accountStatus] || '#6B7280';

  const checks = useMemo(() => {
    if (!data) return [];
    return [
      { label: 'At least 1 asset',              ok: (data.assets?.total ?? 0) >= 1 },
      { label: 'At least 1 trusted contact',    ok: (data.trusted_contacts?.total ?? 0) >= 1 },
      { label: 'Inactivity rule configured',    ok: !!(data.death_rules?.inactivity?.is_active) },
      { label: 'Quorum rule configured',        ok: !!(data.death_rules?.quorum?.is_active) },
      { label: 'At least 1 reminder set',       ok: (data.death_rules?.reminders_configured ?? 0) >= 1 },
      { label: 'Every asset has beneficiaries', ok: (data.assets?.total ?? 0) > 0 && (data.assets?.beneficiary_links ?? 0) > 0 },
    ];
  }, [data]);

  const readinessPct = checks.length === 0 ? 0
    : Math.round((checks.filter((c) => c.ok).length / checks.length) * 100);

  const typeCounts = data?.assets?.by_type || {};
  const maxType = Math.max(1, ...Object.values(typeCounts));

  const inactivity = data?.inactivity || { days_used: 0, days_remaining: 0, percent_used: 0, budget: 0 };

  return (
    <>
      <style>{`
        @media (max-width: 1100px) {
          .dash-kpis { grid-template-columns: repeat(2, 1fr) !important; }
          .dash-grid-2 { grid-template-columns: 1fr !important; }
          .dash-grid-3 { grid-template-columns: 1fr !important; }
        }
        @media (max-width: 600px) {
          .dash-kpis { grid-template-columns: 1fr !important; }
          .dash-root { padding: 14px 12px 24px !important; }
        }
      `}</style>

      <div className="dash-root" style={{ padding: '19px', fontFamily: "'Poppins', 'Inter', sans-serif", display: 'flex', flexDirection: 'column', height: '100%', overflow: 'auto', boxSizing: 'border-box', background: '#F9FAFB' }}>
        {location.state?.successMessage ? (
          <div style={{ background: '#F0FDF4', color: '#166534', padding: '8px 11px', borderRadius: '6px', marginBottom: '13px', fontSize: '10px', border: '1px solid #BBF7D0' }}>
            {location.state.successMessage}
          </div>
        ) : null}

        {/* HERO */}
        <div style={{ ...card, marginBottom: '16px', background: 'linear-gradient(135deg, #ffffff 60%, #E7F6F1 100%)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', flexWrap: 'wrap', gap: '12px' }}>
            <div>
              <div style={{ fontSize: '10px', letterSpacing: '0.6px', color: '#0A8C6D', fontWeight: 600, textTransform: 'uppercase' }}>Digital Afterlife Management</div>
              <h2 style={{ margin: '4px 0 6px', fontSize: '18px', fontWeight: 600, color: '#1f2937' }}>
                Welcome back, {user?.full_name || 'User'}.
              </h2>
              <p style={{ margin: 0, fontSize: '11px', color: '#6B7280' }}>
                {data?.user?.last_checkin_at
                  ? `Last check-in ${fmt(data.user.last_checkin_at)} — ${data.user.days_since_checkin ?? 0} day${(data.user.days_since_checkin ?? 0) === 1 ? '' : 's'} ago.`
                  : 'Welcome to your estate dashboard.'}
              </p>
            </div>
            <div>
              <div style={{ fontSize: '10px', color: '#6B7280' }}>Account status</div>
              <div style={{
                display: 'inline-block', marginTop: '4px',
                padding: '4px 12px', borderRadius: '999px',
                background: `${statusColor}1f`, color: statusColor,
                fontSize: '10px', fontWeight: 700, letterSpacing: '0.6px',
              }}>
                {String(accountStatus).toUpperCase()}
              </div>
            </div>
          </div>
        </div>

        {loading || !data ? (
          <div style={card}>Loading your estate overview…</div>
        ) : (
          <>
            {/* KPI ROW */}
            <div className="dash-kpis" style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '12px', marginBottom: '16px' }}>
              <div style={kpiCard}>
                <div style={kpiTitle}>Total assets</div>
                <div>
                  <div style={kpiValue}>{data.assets.total}</div>
                  <div style={kpiSub}>{data.assets.included} included • {data.assets.excluded} excluded</div>
                </div>
              </div>
              <div style={kpiCard}>
                <div style={kpiTitle}>Beneficiaries</div>
                <div>
                  <div style={kpiValue}>{data.beneficiaries.unique_count}</div>
                  <div style={kpiSub}>{data.assets.beneficiary_links} links across assets</div>
                </div>
              </div>
              <div style={kpiCard}>
                <div style={kpiTitle}>Trusted contacts</div>
                <div>
                  <div style={kpiValue}>{data.trusted_contacts.total}</div>
                  <div style={kpiSub}>{data.trusted_contacts.verified} verified • {data.trusted_contacts.pending} pending</div>
                </div>
              </div>
              <div style={kpiCard}>
                <div style={kpiTitle}>Vault entries</div>
                <div>
                  <div style={kpiValue}>{data.assets.vault_entries}</div>
                  <div style={kpiSub}>{data.assets.gated} verify-gated asset{data.assets.gated === 1 ? '' : 's'}</div>
                </div>
              </div>
              <div style={kpiCard}>
                <div style={kpiTitle}>Inactivity budget</div>
                <div>
                  <div style={kpiValue}>{inactivity.budget || '—'}</div>
                  <div style={kpiSub}>{inactivity.days_remaining} day{inactivity.days_remaining === 1 ? '' : 's'} remaining</div>
                </div>
              </div>
              <div style={kpiCard}>
                <div style={kpiTitle}>Reminders</div>
                <div>
                  <div style={kpiValue}>{data.death_rules.reminders_configured}</div>
                  <div style={kpiSub}>{data.death_rules.reminders_fired} fired</div>
                </div>
              </div>
              <div style={kpiCard}>
                <div style={kpiTitle}>Emails sent</div>
                <div>
                  <div style={kpiValue}>{data.notifications.total_sent}</div>
                  <div style={kpiSub}>{data.notifications.total_failed} failed</div>
                </div>
              </div>
              <div style={kpiCard}>
                <div style={kpiTitle}>Execution queue</div>
                <div>
                  <div style={kpiValue}>{data.assets.pending_execution}</div>
                  <div style={kpiSub}>{data.assets.executed} executed • {data.assets.cancelled} cancelled</div>
                </div>
              </div>
            </div>

            {/* READINESS + INACTIVITY BAR */}
            <div className="dash-grid-2" style={{ display: 'grid', gridTemplateColumns: '1.4fr 1fr', gap: '16px', marginBottom: '16px' }}>
              <div style={card}>
                <div style={sectionTitle}>Estate readiness</div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '16px', flexWrap: 'wrap' }}>
                  <div style={{ position: 'relative', width: '110px', height: '110px', flexShrink: 0 }}>
                    <svg width="110" height="110" viewBox="0 0 110 110">
                      <circle cx="55" cy="55" r="48" fill="none" stroke="#E7F6F1" strokeWidth="10" />
                      <circle
                        cx="55" cy="55" r="48" fill="none" stroke="#0A8C6D" strokeWidth="10"
                        strokeDasharray={`${(2 * Math.PI * 48 * readinessPct) / 100} ${2 * Math.PI * 48}`}
                        strokeLinecap="round"
                        transform="rotate(-90 55 55)"
                      />
                    </svg>
                    <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', flexDirection: 'column' }}>
                      <div style={{ fontSize: '20px', fontWeight: 700, color: '#0A8C6D' }}>{readinessPct}%</div>
                      <div style={{ fontSize: '9px', color: '#6B7280', letterSpacing: '0.4px' }}>READY</div>
                    </div>
                  </div>
                  <div style={{ flex: 1, minWidth: '220px' }}>
                    {checks.map((c, i) => (
                      <div key={i} style={{ display: 'flex', alignItems: 'center', gap: '8px', padding: '6px 0', borderBottom: i < checks.length - 1 ? '1px dashed #E5E7EB' : 'none' }}>
                        <div style={{
                          width: 16, height: 16, borderRadius: '50%',
                          background: c.ok ? '#0A8C6D' : '#FCA5A5',
                          color: '#fff', fontSize: 10, fontWeight: 700,
                          display: 'flex', alignItems: 'center', justifyContent: 'center',
                        }}>
                          {c.ok ? '✓' : '!'}
                        </div>
                        <div style={{ fontSize: '11px', color: '#374151' }}>{c.label}</div>
                      </div>
                    ))}
                  </div>
                </div>
              </div>

              <div style={card}>
                <div style={sectionTitle}>Inactivity countdown</div>
                {inactivity.budget > 0 ? (
                  <>
                    <div style={{ fontSize: '11px', color: '#6B7280', marginBottom: '6px' }}>
                      {inactivity.days_used} of {inactivity.budget} day{inactivity.budget === 1 ? '' : 's'} used
                    </div>
                    <div style={{ height: '14px', background: '#F1F5F4', borderRadius: '7px', overflow: 'hidden', marginBottom: '12px' }}>
                      <div style={{
                        width: `${inactivity.percent_used}%`, height: '100%',
                        background: inactivity.percent_used >= 80 ? 'linear-gradient(90deg,#DC2626,#F59E0B)'
                                  : inactivity.percent_used >= 50 ? 'linear-gradient(90deg,#F59E0B,#FBBF24)'
                                  : 'linear-gradient(90deg, #0A8C6D, #10A17F)',
                        transition: 'width 0.4s ease',
                      }} />
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '10px', color: '#6B7280' }}>
                      <span>0%</span><span style={{ fontWeight: 600, color: '#1f2937' }}>{inactivity.percent_used}% used</span><span>100%</span>
                    </div>
                    <div style={{ marginTop: '14px', padding: '10px', background: '#FAFBFC', borderRadius: '8px', fontSize: '11px', color: '#374151' }}>
                      {inactivity.days_remaining > 0
                        ? <>You have <strong style={{ color: '#0A8C6D' }}>{inactivity.days_remaining} day{inactivity.days_remaining === 1 ? '' : 's'}</strong> left before your account is auto-flagged.</>
                        : <>Inactivity budget exhausted. Account will be flagged on next cron sweep.</>}
                    </div>
                  </>
                ) : (
                  <div style={{ padding: '16px', textAlign: 'center', color: '#6B7280', fontSize: '11px' }}>
                    Configure the Inactivity rule on the Manage Death Rules page to start tracking your countdown.
                  </div>
                )}
              </div>
            </div>

            {/* SECOND GRID — Types + notifications */}
            <div className="dash-grid-2" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', marginBottom: '16px' }}>
              <div style={card}>
                <div style={sectionTitle}>Asset type breakdown</div>
                {Object.keys(typeCounts).length === 0 ? (
                  <div style={{ padding: '16px', textAlign: 'center', color: '#666', fontSize: '11px' }}>No assets yet.</div>
                ) : (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                    {Object.entries(typeCounts).map(([type, count]) => {
                      const pct = (count / maxType) * 100;
                      return (
                        <div key={type} style={{ display: 'grid', gridTemplateColumns: '90px 1fr 30px', gap: '8px', alignItems: 'center' }}>
                          <div style={{ fontSize: '11px', color: '#374151', fontWeight: 600 }}>{ASSET_TYPE_LABEL[type] || type}</div>
                          <div style={{ height: '10px', background: '#F1F5F4', borderRadius: '6px', overflow: 'hidden' }}>
                            <div style={{ width: `${pct}%`, height: '100%', background: 'linear-gradient(90deg, #0A8C6D, #10A17F)', borderRadius: '6px', transition: 'width 0.4s ease' }} />
                          </div>
                          <div style={{ fontSize: '11px', color: '#0A8C6D', fontWeight: 700, textAlign: 'right' }}>{count}</div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>

              <div style={card}>
                <div style={sectionTitle}>Notifications by category</div>
                {Object.keys(data.notifications.by_category).length === 0 ? (
                  <div style={{ padding: '16px', textAlign: 'center', color: '#666', fontSize: '11px' }}>No notifications dispatched yet.</div>
                ) : (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                    {Object.entries(data.notifications.by_category).map(([cat, counts]) => (
                      <div key={cat} style={{ display: 'grid', gridTemplateColumns: '1fr auto auto auto', gap: '10px', padding: '8px 10px', border: '1px solid #E5E7EB', borderRadius: '8px', alignItems: 'center', fontSize: '11px' }}>
                        <div style={{ fontWeight: 600, color: '#374151' }}>{CATEGORY_LABEL[cat] || cat}</div>
                        <div style={{ color: '#0A8C6D' }}>✓ {counts.sent || 0}</div>
                        <div style={{ color: '#B91C1C' }}>✗ {counts.failed || 0}</div>
                        <div style={{ color: '#6B7280' }}>… {counts.queued || 0}</div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>

            {/* THIRD GRID — rules + recent activity */}
            <div className="dash-grid-2" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', marginBottom: '16px' }}>
              <div style={card}>
                <div style={sectionTitle}>Active death rules</div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                  <div style={{ padding: '10px', border: '1px solid #E5E7EB', borderRadius: '8px', background: '#FAFBFC' }}>
                    <div style={{ fontSize: '10px', color: '#6B7280', fontWeight: 600, letterSpacing: '0.4px', textTransform: 'uppercase' }}>Rule 1 · Trusted Contacts</div>
                    <div style={{ fontSize: '13px', color: '#1f2937', marginTop: '4px', fontWeight: 600 }}>
                      Quorum of {data.death_rules.quorum?.quorum_required ?? '—'} contact{data.death_rules.quorum?.quorum_required === 1 ? '' : 's'}
                    </div>
                    <div style={{ fontSize: '10px', color: '#6B7280', marginTop: '2px' }}>
                      Grace period: {data.death_rules.quorum?.grace_period_days ?? 7} days · {data.death_rules.quorum?.is_active ? 'Active' : 'Not configured'}
                    </div>
                  </div>
                  <div style={{ padding: '10px', border: '1px solid #E5E7EB', borderRadius: '8px', background: '#FAFBFC' }}>
                    <div style={{ fontSize: '10px', color: '#6B7280', fontWeight: 600, letterSpacing: '0.4px', textTransform: 'uppercase' }}>Rule 2 · Inactivity</div>
                    <div style={{ fontSize: '13px', color: '#1f2937', marginTop: '4px', fontWeight: 600 }}>
                      Pronounce after {data.death_rules.inactivity?.inactivity_days ?? '—'} days
                    </div>
                    <div style={{ fontSize: '10px', color: '#6B7280', marginTop: '2px' }}>
                      {data.death_rules.reminders_configured} reminder{data.death_rules.reminders_configured === 1 ? '' : 's'} · Grace: {data.death_rules.inactivity?.grace_period_days ?? 7} days · {data.death_rules.inactivity?.is_active ? 'Active' : 'Not configured'}
                    </div>
                  </div>
                </div>
              </div>

              <div style={card}>
                <div style={sectionTitle}>Recent status transitions</div>
                {data.recent_transitions.length === 0 ? (
                  <div style={{ padding: '16px', textAlign: 'center', color: '#666', fontSize: '11px' }}>No transitions yet.</div>
                ) : (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                    {data.recent_transitions.map((t) => (
                      <div key={t.transition_id} style={{ padding: '8px 10px', border: '1px solid #E5E7EB', borderRadius: '8px', background: '#FAFBFC' }}>
                        <div style={{ fontSize: '11px', fontWeight: 600, color: '#1f2937' }}>
                          <span style={{ color: STATUS_COLORS[t.from_status] }}>{t.from_status}</span>
                          {' → '}
                          <span style={{ color: STATUS_COLORS[t.to_status] }}>{t.to_status}</span>
                        </div>
                        <div style={{ fontSize: '10px', color: '#6B7280', marginTop: '2px' }}>{t.triggered_by} · {fmt(t.transitioned_at)}</div>
                        {t.notes ? <div style={{ fontSize: '10px', color: '#9CA3AF', marginTop: '2px' }}>{t.notes}</div> : null}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>

            {/* FOURTH GRID — recent notifications + open verifications */}
            <div className="dash-grid-2" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', marginBottom: '16px' }}>
              <div style={card}>
                <div style={sectionTitle}>Recent notifications</div>
                {data.recent_notifications.length === 0 ? (
                  <div style={{ padding: '16px', textAlign: 'center', color: '#666', fontSize: '11px' }}>No notifications yet.</div>
                ) : (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                    {data.recent_notifications.map((n) => (
                      <div key={n.notification_id} style={{ padding: '8px 10px', border: '1px solid #E5E7EB', borderRadius: '8px', background: '#FAFBFC' }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', gap: '8px', alignItems: 'center' }}>
                          <div style={{ fontSize: '11px', fontWeight: 600, color: '#1f2937', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{n.subject}</div>
                          <span style={{
                            fontSize: '9px', padding: '2px 8px', borderRadius: '999px', fontWeight: 700,
                            background: n.status === 'sent' ? '#E7F6F1' : n.status === 'failed' ? '#FEF2F2' : '#F3F4F6',
                            color:      n.status === 'sent' ? '#0A8C6D' : n.status === 'failed' ? '#B91C1C' : '#6B7280',
                          }}>{(n.status || '').toUpperCase()}</span>
                        </div>
                        <div style={{ fontSize: '10px', color: '#6B7280', marginTop: '2px' }}>
                          {n.recipient_email} · {CATEGORY_LABEL[n.category] || n.category} · {fmt(n.sent_at || n.created_at)}
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              <div style={card}>
                <div style={sectionTitle}>Open death verifications</div>
                {data.open_verifications.length === 0 ? (
                  <div style={{ padding: '16px', textAlign: 'center', color: '#0A8C6D', fontSize: '11px' }}>
                    No active verification — you're in good standing.
                  </div>
                ) : (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                    {data.open_verifications.map((v) => (
                      <div key={v.verification_id} style={{ padding: '10px', border: '1px solid #FDE68A', borderRadius: '8px', background: '#FFFBEB' }}>
                        <div style={{ fontSize: '11px', fontWeight: 600, color: '#92400E' }}>
                          {v.trigger_source} → {v.status}
                        </div>
                        <div style={{ fontSize: '10px', color: '#92400E', marginTop: '4px' }}>
                          Confirmations: {v.confirmations_received} / {v.confirmations_required}
                        </div>
                        <div style={{ fontSize: '10px', color: '#6B7280', marginTop: '2px' }}>
                          Started {fmt(v.initiated_at)} · Expires {fmt(v.expires_at)}
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>

            {/* LIFECYCLE + TIPS */}
            <div className="dash-grid-2" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
              <div style={card}>
                <div style={sectionTitle}>Lifecycle stages</div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                  {[
                    { label: 'Active', desc: 'Account is healthy and being checked in.', color: STATUS_COLORS.Active },
                    { label: 'Flagged', desc: 'Inactivity threshold crossed; reminders sent.', color: STATUS_COLORS.Flagged },
                    { label: 'Pending_Verification', desc: 'Trusted contacts are reviewing.', color: STATUS_COLORS.Pending_Verification },
                    { label: 'Deceased', desc: 'Quorum confirmed; execution jobs queued.', color: STATUS_COLORS.Deceased },
                    { label: 'Executed', desc: 'Assets delivered to beneficiaries.', color: STATUS_COLORS.Executed },
                  ].map((s, i, arr) => (
                    <div key={i} style={{ display: 'flex', alignItems: 'center', gap: '10px', padding: '6px 0', borderBottom: i < arr.length - 1 ? '1px dashed #E5E7EB' : 'none' }}>
                      <div style={{ width: 8, height: 8, borderRadius: '50%', background: s.color, flexShrink: 0 }} />
                      <div style={{ flex: 1 }}>
                        <div style={{ fontSize: '11px', fontWeight: 600, color: '#1f2937' }}>{s.label.replace('_', ' ')}</div>
                        <div style={{ fontSize: '10px', color: '#6B7280' }}>{s.desc}</div>
                      </div>
                      {accountStatus === s.label ? (
                        <div style={{ fontSize: '9px', fontWeight: 700, color: s.color, letterSpacing: '0.4px' }}>YOU ARE HERE</div>
                      ) : null}
                    </div>
                  ))}
                </div>
              </div>

              <div style={card}>
                <div style={sectionTitle}>Account info</div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '11px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', padding: '6px 0', borderBottom: '1px dashed #E5E7EB' }}>
                    <span style={{ color: '#6B7280' }}>Email</span>
                    <span style={{ color: '#1f2937', fontWeight: 600 }}>{data.user.email}</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', padding: '6px 0', borderBottom: '1px dashed #E5E7EB' }}>
                    <span style={{ color: '#6B7280' }}>Member since</span>
                    <span style={{ color: '#1f2937', fontWeight: 600 }}>{fmtDate(data.user.created_at)}</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', padding: '6px 0', borderBottom: '1px dashed #E5E7EB' }}>
                    <span style={{ color: '#6B7280' }}>Last check-in</span>
                    <span style={{ color: '#1f2937', fontWeight: 600 }}>{fmt(data.user.last_checkin_at)}</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', padding: '6px 0', borderBottom: '1px dashed #E5E7EB' }}>
                    <span style={{ color: '#6B7280' }}>Days since check-in</span>
                    <span style={{ color: '#1f2937', fontWeight: 600 }}>{data.user.days_since_checkin ?? 0}</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', padding: '6px 0' }}>
                    <span style={{ color: '#6B7280' }}>Unique beneficiaries</span>
                    <span style={{ color: '#1f2937', fontWeight: 600 }}>{data.beneficiaries.unique_count}</span>
                  </div>
                </div>
              </div>
            </div>
          </>
        )}
      </div>
    </>
  );
}
