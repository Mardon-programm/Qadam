import { Sidebar } from '@/components/layout/Sidebar'
import { ReactNode } from 'react'

export default function Layout({ children }: { children: ReactNode }) {
  return (
    <div className="flex min-h-screen bg-surface">
      <Sidebar />
      <main className="flex-1 ml-56 overflow-x-hidden">{children}</main>
    </div>
  )
}
