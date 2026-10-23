# Hair Fix Salon front-end API contract

This contract defines the interface expected by the static front end. It does **not** implement a server or database. The field names align with the entities in the Technical Design Document so the future API can translate cleanly to the normalized schema.

Base path: `/api/v1`

All requests and responses use JSON. Dates use `YYYY-MM-DD`; local times use `HH:mm`; server timestamps should use ISO 8601 with an offset. The salon time zone is `America/New_York`.

## Error response

```json
{
  "message": "Human-readable explanation",
  "code": "STABLE_ERROR_CODE",
  "fieldErrors": {
    "fieldName": "Validation message"
  }
}
```

## Authentication

### `POST /auth/login`

Request:

```json
{
  "email": "person@example.com",
  "password": "user-supplied password",
  "role": "customer"
}
```

Successful response:

```json
{
  "authenticated": true,
  "user": {
    "userId": 15,
    "firstName": "Taylor",
    "lastName": "Morgan",
    "role": "customer"
  }
}
```

The production implementation should use a secure HTTP-only session cookie. The browser client is already configured with `credentials: "include"`.

## Public catalog and availability

### `GET /services`

Returns active services:

```json
[
  {
    "serviceId": 1,
    "serviceName": "Signature Cut",
    "category": "cut",
    "description": "Consultation, shampoo, tailored cut, and finish.",
    "price": 45,
    "durationMinutes": 45,
    "isActive": true
  }
]
```

### `GET /staff?serviceId=1`

Returns active staff qualified for the selected service:

```json
[
  {
    "staffId": 1,
    "userId": 101,
    "displayName": "Maya Brooks",
    "specialty": "Cuts and grooming",
    "isActive": true
  }
]
```

### `GET /availability?serviceId=1&staffId=1&date=2026-10-24`

`staffId` is optional. The API must account for staff qualifications, recurring availability, date-specific blocked time, existing appointments, service duration, and inactive records.

```json
[
  {
    "startTime": "14:15",
    "displayTime": "2:15 PM"
  }
]
```

## Appointments

### `POST /appointments`

Request from the booking form:

```json
{
  "customer": {
    "firstName": "Taylor",
    "lastName": "Morgan",
    "email": "taylor@example.com",
    "phone": "5550124410"
  },
  "locationId": 1,
  "serviceId": 1,
  "staffId": 1,
  "appointmentDate": "2026-10-24",
  "startTime": "14:15",
  "notes": "Optional customer note"
}
```

Successful response:

```json
{
  "appointmentId": 1052,
  "status": "Scheduled",
  "persisted": true
}
```

The server must recheck availability inside the same transaction used to create the appointment. A time shown earlier is not a guarantee that the slot remains available.

### `PATCH /appointments/{appointmentId}/status`

```json
{
  "status": "Completed",
  "reason": null
}
```

The server must authorize the actor, validate the transition, update the appointment, and append history atomically. Only the assigned staff member or an administrator may mark an appointment `No Show`.

## Role dashboards

- `GET /customer/dashboard`
- `GET /staff/schedule?date=2026-10-22`
- `GET /admin/overview?date=2026-10-22`
- `GET /reports?type=monthly-revenue&from=2026-10-01&to=2026-10-31`

These endpoints are represented in `assets/api-client.js`, but the current dashboard markup remains fictional. Their final response shapes can be expanded when the server layer is designed.

## Status codes

- `200` successful read or update
- `201` appointment or other record created
- `204` successful operation with no response body
- `400` malformed request
- `401` authentication required
- `403` authenticated but not authorized
- `404` record not found
- `409` booking conflict or invalid state transition
- `422` field validation failure
- `500` unexpected server failure

