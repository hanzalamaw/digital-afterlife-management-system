import axios from 'axios';

const explicitBaseURL =
  typeof import.meta !== 'undefined' && import.meta.env && import.meta.env.VITE_API_BASE_URL
    ? import.meta.env.VITE_API_BASE_URL.trim()
    : '';

const inferLocalXamppBaseURL = () => {
  if (typeof window === 'undefined') return '';
  if (window.location.hostname !== 'localhost') return '';

  const firstPathPart = window.location.pathname.split('/').filter(Boolean)[0];
  if (!firstPathPart || firstPathPart === 'client') return '';

  return `${window.location.origin}/${firstPathPart}/server`;
};

const apiBaseURL = (explicitBaseURL || inferLocalXamppBaseURL() || 'http://localhost:8000').replace(/\/+$/, '');

const api = axios.create({
  baseURL: apiBaseURL,
  headers: { 'X-Client': 'DAMS-React' },
});

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('dams_token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

export function getApiErrorMessage(error, fallback = 'Something went wrong. Please try again.') {
  const data = error?.response?.data;
  const status = error?.response?.status;

  if (typeof data === 'string' && data.trim()) {
    return status && status >= 500
      ? 'Server error. Please check backend logs and try again.'
      : data.trim();
  }

  if (data?.error && typeof data.error === 'string') {
    return data.error;
  }

  if (error?.code === 'ERR_NETWORK') {
    return 'Cannot reach the server. Ensure PHP server is running on http://localhost:8000.';
  }

  if (!error?.response && error?.message) {
    return 'Request failed. Check API base URL and server status.';
  }

  return fallback;
}

export default api;