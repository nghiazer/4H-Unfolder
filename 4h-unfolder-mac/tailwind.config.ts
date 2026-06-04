import type { Config } from 'tailwindcss';

export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        background:  'hsl(var(--background) / <alpha-value>)',
        foreground:  'hsl(var(--foreground) / <alpha-value>)',
        muted:       'hsl(var(--muted) / <alpha-value>)',
        border:      'hsl(var(--border) / <alpha-value>)',
        primary:     'hsl(var(--primary) / <alpha-value>)',
        accent:      'hsl(var(--accent) / <alpha-value>)',
        toolbar:     'hsl(var(--toolbar) / <alpha-value>)',
        sidebar:     'hsl(var(--sidebar) / <alpha-value>)',
        canvas:      'hsl(var(--canvas) / <alpha-value>)',
      },
      fontFamily: {
        sans: ['-apple-system', 'BlinkMacSystemFont', '"Segoe UI"', 'Helvetica', 'Arial', 'sans-serif'],
        mono: ['"SF Mono"', '"Fira Code"', '"Fira Mono"', '"Roboto Mono"', 'monospace'],
      },
    },
  },
  plugins: [],
} satisfies Config;
