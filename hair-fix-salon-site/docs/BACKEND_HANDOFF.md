# Backend integration handoff

The site currently runs in mock mode and does not persist information. The separation between presentation code and data access is already in place.

## Current structure

- `assets/config.js` selects mock or server mode and stores the API base URL.
- `assets/mock-data.js` contains fictional development records shaped like API responses.
- `assets/api-client.js` is the only layer that communicates with data sources.
- `assets/app.js` handles page behavior and calls `window.HairFixApi` methods.
- HTML forms use stable `name` attributes that match request payload fields.
- Appointment actions include `data-appointment-id` identifiers for future API calls.

## Transition steps

1. Implement the `/api/v1` endpoints in `API_CONTRACT.md`.
2. Add server-side authentication with a secure HTTP-only session cookie.
3. Apply authorization on the server for customer, staff, and administrator operations.
4. Validate every request on the server; browser validation is only a convenience.
5. Recheck availability and create bookings in a single transaction.
6. Return `409 Conflict` for overlapping or stale booking requests.
7. Add CSRF protection to state-changing operations if cookie authentication is used.
8. Replace the fictional dashboard markup incrementally with API-driven rendering.
9. Change `mode: "mock"` to `mode: "server"` in `assets/config.js`.
10. Execute the TDD test plan and record actual results.

## What should not change

- Page URLs and navigation
- Form field names
- Service, staff, appointment, and user identifiers
- Calls made through `window.HairFixApi`
- Display components and responsive styling

## Security boundary

The browser must never receive password hashes, full payment credentials, database credentials, or unrestricted administrative data. UI visibility is not authorization; every protected operation must be checked by the server.

## Payment boundary

The current project records operational transaction history only. Do not collect raw card numbers, security codes, or bank details in these forms. If real payment processing is added later, use a dedicated payment provider and store only permitted references and transaction status information.

