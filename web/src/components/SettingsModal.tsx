import React from "react";
import { useApp } from "../context/AppContext";
import { Settings, X, Palette, Globe, Sun, Moon } from "lucide-react";

interface SettingsModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const SettingsModal: React.FC<SettingsModalProps> = ({ isOpen, onClose }) => {
  const { theme, setTheme, language, setLanguage, strings } = useApp();

  if (!isOpen) return null;

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal-card" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <div className="modal-title-row">
            <div className="modal-icon-badge">
              <Settings size={20} />
            </div>
            <h2>{strings.settingsTitle}</h2>
          </div>
          <button className="icon-btn" onClick={onClose} aria-label={strings.close}>
            <X size={18} />
          </button>
        </div>

        <div className="modal-body">
          {/* Section 1: Theme */}
          <div className="setting-section">
            <div className="section-label-row">
              <Palette size={17} className="accent-icon" />
              <h3>{strings.themeSection}</h3>
            </div>
            <p className="section-desc">{strings.themeDesc}</p>

            <div className="option-grid">
              <button
                type="button"
                className={`option-card ${theme === "light" ? "active" : ""}`}
                onClick={() => setTheme("light")}
              >
                <Sun size={20} />
                <span>{strings.themeLight}</span>
              </button>

              <button
                type="button"
                className={`option-card ${theme === "dark" ? "active" : ""}`}
                onClick={() => setTheme("dark")}
              >
                <Moon size={20} />
                <span>{strings.themeDark}</span>
              </button>
            </div>
          </div>

          {/* Section 2: Language */}
          <div className="setting-section">
            <div className="section-label-row">
              <Globe size={17} className="accent-icon" />
              <h3>{strings.languageSection}</h3>
            </div>
            <p className="section-desc">{strings.languageDesc}</p>

            <div className="option-grid">
              <button
                type="button"
                className={`option-card ${language === "th" ? "active" : ""}`}
                onClick={() => setLanguage("th")}
              >
                <span className="flag-icon">🇹🇭</span>
                <span>ไทย (Thai)</span>
              </button>

              <button
                type="button"
                className={`option-card ${language === "en" ? "active" : ""}`}
                onClick={() => setLanguage("en")}
              >
                <span className="flag-icon">🇺🇸</span>
                <span>English</span>
              </button>
            </div>
          </div>
        </div>

        <div className="modal-footer">
          <button type="button" className="btn btn-primary full-width" onClick={onClose}>
            {strings.close}
          </button>
        </div>
      </div>
    </div>
  );
};
