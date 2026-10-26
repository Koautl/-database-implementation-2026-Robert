-- Hair Fix Salon sample data
-- Run after tables.sql through procedures.sql.
-- The complete build is repeatable because tables.sql recreates the schema.
-- This seed phase is transactional: any SQL exception rolls back all seed rows.

USE hair_fix_salon;

DROP PROCEDURE IF EXISTS sp_LoadSampleData;

DELIMITER //

CREATE PROCEDURE sp_LoadSampleData()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    INSERT INTO Role (RoleID, RoleName, Description) VALUES
        (1, 'Customer', 'Books and manages personal appointments'),
        (2, 'Staff', 'Performs services and manages assigned appointments'),
        (3, 'Administrator', 'Maintains salon data and operational reports');

    INSERT INTO Location
        (LocationID, SalonName, AddressLine1, AddressLine2, City, StateCode,
         PostalCode, Phone, TimeZone, ActiveFlag)
    VALUES
        (1, 'Hair Fix Salon', '1 College Avenue', NULL, 'New Brunswick', 'NJ',
         '08901', '732-555-0100', 'America/New_York', TRUE);

    INSERT INTO AppointmentStatus
        (StatusID, StatusName, IsFinal, SortOrder)
    VALUES
        (1, 'Scheduled', FALSE, 1),
        (2, 'Confirmed', FALSE, 2),
        (3, 'In Progress', FALSE, 3),
        (4, 'Completed', TRUE, 4),
        (5, 'Cancelled', TRUE, 5),
        (6, 'No-Show', TRUE, 6);

    INSERT INTO AppointmentStatusTransition
        (FromStatusID, ToStatusID, CustomerAllowed, StaffAllowed,
         AdministratorAllowed, RequiresReason)
    VALUES
        (1, 2, FALSE, TRUE, TRUE, FALSE),
        (1, 5, TRUE, TRUE, TRUE, TRUE),
        (1, 6, FALSE, TRUE, TRUE, TRUE),
        (2, 3, FALSE, TRUE, TRUE, FALSE),
        (2, 5, TRUE, TRUE, TRUE, TRUE),
        (2, 6, FALSE, TRUE, TRUE, TRUE),
        (3, 4, FALSE, TRUE, TRUE, FALSE),
        (3, 5, FALSE, TRUE, TRUE, TRUE);

    INSERT INTO PaymentMethod
        (PaymentMethodID, MethodName, ActiveFlag)
    VALUES
        (1, 'Cash', TRUE),
        (2, 'Credit Card', TRUE),
        (3, 'Debit Card', TRUE),
        (4, 'Gift Card', TRUE);

    -- These are obvious non-production placeholders, not plaintext passwords.
    INSERT INTO UserAccount
        (UserID, Email, PasswordHash, FirstName, LastName, RoleID, AccountStatus)
    VALUES
        (1, 'alex.morgan@example.test', 'TEST_HASH_NOT_FOR_AUTHENTICATION_001',
         'Alex', 'Morgan', 1, 'Active'),
        (2, 'jamie.patel@example.test', 'TEST_HASH_NOT_FOR_AUTHENTICATION_002',
         'Jamie', 'Patel', 1, 'Active'),
        (3, 'casey.brown@example.test', 'TEST_HASH_NOT_FOR_AUTHENTICATION_003',
         'Casey', 'Brown', 1, 'Active'),
        (4, 'riley.chen@hairfix.example.test', 'TEST_HASH_NOT_FOR_AUTHENTICATION_004',
         'Riley', 'Chen', 2, 'Active'),
        (5, 'maya.johnson@hairfix.example.test', 'TEST_HASH_NOT_FOR_AUTHENTICATION_005',
         'Maya', 'Johnson', 2, 'Active'),
        (6, 'jordan.lee@hairfix.example.test', 'TEST_HASH_NOT_FOR_AUTHENTICATION_006',
         'Jordan', 'Lee', 2, 'Active'),
        (7, 'admin@hairfix.example.test', 'TEST_HASH_NOT_FOR_AUTHENTICATION_007',
         'Salon', 'Administrator', 3, 'Active');

    INSERT INTO Customer
        (CustomerID, UserID, Phone, ContactPreference, ProfileStatus)
    VALUES
        (1, 1, '732-555-0101', 'Email', 'Active'),
        (2, 2, '732-555-0102', 'Phone', 'Active'),
        (3, 3, '732-555-0103', 'Email', 'Active');

    INSERT INTO Staff
        (StaffID, UserID, Phone, Specialty, ActiveFlag, HireDate, LocationID)
    VALUES
        (1, 4, '732-555-0111', 'Cuts and grooming', TRUE, '2023-06-12', 1),
        (2, 5, '732-555-0112', 'Color and highlights', TRUE, '2022-09-05', 1),
        (3, 6, '732-555-0113', 'Cuts and styling', TRUE, '2024-01-15', 1);

    INSERT INTO Service
        (ServiceID, ServiceName, Description, CurrentPrice,
         DurationMinutes, ActiveFlag)
    VALUES
        (1, 'Haircut', 'Consultation, haircut, and finish', 45.00, 45, TRUE),
        (2, 'Blowout', 'Wash, blow-dry, and styling', 55.00, 60, TRUE),
        (3, 'Hair Color', 'Single-process hair color', 120.00, 120, TRUE),
        (4, 'Highlights', 'Partial foil highlights and finish', 150.00, 150, TRUE),
        (5, 'Beard Trim', 'Beard shaping and cleanup', 25.00, 30, TRUE),
        (6, 'Deep Conditioning', 'Conditioning treatment and finish', 40.00, 45, TRUE);

    INSERT INTO StaffService
        (StaffID, ServiceID, IsActive)
    VALUES
        (1, 1, TRUE),
        (1, 2, TRUE),
        (1, 5, TRUE),
        (1, 6, TRUE),
        (2, 2, TRUE),
        (2, 3, TRUE),
        (2, 4, TRUE),
        (2, 6, TRUE),
        (3, 1, TRUE),
        (3, 2, TRUE),
        (3, 3, TRUE),
        (3, 6, TRUE);

    -- DAYOFWEEK convention: 1 Sunday through 7 Saturday.
    INSERT INTO StaffSchedule
        (ScheduleID, StaffID, ScheduleType, DayOfWeek, ScheduleDate,
         StartTime, EndTime, EffectiveStartDate, EffectiveEndDate, Reason)
    VALUES
        (1, 1, 'RecurringAvailability', 3, NULL, '09:00:00', '17:00:00',
         '2026-01-01', '2026-12-31', NULL),
        (2, 1, 'RecurringAvailability', 4, NULL, '09:00:00', '17:00:00',
         '2026-01-01', '2026-12-31', NULL),
        (3, 1, 'RecurringAvailability', 5, NULL, '09:00:00', '17:00:00',
         '2026-01-01', '2026-12-31', NULL),
        (4, 1, 'RecurringAvailability', 6, NULL, '09:00:00', '17:00:00',
         '2026-01-01', '2026-12-31', NULL),
        (5, 1, 'RecurringAvailability', 7, NULL, '09:00:00', '15:00:00',
         '2026-01-01', '2026-12-31', NULL),
        (6, 2, 'RecurringAvailability', 3, NULL, '10:00:00', '18:00:00',
         '2026-01-01', '2026-12-31', NULL),
        (7, 2, 'RecurringAvailability', 4, NULL, '10:00:00', '18:00:00',
         '2026-01-01', '2026-12-31', NULL),
        (8, 2, 'RecurringAvailability', 5, NULL, '10:00:00', '18:00:00',
         '2026-01-01', '2026-12-31', NULL),
        (9, 2, 'RecurringAvailability', 6, NULL, '10:00:00', '18:00:00',
         '2026-01-01', '2026-12-31', NULL),
        (10, 2, 'RecurringAvailability', 7, NULL, '09:00:00', '16:00:00',
         '2026-01-01', '2026-12-31', NULL),
        (11, 3, 'RecurringAvailability', 4, NULL, '09:00:00', '17:00:00',
         '2026-01-01', '2026-12-31', NULL),
        (12, 3, 'RecurringAvailability', 5, NULL, '09:00:00', '17:00:00',
         '2026-01-01', '2026-12-31', NULL),
        (13, 3, 'RecurringAvailability', 6, NULL, '09:00:00', '17:00:00',
         '2026-01-01', '2026-12-31', NULL),
        (14, 3, 'RecurringAvailability', 7, NULL, '09:00:00', '17:00:00',
         '2026-01-01', '2026-12-31', NULL),
        (15, 3, 'RecurringAvailability', 1, NULL, '10:00:00', '15:00:00',
         '2026-01-01', '2026-12-31', NULL),
        (16, 2, 'BlockedTime', NULL, '2026-11-03', '13:00:00', '14:00:00',
         NULL, NULL, 'Training meeting');

    INSERT INTO Appointment
        (AppointmentID, CustomerID, StaffID, ServiceID, LocationID,
         StartDateTime, EndDateTime, BookedPrice, BookedDurationMinutes,
         StatusID, CreatedAt, UpdatedAt, CancelledAt, Notes)
    VALUES
        (1, 1, 1, 1, 1, '2026-10-20 10:00:00', '2026-10-20 10:45:00',
         45.00, 45, 4, '2026-10-10 12:00:00', '2026-10-20 10:50:00', NULL,
         'Completed sample appointment'),
        (2, 2, 2, 3, 1, '2026-11-03 10:00:00', '2026-11-03 12:00:00',
         120.00, 120, 1, '2026-10-21 09:00:00', '2026-10-21 09:00:00', NULL,
         'Future color appointment'),
        (3, 1, 3, 2, 1, '2026-11-04 13:00:00', '2026-11-04 14:00:00',
         55.00, 60, 2, '2026-10-22 11:00:00', '2026-10-24 08:30:00', NULL,
         'Confirmed blowout'),
        (4, 3, 1, 5, 1, '2026-10-24 14:00:00', '2026-10-24 14:30:00',
         25.00, 30, 5, '2026-10-15 14:00:00', '2026-10-23 16:00:00',
         '2026-10-23 16:00:00', 'Cancelled with refund'),
        (5, 2, 3, 1, 1, '2026-10-22 16:00:00', '2026-10-22 16:45:00',
         45.00, 45, 6, '2026-10-12 10:00:00', '2026-10-22 16:20:00', NULL,
         'No-show sample'),
        (6, 3, 2, 4, 1, '2026-11-05 10:00:00', '2026-11-05 12:30:00',
         150.00, 150, 2, '2026-10-24 13:00:00', '2026-10-25 09:30:00', NULL,
         'Confirmed highlights appointment');

    INSERT INTO AppointmentHistory
        (HistoryID, AppointmentID, EventType, ChangedByUserID, ChangedAt,
         PreviousStatusID, NewStatusID, PreviousStartDateTime,
         NewStartDateTime, PreviousEndDateTime, NewEndDateTime,
         PreviousStaffID, NewStaffID, PreviousServiceID, NewServiceID,
         Reason, RequestID)
    VALUES
        (1, 1, 'Booked', 1, '2026-10-10 12:00:00', NULL, 1, NULL,
         '2026-10-20 10:00:00', NULL, '2026-10-20 10:45:00', NULL, 1,
         NULL, 1, 'Initial booking', '10000000-0000-0000-0000-000000000001'),
        (2, 1, 'StatusChanged', 4, '2026-10-20 10:50:00', 3, 4,
         '2026-10-20 10:00:00', '2026-10-20 10:00:00',
         '2026-10-20 10:45:00', '2026-10-20 10:45:00', 1, 1, 1, 1,
         'Service completed', '10000000-0000-0000-0000-000000000002'),
        (3, 2, 'Booked', 2, '2026-10-21 09:00:00', NULL, 1, NULL,
         '2026-11-03 10:00:00', NULL, '2026-11-03 12:00:00', NULL, 2,
         NULL, 3, 'Initial booking', '20000000-0000-0000-0000-000000000001'),
        (4, 3, 'Booked', 1, '2026-10-22 11:00:00', NULL, 1, NULL,
         '2026-11-04 13:00:00', NULL, '2026-11-04 14:00:00', NULL, 3,
         NULL, 2, 'Initial booking', '30000000-0000-0000-0000-000000000001'),
        (5, 3, 'StatusChanged', 7, '2026-10-24 08:30:00', 1, 2,
         '2026-11-04 13:00:00', '2026-11-04 13:00:00',
         '2026-11-04 14:00:00', '2026-11-04 14:00:00', 3, 3, 2, 2,
         'Appointment confirmed', '30000000-0000-0000-0000-000000000002'),
        (6, 4, 'Booked', 3, '2026-10-15 14:00:00', NULL, 1, NULL,
         '2026-10-24 14:00:00', NULL, '2026-10-24 14:30:00', NULL, 1,
         NULL, 5, 'Initial booking', '40000000-0000-0000-0000-000000000001'),
        (7, 4, 'Cancelled', 3, '2026-10-23 16:00:00', 1, 5,
         '2026-10-24 14:00:00', '2026-10-24 14:00:00',
         '2026-10-24 14:30:00', '2026-10-24 14:30:00', 1, 1, 5, 5,
         'Customer schedule conflict', '40000000-0000-0000-0000-000000000002'),
        (8, 5, 'Booked', 2, '2026-10-12 10:00:00', NULL, 1, NULL,
         '2026-10-22 16:00:00', NULL, '2026-10-22 16:45:00', NULL, 3,
         NULL, 1, 'Initial booking', '50000000-0000-0000-0000-000000000001'),
        (9, 5, 'StatusChanged', 6, '2026-10-22 16:20:00', 2, 6,
         '2026-10-22 16:00:00', '2026-10-22 16:00:00',
         '2026-10-22 16:45:00', '2026-10-22 16:45:00', 3, 3, 1, 1,
         'Customer did not arrive', '50000000-0000-0000-0000-000000000002'),
        (10, 6, 'Booked', 3, '2026-10-24 13:00:00', NULL, 1, NULL,
         '2026-11-05 10:00:00', NULL, '2026-11-05 12:30:00', NULL, 2,
         NULL, 4, 'Initial booking', '60000000-0000-0000-0000-000000000001'),
        (11, 6, 'StatusChanged', 7, '2026-10-25 09:30:00', 1, 2,
         '2026-11-05 10:00:00', '2026-11-05 10:00:00',
         '2026-11-05 12:30:00', '2026-11-05 12:30:00', 2, 2, 4, 4,
         'Appointment confirmed', '60000000-0000-0000-0000-000000000002');

    INSERT INTO PaymentTransaction
        (TransactionID, AppointmentID, Amount, TransactionType,
         PaymentMethodID, PaymentStatus, TransactionDate, RecordedByUserID,
         CreatedAt, ExternalReference)
    VALUES
        (1, 1, 45.00, 'Charge', 2, 'Succeeded', '2026-10-20 10:50:00', 4,
         '2026-10-20 10:50:00', 'SAMPLE-CHARGE-0001'),
        (2, 4, 25.00, 'Charge', 1, 'Succeeded', '2026-10-20 12:00:00', 4,
         '2026-10-20 12:00:00', 'SAMPLE-CHARGE-0002'),
        (3, 4, 25.00, 'Refund', 1, 'Succeeded', '2026-10-23 16:05:00', 7,
         '2026-10-23 16:05:00', 'SAMPLE-REFUND-0001'),
        (4, 5, 45.00, 'Charge', 2, 'Failed', '2026-10-22 16:25:00', 6,
         '2026-10-22 16:25:00', 'SAMPLE-FAILED-0001'),
        (5, 6, 50.00, 'Charge', 3, 'Pending', '2026-10-25 09:35:00', 7,
         '2026-10-25 09:35:00', 'SAMPLE-PENDING-0001');

    COMMIT;
END//

DELIMITER ;

CALL sp_LoadSampleData();
DROP PROCEDURE sp_LoadSampleData;

SELECT 'Sample data loaded successfully' AS BuildMessage;
