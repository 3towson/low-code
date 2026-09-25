import React from "react";
import { useApp } from "../context/AppContext";
import type { CheckSuccess } from "../services/supabase";
import { CheckCircle2, AlertTriangle, XCircle, Flag, Phone, User as UserIcon, Calendar } from "lucide-react";

interface RiskCardProps {
  result: CheckSuccess;
}

export const RiskCard: React.FC<RiskCardProps> = ({ result }) => {
  const { strings, language } = useApp();

  const getLevelConfig = () => {
    switch (result.level) {
      case "green":
        return {
          title: strings.riskLow,
          icon: <CheckCircle2 size={32} className="risk-icon green" />,
          badgeClass: "badge-green",
          cardClass: "card-green",
        };
      case "yellow":
        return {
          title: strings.riskMedium,
          icon: <AlertTriangle size={32} className="risk-icon yellow" />,
          badgeClass: "badge-yellow",
          cardClass: "card-yellow",
        };
      case "red":
        return {
          title: strings.riskHigh,
          icon: <XCircle size={32} className="risk-icon red" />,
          badgeClass: "badge-red",
          cardClass: "card-red",
        };
    }
  };

  const config = getLevelConfig();

  // Localize recommendations if in English mode
  const getLocalizedRecommendation = () => {
    const rec = result.recommendation;
    if (language === "th") {
      return rec;
    }
    if (rec.includes("ส่งได้ตามปกติ")) return strings.recGreen;
    if (rec.includes("ควรโทรหรือทักยืนยันออเดอร์")) return strings.recYellow;
    if (rec.includes("ไม่แนะนำให้ส่งแบบเก็บเงินปลายทาง")) return strings.recRed;
    return rec;
  };

  return (
    <div className={`risk-card ${config.cardClass}`}>
      <div className="risk-card-header">
        <div className="risk-icon-wrapper">{config.icon}</div>
        <div>
          <span className={`risk-badge ${config.badgeClass}`}>{config.title}</span>
          <h3 className="risk-recommendation">{getLocalizedRecommendation()}</h3>
        </div>
      </div>

      <div className="risk-card-divider" />

      <div className="risk-card-grid">
        <div className="risk-info-item">
          <Flag size={16} className="info-icon" />
          <span className="info-label">{strings.reportCountLabel}:</span>
          <span className="info-val font-semibold">{result.counted_reports}</span>
        </div>

        <div className="risk-info-item">
          <Phone size={16} className="info-icon" />
          <span className="info-label">{strings.phoneLabel}:</span>
          <span className="info-val font-mono">{result.phone_masked}</span>
        </div>

        <div className="risk-info-item">
          <UserIcon size={16} className="info-icon" />
          <span className="info-label">{strings.customerNameLabel}:</span>
          <span className="info-val">{result.customer_name || "-"}</span>
        </div>

        {result.last_report_at && (
          <div className="risk-info-item">
            <Calendar size={16} className="info-icon" />
            <span className="info-label">{strings.latestReportLabel}:</span>
            <span className="info-val">
              {new Date(result.last_report_at).toLocaleDateString()}
            </span>
          </div>
        )}
      </div>
    </div>
  );
};
