import React, { useEffect, useState } from "react";
import { supabase } from "../services/supabase";
import type { User } from "@supabase/supabase-js";
import { AppContext } from "./AppContext";
import { translations, type Language, type ThemeMode } from "./translations";

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
