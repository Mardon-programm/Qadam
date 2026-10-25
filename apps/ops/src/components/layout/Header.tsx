'use client'
import { Bell, Search } from 'lucide-react'
import useSWR from 'swr'
import { authApi } from '@/lib/api'

export function Header({ title }: { title: string }) {
  const { data: me } = useSWR('/auth/me', () => authApi.me().then(r => r.data))

  return (
    <header className="h-16 bg-card border-b border-border flex items-center justify-between px-6">
      <h1 className="text-lg font-semibold text-ink">{title}</h1>
      <div className="flex items-center gap-3">
        <button className="p-2 rounded-lg hover:bg-surface text-muted transition-colors">
          <Search size={18} />
        </button>
        <button className="p-2 rounded-lg hover:bg-surface text-muted transition-colors relative">
          <Bell size={18} />
          <span className="absolute top-1.5 right-1.5 w-1.5 h-1.5 bg-danger rounded-full" />
        </button>
        <div className="flex items-center gap-2 pl-3 border-l border-border">
          <div className="w-8 h-8 rounded-full bg-primary-light text-primary flex items-center justify-center font-semibold text-sm">
            {me?.full_name?.[0]?.toUpperCase() ?? 'O'}
          </div>
          <div className="text-sm">
            <p className="font-medium text-ink leading-none">{me?.full_name ?? 'Ops'}</p>
            <p className="text-xs text-muted mt-0.5">{me?.phone ?? ''}</p>
          </div>
        </div>
      </div>
    </header>
  )
}
