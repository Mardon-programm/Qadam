'use client'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { cn } from '@/lib/utils'
import {
  LayoutDashboard, Users, Car, Map, BookOpen,
  HeadphonesIcon, ScrollText, Banknote, LogOut,
} from 'lucide-react'
import { clearTokens } from '@/lib/api'
import { useRouter } from 'next/navigation'

const NAV = [
  { href: '/dashboard', icon: LayoutDashboard, label: 'Дашборд' },
  { href: '/drivers',   icon: Car,             label: 'Водители' },
  { href: '/rides',     icon: Map,             label: 'Поездки' },
  { href: '/bookings',  icon: BookOpen,        label: 'Брони' },
  { href: '/support',   icon: HeadphonesIcon,  label: 'Поддержка' },
  { href: '/finance',   icon: Banknote,        label: 'Финансы' },
  { href: '/audit',     icon: ScrollText,      label: 'Аудит' },
]

export function Sidebar() {
  const pathname = usePathname()
  const router = useRouter()

  function logout() {
    clearTokens()
    router.push('/login')
  }

  return (
    <aside className="fixed inset-y-0 left-0 w-56 bg-ink flex flex-col z-30">
      {/* Logo */}
      <div className="flex items-center gap-3 px-5 py-5 border-b border-white/10">
        <div className="w-8 h-8 bg-primary rounded-lg flex items-center justify-center">
          <Car size={16} className="text-white" />
        </div>
        <div>
          <p className="text-white font-bold text-sm">Qadam</p>
          <p className="text-white/40 text-xs">Operations</p>
        </div>
      </div>

      {/* Nav */}
      <nav className="flex-1 py-4 px-3 space-y-0.5 overflow-y-auto">
        {NAV.map(({ href, icon: Icon, label }) => {
          const active = pathname.startsWith(href)
          return (
            <Link
              key={href}
              href={href}
              className={cn(
                'flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors',
                active
                  ? 'bg-primary text-white'
                  : 'text-white/60 hover:text-white hover:bg-white/8',
              )}
            >
              <Icon size={18} />
              {label}
            </Link>
          )
        })}
      </nav>

      {/* Footer */}
      <div className="px-3 pb-4">
        <button
          onClick={logout}
          className="flex items-center gap-3 px-3 py-2.5 w-full rounded-lg text-sm font-medium text-white/60 hover:text-white hover:bg-white/8 transition-colors"
        >
          <LogOut size={18} />
          Выйти
        </button>
      </div>
    </aside>
  )
}
