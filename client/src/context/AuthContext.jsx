import { createContext, useContext, useState, useEffect } from 'react';
import { jwtDecode } from 'jwt-decode';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = localStorage.getItem('dams_token');
    if (token) {
      try {
        const decoded = jwtDecode(token);
        if (decoded.exp * 1000 > Date.now()) setUser(decoded);
        else localStorage.removeItem('dams_token');
      } catch { localStorage.removeItem('dams_token'); }
    }
    setLoading(false);
  }, []);

  const login = (token, userData) => {
    localStorage.setItem('dams_token', token);
    setUser(userData);
  };

  const logout = () => {
    localStorage.removeItem('dams_token');
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ user, login, logout, loading }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);