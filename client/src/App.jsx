import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import Login from './pages/Login';
import Signup from './pages/Signup';
import Dashboard from './pages/Dashboard';
import NewAssets from './pages/NewAssets';
import ManageAssets from './pages/ManageAssets';
import Contacts from './pages/Contacts';
import Admin from './pages/Admin';
import AppLayout from './components/AppLayout';

function ProtectedRoute({ children }) {
  const { user, loading } = useAuth();
  if (loading) return <div>Loading DAMS...</div>;
  return user ? children : <Navigate to="/login" replace />;
}

function AdminRoute({ children }) {
  const { user, loading } = useAuth();
  if (loading) return <div>Loading DAMS...</div>;
  if (!user) return <Navigate to="/login" replace />;
  return user.is_admin ? children : <Navigate to="/dashboard" replace />;
}

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/login"     element={<Login />} />
          <Route path="/signup"    element={<Signup />} />
          <Route path="/dashboard" element={
            <ProtectedRoute><AppLayout><Dashboard /></AppLayout></ProtectedRoute>
          } />
          <Route path="/assets/new" element={
            <ProtectedRoute><AppLayout><NewAssets /></AppLayout></ProtectedRoute>
          } />
          <Route path="/assets/manage" element={
            <ProtectedRoute><AppLayout><ManageAssets /></AppLayout></ProtectedRoute>
          } />
          <Route path="/contacts/manage" element={
            <ProtectedRoute><AppLayout><Contacts /></AppLayout></ProtectedRoute>
          } />
          <Route path="/admin" element={
            <AdminRoute><AppLayout><Admin /></AppLayout></AdminRoute>
          } />
          <Route path="*" element={<Navigate to="/dashboard" replace />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}