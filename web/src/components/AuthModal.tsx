import React, { useState } from "react";
import { useApp } from "../context/AppContext";
import { supabase } from "../services/supabase";
import { X, LogIn, UserPlus, AlertCircle, RefreshCw } from "lucide-react";

interface AuthModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const AuthModal: React.FC<AuthModalProps> = ({ isOpen, onClose }) => {
  const { strings } = useApp();
  const [tab, setTab] = useState<"signin" | "signup">("signin");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [shopName, setShopName] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [signupSuccess, setSignupSuccess] = useState(false);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      if (tab === "signin") {
        const { error: err } = await supabase.auth.signInWithPassword({
          email: email.trim(),
          password,
        });
        if (err) throw err;
        onClose();
      } else {
        const { error: err } = await supabase.auth.signUp({
          email: email.trim(),
          password,
          options: {
            data: { shop_name: shopName.trim() },
          },
        });
        if (err) throw err;
        setSignupSuccess(true);
      }
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "เกิดข้อผิดพลาดในการเข้าสู่ระบบ";
      if (msg.includes("Invalid login credentials")) {
        setError("อีเมลหรือรหัสผ่านไม่ถูกต้อง");
      } else if (msg.includes("Email not confirmed")) {
        setError("กรุณายืนยันอีเมลก่อนเข้าสู่ระบบ");
      } else {
        setError(msg);
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal-card" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <div className="auth-tab-switch">
            <button
              type="button"
              className={`auth-tab-btn ${tab === "signin" ? "active" : ""}`}
              onClick={() => {
                setTab("signin");
                setError(null);
              }}
            >
              <LogIn size={16} />
              <span>{strings.signIn}</span>
            </button>
            <button
              type="button"
              className={`auth-tab-btn ${tab === "signup" ? "active" : ""}`}
              onClick={() => {
                setTab("signup");
                setError(null);
              }}
            >
              <UserPlus size={16} />
              <span>{strings.signUp}</span>
            </button>
          </div>
          <button className="icon-btn" onClick={onClose} aria-label={strings.close}>
            <X size={18} />
          </button>
        </div>

        {signupSuccess ? (
          <div className="modal-body text-center">
            <h3 className="success-heading">สมัครสมาชิกสำเร็จ!</h3>
            <p className="success-body">
              กรุณาตรวจสอบกล่องข้อความในอีเมล <b>{email}</b> เพื่อกดยืนยันตัวตนก่อนเข้าสู่ระบบ
            </p>
            <button
              type="button"
              className="btn btn-primary mt-4"
              onClick={() => {
                setSignupSuccess(false);
                setTab("signin");
              }}
            >
              ไปที่หน้าเข้าสู่ระบบ
            </button>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="modal-body">
            {error && (
              <div className="error-box">
                <AlertCircle size={18} />
                <span>{error}</span>
              </div>
            )}

            {tab === "signup" && (
              <div className="form-group">
                <label className="field-label">{strings.shopNameLabel} *</label>
                <input
                  type="text"
                  className="text-input"
                  placeholder="เช่น ร้านต้นไม้คุณนัท"
                  value={shopName}
                  onChange={(e) => setShopName(e.target.value)}
                  required
                />
              </div>
            )}

            <div className="form-group">
              <label className="field-label">{strings.emailLabel} *</label>
              <input
                type="email"
                className="text-input"
                placeholder="example@shop.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
              />
            </div>

            <div className="form-group">
              <label className="field-label">{strings.passwordLabel} *</label>
              <input
                type="password"
                className="text-input"
                placeholder="อย่างน้อย 6 ตัวอักษร"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
              />
            </div>

            <div className="modal-footer">
              <button
                type="submit"
                className="btn btn-primary full-width"
                disabled={loading}
              >
                {loading ? (
                  <>
                    <RefreshCw className="spinner" size={16} />
                    <span>{strings.checking}</span>
                  </>
                ) : tab === "signin" ? (
                  strings.signIn
                ) : (
                  strings.signUp
                )}
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
};
