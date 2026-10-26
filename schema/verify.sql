-- Hair Fix Salon build verification
-- Fails the build if the core schema or sample-data counts are unexpected.

USE hair_fix_salon;

DROP PROCEDURE IF EXISTS sp_VerifyCoreBuild;

DELIMITER //

CREATE PROCEDURE sp_VerifyCoreBuild()
BEGIN
    DECLARE BaseTableCount INT DEFAULT 0;
    DECLARE InnoDBTableCount INT DEFAULT 0;
    DECLARE ViewCount INT DEFAULT 0;
    DECLARE NamedIndexCount INT DEFAULT 0;
    DECLARE ForeignKeyCount INT DEFAULT 0;
    DECLARE CheckConstraintCount INT DEFAULT 0;
    DECLARE ProcedureCount INT DEFAULT 0;
    DECLARE FunctionCount INT DEFAULT 0;
    DECLARE TriggerCount INT DEFAULT 0;
    DECLARE RoleCount INT DEFAULT 0;
    DECLARE LocationCount INT DEFAULT 0;
    DECLARE StatusCount INT DEFAULT 0;
    DECLARE ServiceCount INT DEFAULT 0;
    DECLARE AccountCount INT DEFAULT 0;
    DECLARE AppointmentCount INT DEFAULT 0;
    DECLARE InvalidQualificationCount INT DEFAULT 0;
    DECLARE InactiveServiceBookingCount INT DEFAULT 0;
    DECLARE OverlapCount INT DEFAULT 0;

    SELECT COUNT(*)
      INTO BaseTableCount
      FROM information_schema.tables
     WHERE table_schema = 'hair_fix_salon'
       AND table_type = 'BASE TABLE';

    SELECT COUNT(*)
      INTO InnoDBTableCount
      FROM information_schema.tables
     WHERE table_schema = 'hair_fix_salon'
       AND table_type = 'BASE TABLE'
       AND engine = 'InnoDB';

    SELECT COUNT(*)
      INTO ViewCount
      FROM information_schema.views
     WHERE table_schema = 'hair_fix_salon';

    SELECT COUNT(DISTINCT CONCAT(table_name, ':', index_name))
      INTO NamedIndexCount
      FROM information_schema.statistics
     WHERE table_schema = 'hair_fix_salon'
       AND index_name LIKE 'idx_%';

    SELECT COUNT(*)
      INTO ForeignKeyCount
      FROM information_schema.table_constraints
     WHERE constraint_schema = 'hair_fix_salon'
       AND constraint_type = 'FOREIGN KEY';

    SELECT COUNT(*)
      INTO CheckConstraintCount
      FROM information_schema.table_constraints
     WHERE constraint_schema = 'hair_fix_salon'
       AND constraint_type = 'CHECK';

    SELECT COUNT(*)
      INTO ProcedureCount
      FROM information_schema.routines
     WHERE routine_schema = 'hair_fix_salon'
       AND routine_type = 'PROCEDURE'
       AND routine_name <> 'sp_VerifyCoreBuild';

    SELECT COUNT(*)
      INTO FunctionCount
      FROM information_schema.routines
     WHERE routine_schema = 'hair_fix_salon'
       AND routine_type = 'FUNCTION';

    SELECT COUNT(*)
      INTO TriggerCount
      FROM information_schema.triggers
     WHERE trigger_schema = 'hair_fix_salon';

    SELECT COUNT(*) INTO RoleCount FROM Role;
    SELECT COUNT(*) INTO LocationCount FROM Location;
    SELECT COUNT(*) INTO StatusCount FROM AppointmentStatus;
    SELECT COUNT(*) INTO ServiceCount FROM Service;
    SELECT COUNT(*) INTO AccountCount FROM UserAccount;
    SELECT COUNT(*) INTO AppointmentCount FROM Appointment;

    SELECT COUNT(*)
      INTO InvalidQualificationCount
      FROM Appointment AS a
      LEFT JOIN StaffService AS ss
        ON ss.StaffID = a.StaffID
       AND ss.ServiceID = a.ServiceID
       AND ss.IsActive = TRUE
     WHERE ss.StaffID IS NULL;

    SELECT COUNT(*)
      INTO InactiveServiceBookingCount
      FROM Appointment AS a
      JOIN Service AS s ON s.ServiceID = a.ServiceID
     WHERE s.ActiveFlag = FALSE;

    SELECT COUNT(*)
      INTO OverlapCount
      FROM Appointment AS a1
      JOIN Appointment AS a2
        ON a2.StaffID = a1.StaffID
       AND a2.AppointmentID > a1.AppointmentID
       AND a1.StartDateTime < a2.EndDateTime
       AND a1.EndDateTime > a2.StartDateTime
      JOIN AppointmentStatus AS s1 ON s1.StatusID = a1.StatusID
      JOIN AppointmentStatus AS s2 ON s2.StatusID = a2.StatusID
     WHERE s1.StatusName NOT IN ('Cancelled', 'No-Show')
       AND s2.StatusName NOT IN ('Cancelled', 'No-Show');

    IF BaseTableCount <> 14 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Core verification failed: expected 14 base tables';
    END IF;

    IF InnoDBTableCount <> 14 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Core verification failed: every base table must use InnoDB';
    END IF;

    IF ViewCount <> 7 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Core verification failed: expected 7 views';
    END IF;

    IF NamedIndexCount < 8 OR ForeignKeyCount < 22 OR CheckConstraintCount < 16 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Core verification failed: indexes or constraints are missing';
    END IF;

    IF ProcedureCount < 13 OR FunctionCount < 4 OR TriggerCount < 3 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Core verification failed: routines or triggers are missing';
    END IF;

    IF RoleCount <> 3 OR LocationCount <> 1 OR StatusCount <> 6
       OR ServiceCount <> 6 OR AccountCount <> 7 OR AppointmentCount <> 6 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Core verification failed: sample-data counts do not match';
    END IF;

    IF InvalidQualificationCount <> 0 OR InactiveServiceBookingCount <> 0
       OR OverlapCount <> 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Core verification failed: sample appointment validity check failed';
    END IF;
END//

DELIMITER ;

CALL sp_VerifyCoreBuild();
DROP PROCEDURE sp_VerifyCoreBuild;

SELECT 'Core build verification passed' AS BuildMessage;

SELECT VERSION() AS DatabaseVersion;

SELECT
    (SELECT COUNT(*)
       FROM information_schema.tables
      WHERE table_schema = 'hair_fix_salon'
        AND table_type = 'BASE TABLE') AS BaseTables,
    (SELECT COUNT(*)
       FROM information_schema.views
      WHERE table_schema = 'hair_fix_salon') AS Views,
    (SELECT COUNT(DISTINCT CONCAT(table_name, ':', index_name))
       FROM information_schema.statistics
      WHERE table_schema = 'hair_fix_salon'
        AND index_name LIKE 'idx_%') AS NamedIndexes,
    (SELECT COUNT(*)
       FROM information_schema.table_constraints
      WHERE constraint_schema = 'hair_fix_salon'
        AND constraint_type = 'FOREIGN KEY') AS ForeignKeys,
    (SELECT COUNT(*)
       FROM information_schema.table_constraints
      WHERE constraint_schema = 'hair_fix_salon'
        AND constraint_type = 'CHECK') AS CheckConstraints,
    (SELECT COUNT(*)
       FROM information_schema.routines
      WHERE routine_schema = 'hair_fix_salon'
        AND routine_type = 'PROCEDURE') AS StoredProcedures,
    (SELECT COUNT(*)
       FROM information_schema.triggers
      WHERE trigger_schema = 'hair_fix_salon') AS Triggers;

SELECT 'Role' AS SeedTable, COUNT(*) AS RowCount FROM Role
UNION ALL SELECT 'Location', COUNT(*) FROM Location
UNION ALL SELECT 'AppointmentStatus', COUNT(*) FROM AppointmentStatus
UNION ALL SELECT 'AppointmentStatusTransition', COUNT(*) FROM AppointmentStatusTransition
UNION ALL SELECT 'PaymentMethod', COUNT(*) FROM PaymentMethod
UNION ALL SELECT 'UserAccount', COUNT(*) FROM UserAccount
UNION ALL SELECT 'Customer', COUNT(*) FROM Customer
UNION ALL SELECT 'Staff', COUNT(*) FROM Staff
UNION ALL SELECT 'Service', COUNT(*) FROM Service
UNION ALL SELECT 'StaffService', COUNT(*) FROM StaffService
UNION ALL SELECT 'StaffSchedule', COUNT(*) FROM StaffSchedule
UNION ALL SELECT 'Appointment', COUNT(*) FROM Appointment
UNION ALL SELECT 'AppointmentHistory', COUNT(*) FROM AppointmentHistory
UNION ALL SELECT 'PaymentTransaction', COUNT(*) FROM PaymentTransaction;
