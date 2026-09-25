import React, { useState } from "react";
import { useApp } from "../context/AppContext";
import { checkCustomerApi, type CheckResponse, type CheckSuccess } from "../services/supabase";
import { RiskCard } from "./RiskCard";
import { Shield, Search, RefreshCw, AlertCircle, Phone } from "lucide-react";

interface CheckPanelProps {
  onOpenAuth: () => void;
}

export const CheckPanel: React.FC<CheckPanelProps> = ({ onOpenAuth }) => {
  const { strings, user } = useApp();
  const [text, setText] = useState("");
  const [manualPhone, setManualPhone] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<CheckResponse | null>(null);
  const [showManualPhone, setShowManualPhone] = useState(false);

  const handleCheckText = async () => {
    if (!text.trim()) {
      setError(strings.orderEmptyError);
      return;
    }

    if (!user) {
      onOpenAuth();
      return;
    }

    setError(null);
    setLoading(true);
    setResult(null);
    setShowManualPhone(false);

    try {
      const data = await checkCustomerApi({ text });
      setResult(data);
      if (data.status === "NO_PHONE") {
        setShowManualPhone(true);
      }
    } catch (err: unknown) {
      if (err instanceof Error && err.message === "AUTH_REQUIRED") {
        onOpenAuth();
      } else {
        setError(err instanceof Error ? err.message : "เกิดข้อผิดพลาดในการตรวจสอบ");
      }
    } finally {
      setLoading(false);
    }
  };

  const handleCheckPhone = async () => {
    if (!manualPhone.trim()) return;

    if (!user) {
      onOpenAuth();
      return;
    }

    setError(null);
    setLoading(true);

    try {
      const data = await checkCustomerApi({ phone: manualPhone });
      setResult(data);
    } catch (err: unknown) {
      if (err instanceof Error && err.message === "AUTH_REQUIRED") {
        onOpenAuth();
      } else {
        setError(err instanceof Error ? err.message : "เกิดข้อผิดพลาดในการตรวจสอบ");
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="check-panel-card">
      <div className="panel-title-row">
        <h2 className="panel-title">{strings.checkCustomer}</h2>
        <span className="panel-badge">
          <Shield size={14} /> AI Powered
        </span>
      </div>

      <div className="form-group">
        <textarea
          className="textarea-input"
          rows={5}
          placeholder={strings.orderHint}
          value={text}
          onChange={(e) => {
            setText(e.target.value);
            if (error) setError(null);
          }}
          disabled={loading}
        />
        {error && <div className="error-text">{error}</div>}
      </div>

      <div className="actions-row">
        <button
          type="button"
          className="btn btn-primary btn-lg"
          onClick={handleCheckText}
          disabled={loading}
        >
          {loading ? (
            <>
              <RefreshCw className="spinner" size={18} />
              <span>{strings.checking}</span>
            </>
          ) : (
            <>
              <Search size={18} />
              <span>{strings.checkRiskButton}</span>
            </>
          )}
        </button>
      </div>

      {/* Manual Phone Fallback */}
      {showManualPhone && (
        <div className="phone-fallback-box">
          <div className="fallback-header">
            <AlertCircle size={20} className="text-warning" />
            <p>{strings.phoneNotFound}</p>
          </div>
          <div className="fallback-input-row">
            <div className="input-with-icon">
              <Phone size={18} className="field-icon" />
              <input
                type="tel"
                className="text-input"
                placeholder={strings.phoneInputHint}
                value={manualPhone}
                onChange={(e) => setManualPhone(e.target.value)}
                disabled={loading}
              />
            </div>
            <button
              type="button"
              className="btn btn-secondary"
              onClick={handleCheckPhone}
              disabled={loading || !manualPhone}
            >
              {strings.checkPhoneBtn}
            </button>
          </div>
        </div>
      )}

      {/* Result Display */}
      {result && result.status === "OK" && (
        <div className="result-container">
          <RiskCard result={result as CheckSuccess} />
        </div>
      )}

      {result && result.status === "INVALID_PHONE" && (
        <div className="error-box">
          <AlertCircle size={20} />
          <span>{result.message}</span>
        </div>
      )}
    </div>
  );
};
