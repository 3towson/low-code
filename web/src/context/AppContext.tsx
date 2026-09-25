import React, { createContext, useContext, useEffect, useState } from "react";
import { supabase } from "../services/supabase";
import type { User } from "@supabase/supabase-js";

export type Language = "th" | "en";
export type ThemeMode = "light" | "dark";

export const translations = {
  th: {
    appTitle: "COD Risk Shield",
    appSubtitle: "ตรวจก่อนส่ง ป้องกันพัสดุตีกลับ",
    shopsCount: "2,480+",
    shopsLabel: "ร้านค้า",
    protectedCount: "18,340 ชิ้น",
    protectedLabel: "ป้องกันแล้ว",
    savedCount: "฿917,000",
    savedLabel: "ประหยัดได้",
    checkCustomer: "ตรวจสอบลูกค้า",
    reportCustomer: "รายงานลูกค้า",
    checkRiskButton: "ตรวจสอบความเสี่ยง",
    orderHint: "วางข้อความออเดอร์ แชตลูกค้า หรือที่อยู่จัดส่งที่นี่...",
    orderEmptyError: "กรุณาวางข้อความออเดอร์",
    checking: "กำลังตรวจสอบ...",
    phoneNotFound: "ไม่พบเบอร์โทรในข้อความ กรุณากรอกเบอร์เพื่อตรวจสอบ",
    phoneInputLabel: "เบอร์โทรลูกค้า",
    phoneInputHint: "เช่น 081-234-5678",
    checkPhoneBtn: "ตรวจสอบด้วยเบอร์",
    retry: "ลองใหม่",
    riskLow: "ความเสี่ยงต่ำ",
    riskMedium: "ความเสี่ยงปานกลาง",
    riskHigh: "ความเสี่ยงสูง",
    recGreen: "ส่งได้ตามปกติ",
    recYellow: "ควรโทรหรือทักยืนยันออเดอร์กับลูกค้าก่อนแพ็กสินค้า",
    recRed: "ไม่แนะนำให้ส่งแบบเก็บเงินปลายทาง ควรให้ลูกค้าโอนชำระก่อน",
    reportCountLabel: "จำนวนรายงาน",
    latestReportLabel: "รายงานล่าสุด",
    phoneLabel: "เบอร์โทร",
    customerNameLabel: "ชื่อลูกค้า",
    settings: "ตั้งค่า",
    settingsTitle: "การตั้งค่าระบบ",
    themeSection: "ธีมการแสดงผล",
    themeDesc: "เลือกรูปแบบธีมที่สบายตาสำหรับคุณ",
    themeLight: "สว่าง",
    themeDark: "มืด",
    languageSection: "ภาษา (Language)",
    languageDesc: "เลือกภาษาสำหรับการแสดงผล",
    signIn: "เข้าสู่ระบบ",
    signOut: "ออกจากระบบ",
    signUp: "สมัครสมาชิก",
    emailLabel: "อีเมล",
    passwordLabel: "รหัสผ่าน",
    shopNameLabel: "ชื่อร้านค้า",
    loginPrompt: "กรุณาเข้าสู่ระบบเพื่อใช้งานฟังก์ชันนี้",
    alreadyHaveAccount: "มีบัญชีอยู่แล้ว? เข้าสู่ระบบ",
    noAccount: "ยังไม่มีบัญชี? สมัครสมาชิก",
    close: "ปิด",
    submit: "ส่งข้อมูล",
    submitting: "กำลังส่ง...",
    reportSuccess: "ส่งรายงานลูกค้าเรียบร้อยแล้ว",
    reportModalTitle: "รายงานลูกค้า COD",
    platform: "แพลตฟอร์ม",
    reason: "เหตุผล",
    amount: "มูลค่าความเสียหาย (บาท)",
    reasonRefused: "ปฏิเสธรับสินค้า",
    reasonUnreachable: "ติดต่อไม่ได้",
    reasonFakeAddress: "ที่อยู่ปลอมหรือผิด",
    reasonOther: "อื่นๆ",
  },
  en: {
    appTitle: "COD Risk Shield",
    appSubtitle: "Check before shipping, prevent returned parcels",
    shopsCount: "2,480+",
    shopsLabel: "Shops",
    protectedCount: "18,340 pcs",
    protectedLabel: "Protected",
    savedCount: "฿917,000",
    savedLabel: "Saved",
    checkCustomer: "Check Customer",
    reportCustomer: "Report Customer",
    checkRiskButton: "Check Risk",
    orderHint: "Paste order text, customer chat, or shipping address here...",
    orderEmptyError: "Please paste order text",
    checking: "Checking...",
    phoneNotFound: "No phone number found in text. Please enter manually.",
    phoneInputLabel: "Customer Phone",
    phoneInputHint: "e.g. 081-234-5678",
    checkPhoneBtn: "Check with Phone",
    retry: "Retry",
    riskLow: "Low Risk",
    riskMedium: "Moderate Risk",
    riskHigh: "High Risk",
    recGreen: "Safe to ship normally",
    recYellow: "Confirm order with customer via call/chat before packing",
    recRed: "COD not recommended; ask customer to prepay",
    reportCountLabel: "Report count",
    latestReportLabel: "Latest report",
    phoneLabel: "Phone",
    customerNameLabel: "Customer name",
    settings: "Settings",
    settingsTitle: "System Settings",
    themeSection: "Appearance Theme",
    themeDesc: "Choose your preferred visual theme",
    themeLight: "Light",
    themeDark: "Dark",
    languageSection: "Language",
    languageDesc: "Select application display language",
    signIn: "Sign In",
    signOut: "Sign Out",
    signUp: "Sign Up",
    emailLabel: "Email",
    passwordLabel: "Password",
    shopNameLabel: "Shop Name",
    loginPrompt: "Please sign in to use this feature",
    alreadyHaveAccount: "Already have an account? Sign In",
    noAccount: "Don't have an account? Sign Up",
    close: "Close",
    submit: "Submit",
    submitting: "Submitting...",
    reportSuccess: "Report submitted successfully",
    reportModalTitle: "Report COD Customer",
    platform: "Platform",
    reason: "Reason",
    amount: "Damage Amount (THB)",
    reasonRefused: "Refused delivery",
    reasonUnreachable: "Unreachable",
    reasonFakeAddress: "Fake / wrong address",
    reasonOther: "Other",
  },
};

interface AppContextType {
  language: Language;
  setLanguage: (lang: Language) => void;
  theme: ThemeMode;
  setTheme: (theme: ThemeMode) => void;
  toggleTheme: () => void;
  strings: typeof translations["th"];
  user: User | null;
  shopName: string;
  signOut: () => Promise<void>;
  openAuthModal: () => void;
  openSettingsModal: () => void;
}

const AppContext = createContext<AppContextType | null>(null);

export const AppProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [language, setLanguage] = useState<Language>(() => {
    return (localStorage.getItem("app_lang") as Language) || "th";
  });

  const [theme, setTheme] = useState<ThemeMode>(() => {
    return (localStorage.getItem("app_theme") as ThemeMode) || "dark";
  });

  const [user, setUser] = useState<User | null>(null);
  const [shopName, setShopName] = useState<string>("ร้านค้า");

  useEffect(() => {
    localStorage.setItem("app_lang", language);
  }, [language]);

  useEffect(() => {
    localStorage.setItem("app_theme", theme);
    document.documentElement.setAttribute("data-theme", theme);
    if (theme === "dark") {
      document.documentElement.classList.add("dark");
    } else {
      document.documentElement.classList.remove("dark");
    }
  }, [theme]);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setUser(data.session?.user || null);
      if (data.session?.user) {
        const meta = data.session.user.user_metadata;
        setShopName(meta?.shop_name || data.session.user.email?.split("@")[0] || "ร้านค้า");
      }
    });

    const { data: listener } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user || null);
      if (session?.user) {
        const meta = session.user.user_metadata;
        setShopName(meta?.shop_name || session.user.email?.split("@")[0] || "ร้านค้า");
      }
    });

    return () => {
      listener.subscription.unsubscribe();
    };
  }, []);

  const toggleTheme = () => {
    setTheme((prev) => (prev === "dark" ? "light" : "dark"));
  };

  const signOut = async () => {
    await supabase.auth.signOut();
    setUser(null);
  };

  const strings = translations[language];

  return (
    <AppContext.Provider
      value={{
        language,
        setLanguage,
        theme,
        setTheme,
        toggleTheme,
        strings,
        user,
        shopName,
        signOut,
        openAuthModal: () => {},
        openSettingsModal: () => {},
      }}
    >
      {children}
    </AppContext.Provider>
  );
};

export const useApp = () => {
  const context = useContext(AppContext);
  if (!context) throw new Error("useApp must be used within AppProvider");
  return context;
};
