USE hair_fix_salon;
 
-- vw_AppointmentDetails: one row per appointment, all names joined in
-- base for RQ-01, RQ-02, RQ-03 (FR-14, FR-16, FR-17)
-- RQ-02: SELECT ... WHERE StatusName = ? AND StartDateTime >= ? AND StartDateTime < ?
CREATE OR REPLACE VIEW vw_AppointmentDetails AS
SELECT a.AppointmentID,
       a.StartDateTime,
       a.EndDateTime,
       a.CustomerID,
       CONCAT(cu.FirstName, ' ', cu.LastName) AS CustomerName,
       a.StaffID,
       CONCAT(su.FirstName, ' ', su.LastName) AS StaffName,
       a.ServiceID,
       s.ServiceName,
       a.LocationID,
       l.SalonName,
       a.BookedPrice,                 -- snapshot, not current price (FR-18)
       a.BookedDurationMinutes,
       a.StatusID,
       ast.StatusName,
       ast.IsFinal,
       a.CancelledAt,
       a.Notes
FROM Appointment       AS a
JOIN Customer          AS c   ON c.CustomerID = a.CustomerID
JOIN UserAccount       AS cu  ON cu.UserID    = c.UserID
JOIN Staff             AS st  ON st.StaffID   = a.StaffID
JOIN UserAccount       AS su  ON su.UserID    = st.UserID
JOIN Service           AS s   ON s.ServiceID  = a.ServiceID
JOIN Location          AS l   ON l.LocationID = a.LocationID
JOIN AppointmentStatus AS ast ON ast.StatusID = a.StatusID;
 
-- vw_DailySchedule: RQ-01, FR-16, TC-16
-- filter: StartDateTime range (one day), StaffID, StatusName; ORDER BY StartDateTime
-- range on raw StartDateTime, not DATE(...) -> uses idx_Appointment_StaffStartStatus
CREATE OR REPLACE VIEW vw_DailySchedule AS
SELECT AppointmentID,
       StartDateTime,
       EndDateTime,
       CustomerName,
       ServiceName,
       StaffID,
       StaffName,
       BookedDurationMinutes,
       StatusID,
       StatusName
FROM vw_AppointmentDetails;
 
-- vw_CustomerAppointmentHistory: RQ-03, FR-14
-- filter: CustomerID; ORDER BY StartDateTime DESC (newest first)
-- payment summary per appointment; pre-aggregated so payments don't duplicate rows
-- revenue rule BR-18: only Succeeded rows count; refunds subtract
CREATE OR REPLACE VIEW vw_CustomerAppointmentHistory AS
SELECT d.CustomerID,
       d.CustomerName,
       d.AppointmentID,
       d.StartDateTime,
       d.ServiceName,
       d.StaffName,
       d.BookedPrice,
       d.StatusName,
       COALESCE(p.TransactionCount, 0) AS TransactionCount,   -- all statuses
       COALESCE(p.PaidCharges, 0)      AS PaidCharges,
       COALESCE(p.PaidRefunds, 0)      AS PaidRefunds,
       COALESCE(p.NetPaid, 0)          AS NetPaid
FROM vw_AppointmentDetails AS d
LEFT JOIN (
    SELECT AppointmentID,
           COUNT(*) AS TransactionCount,
           SUM(CASE WHEN PaymentStatus = 'Succeeded' AND TransactionType = 'Charge' THEN Amount ELSE 0 END) AS PaidCharges,
           SUM(CASE WHEN PaymentStatus = 'Succeeded' AND TransactionType = 'Refund' THEN Amount ELSE 0 END) AS PaidRefunds,
           SUM(CASE WHEN PaymentStatus = 'Succeeded' AND TransactionType = 'Charge' THEN  Amount
                    WHEN PaymentStatus = 'Succeeded' AND TransactionType = 'Refund' THEN -Amount
                    ELSE 0 END) AS NetPaid
    FROM PaymentTransaction
    GROUP BY AppointmentID
) AS p ON p.AppointmentID = d.AppointmentID;
 
-- vw_MonthlyRevenue: RQ-04, BR-18, TC-14
-- filter: ReportMonth BETWEEN 'YYYY-MM' AND 'YYYY-MM'
-- Pending / Failed / Voided excluded from every money column
CREATE OR REPLACE VIEW vw_MonthlyRevenue AS
SELECT DATE_FORMAT(TransactionDate, '%Y-%m') AS ReportMonth,
       SUM(CASE WHEN PaymentStatus = 'Succeeded' AND TransactionType = 'Charge' THEN  Amount
                WHEN PaymentStatus = 'Succeeded' AND TransactionType = 'Refund' THEN -Amount
                ELSE 0 END)                                                              AS NetRevenue,
       SUM(PaymentStatus = 'Succeeded' AND TransactionType = 'Charge')                   AS SucceededChargeCount,
       SUM(PaymentStatus = 'Succeeded' AND TransactionType = 'Refund')                   AS SucceededRefundCount,
       ROUND(AVG(CASE WHEN PaymentStatus = 'Succeeded' AND TransactionType = 'Charge'
                      THEN Amount END), 2)                                               AS AvgSucceededCharge,
       COUNT(*)                                                                          AS AllTransactionCount
FROM PaymentTransaction
GROUP BY DATE_FORMAT(TransactionDate, '%Y-%m');
 
-- vw_PopularServices: RQ-05, FR-17
-- filter: ReportMonth range; ORDER BY AppointmentCount DESC
-- LEFT JOIN: never-booked service -> one row, ReportMonth NULL, counts 0
-- AppointmentCount excludes Cancelled; BookedValue = BookedPrice of Completed; NetPaid per BR-18
CREATE OR REPLACE VIEW vw_PopularServices AS
SELECT s.ServiceID,
       s.ServiceName,
       DATE_FORMAT(a.StartDateTime, '%Y-%m')                          AS ReportMonth,
       COUNT(CASE WHEN ast.StatusName <> 'Cancelled' THEN 1 END)      AS AppointmentCount,
       COUNT(CASE WHEN ast.StatusName =  'Completed' THEN 1 END)      AS CompletedCount,
       COALESCE(SUM(CASE WHEN ast.StatusName = 'Completed'
                         THEN a.BookedPrice END), 0)                  AS BookedValue,
       COALESCE(SUM(p.NetPaid), 0)                                    AS NetPaid
FROM Service AS s
LEFT JOIN Appointment       AS a   ON a.ServiceID  = s.ServiceID
LEFT JOIN AppointmentStatus AS ast ON ast.StatusID = a.StatusID
LEFT JOIN (
    SELECT AppointmentID,
           SUM(CASE WHEN PaymentStatus = 'Succeeded' AND TransactionType = 'Charge' THEN  Amount
                    WHEN PaymentStatus = 'Succeeded' AND TransactionType = 'Refund' THEN -Amount
                    ELSE 0 END) AS NetPaid
    FROM PaymentTransaction
    GROUP BY AppointmentID
) AS p ON p.AppointmentID = a.AppointmentID
GROUP BY s.ServiceID, s.ServiceName, DATE_FORMAT(a.StartDateTime, '%Y-%m');
 
-- vw_StaffWorkload: RQ-06, FR-17
-- filter: ReportMonth range, StaffID
-- AppointmentCount + BookedMinutes exclude Cancelled (time not worked)
CREATE OR REPLACE VIEW vw_StaffWorkload AS
SELECT st.StaffID,
       CONCAT(u.FirstName, ' ', u.LastName)                                      AS StaffName,
       DATE_FORMAT(a.StartDateTime, '%Y-%m')                                     AS ReportMonth,
       COUNT(CASE WHEN ast.StatusName <> 'Cancelled' THEN 1 END)                 AS AppointmentCount,
       COUNT(CASE WHEN ast.StatusName =  'Completed' THEN 1 END)                 AS CompletedCount,
       COUNT(CASE WHEN ast.StatusName =  'No-Show'   THEN 1 END)                 AS NoShowCount,
       COALESCE(SUM(CASE WHEN ast.StatusName <> 'Cancelled'
                         THEN a.BookedDurationMinutes END), 0)                   AS BookedMinutes
FROM Staff AS st
JOIN UserAccount            AS u   ON u.UserID     = st.UserID
LEFT JOIN Appointment       AS a   ON a.StaffID    = st.StaffID
LEFT JOIN AppointmentStatus AS ast ON ast.StatusID = a.StatusID
GROUP BY st.StaffID, u.FirstName, u.LastName, DATE_FORMAT(a.StartDateTime, '%Y-%m');
 
-- vw_CancellationNoShow: RQ-07, FR-17, BR-14
-- filter: StatusName ('Cancelled' / 'No-Show'), StartDateTime range
-- reason + actor + time from the history event that set the final status (BR-13)
-- uses idx_History_AppointmentChanged
CREATE OR REPLACE VIEW vw_CancellationNoShow AS
SELECT d.AppointmentID,
       d.StartDateTime,
       d.CustomerName,
       d.ServiceName,
       d.StaffName,
       d.StatusName                                AS FinalStatus,
       h.Reason,
       CONCAT(actor.FirstName, ' ', actor.LastName) AS ChangedByName,
       r.RoleName                                  AS ChangedByRole,
       h.ChangedAt
FROM vw_AppointmentDetails AS d
JOIN AppointmentHistory    AS h
     ON  h.AppointmentID = d.AppointmentID
     AND h.NewStatusID   = d.StatusID
JOIN UserAccount           AS actor ON actor.UserID = h.ChangedByUserID
JOIN Role                  AS r     ON r.RoleID     = actor.RoleID
WHERE d.StatusName IN ('Cancelled', 'No-Show')
  -- latest matching event only (a later Correction may repeat the status)
  AND NOT EXISTS (
        SELECT 1
        FROM AppointmentHistory AS h2
        WHERE h2.AppointmentID = h.AppointmentID
          AND h2.NewStatusID   = h.NewStatusID
          AND (h2.ChangedAt > h.ChangedAt
               OR (h2.ChangedAt = h.ChangedAt AND h2.HistoryID > h.HistoryID))
      );
