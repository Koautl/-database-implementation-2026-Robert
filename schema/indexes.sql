USE hair_fix_salon;
 
-- Appointment
-- staff calendar + overlap check (FR-07, FR-09, BR-08, RQ-01)
--   WHERE StaffID = ? AND StartDateTime < ? ... StatusID <> Cancelled
CREATE INDEX idx_Appointment_StaffStartStatus
    ON Appointment (StaffID, StartDateTime, StatusID);
 
-- customer's own appointments, newest first (FR-10, FR-14, BR-09, RQ-03)
--   WHERE CustomerID = ? ORDER BY StartDateTime DESC
CREATE INDEX idx_Appointment_CustomerStart
    ON Appointment (CustomerID, StartDateTime);
 
-- service popularity / completions by date range (RQ-05)
CREATE INDEX idx_Appointment_ServiceStartStatus
    ON Appointment (ServiceID, StartDateTime, StatusID);
 
-- PaymentTransaction
-- monthly revenue: date range, then status filter (RQ-04, BR-18)
CREATE INDEX idx_Payment_DateStatus
    ON PaymentTransaction (TransactionDate, PaymentStatus);
 
-- StaffSchedule
-- date-specific + blocked time for one staff on one date (FR-06, FR-07, BR-15)
CREATE INDEX idx_Schedule_StaffDateTime
    ON StaffSchedule (StaffID, ScheduleDate, StartTime);
 
-- recurring availability for one staff on one weekday (FR-06, FR-07)
CREATE INDEX idx_Schedule_StaffDayTime
    ON StaffSchedule (StaffID, DayOfWeek, StartTime);
 
-- AppointmentHistory
-- one appointment's audit trail in time order (FR-10 to FR-12, FR-24, RQ-07)
CREATE INDEX idx_History_AppointmentChanged
    ON AppointmentHistory (AppointmentID, ChangedAt);
 
-- all rows from one operation (TDD §7 p.10: RequestID "Indexed"; not in §10 list)
CREATE INDEX idx_History_RequestID
    ON AppointmentHistory (RequestID);
