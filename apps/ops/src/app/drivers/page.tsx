'use client'
import { useState } from 'react'
import useSWR from 'swr'
import { opsApi } from '@/lib/api'
import { Header } from '@/components/layout/Header'
import { DataTable } from '@/components/ui/Table'
import { StatusBadge } from '@/components/ui/Badge'
import { Button } from '@/components/ui/Button'
import { Modal } from '@/components/ui/Modal'
import { fmtDate } from '@/lib/utils'
import { CheckCircle, XCircle, AlertTriangle } from 'lucide-react'

export default function DriversPage() {
  const [filter, setFilter] = useState<string>('')
  const [selected, setSelected] = useState<any>(null)
  const [docsModal, setDocsModal] = useState(false)
  const [vehiclesModal, setVehiclesModal] = useState(false)
  const [rejReason, setRejReason] = useState('')
  const [loading, setLoading] = useState(false)

  const { data: drivers, isLoading, mutate } = useSWR(
    `/ops/drivers?${filter}`,
    () => opsApi.drivers(filter ? { verification_status: filter } : {}).then(r => r.data),
  )
  const { data: pending } = useSWR('/ops/drivers/pending-docs', () =>
    opsApi.pendingDocs().then(r => r.data),
  )
  const { data: docs, mutate: mutateDocs } = useSWR(
    selected && docsModal ? `/ops/driver/${selected.id}/documents` : null,
    () => opsApi.driverDocuments(selected.id).then(r => r.data),
  )
  const { data: vehicles, mutate: mutateVehicles } = useSWR(
    selected && vehiclesModal ? `/ops/driver/${selected.id}/vehicles` : null,
    () => opsApi.driverVehicles(selected.id).then(r => r.data),
  )

  async function reviewDoc(docId: string, approve: boolean) {
    setLoading(true)
    try {
      await opsApi.reviewDocument(docId, approve, approve ? undefined : rejReason)
      mutateDocs()
      mutate()
    } finally {
      setLoading(false)
      setRejReason('')
    }
  }

  async function reviewVehicle(vehicleId: string, approve: boolean) {
    setLoading(true)
    try {
      await opsApi.reviewVehicle(vehicleId, approve)
      mutateVehicles()
      mutate()
    } finally {
      setLoading(false)
    }
  }

  async function blockDriver(driverId: string) {
    if (!confirm('Заблокировать водителя?')) return
    await opsApi.blockDriver(driverId, 'ops_decision')
    mutate()
  }

  const columns = [
    {
      key: 'id',
      header: 'ID',
      render: (r: any) => (
        <span className="font-mono text-xs">{r.id.slice(0, 8)}</span>
      ),
    },
    { key: 'user_id', header: 'User ID',
      render: (r: any) => <span className="font-mono text-xs">{r.user_id.slice(0, 8)}</span>,
    },
    {
      key: 'verification_status',
      header: 'Верификация',
      render: (r: any) => <StatusBadge status={r.verification_status} />,
    },
    {
      key: 'online_status',
      header: 'Онлайн',
      render: (r: any) => <StatusBadge status={r.online_status} />,
    },
    {
      key: 'rating',
      header: 'Рейтинг',
      render: (r: any) => (
        <span className="font-medium">⭐ {parseFloat(r.rating).toFixed(2)}</span>
      ),
    },
    {
      key: 'actions',
      header: '',
      render: (r: any) => (
        <div className="flex gap-2">
          <Button
            size="sm"
            variant="outline"
            onClick={(e) => {
              e.stopPropagation()
              setSelected(r)
              setDocsModal(true)
            }}
          >
            Документы
          </Button>
          <Button
            size="sm"
            variant="outline"
            onClick={(e) => {
              e.stopPropagation()
              setSelected(r)
              setVehiclesModal(true)
            }}
          >
            Авто
          </Button>
          <Button
            size="sm"
            variant="danger"
            onClick={(e) => {
              e.stopPropagation()
              blockDriver(r.id)
            }}
          >
            Блок
          </Button>
        </div>
      ),
    },
  ]

  return (
    <div>
      <Header title="Водители" />
      <div className="p-6 space-y-4">
        {/* Pending docs alert */}
        {pending && pending.length > 0 && (
          <div className="flex items-center gap-3 bg-yellow-50 border border-yellow-200 rounded-xl px-4 py-3">
            <AlertTriangle size={18} className="text-warning flex-shrink-0" />
            <p className="text-sm text-yellow-800">
              <strong>{pending.length}</strong> водителей ожидают проверки документов
            </p>
            <Button
              size="sm"
              variant="outline"
              className="ml-auto border-yellow-300 text-yellow-700"
              onClick={() => setFilter('pending')}
            >
              Показать
            </Button>
          </div>
        )}

        {/* Filter tabs */}
        <div className="flex gap-2">
          {['', 'pending', 'approved', 'rejected'].map((f) => (
            <button
              key={f}
              onClick={() => setFilter(f)}
              className={`px-4 py-1.5 rounded-full text-sm font-medium transition-colors ${
                filter === f
                  ? 'bg-primary text-white'
                  : 'bg-card border border-border text-muted hover:text-ink'
              }`}
            >
              {f === '' ? 'Все' : f === 'pending' ? 'На проверке'
               : f === 'approved' ? 'Одобрены' : 'Отклонены'}
            </button>
          ))}
        </div>

        <DataTable
          columns={columns}
          data={drivers ?? []}
          loading={isLoading}
          emptyText="Водители не найдены"
        />
      </div>

      {/* Documents modal */}
      <Modal
        open={docsModal}
        onClose={() => { setDocsModal(false); setSelected(null) }}
        title={`Документы водителя ${selected?.id?.slice(0, 8) ?? ''}`}
        className="max-w-2xl"
      >
        {!docs ? (
          <div className="flex justify-center py-8">
            <div className="w-8 h-8 border-4 border-primary border-t-transparent rounded-full animate-spin" />
          </div>
        ) : docs.length === 0 ? (
          <p className="text-muted text-center py-8">Документов нет</p>
        ) : (
          <div className="space-y-3">
            {docs.map((doc: any) => (
              <div key={doc.id} className="border border-border rounded-xl p-4">
                <div className="flex items-start justify-between">
                  <div>
                    <p className="font-medium text-ink">{DOC_LABELS[doc.doc_type] ?? doc.doc_type}</p>
                    {doc.document_number && (
                      <p className="text-xs text-muted mt-0.5">№ {doc.document_number}</p>
                    )}
                    {doc.expires_on && (
                      <p className="text-xs text-muted">Истекает: {doc.expires_on}</p>
                    )}
                    {doc.rejection_reason && (
                      <p className="text-xs text-danger mt-1">Причина: {doc.rejection_reason}</p>
                    )}
                  </div>
                  <StatusBadge status={doc.status} />
                </div>

                {doc.status === 'pending' && (
                  <div className="flex gap-2 mt-3">
                    <Button
                      size="sm"
                      variant="primary"
                      loading={loading}
                      onClick={() => reviewDoc(doc.id, true)}
                    >
                      <CheckCircle size={14} /> Одобрить
                    </Button>
                    <div className="flex-1 flex gap-2">
                      <input
                        value={rejReason}
                        onChange={e => setRejReason(e.target.value)}
                        placeholder="Причина отклонения"
                        className="flex-1 px-3 py-1.5 text-sm border border-border rounded-lg focus:outline-none focus:ring-1 focus:ring-danger/30"
                      />
                      <Button
                        size="sm"
                        variant="danger"
                        loading={loading}
                        disabled={!rejReason}
                        onClick={() => reviewDoc(doc.id, false)}
                      >
                        <XCircle size={14} /> Отклонить
                      </Button>
                    </div>
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </Modal>

      {/* Vehicles modal */}
      <Modal
        open={vehiclesModal}
        onClose={() => { setVehiclesModal(false); setSelected(null) }}
        title={`Автомобили водителя ${selected?.id?.slice(0, 8) ?? ''}`}
        className="max-w-2xl"
      >
        {!vehicles ? (
          <div className="flex justify-center py-8">
            <div className="w-8 h-8 border-4 border-primary border-t-transparent rounded-full animate-spin" />
          </div>
        ) : vehicles.length === 0 ? (
          <p className="text-muted text-center py-8">Автомобилей нет</p>
        ) : (
          <div className="space-y-3">
            {vehicles.map((v: any) => (
              <div key={v.id} className="border border-border rounded-xl p-4">
                <div className="flex items-start justify-between">
                  <div>
                    <p className="font-medium text-ink">
                      {v.make} {v.model} · {v.plate_number}
                    </p>
                    <p className="text-xs text-muted mt-0.5">
                      {v.color ? `${v.color} · ` : ''}{v.seats} мест · {v.vehicle_class}
                    </p>
                  </div>
                  <StatusBadge status={v.status} />
                </div>

                {v.status === 'pending' && (
                  <div className="flex gap-2 mt-3">
                    <Button
                      size="sm"
                      variant="primary"
                      loading={loading}
                      onClick={() => reviewVehicle(v.id, true)}
                    >
                      <CheckCircle size={14} /> Одобрить
                    </Button>
                    <Button
                      size="sm"
                      variant="danger"
                      loading={loading}
                      onClick={() => reviewVehicle(v.id, false)}
                    >
                      <XCircle size={14} /> Отклонить
                    </Button>
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </Modal>
    </div>
  )
}

const DOC_LABELS: Record<string, string> = {
  driver_license: 'Водительское удостоверение',
  vehicle_registration: 'Тех. паспорт',
  taxi_license: 'Лицензия такси',
  insurance: 'Страховка',
  passport: 'Паспорт',
  selfie: 'Селфи',
}
