import { type ClassValue, clsx } from 'clsx'
export function cn(...inputs: ClassValue[]) { return clsx(inputs) }

export function fmtMoney(v: number | string | null | undefined, currency = 'KGS'): string {
  const n = typeof v === 'string' ? parseFloat(v) : (v ?? 0)
  return `${n.toLocaleString('ru-RU', { maximumFractionDigits: 0 })} сом`
}

export function fmtDate(iso: string | null | undefined): string {
  if (!iso) return '—'
  return new Date(iso).toLocaleString('ru-RU', {
    day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  })
}

export function fmtShortDate(iso: string | null | undefined): string {
  if (!iso) return '—'
  return new Date(iso).toLocaleString('ru-RU', {
    day: '2-digit', month: 'short', year: 'numeric',
  })
}

export const STATUS_LABELS: Record<string, string> = {
  active: 'Активен',
  blocked: 'Заблокирован',
  deleted: 'Удалён',
  draft: 'Черновик',
  pending: 'На проверке',
  approved: 'Одобрен',
  rejected: 'Отклонён',
  expired: 'Истёк',
  online: 'Онлайн',
  offline: 'Офлайн',
  busy: 'Занят',
  open: 'Открыт',
  in_progress: 'В работе',
  resolved: 'Решён',
  closed: 'Закрыт',
  searching: 'Поиск',
  assigned: 'Назначен',
  in_progress_ride: 'В пути',
  completed: 'Завершён',
  cancelled: 'Отменён',
  held: 'На удержании',
  confirmed: 'Подтверждён',
}

export const STATUS_COLORS: Record<string, string> = {
  active: 'bg-green-100 text-green-700',
  approved: 'bg-green-100 text-green-700',
  online: 'bg-green-100 text-green-700',
  completed: 'bg-green-100 text-green-700',
  resolved: 'bg-green-100 text-green-700',
  confirmed: 'bg-green-100 text-green-700',
  blocked: 'bg-red-100 text-red-700',
  rejected: 'bg-red-100 text-red-700',
  cancelled: 'bg-red-100 text-red-700',
  expired: 'bg-red-100 text-red-700',
  pending: 'bg-yellow-100 text-yellow-700',
  in_progress: 'bg-blue-100 text-blue-700',
  searching: 'bg-blue-100 text-blue-700',
  assigned: 'bg-blue-100 text-blue-700',
  held: 'bg-yellow-100 text-yellow-700',
  offline: 'bg-gray-100 text-gray-600',
  busy: 'bg-orange-100 text-orange-700',
  draft: 'bg-gray-100 text-gray-600',
  open: 'bg-yellow-100 text-yellow-700',
  closed: 'bg-gray-100 text-gray-600',
}
