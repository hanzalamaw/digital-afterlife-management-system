import { useAuth } from '../context/AuthContext';
import Sidebar from './Sidebar';
import { useState } from 'react';

export default function AppLayout({ children }) {
  const [sidebarExpanded, setSidebarExpanded] = useState(false);

  return (
    <div className="app-shell">
      <Sidebar onExpandChange={setSidebarExpanded} />

      <main className={`app-main ${sidebarExpanded ? 'with-sidebar-expanded' : 'with-sidebar-collapsed'}`}>
        <section className="content">
          {children}
        </section>
      </main>
    </div>
  );
}

