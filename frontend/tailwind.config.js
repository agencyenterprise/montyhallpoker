/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      backgroundImage: {
        game: "url('/poker.png')",
        "table-red": "url('/table-bg-red.png')",
        "table-yellow": "url('/table-bg-yellow.png')",
        "table-green": "url('/table-bg-green.png')",
      },
      backgroundSize: {
        scale: "90%",
      },
      colors: {
        lime: {
          400: "#A3E635",
        },
        amber: {
          500: "#F59E0B",
        },
        rose: {
          500: "#F43F5E",
        },
        cyan: {
          400: "#22D3EE",
        },
        slate: {
          900: "#0F172A",
          950: "#020617",
        },
      },
    },
  },
  plugins: [],
};
