
(function () {
  const STORAGE_KEY = "gadx-support-theme";
  const defaultTheme = document.documentElement.getAttribute("data-default-theme") || "dark";

  function getStoredTheme() {
    try {
      return localStorage.getItem(STORAGE_KEY);
    } catch (e) {
      return null;
    }
  }

  function storeTheme(theme) {
    try {
      localStorage.setItem(STORAGE_KEY, theme);
    } catch (e) {}
  }

  function applyTheme(theme) {
    const normalized = theme === "light" ? "light" : "dark";
    document.body.setAttribute("data-theme", normalized);
    document.documentElement.setAttribute("data-theme", normalized);

    document.querySelectorAll("[data-theme-toggle]").forEach((button) => {
      const isDark = normalized === "dark";
      button.setAttribute("aria-pressed", String(isDark));
      button.querySelector("[data-theme-label]").textContent = isDark ? "Modo escuro" : "Modo claro";
      button.querySelector("[data-theme-icon]").textContent = isDark ? "☾" : "☀";
    });
  }

  function initTheme() {
    const theme = getStoredTheme() || defaultTheme;
    applyTheme(theme);

    document.querySelectorAll("[data-theme-toggle]").forEach((button) => {
      button.addEventListener("click", () => {
        const current = document.body.getAttribute("data-theme") || defaultTheme;
        const next = current === "dark" ? "light" : "dark";
        applyTheme(next);
        storeTheme(next);
      });
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initTheme);
  } else {
    initTheme();
  }
})();
