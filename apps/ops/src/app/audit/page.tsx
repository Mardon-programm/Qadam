'use client'
import { useState } from 'react'
import useSWR from 'swr'
import { opsApi } from '@/lib/api'
import { Header } from '@/components/layout/Header'
import { DataTable } from '@/components/ui/Table'
import { fmtDate } from '@/lib/utils'

export default function AuditPage() {
  const [actorId, setActorId] = useState('')
  const [action, setAction] = useState('')
  const [objectType, setObjectType] = useState('')

  const params: Record<string, string> = {}
  if (actorId) params.actor_id = actorId
  if (action) params.action = action
  if (objectType) params.object_type = objectType

  const { data, isLoading } = useSWR(
    `/ops/audit?${new URLSearchParams(params)}`,
    () => opsApi.audit(params).then(r => r.data),
  )

  const columns = [
    {
      key: 'created_at',
      header: 'Время',
      render: (r: any) => (
        <span className="text-xs text-muted whitespace-nowrap">{fmtDate(r.created_at)}</span>
      ),
    },
    {
      key: 'actor_id',
      header: 'Субъект',
      render: (r: any) => (
        <div>
          <span className="font-mono text-xs">{r.actor_id?.slice(0, 8) ?? 'system'}</span>
          {r.actor_role && (
            <span className="ml-2 text-xs text-muted">[{r.actor_role}]</span>
          )}
        </div>
      ),
    },
    {
      key: 'action',
      header: 'Действие',
      render: (r: any) => (
        <code className="text-xs bg-surface px-2 py-0.5 rounded font-mono">{r.action}</code>
      ),
    },
    {
      key: 'object',
      header: 'Объект',
      render: (r: any) => (
        <span className="text-xs text-muted">
          {r.object_type}{r.object_id ? ` / ${r.object_id.slice(0, 8)}` : ''}
        </span>
      ),
    },
    {
      key: 'ip_address',
      header: 'IP',
      render: (r: any) => <span className="text-xs text-muted">{r.ip_address ?? '—'}</span>,
    },
  ]

  return (
    <div>
      <Header title="Аудит" />
      <div className="p-6 space-y-4">
        {/* Filters */}
        <div className="flex gap-3 flex-wrap">
          <input
            value={actorId}
            onChange={e => setActorId(e.target.value)}
            placeholder="Actor ID"
            className="px-4 py-2 border border-border rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 w-48"
          />
          <input
            value={action}
            onChange={e => setAction(e.target.value)}
            placeholder="Действие (напр. auth.login)"
            className="px-4 py-2 border border-border rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 w-56"
          />
          <input
            value={objectType}
            onChange={e => setObjectType(e.target.value)}
            placeholder="Тип объекта (напр. user)"
            className="px-4 py-2 border border-border rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 w-48"
          />
        </div>

        <DataTable
          columns={columns}
          data={data ?? []}
          loading={isLoading}
          emptyText="Событий не найдено"
        />
      </div>
    </div>
  )
}
