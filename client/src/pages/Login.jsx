import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import api, { getApiErrorMessage } from '../utils/api';
import loginImage from '../assets/login-page-image.png';

export default function Login() {
  const [form, setForm] = useState({ email: '', password: '' });
  const [error, setError] = useState('');
  const [fieldErrors, setFieldErrors] = useState({ email: '', password: '' });
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const { login } = useAuth();
  const navigate = useNavigate();

  const handleChange = (e) => setForm({ ...form, [e.target.name]: e.target.value });

  const validateField = (name, value) => {
    if (!String(value || '').trim()) {
      setFieldErrors((prev) => ({ ...prev, [name]: 'Please fill out this field.' }));
      return false;
    }
    if (name === 'email' && String(value).length < 3) {
      setFieldErrors((prev) => ({ ...prev, [name]: 'Email must be at least 3 characters.' }));
      return false;
    }
    setFieldErrors((prev) => ({ ...prev, [name]: '' }));
    return true;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    const okEmail = validateField('email', form.email);
    const okPass = validateField('password', form.password);
    if (!okEmail || !okPass) { setLoading(false); return; }
    try {
      const res = await api.post('/api/auth/login', form);
      const token = res?.data?.token;
      const user = res?.data?.user;
      if (!token || !user) {
        throw new Error('Login succeeded but response is missing token/user. Check API base URL.');
      }
      login(token, user);
      navigate('/dashboard');
    } catch (err) {
      setError(getApiErrorMessage(err, 'Login failed. Please try again.'));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'center',
      minHeight: '100vh',
      width: '100%',
      background: '#FFFFFF',
      fontFamily: "'Poppins', 'Inter', sans-serif",
      padding: '20px 12px',
      boxSizing: 'border-box',
    }}>

      <div className="login-grid" style={{
        display: 'grid',
        width: '100%',
        maxWidth: '720px',
      }}>

        {/* Back Card 2 */}
        <div style={{
          gridArea: '1 / 1',
          background: '#D9EFE7',
          borderRadius: '24px',
          transform: 'rotate(2deg) translate(6px, 8px)',
          animation: 'cardDrift1 6s ease-in-out infinite',
          zIndex: 0
        }} />

        {/* Back Card 1 */}
        <div style={{
          gridArea: '1 / 1',
          background: '#EAF7F3',
          borderRadius: '22px',
          transform: 'rotate(-1.5deg) translate(-5px, -6px)',
          animation: 'cardDrift2 5s ease-in-out infinite',
          zIndex: 1
        }} />

        {/* Main White Card */}
        <div style={{
          gridArea: '1 / 1',
          background: '#FFFFFF',
          borderRadius: '20px',
          width: '100%',
          display: 'flex',
          flexDirection: 'row',
          flexWrap: 'wrap',
          overflow: 'hidden',
          position: 'relative',
          padding: '24px',
          boxSizing: 'border-box',
          alignItems: 'center',
          zIndex: 2,
          boxShadow: '0 5px 25px rgba(0,0,0,0.04)'
        }}>

          {/* Inner Login Card */}
          <div className="login-inner-card" style={{
            background: '#FFFFFF',
            borderRadius: '16px',
            boxShadow: '0 8px 30px rgba(0,0,0,0.06)',
            padding: '28px',
            width: '100%',
            maxWidth: '300px',
            zIndex: 3,
            display: 'flex',
            flexDirection: 'column',
            boxSizing: 'border-box',
            margin: '0 auto'
          }}>
            <div style={{ marginBottom: '16px' }}>
              <p style={{ color: '#0A8C6D', fontSize: '12px', fontWeight: '500', margin: '0 0 4px 0' }}>Your logo</p>
              <h1 style={{ fontSize: '24px', fontWeight: '700', color: '#333', margin: 0 }}>Login</h1>
            </div>

            {error && (
              <div style={{
                background: '#F0FDF4',
                color: '#0A8C6D',
                padding: '8px',
                borderRadius: '6px',
                fontSize: '10px',
                marginBottom: '14px',
                border: '1px solid #BBF7D0'
              }}>
                {error}
              </div>
            )}

            <form onSubmit={handleSubmit} noValidate autoComplete="off">
              <div style={{ marginBottom: '14px', position: 'relative' }}>
                <label style={{ display: 'block', fontSize: '11px', color: '#888', marginBottom: '5px' }}>Email</label>
                <input
                  type="email"
                  name="email"
                  placeholder="username@gmail.com"
                  value={form.email}
                  onChange={(e) => {
                    handleChange(e);
                    if (fieldErrors.email) validateField('email', e.target.value);
                  }}
                  onBlur={(e) => validateField('email', e.target.value)}
                  autoComplete="off"
                  style={{
                    width: '100%',
                    padding: '9px 12px',
                    borderRadius: '6px',
                    border: fieldErrors.email ? '1px solid #0A8C6D' : '1px solid #F0F0F0',
                    fontSize: '10px',
                    outline: 'none',
                    background: '#FAFAFA',
                    boxSizing: 'border-box',
                    transition: 'border-color 0.2s'
                  }}
                />
              </div>

              <div style={{ marginBottom: '6px', position: 'relative' }}>
                <label style={{ display: 'block', fontSize: '11px', color: '#888', marginBottom: '5px' }}>Password</label>
                <input
                  type={showPassword ? 'text' : 'password'}
                  name="password"
                  placeholder="Password"
                  value={form.password}
                  onChange={(e) => {
                    handleChange(e);
                    if (fieldErrors.password) validateField('password', e.target.value);
                  }}
                  onBlur={(e) => validateField('password', e.target.value)}
                  autoComplete="off"
                  style={{
                    width: '100%',
                    padding: '9px 12px',
                    borderRadius: '6px',
                    border: fieldErrors.password ? '1px solid #0A8C6D' : '1px solid #F0F0F0',
                    fontSize: '10px',
                    outline: 'none',
                    background: '#FAFAFA',
                    boxSizing: 'border-box',
                    transition: 'border-color 0.2s'
                  }}
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  style={{
                    position: 'absolute',
                    right: '10px',
                    top: '30px',
                    background: 'none',
                    border: 'none',
                    cursor: 'pointer',
                    color: '#CCC',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    padding: 0
                  }}
                >
                  {showPassword ? (
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"></path><line x1="1" y1="1" x2="23" y2="23"></line></svg>
                  ) : (
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path><circle cx="12" cy="12" r="3"></circle></svg>
                  )}
                </button>
              </div>

              <div style={{ textAlign: 'right', marginBottom: '16px' }}>
                <button
                  type="button"
                  onClick={() => navigate('/signup')}
                  style={{
                    background: 'none',
                    border: 'none',
                    color: '#0A8C6D',
                    fontSize: '11px',
                    textDecoration: 'none',
                    fontWeight: '500',
                    cursor: 'pointer',
                    padding: 0
                  }}
                >
                  Forgot Password?
                </button>
              </div>

              <button
                type="submit"
                disabled={loading}
                style={{
                  width: '100%',
                  padding: '10px',
                  background: '#0A8C6D',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '6px',
                  fontSize: '13px',
                  fontWeight: '600',
                  cursor: loading ? 'not-allowed' : 'pointer',
                  marginBottom: '16px'
                }}
              >
                {loading ? 'Signing in...' : 'Sign in'}
              </button>
            </form>

            <p style={{ textAlign: 'center', fontSize: '11px', color: '#777', margin: 0 }}>
              Don&apos;t have an account? <Link to="/signup" style={{ color: '#0A8C6D', fontWeight: 600, textDecoration: 'none' }}>Register</Link>
            </p>
          </div>

          {/* Right Side - Image Area — hidden on small screens */}
          <div className="login-image-panel" style={{
            flex: '1',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            position: 'relative',
            paddingLeft: '30px',
            minWidth: '220px'
          }}>
            <img
              src={loginImage}
              alt="Login visual"
              style={{
                width: '100%',
                height: 'auto',
                maxWidth: '450px',
                objectFit: 'contain',
                zIndex: 1
              }}
            />
            <div style={{ position: 'absolute', top: '15%', right: '15%', width: '10px', height: '10px', background: '#0A8C6D', borderRadius: '50%', opacity: 0.18 }} />
            <div style={{ position: 'absolute', top: '10%', left: '35%', width: '7px', height: '7px', background: '#0A8C6D', borderRadius: '50%', opacity: 0.12 }} />
            <div style={{ position: 'absolute', bottom: '20%', left: '30%', width: '9px', height: '9px', background: '#0A8C6D', borderRadius: '50%', opacity: 0.14 }} />
          </div>
        </div>
      </div>

      <style>{`
        @keyframes cardDrift1 {
          0%, 100% { transform: rotate(2deg) translate(6px, 8px); }
          50% { transform: rotate(3deg) translate(10px, -4px); }
        }
        @keyframes cardDrift2 {
          0%, 100% { transform: rotate(-1.5deg) translate(-5px, -6px); }
          50% { transform: rotate(-2.5deg) translate(-8px, 6px); }
        }

        /* Hide image panel below 700px */
        @media (max-width: 700px) {
          .login-image-panel {
            display: none !important;
          }
        }

        /* Mobile: fluid width on every phone, taller via padding */
        @media (max-width: 480px) {
          .login-grid {
            width: calc(100vw - 48px) !important;
            max-width: 340px !important;
          }
          .login-inner-card {
            max-width: 100% !important;
            padding: 32px 20px 44px !important;
            box-shadow: none !important;
          }
        }
      `}</style>
    </div>
  );
}