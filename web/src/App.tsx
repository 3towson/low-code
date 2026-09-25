import { useState } from "react";
import { AppProvider, useApp } from "./context/AppContext";
import { Navbar } from "./components/Navbar";
import { CheckPanel } from "./components/CheckPanel";
import { SettingsModal } from "./components/SettingsModal";
import { AuthModal } from "./components/AuthModal";
import { ReportModal } from "./components/ReportModal";
import { Store, ShieldCheck, TrendingUp, AlertOctagon } from "lucide-react";

function MainContent() {
  const { strings, user } = useApp();
  const [authOpen, setAuthOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [reportOpen, setReportOpen] = useState(false);

  const handleOpenReport = () => {
    if (!user) {
      setAuthOpen(true);
    } else {
      setReportOpen(true);
    }
  };

  return (
    <div className="app-layout">
      <Navbar
        onOpenAuth={() => setAuthOpen(true)}
        onOpenSettings={() => setSettingsOpen(true)}
      />

      <main className="main-content">
        <div className="hero-section">
          <div className="hero-badge">
            <span className="pulse-dot" />
            <span>AI Risk Protection for Online Merchants</span>
          </div>
          <h2 className="hero-title">COD Risk Shield</h2>
          <p className="hero-subtitle">{strings.appSubtitle}</p>
        </div>

        {/* Stats Row */}
        <div className="stats-row">
          <div className="stat-card">
            <div className="stat-icon-box">
              <Store size={20} />
            </div>
            <div className="stat-data">
              <span className="stat-value">{strings.shopsCount}</span>
              <span className="stat-label">{strings.shopsLabel}</span>
            </div>
          </div>

          <div className="stat-card">
            <div className="stat-icon-box">
              <ShieldCheck size={20} />
            </div>
            <div className="stat-data">
              <span className="stat-value">{strings.protectedCount}</span>
              <span className="stat-label">{strings.protectedLabel}</span>
            </div>
          </div>

          <div className="stat-card">
            <div className="stat-icon-box">
              <TrendingUp size={20} />
            </div>
            <div className="stat-data">
              <span className="stat-value">{strings.savedCount}</span>
              <span className="stat-label">{strings.savedLabel}</span>
            </div>
          </div>
        </div>

        {/* Check Customer Panel */}
        <CheckPanel onOpenAuth={() => setAuthOpen(true)} />

        {/* Action Button: Report Customer */}
        <div className="report-cta-container">
          <button
            type="button"
            className="btn btn-outline-danger btn-lg"
            onClick={handleOpenReport}
          >
            <AlertOctagon size={18} />
            <span>{strings.reportCustomer}</span>
          </button>
        </div>
      </main>

      <footer className="app-footer">
        <p>© 2026 COD Risk Shield — ระบบตรวจสอบและป้องกันพัสดุตีกลับสำหรับร้านค้าออนไลน์</p>
      </footer>

      {/* Modals */}
      <AuthModal isOpen={authOpen} onClose={() => setAuthOpen(false)} />
      <SettingsModal isOpen={settingsOpen} onClose={() => setSettingsOpen(false)} />
      <ReportModal isOpen={reportOpen} onClose={() => setReportOpen(false)} />
    </div>
  );
}

export default function App() {
  return (
    <AppProvider>
      <MainContent />
    </AppProvider>
  );
}
