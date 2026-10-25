'use client'
import { useState } from 'react'
import useSWR from 'swr'
import { opsApi } from '@/lib/api'
import { Header } from '@/components/layout/Header'
import { DataTable } from '@/components/ui/Table'
import { StatusBadge } from '@/components/ui/Badge'
import { fmtDate, fmtMoney } from '@/lib/utils'

const STATUSES = [
  '', 'searching', 'assigned', 'driver_arriving',
  'in_progress', 'completed', 'cancelled',
]

export default function RidesPage() {
  const [status, setStatus] = useState('')

  const { data, isLoading } = useSWR(
    `/ops/rides?status=${status}`,
    () => opsApi.rides(status ? { status } : {}).then(r => r.data),
    { refreshInterval: 15_000 },
  )

  const columns = [
    {
      key: 'id',
      header: 'ID',
      render: (r: any) => <span className="font-mono text-xs">{r.id.slice(0, 8)}</span>,
    },
    { key: 'city', header: 'Город' },
    {
      key: 'status',
      header: 'Статус',
      render: (r: any) => <StatusBadge status={r.status} />,
    },
    {
      key: 'quoted_price',
      header: 'Цена',
      render: (r: any) => r.quoted_price ? fmtMoney(r.quoted_price) : '—',
    },
    {
      key: 'final_price',
      header: 'Итог',
      render: (r: any) => r.final_price ? fmtMoney(r.final_price) : '—',
    },
    {
      key: 'created_at',
      header: 'Создан',
      render: (r: any) => <span className="text-xs text-muted">{fmtDate(r.created_at)}</span>,
    },
    {
      key: 'passenger_id',
      header: 'Пассажир',
      render: (r: any) => <span className="font-mono text-xs">{r.passenger_id.slice(0, 8)}</span>,
    },
    {
      key: 'driver_id',
      header: 'Водитель',
      render: (r: any) => r.driver_id
        ? <span className="font-mono text-xs">{r.driver_id.slice(0, 8)}</span>
        : <span className="text-muted">—</span>,
    },
  ]

  return (
    <div>
      <Header title="Поездки" />
      <div className="p-6 space-y-4">
        {/* Status filter */}
        <div className="flex flex-wrap gap-2">
          {STATUSES.map((s) => (
            <button
              key={s}
              onClick={() => setStatus(s)}
              className={`px-4 py-1.5 rounded-full text-sm font-medium transition-colors ${
                status === s
                  ? 'bg-primary text-white'
                  : 'bg-card border border-border text-muted hover:text-ink'
              }`}
            >
              {s === '' ? 'Все' : s}
            </button>
          ))}
        </div>

        <DataTable
          columns={columns}
          data={data ?? []}
          loading={isLoading}
          emptyText="Поездок нет"
        />
      </div>
    </div>
  )
}
