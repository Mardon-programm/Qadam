import axios, { AxiosInstance, AxiosError } from 'axios'
import Cookies from 'js-cookie'

const BASE = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:8000/api/v1'

const ACCESS_KEY = 'qadam_ops_access'
const REFRESH_KEY = 'qadam_ops_refresh'

export function getAccessToken() { return Cookies.get(ACCESS_KEY) ?? null }
export function getRefreshToken() { return Cookies.get(REFRESH_KEY) ?? null }

export function saveTokens(access: string, refresh: string) {
  Cookies.set(ACCESS_KEY, access, { expires: 1, sameSite: 'lax' })
  Cookies.set(REFRESH_KEY, refresh, { expires: 30, sameSite: 'lax' })
}

export function clearTokens() {
  Cookies.remove(ACCESS_KEY)
  Cookies.remove(REFRESH_KEY)
}

// ── Axios instance ─────────────────────────────────────────────────────────

const api: AxiosInstance = axios.create({
  baseURL: BASE,
  headers: { 'Content-Type': 'application/json' },
})

api.interceptors.request.use((config) => {
  const token = getAccessToken()
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

api.interceptors.response.use(
  (r) => r,
  async (err: AxiosError) => {
    if (err.response?.status === 401) {
      const rt = getRefreshToken()
      if (rt) {
        try {
          const r = await axios.post(`${BASE}/auth/refresh`, { refresh_token: rt })
          saveTokens(r.data.access_token, r.data.refresh_token)
          if (err.config) {
            err.config.headers.Authorization = `Bearer ${r.data.access_token}`
            return api.request(err.config)
          }
        } catch {
          clearTokens()
          if (typeof window !== 'undefined') window.location.href = '/login'
        }
      }
    }
    return Promise.reject(err)
  },
)

export default api

// ── Typed API helpers ──────────────────────────────────────────────────────

export const authApi = {
  requestOtp: (phone: string) =>
    api.post('/auth/otp/request', { phone, role: 'ops' }),
  verifyOtp: (phone: string, code: string) =>
    api.post('/auth/otp/verify', { phone, code, role: 'ops' }),
  me: () => api.get('/auth/me'),
}

export const opsApi = {
  stats: () => api.get('/ops/stats'),
  users: (params?: Record<string, string>) => api.get('/ops/users', { params }),
  blockUser: (id: string, reason: string) =>
    api.post(`/ops/users/${id}/block`, { reason }),
  unblockUser: (id: string) => api.post(`/ops/users/${id}/unblock`),
  drivers: (params?: Record<string, string>) => api.get('/ops/drivers', { params }),
  pendingDocs: () => api.get('/ops/drivers/pending-docs'),
  driverDocuments: (driverId: string) =>
    api.get(`/ops/driver/${driverId}/documents`),
  driverVehicles: (driverId: string) =>
    api.get(`/ops/driver/${driverId}/vehicles`),
  reviewVehicle: (vehicleId: string, approve: boolean) =>
    api.post(`/ops/driver/vehicles/${vehicleId}/review`, { approve }),
  reviewDocument: (docId: string, approve: boolean, reason?: string) =>
    api.post(`/ops/driver/documents/${docId}/review`, {
      approve,
      rejection_reason: reason ?? null,
    }),
  blockDriver: (driverId: string, reason: string) =>
    api.post(`/ops/driver/${driverId}/block`, null, { params: { reason } }),
  rides: (params?: Record<string, string>) => api.get('/ops/rides', { params }),
  bookings: (params?: Record<string, string>) => api.get('/ops/bookings', { params }),
  audit: (params?: Record<string, string>) => api.get('/ops/audit', { params }),
  platformBalance: () => api.get('/ops/finance/platform-balance'),
  revenueReport: (days = 30) => api.get('/ops/reports/revenue', { params: { days } }),
}

export const supportApi = {
  list: (params?: Record<string, string>) => api.get('/support', { params }),
  resolve: (id: string, resolution: string) =>
    api.post(`/support/${id}/resolve`, { resolution }),
  close: (id: string) => api.post(`/support/${id}/close`),
}
