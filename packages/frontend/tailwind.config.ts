/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        brand: { 500: "#7c3aed", 600: "#6d28d9" },
      },
    },
  },
  plugins: [],
};
