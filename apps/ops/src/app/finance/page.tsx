'use client'
import useSWR from 'swr'
import { opsApi } from '@/lib/api'
import { Header } from '@/components/layout/Header'
import { Card, StatCard } from '@/components/ui/Card'
import { fmtMoney } from '@/lib/utils'
import { Banknote, TrendingUp, CheckCircle } from 'lucide-react'

export default function FinancePage() {
  const { data: balance } = useSWR('/ops/finance/platform-balance', () =>
    opsApi.platformBalance().then(r => r.data),
  )
  const { data: rev30 } = useSWR('/ops/reports/revenue?30', () =>
    opsApi.revenueReport(30).then(r => r.data),
  )
  const { data: rev7 } = useSWR('/ops/reports/revenue?7', () =>
    opsApi.revenueReport(7).then(r => r.data),
  )

  return (
    <div>
      <Header title="Финансы" />
      <div className="p-6 space-y-6">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <StatCard
            label="Баланс платформы"
            value={balance ? fmtMoney(balance.balance) : '—'}
            icon={<Banknote size={20} />}
            color="text-primary"
          />
          <StatCard
            label="Выручка за 7 дней"
            value={rev7 ? fmtMoney(rev7.platform_fee_revenue) : '—'}
            icon={<TrendingUp size={20} />}
            color="text-success"
            sub={`${rev7?.completed_rides ?? 0} завершённых поездок`}
          />
          <StatCard
            label="Выручка за 30 дней"
            value={rev30 ? fmtMoney(rev30.platform_fee_revenue) : '—'}
            icon={<CheckCircle size={20} />}
            color="text-primary"
            sub={`${rev30?.completed_rides ?? 0} завершённых поездок`}
          />
        </div>

        <Card title="Детали финансов">
          <div className="space-y-4">
            {[
              { label: 'Счёт', value: balance?.account_id ?? '—' },
              { label: 'Валюта', value: balance?.currency ?? 'KGS' },
              { label: 'Период (30 дней)', value: rev30 ? fmtMoney(rev30.platform_fee_revenue) : '—' },
              { label: 'Завершено поездок (30 дн.)', value: rev30?.completed_rides ?? '—' },
            ].map(({ label, value }) => (
              <div key={label} className="flex justify-between items-center py-2 border-b border-border last:border-0">
                <span className="text-sm text-muted">{label}</span>
                <span className="text-sm font-semibold text-ink">{String(value)}</span>
              </div>
            ))}
          </div>
        </Card>

        <Card title="Примечания">
          <ul className="space-y-2 text-sm text-muted list-disc list-inside">
            <li>Баланс платформы — сумма всех кредитов комиссий за поездки и бронирования.</li>
            <li>Средства водителей хранятся отдельно в их кошельках и не включены в этот баланс.</li>
            <li>Выплаты водителям обрабатываются через раздел «Водители».</li>
          </ul>
        </Card>
      </div>
    </div>
  )
}
