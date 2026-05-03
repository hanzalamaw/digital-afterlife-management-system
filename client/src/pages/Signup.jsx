import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import api, { getApiErrorMessage } from '../utils/api';
import loginImage from '../assets/login-page-image.png';

const COUNTRIES = [
  'Pakistan','United States','United Kingdom','Canada','Australia','Germany',
  'France','India','UAE','Saudi Arabia','Singapore','Malaysia','Other'
];

export default function Signup() {
  const [form, setForm] = useState({
    full_name: '', email: '', password: '', confirm_password: '',
    date_of_birth: '', phone_number: '', country: '', recovery_email: '',
  });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const { login } = useAuth();
  const navigate = useNavigate();

  const handleChange = (e) => setForm({ ...form, [e.target.name]: e.target.value });

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    if (form.password !== form.confirm_password) {
      setError('Passwords do not match');
      return;
    }
    setLoading(true);
    try {
      const { confirm_password, ...payload } = form;
      const res = await api.post('/api/auth/register', payload);
      let token = res?.data?.token;
      let user = res?.data?.user;

      // Compatibility fallback: if register endpoint does not return auth payload, log in immediately.
      if (!token || !user) {
        const loginRes = await api.post('/api/auth/login', {
          email: form.email,
          password: form.password,
        });
        token = loginRes?.data?.token;
        user = loginRes?.data?.user;
      }

      if (!token || !user) {
        throw new Error('Account created, but automatic sign-in failed. Please log in.');
      }

      login(token, user);
      navigate('/dashboard', {
        state: { successMessage: 'Account created successfully. You are now signed in.' },
      });
    } catch (err) {
      setError(getApiErrorMessage(err, 'Registration failed. Please try again.'));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth-page">
      <div className="auth-bg-card auth-bg-card-one" />
      <div className="auth-bg-card auth-bg-card-two" />

      <div className="auth-main-card">
        <div className="auth-left">
          <div className="auth-form-card signup-card">
            <p className="auth-logo-text">Your logo</p>
            <h1 className="auth-title">Create account</h1>

            {error && <div className="alert alert-danger">{error}</div>}

            <form className="form" onSubmit={handleSubmit} autoComplete="off">
              <div className="grid-2 signup-grid">
                <div className="field compact">
                  <label>Full name</label>
                  <input type="text" name="full_name" value={form.full_name} onChange={handleChange} required autoComplete="off" />
                </div>
                <div className="field compact">
                  <label>Email</label>
                  <input type="email" name="email" value={form.email} onChange={handleChange} required autoComplete="off" />
                </div>
                <div className="field compact">
                  <label>Password</label>
                  <input type="password" name="password" value={form.password} onChange={handleChange} minLength={8} required autoComplete="off" />
                </div>
                <div className="field compact">
                  <label>Confirm password</label>
                  <input type="password" name="confirm_password" value={form.confirm_password} onChange={handleChange} required autoComplete="off" />
                </div>
                <div className="field compact">
                  <label>Date of birth</label>
                  <input type="date" name="date_of_birth" value={form.date_of_birth} onChange={handleChange} required autoComplete="off" />
                </div>
                <div className="field compact">
                  <label>Phone</label>
                  <input type="tel" name="phone_number" value={form.phone_number} onChange={handleChange} required autoComplete="off" />
                </div>
                <div className="field compact">
                  <label>Country</label>
                  <select name="country" value={form.country} onChange={handleChange} required autoComplete="off">
                    <option value="">Select country…</option>
                    {COUNTRIES.map((c) => <option key={c} value={c}>{c}</option>)}
                  </select>
                </div>
                <div className="field compact">
                  <label>Recovery email</label>
                  <input type="email" name="recovery_email" value={form.recovery_email} onChange={handleChange} required autoComplete="off" />
                </div>
              </div>

              <button type="submit" disabled={loading} className="btn-primary full auth-submit">
                {loading ? 'Creating...' : 'Create account'}
              </button>
            </form>

            <p className="auth-footer centered">
              Already have an account? <Link to="/login">Sign in</Link>
            </p>
          </div>
        </div>

        <div className="auth-right">
          <img src={loginImage} alt="Signup visual" />
        </div>
      </div>
    </div>
  );
}