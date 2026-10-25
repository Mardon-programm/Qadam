'use client'
import { useState } from 'react'
import useSWR from 'swr'
import { opsApi } from '@/lib/api'
import { Header } from '@/components/layout/Header'
import { DataTable } from '@/components/ui/Table'
import { StatusBadge } from '@/components/ui/Badge'
import { fmtDate, fmtMoney } from '@/lib/utils'

export default function BookingsPage() {
  const [status, setStatus] = useState('')

  const { data, isLoading } = useSWR(
    `/ops/bookings?status=${status}`,
    () => opsApi.bookings(status ? { status } : {}).then(r => r.data),
  )

  const columns = [
    {
      key: 'id',
      header: 'ID',
      render: (r: any) => <span className="font-mono text-xs">{r.id.slice(0, 8)}</span>,
    },
    {
      key: 'passenger_id',
      header: 'Пассажир',
      render: (r: any) => <span className="font-mono text-xs">{r.passenger_id.slice(0, 8)}</span>,
    },
    {
      key: 'status',
      header: 'Статус',
      render: (r: any) => <StatusBadge status={r.status} />,
    },
    {
      key: 'total_price',
      header: 'Сумма',
      render: (r: any) => fmtMoney(r.total_price),
    },
    {
      key: 'created_at',
      header: 'Дата',
      render: (r: any) => <span className="text-xs text-muted">{fmtDate(r.created_at)}</span>,
    },
  ]

  return (
    <div>
      <Header title="Бронирования" />
      <div className="p-6 space-y-4">
        <div className="flex gap-2 flex-wrap">
          {['', 'held', 'confirmed', 'completed', 'cancelled'].map((s) => (
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
          emptyText="Брони не найдены"
        />
      </div>
    </div>
  )
}
