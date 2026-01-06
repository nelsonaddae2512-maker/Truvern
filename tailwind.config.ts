/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        // Semantic palette backed by CSS variables in globals.css
        tv: {
          bg: "var(--tv-bg)",
          surface: "var(--tv-surface)",
          surfaceSoft: "var(--tv-surface-soft)",
          border: "var(--tv-border)",
          accent: "var(--tv-accent)",
          accentSoft: "var(--tv-accent-soft)",
          accentStrong: "var(--tv-accent-strong)",
          text: "var(--tv-text)",
          textMuted: "var(--tv-text-muted)",
          success: "var(--tv-success)",
          warning: "var(--tv-warning)",
          danger: "var(--tv-danger)",
        },
        // Direct brand hues if you ever want them
        truvern: {
          blue: "var(--truvern-blue)",
          emerald: "var(--truvern-emerald)",
          accent: "var(--truvern-accent)",
        },
      },
      fontFamily: {
        // Feel free to swap this later for an actual brand font
        sans: [
          "system-ui",
          "-apple-system",
          "BlinkMacSystemFont",
          '"Segoe UI"',
          "Roboto",
          "sans-serif",
        ],
      },
      boxShadow: {
        "tv-soft": "0 18px 45px rgba(15,23,42,0.85)",
        "tv-ring": "0 0 0 1px rgba(148,163,184,0.45)",
      },
      borderRadius: {
        "tv-card": "1.25rem",
        "tv-pill": "999px",
      },
      spacing: {
        "tv-gutter": "1.25rem", // 20px – consistent horizontal padding
      },
    },
  },
  plugins: [],
};
