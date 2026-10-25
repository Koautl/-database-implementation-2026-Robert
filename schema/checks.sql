USE hair_fix_salon;
USE hair_fix_salon;
 
-- UserAccount - TDD Sec. 7 pp.5-6; FR-01
ALTER TABLE UserAccount
    ADD CONSTRAINT chk_UserAccount_AccountStatus
        CHECK (AccountStatus IN ('Active', 'Inactive', 'Locked'));
 
-- Customer - TDD Sec. 7 p.6; FR-03, BR-25
ALTER TABLE Customer
    ADD CONSTRAINT chk_Customer_ContactPreference
        CHECK (ContactPreference IN ('Email', 'Phone')),
    ADD CONSTRAINT chk_Customer_ProfileStatus
        CHECK (ProfileStatus IN ('Active', 'Inactive')),
    -- phone already NOT NULL; also block empty string (BR-25)
    ADD CONSTRAINT chk_Customer_PhoneNotBlank
        CHECK (CHAR_LENGTH(TRIM(Phone)) > 0);
 
-- Service - TDD Sec. 7 p.7; FR-05, BR-04
ALTER TABLE Service
    ADD CONSTRAINT chk_Service_CurrentPrice
        CHECK (CurrentPrice >= 0),          -- free service allowed
    ADD CONSTRAINT chk_Service_DurationMinutes
        CHECK (DurationMinutes > 0);
 
-- StaffSchedule - TDD Sec. 7 pp.7-8; FR-06, FR-22, BR-16
-- DayOfWeek: 1 = Sunday ... 7 = Saturday (MySQL DAYOFWEEK())
ALTER TABLE StaffSchedule
    ADD CONSTRAINT chk_StaffSchedule_ScheduleType
        CHECK (ScheduleType IN ('RecurringAvailability', 'DateAvailability', 'BlockedTime')),
    ADD CONSTRAINT chk_StaffSchedule_DayOfWeek
        CHECK (DayOfWeek BETWEEN 1 AND 7),  -- NULL allowed (non-recurring)
    ADD CONSTRAINT chk_StaffSchedule_TimeRange
        CHECK (EndTime > StartTime),        -- BR-16; no overnight intervals
    ADD CONSTRAINT chk_StaffSchedule_EffectiveRange
        CHECK (EffectiveEndDate IS NULL OR EffectiveEndDate >= EffectiveStartDate),
    -- type decides which fields are filled:
    --   Recurring        -> DayOfWeek + EffectiveStartDate, no ScheduleDate
    --   Date / Blocked   -> ScheduleDate only, no recurring fields
    ADD CONSTRAINT chk_StaffSchedule_TypeFields
        CHECK (
            (ScheduleType = 'RecurringAvailability'
                AND DayOfWeek IS NOT NULL
                AND EffectiveStartDate IS NOT NULL
                AND ScheduleDate IS NULL)
         OR (ScheduleType IN ('DateAvailability', 'BlockedTime')
                AND ScheduleDate IS NOT NULL
                AND DayOfWeek IS NULL
                AND EffectiveStartDate IS NULL
                AND EffectiveEndDate IS NULL)
        );
 
-- Appointment - TDD Sec. 7 p.9; FR-18, BR-07
ALTER TABLE Appointment
    ADD CONSTRAINT chk_Appointment_TimeRange
        CHECK (EndDateTime > StartDateTime),
    ADD CONSTRAINT chk_Appointment_EndMatchesDuration   -- BR-07
        CHECK (TIMESTAMPDIFF(MINUTE, StartDateTime, EndDateTime) = BookedDurationMinutes),
    ADD CONSTRAINT chk_Appointment_BookedPrice          -- snapshot, FR-18
        CHECK (BookedPrice >= 0),
    ADD CONSTRAINT chk_Appointment_BookedDuration
        CHECK (BookedDurationMinutes > 0);
 
-- AppointmentHistory - TDD Sec. 7 pp.9-10; FR-21, BR-13
ALTER TABLE AppointmentHistory
    ADD CONSTRAINT chk_AppointmentHistory_EventType
        CHECK (EventType IN ('Booked', 'Rescheduled', 'Cancelled', 'StatusChanged', 'Correction'));
