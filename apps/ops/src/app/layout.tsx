import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Qadam Ops',
  description: 'Qadam operations panel',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ru">
      <body>{children}</body>
    </html>
  )
}
