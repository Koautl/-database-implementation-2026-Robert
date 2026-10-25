-- Hair Fix Salon
-- Executable subset of the FRD/TDD acceptance tests
-- Target: MySQL 8.x
--
-- Prerequisite: run tables.sql, keys.sql, checks.sql, indexes.sql, and
-- views.sql in that order. This script deliberately uses a small,
-- repeatable test data set. It does not add application procedures or
-- triggers that are missing from the submitted schema.

USE hair_fix_salon;

SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE PaymentTransaction;
TRUNCATE TABLE AppointmentHistory;
TRUNCATE TABLE Appointment;
TRUNCATE TABLE AppointmentStatusTransition;
TRUNCATE TABLE StaffSchedule;
TRUNCATE TABLE StaffService;
TRUNCATE TABLE Service;
TRUNCATE TABLE Staff;
TRUNCATE TABLE Customer;
TRUNCATE TABLE UserAccount;
TRUNCATE TABLE PaymentMethod;
TRUNCATE TABLE AppointmentStatus;
TRUNCATE TABLE Location;
TRUNCATE TABLE Role;
SET FOREIGN_KEY_CHECKS = 1;

-- Minimal seed data used only for repeatable acceptance testing.
INSERT INTO Role (RoleID, RoleName, Description) VALUES
    (1, 'Customer', 'Customer account'),
    (2, 'Staff', 'Salon staff account'),
    (3, 'Administrator', 'Administrative account');

INSERT INTO Location
    (LocationID, SalonName, AddressLine1, City, StateCode, PostalCode,
     Phone, TimeZone, ActiveFlag)
VALUES
    (1, 'Hair Fix Salon', '1 College Avenue', 'New Brunswick', 'NJ',
     '08901', '732-555-0100', 'America/New_York', TRUE);

INSERT INTO AppointmentStatus
    (StatusID, StatusName, IsFinal, SortOrder)
VALUES
    (1, 'Scheduled', FALSE, 1),
    (2, 'Completed', TRUE, 2),
    (3, 'Cancelled', TRUE, 3),
    (4, 'No-Show', TRUE, 4);

INSERT INTO PaymentMethod (PaymentMethodID, MethodName, ActiveFlag)
VALUES (1, 'Cash', TRUE), (2, 'Card', TRUE);

INSERT INTO UserAccount
    (UserID, Email, PasswordHash, FirstName, LastName, RoleID, AccountStatus)
VALUES
    (1, 'customer@example.com', 'test-hash-customer', 'Taylor', 'Reed', 1, 'Active'),
    (2, 'staff@example.com', 'test-hash-staff', 'Jordan', 'Lee', 2, 'Active'),
    (3, 'admin@example.com', 'test-hash-admin', 'Morgan', 'Diaz', 3, 'Active'),
    (4, 'second.customer@example.com', 'test-hash-second', 'Casey', 'Ng', 1, 'Active');

INSERT INTO Customer
    (CustomerID, UserID, Phone, ContactPreference, ProfileStatus)
VALUES
    (1, 1, '732-555-0101', 'Email', 'Active');

INSERT INTO Staff
    (StaffID, UserID, Phone, Specialty, ActiveFlag, HireDate, LocationID)
VALUES
    (1, 2, '732-555-0102', 'Cuts and styling', TRUE, '2024-01-15', 1);

INSERT INTO Service
    (ServiceID, ServiceName, Description, CurrentPrice, DurationMinutes, ActiveFlag)
VALUES
    (1, 'Haircut', 'Standard haircut and finish', 50.00, 60, TRUE),
    (2, 'Color', 'Single-process color', 100.00, 120, TRUE);

INSERT INTO StaffService (StaffID, ServiceID, IsActive)
VALUES (1, 1, TRUE), (1, 2, TRUE);

INSERT INTO StaffSchedule
    (ScheduleID, StaffID, ScheduleType, DayOfWeek, StartTime, EndTime,
     EffectiveStartDate, EffectiveEndDate)
VALUES
    (1, 1, 'RecurringAvailability', 3, '09:00:00', '17:00:00',
     '2026-01-01', '2026-12-31');

INSERT INTO Appointment
    (AppointmentID, CustomerID, StaffID, ServiceID, LocationID,
     StartDateTime, EndDateTime, BookedPrice, BookedDurationMinutes,
     StatusID, Notes)
VALUES
    (1, 1, 1, 1, 1, '2026-10-27 09:00:00', '2026-10-27 10:00:00', 50.00, 60, 1, 'Morning appointment'),
    (2, 1, 1, 1, 1, '2026-10-27 11:00:00', '2026-10-27 12:00:00', 50.00, 60, 2, 'Completed appointment'),
    (3, 1, 1, 2, 1, '2026-10-28 13:00:00', '2026-10-28 15:00:00', 100.00, 120, 1, 'Next-day appointment'),
    (4, 1, 1, 1, 1, '2026-10-29 09:00:00', '2026-10-29 10:00:00', 50.00, 60, 3, 'Cancelled appointment'),
    (5, 1, 1, 1, 1, '2026-10-30 09:00:00', '2026-10-30 10:00:00', 50.00, 60, 4, 'No-show appointment');

INSERT INTO AppointmentHistory
    (HistoryID, AppointmentID, EventType, ChangedByUserID, PreviousStatusID,
     NewStatusID, NewStartDateTime, NewEndDateTime, NewStaffID, NewServiceID,
     Reason, RequestID)
VALUES
    (1, 1, 'Booked', 1, NULL, 1, '2026-10-27 09:00:00',
     '2026-10-27 10:00:00', 1, 1, 'Initial booking',
     '00000000-0000-0000-0000-000000000001');

INSERT INTO PaymentTransaction
    (TransactionID, AppointmentID, Amount, TransactionType, PaymentMethodID,
     PaymentStatus, TransactionDate, RecordedByUserID, ExternalReference)
VALUES
    (1, 2, 100.00, 'Charge', 1, 'Succeeded', '2026-10-27 12:05:00', 2, 'TEST-CHARGE-1'),
    (2, 2, 20.00, 'Refund', 1, 'Succeeded', '2026-10-27 12:10:00', 2, 'TEST-REFUND-1'),
    (3, 2, 999.00, 'Charge', 1, 'Failed', '2026-10-27 12:15:00', 2, 'TEST-FAILED-1'),
    (4, 2, 500.00, 'Charge', 1, 'Pending', '2026-10-27 12:20:00', 2, 'TEST-PENDING-1');

DROP TEMPORARY TABLE IF EXISTS TestResults;
CREATE TEMPORARY TABLE TestResults (
    TestID VARCHAR(10) NOT NULL,
    TestName VARCHAR(100) NOT NULL,
    ExpectedResult VARCHAR(255) NOT NULL,
    ActualResult VARCHAR(255) NOT NULL,
    TestStatus VARCHAR(12) NOT NULL
);

DELIMITER //

CREATE PROCEDURE RunTC01()
BEGIN
    DECLARE WasRejected BOOLEAN DEFAULT FALSE;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET WasRejected = TRUE;

    START TRANSACTION;
    INSERT INTO UserAccount
        (Email, PasswordHash, FirstName, LastName, RoleID, AccountStatus)
    VALUES
        ('customer@example.com', 'duplicate-hash', 'Duplicate', 'Email', 1, 'Active');
    ROLLBACK;

    INSERT INTO TestResults VALUES
        ('TC-01', 'Duplicate account email',
         'Second row is rejected by the unique email constraint',
         IF(WasRejected, 'Duplicate row was rejected', 'Duplicate row was accepted'),
         IF(WasRejected, 'PASS', 'FAIL'));
END//

CREATE PROCEDURE RunTC03()
BEGIN
    DECLARE WasRejected BOOLEAN DEFAULT FALSE;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET WasRejected = TRUE;

    START TRANSACTION;
    INSERT INTO Appointment
        (AppointmentID, CustomerID, StaffID, ServiceID, LocationID,
         StartDateTime, EndDateTime, BookedPrice, BookedDurationMinutes,
         StatusID, Notes)
    VALUES
        (90, 1, 1, 1, 1, '2026-10-27 09:30:00', '2026-10-27 10:30:00',
         50.00, 60, 1, 'Intentional overlap test');
    ROLLBACK;

    INSERT INTO TestResults VALUES
        ('TC-03', 'Reject overlapping appointment',
         'Partially overlapping appointment is rejected',
         IF(WasRejected, 'Overlap was rejected', 'Overlap was accepted by direct INSERT'),
         IF(WasRejected, 'PASS', 'FAIL'));
END//

CREATE PROCEDURE RunTC07()
BEGIN
    DECLARE SnapshotPrice DECIMAL(10,2);
    DECLARE SnapshotDuration SMALLINT UNSIGNED;

    START TRANSACTION;
    UPDATE Service
       SET CurrentPrice = 75.00,
           DurationMinutes = 90
     WHERE ServiceID = 1;

    SELECT BookedPrice, BookedDurationMinutes
      INTO SnapshotPrice, SnapshotDuration
      FROM Appointment
     WHERE AppointmentID = 1;
    ROLLBACK;

    INSERT INTO TestResults VALUES
        ('TC-07', 'Preserve appointment snapshots',
         'Booked price and duration remain 50.00 and 60',
         CONCAT('Stored snapshot is ', SnapshotPrice, ' and ', SnapshotDuration),
         IF(SnapshotPrice = 50.00 AND SnapshotDuration = 60, 'PASS', 'FAIL'));
END//

CREATE PROCEDURE RunTC08()
BEGIN
    DECLARE WasRejected BOOLEAN DEFAULT FALSE;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET WasRejected = TRUE;

    START TRANSACTION;
    UPDATE AppointmentHistory
       SET Reason = 'Ordinary direct update'
     WHERE HistoryID = 1;
    ROLLBACK;

    INSERT INTO TestResults VALUES
        ('TC-08', 'Protect appointment history',
         'Ordinary UPDATE is rejected',
         IF(WasRejected, 'History UPDATE was rejected', 'History UPDATE was accepted'),
         IF(WasRejected, 'PASS', 'FAIL'));
END//

CREATE PROCEDURE RunTC14()
BEGIN
    DECLARE Revenue DECIMAL(20,2);
    DECLARE ChargeCount BIGINT;
    DECLARE RefundCount BIGINT;
    DECLARE AllCount BIGINT;

    SELECT NetRevenue, SucceededChargeCount, SucceededRefundCount,
           AllTransactionCount
      INTO Revenue, ChargeCount, RefundCount, AllCount
      FROM vw_MonthlyRevenue
     WHERE ReportMonth = '2026-10';

    INSERT INTO TestResults VALUES
        ('TC-14', 'Monthly net revenue',
         'Only succeeded charge minus refund counts: 100 - 20 = 80',
         CONCAT('Net=', Revenue, ', charges=', ChargeCount,
                ', refunds=', RefundCount, ', all rows=', AllCount),
         IF(Revenue = 80.00 AND ChargeCount = 1 AND RefundCount = 1
            AND AllCount = 4, 'PASS', 'FAIL'));
END//

CREATE PROCEDURE RunTC15()
BEGIN
    DECLARE WasRejected BOOLEAN DEFAULT FALSE;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET WasRejected = TRUE;

    START TRANSACTION;
    UPDATE Service SET ActiveFlag = FALSE WHERE ServiceID = 1;
    INSERT INTO Appointment
        (AppointmentID, CustomerID, StaffID, ServiceID, LocationID,
         StartDateTime, EndDateTime, BookedPrice, BookedDurationMinutes,
         StatusID, Notes)
    VALUES
        (91, 1, 1, 1, 1, '2026-11-01 09:00:00', '2026-11-01 10:00:00',
         50.00, 60, 1, 'Inactive-service test');
    ROLLBACK;

    INSERT INTO TestResults VALUES
        ('TC-15', 'Reject booking for inactive service',
         'New booking is rejected while existing history remains',
         IF(WasRejected, 'Inactive-service booking was rejected',
            'Inactive-service booking was accepted by direct INSERT'),
         IF(WasRejected, 'PASS', 'FAIL'));
END//

CREATE PROCEDURE RunTC16()
BEGIN
    DECLARE RowCountFound INT;
    DECLARE OrderedIDs VARCHAR(100);

    SELECT COUNT(*), GROUP_CONCAT(AppointmentID ORDER BY StartDateTime)
      INTO RowCountFound, OrderedIDs
      FROM vw_DailySchedule
     WHERE StartDateTime >= '2026-10-27 00:00:00'
       AND StartDateTime <  '2026-10-28 00:00:00'
       AND StaffID = 1;

    INSERT INTO TestResults VALUES
        ('TC-16', 'Daily schedule filtering and order',
         'Only appointments 1 and 2 appear in start-time order',
         CONCAT('Rows=', RowCountFound, ', ordered IDs=', OrderedIDs),
         IF(RowCountFound = 2 AND OrderedIDs = '1,2', 'PASS', 'FAIL'));
END//

CREATE PROCEDURE RunTC17()
BEGIN
    DECLARE WasRejected BOOLEAN DEFAULT FALSE;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET WasRejected = TRUE;

    START TRANSACTION;
    INSERT INTO StaffSchedule
        (StaffID, ScheduleType, ScheduleDate, StartTime, EndTime)
    VALUES
        (1, 'DateAvailability', '2026-11-02', '17:00:00', '09:00:00');
    ROLLBACK;

    INSERT INTO TestResults VALUES
        ('TC-17', 'Reject invalid schedule time range',
         'EndTime not later than StartTime is rejected',
         IF(WasRejected, 'Invalid time range was rejected',
            'Invalid time range was accepted'),
         IF(WasRejected, 'PASS', 'FAIL'));
END//

CREATE PROCEDURE RunTC18()
BEGIN
    DECLARE BlankPhoneRejected BOOLEAN DEFAULT FALSE;
    DECLARE PreferenceRejected BOOLEAN DEFAULT FALSE;

    START TRANSACTION;
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET BlankPhoneRejected = TRUE;
        INSERT INTO Customer
            (CustomerID, UserID, Phone, ContactPreference, ProfileStatus)
        VALUES
            (18, 4, '   ', 'Email', 'Active');
    END;
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET PreferenceRejected = TRUE;
        INSERT INTO Customer
            (CustomerID, UserID, Phone, ContactPreference, ProfileStatus)
        VALUES
            (19, 4, '732-555-0199', 'Text', 'Active');
    END;
    ROLLBACK;

    INSERT INTO TestResults VALUES
        ('TC-18', 'Validate customer phone and preference',
         'Blank phone and unsupported preference are rejected',
         CONCAT('blank phone rejected=', BlankPhoneRejected,
                ', invalid preference rejected=', PreferenceRejected),
         IF(BlankPhoneRejected AND PreferenceRejected, 'PASS', 'FAIL'));
END//

CREATE PROCEDURE RunTC20()
BEGIN
    DECLARE SavedPayments INT;
    DECLARE CancelledStatus TINYINT UNSIGNED;
    DECLARE NoShowStatus TINYINT UNSIGNED;

    START TRANSACTION;
    INSERT INTO PaymentTransaction
        (TransactionID, AppointmentID, Amount, TransactionType,
         PaymentMethodID, PaymentStatus, TransactionDate, RecordedByUserID,
         ExternalReference)
    VALUES
        (20, 4, 10.00, 'Refund', 1, 'Succeeded', '2026-10-29 10:00:00', 2, 'TEST-FINAL-REFUND'),
        (21, 5, 50.00, 'Charge', 1, 'Succeeded', '2026-10-30 10:00:00', 2, 'TEST-FINAL-CHARGE');

    SELECT COUNT(*) INTO SavedPayments
      FROM PaymentTransaction
     WHERE TransactionID IN (20, 21);
    SELECT StatusID INTO CancelledStatus FROM Appointment WHERE AppointmentID = 4;
    SELECT StatusID INTO NoShowStatus FROM Appointment WHERE AppointmentID = 5;
    ROLLBACK;

    INSERT INTO TestResults VALUES
        ('TC-20', 'Payments on final-status appointments',
         'Both payments save and appointment statuses remain unchanged',
         CONCAT('payments=', SavedPayments, ', statuses=',
                CancelledStatus, '/', NoShowStatus),
         IF(SavedPayments = 2 AND CancelledStatus = 3 AND NoShowStatus = 4,
            'PASS', 'FAIL'));
END//

DELIMITER ;

CALL RunTC01();
CALL RunTC03();
CALL RunTC07();
CALL RunTC08();
CALL RunTC14();
CALL RunTC15();
CALL RunTC16();
CALL RunTC17();
CALL RunTC18();
CALL RunTC20();

DROP PROCEDURE RunTC01;
DROP PROCEDURE RunTC03;
DROP PROCEDURE RunTC07;
DROP PROCEDURE RunTC08;
DROP PROCEDURE RunTC14;
DROP PROCEDURE RunTC15;
DROP PROCEDURE RunTC16;
DROP PROCEDURE RunTC17;
DROP PROCEDURE RunTC18;
DROP PROCEDURE RunTC20;

SELECT TestID, TestName, ExpectedResult, ActualResult, TestStatus
FROM TestResults
ORDER BY CAST(SUBSTRING(TestID, 4) AS UNSIGNED);

-- Supporting evidence queries.
SELECT COUNT(*) AS BaseTableCount
FROM information_schema.tables
WHERE table_schema = 'hair_fix_salon'
  AND table_type = 'BASE TABLE';

SELECT COUNT(*) AS ViewCount
FROM information_schema.views
WHERE table_schema = 'hair_fix_salon';

SELECT ReportMonth, NetRevenue, SucceededChargeCount,
       SucceededRefundCount, AvgSucceededCharge, AllTransactionCount
FROM vw_MonthlyRevenue
ORDER BY ReportMonth;

SELECT AppointmentID, StartDateTime, CustomerName, ServiceName,
       StaffName, StatusName
FROM vw_DailySchedule
WHERE StartDateTime >= '2026-10-27 00:00:00'
  AND StartDateTime <  '2026-10-28 00:00:00'
  AND StaffID = 1
ORDER BY StartDateTime;

EXPLAIN SELECT AppointmentID, StartDateTime, StatusID
FROM Appointment
WHERE StaffID = 1
  AND StartDateTime >= '2026-10-27 00:00:00'
  AND StartDateTime <  '2026-10-28 00:00:00'
ORDER BY StartDateTime;
