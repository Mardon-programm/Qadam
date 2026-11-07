'use client'
import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { authApi, saveTokens } from '@/lib/api'
import { Button } from '@/components/ui/Button'
import { Car } from 'lucide-react'

export default function LoginPage() {
  const router = useRouter()
  const [mode, setMode] = useState<'otp' | 'password'>('password')
  const [phone, setPhone] = useState('+996')
  const [password, setPassword] = useState('')
  const [code, setCode] = useState('')
  const [step, setStep] = useState<'phone' | 'otp'>('phone')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [debugCode, setDebugCode] = useState<string | null>(null)

  function afterLogin(data: any) {
    if (data.role !== 'ops') {
      setError('Доступ только для операторов')
      return false
    }
    saveTokens(data.access_token, data.refresh_token)
    router.push('/dashboard')
    return true
  }

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
      afterLogin(r.data)
    } catch (e: any) {
      setError(e.response?.data?.message ?? 'Неверный код')
    } finally {
      setLoading(false)
    }
  }

  async function loginWithPassword() {
    setLoading(true); setError('')
    try {
      const r = await authApi.loginOps(phone.trim() || null, password)
      afterLogin(r.data)
    } catch (e: any) {
      setError(e.response?.data?.message ?? e.response?.data?.detail ?? 'Неверный пароль')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-surface flex items-center justify-center p-4">
      <div className="bg-card rounded-2xl border border-border p-8 w-full max-w-sm shadow-sm">
        {/* Logo */}
        <div className="flex items-center gap-3 mb-6">
          <div className="w-10 h-10 bg-primary rounded-xl flex items-center justify-center">
            <Car size={20} className="text-white" />
          </div>
          <div>
            <p className="font-bold text-ink">Qadam</p>
            <p className="text-xs text-muted">Operations Panel</p>
          </div>
        </div>

        <div className="flex gap-2 mb-6">
          <button
            onClick={() => { setMode('password'); setError('') }}
            className={`flex-1 px-3 py-1.5 rounded-full text-sm font-medium transition-colors ${
              mode === 'password' ? 'bg-primary text-white' : 'bg-surface border border-border text-muted'
            }`}
          >
            Пароль
          </button>
          <button
            onClick={() => { setMode('otp'); setStep('phone'); setError('') }}
            className={`flex-1 px-3 py-1.5 rounded-full text-sm font-medium transition-colors ${
              mode === 'otp' ? 'bg-primary text-white' : 'bg-surface border border-border text-muted'
            }`}
          >
            Код (OTP)
          </button>
        </div>

        <h1 className="text-xl font-bold text-ink mb-1">
          {mode === 'password' ? 'Войти в систему' : step === 'phone' ? 'Войти в систему' : 'Введите код'}
        </h1>
        <p className="text-sm text-muted mb-6">
          {mode === 'password'
            ? 'Вход оператора по паролю'
            : step === 'phone'
            ? 'Укажите номер телефона оператора'
            : `Код отправлен на ${phone}`}
        </p>

        {mode === 'password' ? (
          <>
            <input
              type="tel"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              placeholder="+996 700 000 001"
              className="w-full px-4 py-3 rounded-xl border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 bg-surface"
            />
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Пароль оператора"
              className="w-full mt-3 px-4 py-3 rounded-xl border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 bg-surface"
            />
            {error && <p className="mt-2 text-xs text-danger">{error}</p>}
            <Button
              className="w-full mt-4"
              onClick={loginWithPassword}
              loading={loading}
              disabled={!password}
            >
              Войти
            </Button>
          </>
        ) : step === 'phone' ? (
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
