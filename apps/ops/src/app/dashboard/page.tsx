'use client'
import useSWR from 'swr'
import { opsApi } from '@/lib/api'
import { StatCard } from '@/components/ui/Card'
import { Header } from '@/components/layout/Header'
import {
  Users, Car, Map, BookOpen, HeadphonesIcon, TrendingUp,
} from 'lucide-react'
import { fmtMoney } from '@/lib/utils'
import {
  BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid,
} from 'recharts'

export default function DashboardPage() {
  const { data: stats, isLoading } = useSWR('/ops/stats', () =>
    opsApi.stats().then(r => r.data),
  )
  const { data: revenue } = useSWR('/ops/reports/revenue', () =>
    opsApi.revenueReport(30).then(r => r.data),
  )
  const { data: balance } = useSWR('/ops/finance/platform-balance', () =>
    opsApi.platformBalance().then(r => r.data),
  )

  return (
    <div>
      <Header title="Дашборд" />
      <div className="p-6 space-y-6">
        {/* Stats grid */}
        <div className="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4">
          <StatCard
            label="Пользователи"
            value={stats?.total_users ?? '—'}
            icon={<Users size={20} />}
            color="text-primary"
          />
          <StatCard
            label="Водители"
            value={stats?.total_drivers ?? '—'}
            icon={<Car size={20} />}
            color="text-primary"
          />
          <StatCard
            label="Онлайн"
            value={stats?.active_drivers_online ?? '—'}
            icon={<Car size={20} />}
            color="text-success"
          />
          <StatCard
            label="Поездки сегодня"
            value={stats?.rides_today ?? '—'}
            icon={<Map size={20} />}
            color="text-primary"
          />
          <StatCard
            label="Брони сегодня"
            value={stats?.bookings_today ?? '—'}
            icon={<BookOpen size={20} />}
            color="text-warning"
          />
          <StatCard
            label="Открытые тикеты"
            value={stats?.open_support_cases ?? '—'}
            icon={<HeadphonesIcon size={20} />}
            color="text-danger"
          />
        </div>

        {/* Revenue + Balance */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
          {/* Revenue chart */}
          <div className="lg:col-span-2 bg-card rounded-card border border-border p-5">
            <div className="flex items-center justify-between mb-4">
              <h3 className="font-semibold text-ink">Выручка платформы (30 дней)</h3>
              {revenue && (
                <span className="text-lg font-bold text-primary">
                  {fmtMoney(revenue.platform_fee_revenue)}
                </span>
              )}
            </div>
            <div className="h-48">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={[
                  { name: 'Поездки', value: revenue?.completed_rides ?? 0 },
                ]}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#E5E7EB" />
                  <XAxis dataKey="name" tick={{ fontSize: 12 }} />
                  <YAxis tick={{ fontSize: 12 }} />
                  <Tooltip />
                  <Bar dataKey="value" fill="#1E6FE8" radius={[6, 6, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>

          {/* Platform balance */}
          <div className="bg-card rounded-card border border-border p-5 flex flex-col justify-between">
            <div>
              <p className="text-sm text-muted flex items-center gap-2">
                <TrendingUp size={16} />
                Баланс платформы
              </p>
              <p className="text-3xl font-extrabold text-ink mt-2">
                {balance ? fmtMoney(balance.balance) : '—'}
              </p>
            </div>
            <div className="mt-4 space-y-2 text-sm">
              <div className="flex justify-between text-muted">
                <span>Завершённых поездок</span>
                <span className="font-medium text-ink">{revenue?.completed_rides ?? '—'}</span>
              </div>
              <div className="flex justify-between text-muted">
                <span>Период</span>
                <span className="font-medium text-ink">30 дней</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
