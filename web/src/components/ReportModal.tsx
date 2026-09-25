import React, { useState } from "react";
import { useApp } from "../context/AppContext";
import { reportCustomerApi } from "../services/supabase";
import { X, Flag, AlertTriangle, CheckCircle, RefreshCw } from "lucide-react";

interface ReportModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const ReportModal: React.FC<ReportModalProps> = ({ isOpen, onClose }) => {
  const { strings } = useApp();
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [platform, setPlatform] = useState("shopee");
  const [reason, setReason] = useState("refused_delivery");
  const [amount, setAmount] = useState<string>("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!name.trim()) {
      setError("กรุณากรอกชื่อลูกค้า");
      return;
    }
    if (!phone.trim()) {
      setError("กรุณากรอกเบอร์โทรศัพท์");
      return;
    }

    setLoading(true);
    try {
      await reportCustomerApi({
        customer_name: name.trim(),
        phone: phone.trim(),
        platform,
        reason,
        amount: amount ? parseFloat(amount) : null,
      });

      setSuccess(true);
      setTimeout(() => {
        setSuccess(false);
        setName("");
        setPhone("");
        setAmount("");
        onClose();
      }, 1500);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "เกิดข้อผิดพลาดในการส่งรายงาน");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal-card" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <div className="modal-title-row">
            <div className="modal-icon-badge danger">
              <Flag size={20} />
            </div>
            <h2>{strings.reportModalTitle}</h2>
          </div>
          <button className="icon-btn" onClick={onClose} aria-label={strings.close}>
            <X size={18} />
          </button>
        </div>

        {success ? (
          <div className="modal-success-state">
            <CheckCircle size={48} className="text-success" />
            <h3>{strings.reportSuccess}</h3>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="modal-body">
            {error && (
              <div className="error-box">
                <AlertTriangle size={18} />
                <span>{error}</span>
              </div>
            )}

            <div className="form-group">
              <label className="field-label">{strings.customerNameLabel} *</label>
              <input
                type="text"
                className="text-input"
                placeholder="เช่น สมชาย ใจดี"
                value={name}
                onChange={(e) => setName(e.target.value)}
                required
              />
            </div>

            <div className="form-group">
              <label className="field-label">{strings.phoneLabel} *</label>
              <input
                type="tel"
                className="text-input"
                placeholder="เช่น 0812345678"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                required
              />
            </div>

            <div className="form-row">
              <div className="form-group flex-1">
                <label className="field-label">{strings.platform} *</label>
                <select
                  className="select-input"
                  value={platform}
                  onChange={(e) => setPlatform(e.target.value)}
                >
                  <option value="shopee">Shopee</option>
                  <option value="lazada">Lazada</option>
                  <option value="facebook">Facebook</option>
                  <option value="line">LINE</option>
                  <option value="tiktok">TikTok</option>
                  <option value="other">{strings.reasonOther}</option>
                </select>
              </div>

              <div className="form-group flex-1">
                <label className="field-label">{strings.reason} *</label>
                <select
                  className="select-input"
                  value={reason}
                  onChange={(e) => setReason(e.target.value)}
                >
                  <option value="refused_delivery">{strings.reasonRefused}</option>
                  <option value="unreachable">{strings.reasonUnreachable}</option>
                  <option value="fake_address">{strings.reasonFakeAddress}</option>
                  <option value="other">{strings.reasonOther}</option>
                </select>
              </div>
            </div>

            <div className="form-group">
              <label className="field-label">{strings.amount}</label>
              <input
                type="number"
                className="text-input"
                placeholder="เช่น 350 (ไม่บังคับ)"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                min="0"
                step="any"
              />
            </div>

            <div className="modal-footer">
              <button
                type="button"
                className="btn btn-outline"
                onClick={onClose}
                disabled={loading}
              >
                {strings.close}
              </button>
              <button type="submit" className="btn btn-danger" disabled={loading}>
                {loading ? (
                  <>
                    <RefreshCw className="spinner" size={16} />
                    <span>{strings.submitting}</span>
                  </>
                ) : (
                  strings.submit
                )}
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
};
