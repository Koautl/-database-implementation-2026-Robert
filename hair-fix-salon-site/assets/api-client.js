/*
 * API boundary for the Hair Fix Salon front end.
 *
 * Pages should call this client instead of using fetch() directly. In mock
 * mode the methods return fictional data without persistence. In server mode
 * they call the REST endpoints documented in docs/API_CONTRACT.md.
 */
(function initializeApi(global) {
  const config = global.HAIR_FIX_CONFIG;
  const mockData = global.HAIR_FIX_MOCK_DATA;

  if (!config) {
    throw new Error('HAIR_FIX_CONFIG must load before api-client.js');
  }

  class ApiError extends Error {
    constructor(message, status = 0, details = null) {
      super(message);
      this.name = 'ApiError';
      this.status = status;
      this.details = details;
    }
  }

  async function request(path, options = {}) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), config.requestTimeoutMs);
    const { headers = {}, ...requestOptions } = options;

    try {
      const response = await fetch(`${config.apiBaseUrl}${path}`, {
        credentials: 'include',
        ...requestOptions,
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json',
          ...headers
        },
        signal: controller.signal
      });

      const payload = response.status === 204 ? null : await response.json();
      if (!response.ok) {
        throw new ApiError(payload?.message || 'The request failed.', response.status, payload);
      }
      return payload;
    } catch (error) {
      if (error.name === 'AbortError') {
        throw new ApiError('The request timed out. Please try again.');
      }
      throw error;
    } finally {
      clearTimeout(timeout);
    }
  }

  function mockResult(value) {
    return Promise.resolve(structuredClone(value));
  }

  const serverApi = {
    listServices: () => request('/services'),
    listStaff: (serviceId) => request(`/staff${serviceId ? `?serviceId=${encodeURIComponent(serviceId)}` : ''}`),
    getAvailability: ({ serviceId, staffId, date }) => {
      const query = new URLSearchParams({ serviceId, date });
      if (staffId) query.set('staffId', staffId);
      return request(`/availability?${query.toString()}`);
    },
    createAppointment: (appointment) => request('/appointments', { method: 'POST', body: JSON.stringify(appointment) }),
    authenticate: (credentials) => request('/auth/login', { method: 'POST', body: JSON.stringify(credentials) }),
    updateAppointmentStatus: (appointmentId, change) => request(`/appointments/${appointmentId}/status`, { method: 'PATCH', body: JSON.stringify(change) }),
    getCustomerDashboard: () => request('/customer/dashboard'),
    getStaffSchedule: (date) => request(`/staff/schedule?date=${encodeURIComponent(date)}`),
    getAdminOverview: (date) => request(`/admin/overview?date=${encodeURIComponent(date)}`),
    getReports: (parameters) => request(`/reports?${new URLSearchParams(parameters).toString()}`)
  };

  const mockApi = {
    listServices: () => mockResult(mockData.services.filter((service) => service.isActive)),
    listStaff: (serviceId) => {
      const normalizedId = Number(serviceId);
      const staff = mockData.staff.filter((member) => member.isActive && (!normalizedId || member.serviceIds.includes(normalizedId)));
      return mockResult(staff);
    },
    getAvailability: () => mockResult(mockData.availability),
    createAppointment: (appointment) => mockResult({
      appointmentId: null,
      status: 'prototype-only',
      persisted: false,
      appointment
    }),
    authenticate: ({ role }) => mockResult({
      authenticated: false,
      prototype: true,
      user: { userId: null, role }
    }),
    updateAppointmentStatus: (appointmentId, change) => mockResult({
      appointmentId: Number(appointmentId),
      status: change.status,
      persisted: false
    }),
    getCustomerDashboard: () => mockResult({ prototype: true }),
    getStaffSchedule: () => mockResult({ prototype: true }),
    getAdminOverview: () => mockResult({ prototype: true }),
    getReports: () => mockResult({ prototype: true })
  };

  global.HairFixApi = config.mode === 'server' ? serverApi : mockApi;
  global.HairFixApiError = ApiError;
})(window);
