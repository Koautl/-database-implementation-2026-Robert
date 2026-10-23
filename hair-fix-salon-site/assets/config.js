/*
 * Front-end runtime configuration.
 *
 * Keep `mode` set to `mock` until the server-side API is implemented.
 * When the API is ready, change only `mode` and `apiBaseUrl`; the pages can
 * continue calling the same HairFixApi methods.
 */
window.HAIR_FIX_CONFIG = Object.freeze({
  mode: 'mock',
  apiBaseUrl: '/api/v1',
  requestTimeoutMs: 10000,
  defaultLocationId: 1,
  salonTimeZone: 'America/New_York'
});
