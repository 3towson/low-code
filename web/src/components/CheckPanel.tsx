import React, { useState } from "react";
import { useApp } from "../context/AppContext";
import { checkCustomerApi, type CheckResponse, type CheckSuccess } from "../services/supabase";
import { splitOrders, exceedsOrderLimit } from "../utils/orderSplitter";
import { RiskCard } from "./RiskCard";
import {
  Shield,
  Search,
  RefreshCw,
  AlertCircle,
  Phone,
  CheckCircle2,
  AlertTriangle,
  XCircle,
  ChevronDown,
  Flag,
  Calendar,
  User as UserIcon,
} from "lucide-react";

interface CheckPanelProps {
  onOpenAuth: () => void;
}

interface MultiItem {
  orderText: string;
  result: CheckResponse | { status: "ERROR"; message: string };
}

export const CheckPanel: React.FC<CheckPanelProps> = ({ onOpenAuth }) => {
  const { strings, user } = useApp();
  const [text, setText] = useState("");
  const [manualPhone, setManualPhone] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<CheckResponse | null>(null);
  const [showManualPhone, setShowManualPhone] = useState(false);

  // Multi-order states
  const [multiResults, setMultiResults] = useState<MultiItem[] | null>(null);
  const [multiTotal, setMultiTotal] = useState(0);
  const [multiTruncated, setMultiTruncated] = useState(false);
  const [multiRunning, setMultiRunning] = useState(false);
  const [expandedIndexes, setExpandedIndexes] = useState<Record<number, boolean>>({});

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
    setResult(null);
    setShowManualPhone(false);

    const orders = splitOrders(text);
    if (orders.length > 1) {
      // Multi-order / Multi-phone check
      setLoading(true);
      setMultiRunning(true);
      setMultiTotal(orders.length);
      setMultiTruncated(exceedsOrderLimit(text));
      setMultiResults([]);
      setExpandedIndexes({});

      const currentResults: MultiItem[] = [];
      for (const order of orders) {
        try {
          const data = await checkCustomerApi({ text: order });
          const item: MultiItem = { orderText: order, result: data };
          currentResults.push(item);
          setMultiResults([...currentResults]);
        } catch (err: unknown) {
          if (err instanceof Error && err.message === "AUTH_REQUIRED") {
            onOpenAuth();
            setLoading(false);
            setMultiRunning(false);
            return;
          }
          const errMsg = err instanceof Error ? err.message : "เกิดข้อผิดพลาดในการตรวจสอบ";
          const item: MultiItem = { orderText: order, result: { status: "ERROR", message: errMsg } };
          currentResults.push(item);
          setMultiResults([...currentResults]);
        }
      }
      setMultiRunning(false);
      setLoading(false);
    } else {
      // Single order check
      setMultiResults(null);
      setLoading(true);

      try {
        const data = await checkCustomerApi({ text });
        setResult(data);
        if (
          data.status === "NO_PHONE" ||
          (data as unknown as { status?: string }).status === "NO_PHONE_DETECTED"
        ) {
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
    setMultiResults(null);

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

      {/* Single Result Display */}
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

      {/* Multi-Order Results Display */}
      {multiResults && (
        <div className="multi-result-container">
          {multiTruncated && (
            <div className="multi-warning-banner">
              <AlertCircle size={20} style={{ flexShrink: 0, marginTop: 2 }} />
              <span>ระบบจะตรวจสอบเฉพาะ 10 ออเดอร์แรกเท่านั้น เพื่อความเสถียรของระบบ</span>
            </div>
          )}

          <div className="multi-status-row">
            <span>
              {multiRunning
                ? `พบ ${multiTotal} ออเดอร์ กำลังตรวจสอบ... ${multiResults.length + 1}/${multiTotal}`
                : `ตรวจแล้ว ${multiTotal} ออเดอร์`}
            </span>
            <span style={{ fontSize: "0.85rem", opacity: 0.8 }}>
              {multiResults.length} / {multiTotal}
            </span>
          </div>

          {multiRunning && (
            <div className="multi-progress-track">
              <div
                className="multi-progress-bar"
                style={{ width: `${(multiResults.length / multiTotal) * 100}%` }}
              />
            </div>
          )}

          {multiResults.map((item, index) => {
            const res = item.result;
            const isExpanded = !!expandedIndexes[index];
            const firstLine = item.orderText.trim().split("\n")[0];

            let tileClass = "multi-order-tile";
            let icon = <AlertCircle size={20} />;
            let title = firstLine;
            let subtitle = "";
            let badgeLabel = "";

            if (res.status === "OK") {
              const success = res as CheckSuccess;
              if (success.level === "green") {
                tileClass += " tile-green";
                icon = <CheckCircle2 size={20} />;
                badgeLabel = strings.riskLow;
              } else if (success.level === "yellow") {
                tileClass += " tile-yellow";
                icon = <AlertTriangle size={20} />;
                badgeLabel = strings.riskMedium;
              } else {
                tileClass += " tile-red";
                icon = <XCircle size={20} />;
                badgeLabel = strings.riskHigh;
              }
              title = success.customer_name || "ไม่ทราบชื่อลูกค้า";
              subtitle = `${success.phone_masked} · ${badgeLabel}`;
            } else if (
              res.status === "NO_PHONE" ||
              (res as unknown as { status?: string }).status === "NO_PHONE_DETECTED"
            ) {
              tileClass += " tile-yellow";
              subtitle = "ไม่พบเบอร์โทรในออเดอร์นี้";
            } else {
              tileClass += " tile-red";
              subtitle = `ตรวจไม่สำเร็จ: ${(res as { message?: string }).message || "เกิดข้อผิดพลาด"}`;
            }

            return (
              <div key={index} className={tileClass}>
                <button
                  type="button"
                  className="multi-tile-header"
                  onClick={() =>
                    setExpandedIndexes((prev) => ({ ...prev, [index]: !prev[index] }))
                  }
                >
                  <div className="multi-tile-icon">{icon}</div>
                  <div className="multi-tile-title-box">
                    <div className="multi-tile-name">{title}</div>
                    <div className="multi-tile-subtitle">
                      <span className="multi-tile-badge">{subtitle}</span>
                    </div>
                  </div>
                  <ChevronDown
                    size={18}
                    className={`multi-tile-chevron ${isExpanded ? "expanded" : ""}`}
                  />
                </button>

                {isExpanded && (
                  <div className="multi-tile-content">
                    {res.status === "OK" && (
                      <>
                        <div className="multi-recommendation">
                          {(res as CheckSuccess).recommendation}
                        </div>
                        <div className="risk-card-grid">
                          <div className="risk-info-item">
                            <Flag size={15} className="info-icon" />
                            <span className="info-label">{strings.reportCountLabel}:</span>
                            <span className="info-val font-semibold">
                              {(res as CheckSuccess).counted_reports}
                            </span>
                          </div>
                          <div className="risk-info-item">
                            <Phone size={15} className="info-icon" />
                            <span className="info-label">{strings.phoneLabel}:</span>
                            <span className="info-val font-mono">
                              {(res as CheckSuccess).phone_masked}
                            </span>
                          </div>
                          {(res as CheckSuccess).customer_name && (
                            <div className="risk-info-item">
                              <UserIcon size={15} className="info-icon" />
                              <span className="info-label">{strings.customerNameLabel}:</span>
                              <span className="info-val">
                                {(res as CheckSuccess).customer_name}
                              </span>
                            </div>
                          )}
                          {(res as CheckSuccess).last_report_at && (
                            <div className="risk-info-item">
                              <Calendar size={15} className="info-icon" />
                              <span className="info-label">{strings.latestReportLabel}:</span>
                              <span className="info-val">
                                {new Date(
                                  (res as CheckSuccess).last_report_at!
                                ).toLocaleDateString()}
                              </span>
                            </div>
                          )}
                        </div>
                      </>
                    )}
                    <div className="multi-raw-order">{item.orderText}</div>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};
