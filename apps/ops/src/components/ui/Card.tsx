import { cn } from '@/lib/utils'
import { ReactNode } from 'react'

interface Props {
  children: ReactNode
  className?: string
  title?: string
  action?: ReactNode
}

export function Card({ children, className, title, action }: Props) {
  return (
    <div className={cn('bg-card rounded-card border border-border', className)}>
      {(title || action) && (
        <div className="flex items-center justify-between px-5 py-4 border-b border-border">
          {title && <h3 className="font-semibold text-ink">{title}</h3>}
          {action}
        </div>
      )}
      <div className="p-5">{children}</div>
    </div>
  )
}

interface StatCardProps {
  label: string
  value: string | number
  icon: ReactNode
  color?: string
  sub?: string
}

export function StatCard({ label, value, icon, color = 'text-primary', sub }: StatCardProps) {
  return (
    <div className="bg-card rounded-card border border-border p-5 flex items-start gap-4">
      <div className={cn('p-2.5 rounded-xl bg-primary-light', color)}>{icon}</div>
      <div>
        <p className="text-sm text-muted">{label}</p>
        <p className="text-2xl font-bold text-ink mt-0.5">{value}</p>
        {sub && <p className="text-xs text-muted mt-1">{sub}</p>}
      </div>
    </div>
  )
}
