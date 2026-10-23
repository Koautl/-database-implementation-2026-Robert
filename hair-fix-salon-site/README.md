# Hair Fix Salon front-end prototype

This folder contains a static, front-end-only prototype for the Hair Fix Salon online appointment platform. It is organized around an API client so a server and relational database can be added later without rewriting the page layer.

## Included pages

- `index.html` — public landing page
- `services.html` — service catalog with client-side filtering
- `book.html` — mock appointment booking flow
- `login.html` — prototype role selector
- `customer-dashboard.html` — customer portal preview
- `staff-dashboard.html` — staff schedule and status-action preview
- `admin-dashboard.html` — administrator overview
- `reports.html` — sample reporting dashboard

## Running locally

Open `index.html` directly in a browser, or start a simple static server from this directory:

```bash
python3 -m http.server 8000
```

Then visit `http://localhost:8000`.

## Important limitation

This prototype has no database, server-side authentication, persistent storage, or payment processing. All displayed records are fictional, and form actions remain in the browser only.

## Database-ready front-end boundary

- `assets/config.js` controls mock versus server mode.
- `assets/mock-data.js` supplies fictional records during front-end development.
- `assets/api-client.js` defines all future server calls.
- `assets/app.js` calls the client rather than accessing a database or using `fetch()` directly.
- `docs/API_CONTRACT.md` defines endpoint paths and JSON payloads.
- `docs/BACKEND_HANDOFF.md` lists the eventual integration sequence and security requirements.

Keep `mode: 'mock'` until the API has been implemented and tested. The future backend should be the only component that communicates with the database.
