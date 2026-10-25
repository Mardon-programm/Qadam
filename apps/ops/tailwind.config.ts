import type { Config } from 'tailwindcss'

const config: Config = {
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#1E6FE8',
          dark: '#1558C0',
          light: '#EEF4FD',
        },
        success: '#34C759',
        warning: '#FF9500',
        danger: '#FF3B30',
        surface: '#F8F9FB',
        card: '#FFFFFF',
        border: '#E5E7EB',
        muted: '#6B7280',
        ink: '#0F1923',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
      },
      borderRadius: {
        card: '12px',
      },
    },
  },
  plugins: [],
}

export default config
