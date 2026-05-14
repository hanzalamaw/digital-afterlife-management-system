import { useState, useEffect, useRef } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import './Sidebar.css';

import dashboardIcon from '../assets/dashboard.png';
import dashboardActiveIcon from '../assets/dashboard-active.png';
import newAssetsIcon from '../assets/new-assets.png';
import newAssetsActiveIcon from '../assets/new-assets-active.png';
import manageAssetsIcon from '../assets/asset-management.png';
import manageAssetsActiveIcon from '../assets/asset-management-active.png';
import contactsIcon from '../assets/trusted-contacts.png';
import contactsActiveIcon from '../assets/trusted-contacts-active.png';

const LogoutIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
    <polyline points="16 17 21 12 16 7" />
    <line x1="21" y1="12" x2="9" y2="12" />
  </svg>
);
const ChevronIcon = ({ direction = 'right' }) => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"
    style={{ transform: direction === 'left' ? 'rotate(180deg)' : 'none', transition: 'transform 0.3s ease' }}>
    <polyline points="9 18 15 12 9 6" />
  </svg>
);
const HamburgerIcon = ({ isOpen }) => (
  <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round">
    {isOpen ? (
      <>
        <line x1="18" y1="6" x2="6" y2="18" />
        <line x1="6" y1="6" x2="18" y2="18" />
      </>
    ) : (
      <>
        <line x1="3" y1="6" x2="21" y2="6" />
        <line x1="3" y1="12" x2="21" y2="12" />
        <line x1="3" y1="18" x2="21" y2="18" />
      </>
    )}
  </svg>
);

const MENU_ITEMS = [
  { id: 'dashboard', label: 'Dashboard', iconDefault: dashboardIcon, iconActive: dashboardActiveIcon, path: '/dashboard' },
  { id: 'new-assets', label: 'New Assets', iconDefault: newAssetsIcon, iconActive: newAssetsActiveIcon, path: '/assets/new' },
  { id: 'manage-assets', label: 'Manage Assets', iconDefault: manageAssetsIcon, iconActive: manageAssetsActiveIcon, path: '/assets/manage' },
  { id: 'contacts', label: 'Manage Death Rules', iconDefault: contactsIcon, iconActive: contactsActiveIcon, path: '/contacts/manage' },
];

const SIDEBAR_EXPANDED_KEY = 'dams_sidebar_expanded';

function readSidebarExpanded() {
  try {
    return sessionStorage.getItem(SIDEBAR_EXPANDED_KEY) === '1';
  } catch {
    return false;
  }
}

function Sidebar({ onExpandChange }) {
  const [isExpanded, setIsExpanded] = useState(readSidebarExpanded);
  const [mobileOpen, setMobileOpen] = useState(false);
  const [isMobile, setIsMobile] = useState(false);
  const drawerRef = useRef(null);
  const navigate = useNavigate();
  const location = useLocation();
  const { user, logout } = useAuth();

  const isActive = (path) => location.pathname === path || location.pathname.startsWith(path + '/');
  const sectionLabel = 'MANAGEMENT';

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const handleNavigate = (path) => {
    navigate(path);
    if (isMobile) setMobileOpen(false);
  };

  useEffect(() => {
    const check = () => setIsMobile(window.innerWidth < 768);
    check();
    window.addEventListener('resize', check);
    return () => window.removeEventListener('resize', check);
  }, []);

  useEffect(() => {
    if (!mobileOpen) return;
    const handler = (e) => {
      if (drawerRef.current && !drawerRef.current.contains(e.target)) setMobileOpen(false);
    };
    document.addEventListener('mousedown', handler);
    document.addEventListener('touchstart', handler);
    return () => {
      document.removeEventListener('mousedown', handler);
      document.removeEventListener('touchstart', handler);
    };
  }, [mobileOpen]);

  useEffect(() => {
    if (isMobile) document.body.style.overflow = mobileOpen ? 'hidden' : '';
    return () => { document.body.style.overflow = ''; };
  }, [mobileOpen, isMobile]);

  useEffect(() => {
    try {
      sessionStorage.setItem(SIDEBAR_EXPANDED_KEY, isExpanded ? '1' : '0');
    } catch {
      // ignore
    }
  }, [isExpanded]);

  useEffect(() => {
    if (onExpandChange) onExpandChange(!isMobile && isExpanded);
  }, [isExpanded, isMobile, onExpandChange]);

  if (isMobile) {
    return (
      <>
        {!mobileOpen && (
          <button className="mobile-fab" onClick={() => setMobileOpen(true)} aria-label="Open menu">
            <HamburgerIcon isOpen={false} />
          </button>
        )}

        <div className={`mobile-overlay ${mobileOpen ? 'visible' : ''}`} onClick={() => setMobileOpen(false)} />

        <aside ref={drawerRef} className={`mobile-drawer ${mobileOpen ? 'open' : ''}`}>
          <div className="drawer-header">
            <div className="drawer-profile">
              <div className="drawer-avatar">
                <img src="https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop&crop=face" alt="Profile" />
              </div>
              <div className="drawer-user-info">
                <span className="drawer-role">{user?.is_admin ? 'ADMIN' : 'USER'}</span>
                <span className="drawer-name">{user?.full_name || 'User'}</span>
              </div>
            </div>
            <button className="drawer-close" onClick={() => setMobileOpen(false)} aria-label="Close menu">
              <HamburgerIcon isOpen />
            </button>
          </div>

          <div className="drawer-section-label">{sectionLabel}</div>

          <nav className="drawer-nav">
            <ul className="drawer-nav-list">
              {MENU_ITEMS.map((item, idx) => (
                <li key={item.id} className={`drawer-nav-item ${isActive(item.path) ? 'active' : ''}`} style={{ animationDelay: `${idx * 40}ms` }}>
                  <button type="button" className={`drawer-nav-link ${isActive(item.path) ? 'active' : ''}`} onClick={() => handleNavigate(item.path)}>
                    <span className="drawer-nav-icon">
                      <img src={isActive(item.path) ? item.iconActive : item.iconDefault} alt="" style={{ width: '20px', height: '20px' }} />
                    </span>
                    <span className="drawer-nav-label">{item.label}</span>
                    {isActive(item.path) && <span className="drawer-active-dot" />}
                  </button>
                </li>
              ))}
            </ul>
          </nav>

          <div className="drawer-footer">
            <button type="button" className="drawer-logout-btn" onClick={handleLogout}>
              <LogoutIcon />
              <span>Logout</span>
            </button>
          </div>
        </aside>
      </>
    );
  }

  return (
    <aside className={`sidebar ${isExpanded ? 'expanded' : 'collapsed'} sidebar--module`}>
      <div className="sidebar-profile">
        <div className="profile-avatar">
          <img src="https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop&crop=face" alt="Profile" />
        </div>
        {isExpanded && (
          <div className="profile-info">
            <span className="profile-role">{user?.is_admin ? 'ADMIN' : 'USER'}</span>
            <span className="profile-name">{user?.full_name || 'User'}</span>
            <button type="button" className="logout-btn" onClick={handleLogout}>
              <LogoutIcon />
              <span>Logout</span>
            </button>
          </div>
        )}
        {!isExpanded && (
          <button type="button" className="logout-btn-collapsed" onClick={handleLogout} title="Logout">
            <LogoutIcon />
          </button>
        )}
        <button type="button" className="toggle-btn" onClick={() => setIsExpanded(!isExpanded)} aria-label={isExpanded ? 'Collapse sidebar' : 'Expand sidebar'}>
          <ChevronIcon direction={isExpanded ? 'left' : 'right'} />
        </button>
      </div>

      <nav className="sidebar-nav">
        <span className="nav-section-label">{isExpanded ? sectionLabel : ''}</span>
        <ul className="nav-list">
          {MENU_ITEMS.map((item) => (
            <li key={item.id} className={`nav-item ${isActive(item.path) ? 'active' : ''}`}>
              <button type="button" className={`nav-link ${isActive(item.path) ? 'active' : ''}`} onClick={() => navigate(item.path)}>
                <span className="nav-icon nav-icon-main">
                  <img src={isActive(item.path) ? item.iconActive : item.iconDefault} alt="" style={{ width: '20px', height: '20px', display: 'block' }} />
                </span>
                {isExpanded && <span className="nav-label">{item.label}</span>}
              </button>
            </li>
          ))}
        </ul>
      </nav>
    </aside>
  );
}

export default Sidebar;

