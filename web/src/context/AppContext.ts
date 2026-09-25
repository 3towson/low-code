import { createContext, useContext } from "react";
import type { User } from "@supabase/supabase-js";
import { translations, type Language, type ThemeMode } from "./translations";

export { translations, type Language, type ThemeMode };

export interface AppContextType {
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

export const AppContext = createContext<AppContextType | null>(null);

export const useApp = () => {
  const context = useContext(AppContext);
  if (!context) throw new Error("useApp must be used within AppProvider");
  return context;
};
