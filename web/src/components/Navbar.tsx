import React from "react";
import { useApp } from "../context/AppContext";
import { ShieldCheck, Moon, Sun, Settings, LogIn, LogOut, Store } from "lucide-react";

interface NavbarProps {
  onOpenAuth: () => void;
  onOpenSettings: () => void;
}

export const Navbar: React.FC<NavbarProps> = ({ onOpenAuth, onOpenSettings }) => {
  const { theme, toggleTheme, user, shopName, signOut, strings } = useApp();

  return (
    <header className="navbar">
      <div className="navbar-container">
        <div className="brand">
          <div className="logo-box">
            <ShieldCheck className="logo-icon" size={26} />
          </div>
          <div>
            <h1 className="brand-title">COD Risk Shield</h1>
            <p className="brand-subtitle">{strings.appSubtitle}</p>
          </div>
        </div>

        <div className="nav-actions">
          {/* Quick Theme Toggle */}
          <button
            type="button"
            className="icon-btn theme-toggle-btn"
            onClick={toggleTheme}
            title={theme === "dark" ? "เปลี่ยนเป็นธีมสว่าง" : "เปลี่ยนเป็นธีมมืด"}
            aria-label="Toggle Theme"
          >
            {theme === "dark" ? (
              <Sun className="icon sun-icon" size={19} />
            ) : (
              <Moon className="icon moon-icon" size={19} />
            )}
          </button>

          {/* Settings Button */}
          <button
            type="button"
            className="icon-btn"
            onClick={onOpenSettings}
            title={strings.settings}
            aria-label="Open Settings"
          >
            <Settings size={19} />
          </button>

          {/* User / Sign In */}
          {user ? (
            <div className="user-profile">
              <Store size={16} className="user-icon" />
              <span className="user-shop" title={shopName}>{shopName}</span>
              <button
                type="button"
                className="icon-btn logout-btn"
                onClick={signOut}
                title={strings.signOut}
              >
                <LogOut size={16} />
              </button>
            </div>
          ) : (
            <button type="button" className="btn btn-outline" onClick={onOpenAuth}>
              <LogIn size={16} />
              <span>{strings.signIn}</span>
            </button>
          )}
        </div>
      </div>
    </header>
  );
};
