import { cn, STATUS_COLORS, STATUS_LABELS } from '@/lib/utils'

interface Props {
  status: string
  className?: string
}

export function StatusBadge({ status, className }: Props) {
  const color = STATUS_COLORS[status] ?? 'bg-gray-100 text-gray-600'
  const label = STATUS_LABELS[status] ?? status
  return (
    <span className={cn('inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium', color, className)}>
      {label}
    </span>
  )
}
