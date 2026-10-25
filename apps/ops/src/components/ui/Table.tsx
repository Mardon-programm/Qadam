import { cn } from '@/lib/utils'
import { ReactNode } from 'react'

interface Column<T> {
  key: string
  header: string
  render?: (row: T) => ReactNode
  className?: string
}

interface Props<T> {
  columns: Column<T>[]
  data: T[]
  keyField?: keyof T
  onRowClick?: (row: T) => void
  emptyText?: string
  loading?: boolean
}

export function DataTable<T extends Record<string, any>>({
  columns, data, keyField = 'id' as keyof T,
  onRowClick, emptyText = 'Нет данных', loading,
}: Props<T>) {
  return (
    <div className="w-full overflow-x-auto rounded-card border border-border bg-card">
      <table className="w-full text-sm">
        <thead className="bg-surface border-b border-border">
          <tr>
            {columns.map(col => (
              <th
                key={col.key}
                className={cn(
                  'px-4 py-3 text-left font-semibold text-muted text-xs uppercase tracking-wide',
                  col.className,
                )}
              >
                {col.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="divide-y divide-border">
          {loading ? (
            Array.from({ length: 5 }).map((_, i) => (
              <tr key={i}>
                {columns.map(col => (
                  <td key={col.key} className="px-4 py-3">
                    <div className="h-4 bg-gray-100 rounded animate-pulse w-3/4" />
                  </td>
                ))}
              </tr>
            ))
          ) : data.length === 0 ? (
            <tr>
              <td colSpan={columns.length} className="px-4 py-12 text-center text-muted">
                {emptyText}
              </td>
            </tr>
          ) : (
            data.map(row => (
              <tr
                key={String(row[keyField])}
                onClick={() => onRowClick?.(row)}
                className={cn(
                  'hover:bg-surface transition-colors',
                  onRowClick && 'cursor-pointer',
                )}
              >
                {columns.map(col => (
                  <td key={col.key} className={cn('px-4 py-3 text-ink', col.className)}>
                    {col.render ? col.render(row) : row[col.key]}
                  </td>
                ))}
              </tr>
            ))
          )}
        </tbody>
      </table>
    </div>
  )
}
