'use client'
import { useState } from 'react'
import useSWR from 'swr'
import { supportApi } from '@/lib/api'
import { Header } from '@/components/layout/Header'
import { DataTable } from '@/components/ui/Table'
import { StatusBadge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Modal } from '@/components/ui/Modal'
import { fmtDate } from '@/lib/utils'
import { MessageSquare } from 'lucide-react'

export default function SupportPage() {
  const [statusFilter, setStatusFilter] = useState('open')
  const [selected, setSelected] = useState<any>(null)
  const [resolution, setResolution] = useState('')
  const [loading, setLoading] = useState(false)

  const { data, isLoading, mutate } = useSWR(
    `/support?status=${statusFilter}`,
    () => supportApi.list(statusFilter ? { status: statusFilter } : {}).then(r => r.data),
  )

  async function resolve(id: string) {
    if (!resolution.trim()) return
    setLoading(true)
    try {
      await supportApi.resolve(id, resolution)
      mutate()
      setSelected(null)
      setResolution('')
    } finally {
      setLoading(false)
    }
  }

  async function close(id: string) {
    if (!confirm('Закрыть обращение?')) return
    await supportApi.close(id)
    mutate()
    setSelected(null)
  }

  const columns = [
    {
      key: 'id',
      header: 'ID',
      render: (r: any) => <span className="font-mono text-xs">{r.id.slice(0, 8)}</span>,
    },
    { key: 'case_type', header: 'Тип' },
    {
      key: 'subject',
      header: 'Тема',
      render: (r: any) => (
        <span className="font-medium text-ink">{r.subject}</span>
      ),
    },
    {
      key: 'status',
      header: 'Статус',
      render: (r: any) => <StatusBadge status={r.status} />,
    },
    {
      key: 'created_at',
      header: 'Дата',
      render: (r: any) => <span className="text-xs text-muted">{fmtDate(r.created_at)}</span>,
    },
    {
      key: 'actions',
      header: '',
      render: (r: any) => (
        <Button size="sm" variant="outline" onClick={(e) => { e.stopPropagation(); setSelected(r) }}>
          <MessageSquare size={14} /> Открыть
        </Button>
      ),
    },
  ]

  return (
    <div>
      <Header title="Поддержка" />
      <div className="p-6 space-y-4">
        <div className="flex gap-2">
          {['open', 'in_progress', 'resolved', 'closed', ''].map((s) => (
            <button
              key={s}
              onClick={() => setStatusFilter(s)}
              className={`px-4 py-1.5 rounded-full text-sm font-medium transition-colors ${
                statusFilter === s
                  ? 'bg-primary text-white'
                  : 'bg-card border border-border text-muted hover:text-ink'
              }`}
            >
              {s === '' ? 'Все' : s === 'open' ? 'Открытые'
               : s === 'in_progress' ? 'В работе'
               : s === 'resolved' ? 'Решённые' : 'Закрытые'}
            </button>
          ))}
        </div>

        <DataTable
          columns={columns}
          data={data ?? []}
          loading={isLoading}
          onRowClick={setSelected}
          emptyText="Обращений нет"
        />
      </div>

      <Modal
        open={!!selected}
        onClose={() => { setSelected(null); setResolution('') }}
        title="Обращение"
      >
        {selected && (
          <div className="space-y-4">
            <div>
              <p className="text-xs text-muted">Тема</p>
              <p className="font-semibold text-ink mt-0.5">{selected.subject}</p>
            </div>
            <div>
              <p className="text-xs text-muted">Описание</p>
              <p className="text-sm text-ink mt-0.5 whitespace-pre-wrap">{selected.description}</p>
            </div>
            <div className="flex gap-3">
              <div>
                <p className="text-xs text-muted">Тип</p>
                <p className="text-sm font-medium">{selected.case_type}</p>
              </div>
              <div>
                <p className="text-xs text-muted">Статус</p>
                <StatusBadge status={selected.status} className="mt-0.5" />
              </div>
            </div>
            {selected.resolution && (
              <div className="bg-green-50 rounded-xl p-3">
                <p className="text-xs text-muted">Ответ</p>
                <p className="text-sm text-green-800 mt-0.5">{selected.resolution}</p>
              </div>
            )}
            {!['resolved', 'closed'].includes(selected.status) && (
              <>
                <textarea
                  value={resolution}
                  onChange={e => setResolution(e.target.value)}
                  placeholder="Напишите ответ пользователю…"
                  rows={4}
                  className="w-full px-4 py-3 border border-border rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 resize-none"
                />
                <div className="flex gap-2">
                  <Button
                    className="flex-1"
                    loading={loading}
                    disabled={!resolution.trim()}
                    onClick={() => resolve(selected.id)}
                  >
                    Решить
                  </Button>
                  <Button
                    variant="outline"
                    onClick={() => close(selected.id)}
                  >
                    Закрыть
                  </Button>
                </div>
              </>
            )}
          </div>
        )}
      </Modal>
    </div>
  )
}
