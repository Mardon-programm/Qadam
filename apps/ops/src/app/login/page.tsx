'use client'
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { authApi, saveTokens } from '@/lib/api'
import { Button } from '@/components/ui/Button'
import { Car } from 'lucide-react'

export default function LoginPage() {
  const router = useRouter()
  const [phone, setPhone] = useState('+996')
  const [code, setCode] = useState('')
  const [step, setStep] = useState<'phone' | 'otp'>('phone')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [debugCode, setDebugCode] = useState<string | null>(null)

  async function requestOtp() {
    setLoading(true); setError('')
    try {
      const r = await authApi.requestOtp(phone)
      setDebugCode(r.data.debug_code ?? null)
      setStep('otp')
    } catch (e: any) {
      setError(e.response?.data?.message ?? 'Ошибка отправки кода')
    } finally {
      setLoading(false)
    }
  }

  async function verifyOtp() {
    setLoading(true); setError('')
    try {
      const r = await authApi.verifyOtp(phone, code)
      if (r.data.role !== 'ops') {
        setError('Доступ только для операторов')
        return
      }
      saveTokens(r.data.access_token, r.data.refresh_token)
      router.push('/dashboard')
    } catch (e: any) {
      setError(e.response?.data?.message ?? 'Неверный код')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-surface flex items-center justify-center p-4">
      <div className="bg-card rounded-2xl border border-border p-8 w-full max-w-sm shadow-sm">
        {/* Logo */}
        <div className="flex items-center gap-3 mb-8">
          <div className="w-10 h-10 bg-primary rounded-xl flex items-center justify-center">
            <Car size={20} className="text-white" />
          </div>
          <div>
            <p className="font-bold text-ink">Qadam</p>
            <p className="text-xs text-muted">Operations Panel</p>
          </div>
        </div>

        <h1 className="text-xl font-bold text-ink mb-1">
          {step === 'phone' ? 'Войти в систему' : 'Введите код'}
        </h1>
        <p className="text-sm text-muted mb-6">
          {step === 'phone'
            ? 'Укажите номер телефона оператора'
            : `Код отправлен на ${phone}`}
        </p>

        {step === 'phone' ? (
          <>
            <input
              type="tel"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              placeholder="+996 700 000 000"
              className="w-full px-4 py-3 rounded-xl border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 bg-surface"
            />
            {error && <p className="mt-2 text-xs text-danger">{error}</p>}
            <Button
              className="w-full mt-4"
              onClick={requestOtp}
              loading={loading}
            >
              Получить код
            </Button>
          </>
        ) : (
          <>
            <input
              type="text"
              value={code}
              onChange={(e) => setCode(e.target.value)}
              placeholder="000000"
              maxLength={6}
              className="w-full px-4 py-3 rounded-xl border border-border text-sm text-center tracking-[0.5em] focus:outline-none focus:ring-2 focus:ring-primary/30 bg-surface font-mono"
              autoFocus
            />
            {debugCode && (
              <p className="mt-2 text-xs text-muted text-center">
                DEV-код: <span className="font-mono font-bold text-primary">{debugCode}</span>
              </p>
            )}
            {error && <p className="mt-2 text-xs text-danger">{error}</p>}
            <Button
              className="w-full mt-4"
              onClick={verifyOtp}
              loading={loading}
              disabled={code.length < 6}
            >
              Войти
            </Button>
            <button
              onClick={() => setStep('phone')}
              className="w-full mt-2 text-xs text-muted hover:text-ink transition-colors"
            >
              Изменить номер
            </button>
          </>
        )}
      </div>
    </div>
  )
}
