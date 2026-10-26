USE hair_fix_salon;

CREATE USER IF NOT EXISTS 'hfs_definer'@'localhost' IDENTIFIED BY RANDOM PASSWORD ACCOUNT LOCK;
ALTER USER 'hfs_definer'@'localhost' ACCOUNT LOCK;
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'hfs_definer'@'localhost';

GRANT SELECT ON hair_fix_salon.Role                        TO 'hfs_definer'@'localhost';
GRANT SELECT ON hair_fix_salon.Location                    TO 'hfs_definer'@'localhost';
GRANT SELECT ON hair_fix_salon.AppointmentStatus           TO 'hfs_definer'@'localhost';
GRANT SELECT ON hair_fix_salon.AppointmentStatusTransition TO 'hfs_definer'@'localhost';
GRANT SELECT ON hair_fix_salon.PaymentMethod               TO 'hfs_definer'@'localhost';
GRANT SELECT (UserID, Email, FirstName, LastName, RoleID, AccountStatus)
             ON hair_fix_salon.UserAccount                 TO 'hfs_definer'@'localhost';
GRANT SELECT ON hair_fix_salon.Service                     TO 'hfs_definer'@'localhost';
GRANT SELECT ON hair_fix_salon.StaffService                TO 'hfs_definer'@'localhost';
GRANT SELECT, UPDATE         ON hair_fix_salon.Customer           TO 'hfs_definer'@'localhost';
GRANT SELECT, UPDATE         ON hair_fix_salon.Staff              TO 'hfs_definer'@'localhost';
GRANT UPDATE (FirstName, LastName) ON hair_fix_salon.UserAccount  TO 'hfs_definer'@'localhost';
GRANT SELECT, INSERT         ON hair_fix_salon.StaffSchedule      TO 'hfs_definer'@'localhost';
GRANT SELECT, INSERT, UPDATE ON hair_fix_salon.Appointment        TO 'hfs_definer'@'localhost';
GRANT SELECT, INSERT         ON hair_fix_salon.AppointmentHistory TO 'hfs_definer'@'localhost';
GRANT SELECT, INSERT         ON hair_fix_salon.PaymentTransaction TO 'hfs_definer'@'localhost';
GRANT LOCK TABLES, EXECUTE   ON hair_fix_salon.*                  TO 'hfs_definer'@'localhost';
GRANT TRIGGER ON hair_fix_salon.Appointment                       TO 'hfs_definer'@'localhost';
GRANT TRIGGER ON hair_fix_salon.AppointmentHistory                TO 'hfs_definer'@'localhost';
GRANT SELECT ON performance_schema.events_transactions_current    TO 'hfs_definer'@'localhost';
GRANT SELECT ON mysql.role_edges                                  TO 'hfs_definer'@'localhost';

DROP PROCEDURE IF EXISTS sp_UpdateMyProfile;
DROP PROCEDURE IF EXISTS sp_GetStaffSchedule;
DROP PROCEDURE IF EXISTS sp_GetAppointmentTrail;
DROP PROCEDURE IF EXISTS sp_GetMyAppointments;
DROP PROCEDURE IF EXISTS sp_GetAvailableSlots;
DROP PROCEDURE IF EXISTS sp_RecordPayment;
DROP PROCEDURE IF EXISTS sp_SaveStaffSchedule;
DROP PROCEDURE IF EXISTS sp_ChangeAppointmentStatus;
DROP PROCEDURE IF EXISTS sp_CancelAppointment;
DROP PROCEDURE IF EXISTS sp_ApplyStatusChange;
DROP PROCEDURE IF EXISTS sp_RescheduleAppointment;
DROP PROCEDURE IF EXISTS sp_BookAppointment;
DROP PROCEDURE IF EXISTS sp_ResolveActor;
DROP FUNCTION  IF EXISTS fn_IsStaffAvailable;
DROP FUNCTION  IF EXISTS fn_SalonNow;
DROP FUNCTION  IF EXISTS fn_InCallerTransaction;
DROP FUNCTION  IF EXISTS fn_SessionLogin;

DELIMITER $$

CREATE DEFINER = 'hfs_definer'@'localhost' FUNCTION fn_SessionLogin()
RETURNS VARCHAR(288)
NOT DETERMINISTIC
NO SQL
BEGIN
    DECLARE v_Session VARCHAR(288) DEFAULT SESSION_USER();
    RETURN SUBSTRING(v_Session, 1,
           CHAR_LENGTH(v_Session) - CHAR_LENGTH(SUBSTRING_INDEX(v_Session, '@', -1)) - 1);
END$$

CREATE DEFINER = 'hfs_definer'@'localhost' FUNCTION fn_InCallerTransaction()
RETURNS TINYINT
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    RETURN COALESCE((SELECT STATE = 'ACTIVE' AND AUTOCOMMIT = 'NO'
                       FROM performance_schema.events_transactions_current
                      WHERE THREAD_ID = PS_CURRENT_THREAD_ID()), 0);
END$$

CREATE DEFINER = 'hfs_definer'@'localhost' FUNCTION fn_SalonNow(p_LocationID SMALLINT UNSIGNED)
RETURNS DATETIME
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_TimeZone VARCHAR(64);
    SET v_TimeZone = (SELECT TimeZone FROM Location WHERE LocationID = p_LocationID);
    RETURN COALESCE(CONVERT_TZ(UTC_TIMESTAMP(), '+00:00', v_TimeZone), NOW());
END$$

CREATE DEFINER = 'hfs_definer'@'localhost' FUNCTION fn_IsStaffAvailable(p_StaffID BIGINT UNSIGNED,
                                    p_Start   DATETIME,
                                    p_End     DATETIME)
RETURNS TINYINT
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_Date      DATE DEFAULT DATE(p_Start);
    DECLARE v_StartTime TIME DEFAULT TIME(p_Start);
    DECLARE v_EndTime   TIME DEFAULT TIME(p_End);

    IF p_Start IS NULL OR p_End IS NULL OR p_End <= p_Start OR DATE(p_End) <> v_Date THEN
        RETURN 0;
    END IF;

    IF EXISTS (SELECT 1 FROM StaffSchedule
               WHERE StaffID = p_StaffID
                 AND ScheduleType = 'BlockedTime'
                 AND ScheduleDate = v_Date
                 AND v_StartTime < EndTime
                 AND v_EndTime   > StartTime) THEN
        RETURN 0;
    END IF;

    IF EXISTS (SELECT 1 FROM StaffSchedule
               WHERE StaffID = p_StaffID
                 AND ScheduleType = 'DateAvailability'
                 AND ScheduleDate = v_Date) THEN
        RETURN EXISTS (SELECT 1 FROM StaffSchedule
                       WHERE StaffID = p_StaffID
                         AND ScheduleType = 'DateAvailability'
                         AND ScheduleDate = v_Date
                         AND v_StartTime >= StartTime
                         AND v_EndTime   <= EndTime);
    END IF;

    RETURN EXISTS (SELECT 1 FROM StaffSchedule
                   WHERE StaffID = p_StaffID
                     AND ScheduleType = 'RecurringAvailability'
                     AND DayOfWeek = DAYOFWEEK(v_Date)
                     AND EffectiveStartDate <= v_Date
                     AND (EffectiveEndDate IS NULL OR EffectiveEndDate >= v_Date)
                     AND v_StartTime >= StartTime
                     AND v_EndTime   <= EndTime);
END$$

CREATE DEFINER = 'hfs_definer'@'localhost' PROCEDURE sp_ResolveActor(IN  p_ActorUserID BIGINT UNSIGNED,
                                 OUT o_RoleName    VARCHAR(30))
BEGIN
    DECLARE v_Login         VARCHAR(288) DEFAULT fn_SessionLogin();
    DECLARE v_LoginUserID   BIGINT UNSIGNED;
    DECLARE v_AccountStatus VARCHAR(12);

    SET o_RoleName = NULL;

    IF p_ActorUserID IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Actor user ID is required';
    END IF;

    SET v_LoginUserID = (SELECT UserID FROM UserAccount WHERE Email = v_Login);

    IF v_LoginUserID IS NOT NULL THEN
        IF v_LoginUserID <> p_ActorUserID THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Actor ID does not match the signed-in account';
        END IF;
    ELSEIF v_Login <> 'root' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Database login is not linked to a salon account';
    END IF;

    SELECT r.RoleName, u.AccountStatus
      INTO o_RoleName, v_AccountStatus
      FROM UserAccount AS u
      JOIN Role        AS r ON r.RoleID = u.RoleID
     WHERE u.UserID = p_ActorUserID;

    IF o_RoleName IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Actor account not found';
    END IF;
    IF v_AccountStatus <> 'Active' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Actor account is not active';
    END IF;

    IF v_LoginUserID IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM mysql.role_edges
                       WHERE TO_USER = v_Login
                         AND FROM_USER = CASE o_RoleName
                                             WHEN 'Customer'      THEN 'hair_fix_customer'
                                             WHEN 'Staff'         THEN 'hair_fix_staff'
                                             WHEN 'Administrator' THEN 'hair_fix_administrator'
                                         END) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Database role of this login does not match the application role';
    END IF;
END$$

CREATE DEFINER = 'hfs_definer'@'localhost' PROCEDURE sp_BookAppointment(IN  p_ActorUserID   BIGINT UNSIGNED,
                                    IN  p_CustomerID    BIGINT UNSIGNED,
                                    IN  p_StaffID       BIGINT UNSIGNED,
                                    IN  p_ServiceID     INT UNSIGNED,
                                    IN  p_StartDateTime DATETIME,
                                    IN  p_Notes         VARCHAR(500),
                                    OUT p_AppointmentID BIGINT UNSIGNED)
BEGIN
    DECLARE v_OwnTxn         BOOLEAN DEFAULT (NOT fn_InCallerTransaction());
    DECLARE v_Role           VARCHAR(30);
    DECLARE v_CustUserID     BIGINT UNSIGNED;
    DECLARE v_CustProfile    VARCHAR(12);
    DECLARE v_CustAccount    VARCHAR(12);
    DECLARE v_StaffActive    BOOLEAN;
    DECLARE v_StaffAccount   VARCHAR(12);
    DECLARE v_LocationID     SMALLINT UNSIGNED;
    DECLARE v_LocationActive BOOLEAN;
    DECLARE v_ServiceActive  BOOLEAN;
    DECLARE v_Price          DECIMAL(10,2);
    DECLARE v_Duration       SMALLINT UNSIGNED;
    DECLARE v_End            DATETIME;
    DECLARE v_Now            DATETIME;
    DECLARE v_ScheduledID    TINYINT UNSIGNED;
    DECLARE v_CancelledID    TINYINT UNSIGNED;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        IF v_OwnTxn THEN ROLLBACK; ELSE ROLLBACK TO SAVEPOINT sp_book; END IF;
        SET p_AppointmentID = NULL;
        RESIGNAL;
    END;

    IF v_OwnTxn THEN START TRANSACTION; ELSE SAVEPOINT sp_book; END IF;
    SET p_AppointmentID = NULL;

    CALL sp_ResolveActor(p_ActorUserID, v_Role);
    IF v_Role NOT IN ('Customer', 'Administrator') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Only customers or administrators can book appointments';
    END IF;

    SELECT c.UserID, c.ProfileStatus, u.AccountStatus
      INTO v_CustUserID, v_CustProfile, v_CustAccount
      FROM Customer    AS c
      JOIN UserAccount AS u ON u.UserID = c.UserID
     WHERE c.CustomerID = p_CustomerID
       FOR SHARE;
    IF v_CustUserID IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Customer not found';
    END IF;
    IF v_Role = 'Customer' AND v_CustUserID <> p_ActorUserID THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Customers can book only for their own profile';
    END IF;
    IF v_CustProfile <> 'Active' OR v_CustAccount <> 'Active' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Customer profile or account is not active';
    END IF;

    SELECT s.ActiveFlag, u.AccountStatus, s.LocationID
      INTO v_StaffActive, v_StaffAccount, v_LocationID
      FROM Staff       AS s
      JOIN UserAccount AS u ON u.UserID = s.UserID
     WHERE s.StaffID = p_StaffID
       FOR UPDATE OF s;
    IF v_LocationID IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Staff member not found';
    END IF;
    IF NOT v_StaffActive OR v_StaffAccount <> 'Active' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Staff member or staff account is not active';
    END IF;

    SET v_LocationActive = (SELECT ActiveFlag FROM Location WHERE LocationID = v_LocationID FOR SHARE);
    IF NOT COALESCE(v_LocationActive, FALSE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Salon location is not active';
    END IF;

    SELECT ActiveFlag, CurrentPrice, DurationMinutes
      INTO v_ServiceActive, v_Price, v_Duration
      FROM Service
     WHERE ServiceID = p_ServiceID
       FOR SHARE;
    IF v_Duration IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Service not found';
    END IF;
    IF NOT v_ServiceActive THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Service is not active';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM StaffService
                   WHERE StaffID = p_StaffID AND ServiceID = p_ServiceID AND IsActive) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Staff member is not qualified for this service';
    END IF;

    SET v_Now = fn_SalonNow(v_LocationID);
    IF p_StartDateTime IS NULL OR p_StartDateTime <= v_Now THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Appointment must start in the future';
    END IF;

    SET v_End = p_StartDateTime + INTERVAL v_Duration MINUTE;

    IF NOT fn_IsStaffAvailable(p_StaffID, p_StartDateTime, v_End) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Requested time is outside staff availability or inside blocked time';
    END IF;

    SET v_ScheduledID = (SELECT StatusID FROM AppointmentStatus WHERE StatusName = 'Scheduled');
    SET v_CancelledID = (SELECT StatusID FROM AppointmentStatus WHERE StatusName = 'Cancelled');
    IF v_ScheduledID IS NULL OR v_CancelledID IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Appointment status reference data is missing';
    END IF;

    IF EXISTS (SELECT 1 FROM Appointment
               WHERE StaffID = p_StaffID
                 AND StatusID <> v_CancelledID
                 AND p_StartDateTime < EndDateTime
                 AND v_End           > StartDateTime) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Requested time overlaps an existing appointment for this staff member';
    END IF;

    INSERT INTO Appointment
        (CustomerID, StaffID, ServiceID, LocationID, StartDateTime, EndDateTime,
         BookedPrice, BookedDurationMinutes, StatusID, Notes)
    VALUES
        (p_CustomerID, p_StaffID, p_ServiceID, v_LocationID, p_StartDateTime, v_End,
         v_Price, v_Duration, v_ScheduledID, NULLIF(TRIM(p_Notes), ''));
    SET p_AppointmentID = LAST_INSERT_ID();

    INSERT INTO AppointmentHistory
        (AppointmentID, EventType, ChangedByUserID, ChangedAt,
         PreviousStatusID, NewStatusID, NewStartDateTime, NewEndDateTime,
         NewStaffID, NewServiceID, Reason, RequestID)
    VALUES
        (p_AppointmentID, 'Booked', p_ActorUserID, v_Now,
         NULL, v_ScheduledID, p_StartDateTime, v_End,
         p_StaffID, p_ServiceID, NULL, UUID());

    IF v_OwnTxn THEN COMMIT; ELSE RELEASE SAVEPOINT sp_book; END IF;
END$$

CREATE DEFINER = 'hfs_definer'@'localhost' PROCEDURE sp_RescheduleAppointment(IN p_AppointmentID    BIGINT UNSIGNED,
                                          IN p_ActorUserID      BIGINT UNSIGNED,
                                          IN p_NewStartDateTime DATETIME,
                                          IN p_NewStaffID       BIGINT UNSIGNED,
                                          IN p_Reason           VARCHAR(500))
BEGIN
    DECLARE v_OwnTxn         BOOLEAN DEFAULT (NOT fn_InCallerTransaction());
    DECLARE v_Role           VARCHAR(30);
    DECLARE v_CustomerID     BIGINT UNSIGNED;
    DECLARE v_OldStaffID     BIGINT UNSIGNED;
    DECLARE v_NewStaffID     BIGINT UNSIGNED;
    DECLARE v_ServiceID      INT UNSIGNED;
    DECLARE v_OldLocationID  SMALLINT UNSIGNED;
    DECLARE v_NewLocationID  SMALLINT UNSIGNED;
    DECLARE v_OldStart       DATETIME;
    DECLARE v_OldEnd         DATETIME;
    DECLARE v_NewEnd         DATETIME;
    DECLARE v_Duration       SMALLINT UNSIGNED;
    DECLARE v_StatusID       TINYINT UNSIGNED;
    DECLARE v_StatusName     VARCHAR(30);
    DECLARE v_CancelledID    TINYINT UNSIGNED;
    DECLARE v_Now            DATETIME;
    DECLARE v_StaffActive    BOOLEAN;
    DECLARE v_StaffAccount   VARCHAR(12);
    DECLARE v_LocationActive BOOLEAN;
    DECLARE v_LockCount      INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        IF v_OwnTxn THEN ROLLBACK; ELSE ROLLBACK TO SAVEPOINT sp_resched; END IF;
        RESIGNAL;
    END;

    IF v_OwnTxn THEN START TRANSACTION; ELSE SAVEPOINT sp_resched; END IF;

    CALL sp_ResolveActor(p_ActorUserID, v_Role);

    SET v_OldStaffID = (SELECT StaffID FROM Appointment WHERE AppointmentID = p_AppointmentID);
    IF v_OldStaffID IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Appointment not found';
    END IF;
    SET v_NewStaffID = COALESCE(p_NewStaffID, v_OldStaffID);

    SELECT COUNT(*) INTO v_LockCount FROM Staff
     WHERE StaffID = LEAST(v_OldStaffID, v_NewStaffID) FOR UPDATE;
    IF v_NewStaffID <> v_OldStaffID THEN
        SELECT v_LockCount + COUNT(*) INTO v_LockCount FROM Staff
         WHERE StaffID = GREATEST(v_OldStaffID, v_NewStaffID) FOR UPDATE;
    END IF;
    IF v_LockCount < IF(v_OldStaffID = v_NewStaffID, 1, 2) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Staff member not found';
    END IF;

    SELECT a.CustomerID, a.StaffID, a.ServiceID, a.LocationID, a.StartDateTime, a.EndDateTime,
           a.BookedDurationMinutes, a.StatusID, st.StatusName
      INTO v_CustomerID, v_OldStaffID, v_ServiceID, v_OldLocationID, v_OldStart, v_OldEnd,
           v_Duration, v_StatusID, v_StatusName
      FROM Appointment       AS a
      JOIN AppointmentStatus AS st ON st.StatusID = a.StatusID
     WHERE a.AppointmentID = p_AppointmentID
       FOR UPDATE OF a;

    IF v_StatusName NOT IN ('Scheduled', 'Confirmed') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Only Scheduled or Confirmed appointments can be rescheduled';
    END IF;

    SET v_Now = fn_SalonNow(v_OldLocationID);

    IF v_Role = 'Customer' THEN
        IF NOT EXISTS (SELECT 1 FROM Customer
                       WHERE CustomerID = v_CustomerID AND UserID = p_ActorUserID) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Customers can reschedule only their own appointments';
        END IF;
        IF TIMESTAMPDIFF(MINUTE, v_Now, v_OldStart) < 1440 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Customers must reschedule at least 24 hours before the start';
        END IF;
    ELSEIF v_Role = 'Staff' THEN
        IF NOT EXISTS (SELECT 1 FROM Staff
                       WHERE StaffID = v_OldStaffID AND UserID = p_ActorUserID) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Staff can reschedule only appointments assigned to them';
        END IF;
        IF v_NewStaffID <> v_OldStaffID THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Only administrators can move an appointment to another staff member';
        END IF;
    ELSEIF v_Role <> 'Administrator' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Role is not allowed to reschedule appointments';
    END IF;

    SELECT s.ActiveFlag, u.AccountStatus, s.LocationID
      INTO v_StaffActive, v_StaffAccount, v_NewLocationID
      FROM Staff       AS s
      JOIN UserAccount AS u ON u.UserID = s.UserID
     WHERE s.StaffID = v_NewStaffID;
    IF NOT v_StaffActive OR v_StaffAccount <> 'Active' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Staff member or staff account is not active';
    END IF;

    SET v_LocationActive = (SELECT ActiveFlag FROM Location WHERE LocationID = v_NewLocationID);
    IF NOT COALESCE(v_LocationActive, FALSE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Salon location is not active';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM Service WHERE ServiceID = v_ServiceID AND ActiveFlag) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Service is not active';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM StaffService
                   WHERE StaffID = v_NewStaffID AND ServiceID = v_ServiceID AND IsActive) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Staff member is not qualified for this service';
    END IF;

    IF p_NewStartDateTime IS NULL OR p_NewStartDateTime <= v_Now THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'New start time must be in the future';
    END IF;
    SET v_NewEnd = p_NewStartDateTime + INTERVAL v_Duration MINUTE;

    IF p_NewStartDateTime = v_OldStart AND v_NewStaffID = v_OldStaffID THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'New time and staff match the current booking';
    END IF;

    IF NOT fn_IsStaffAvailable(v_NewStaffID, p_NewStartDateTime, v_NewEnd) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Requested time is outside staff availability or inside blocked time';
    END IF;

    SET v_CancelledID = (SELECT StatusID FROM AppointmentStatus WHERE StatusName = 'Cancelled');
    IF EXISTS (SELECT 1 FROM Appointment
               WHERE StaffID = v_NewStaffID
                 AND AppointmentID <> p_AppointmentID
                 AND StatusID <> v_CancelledID
                 AND p_NewStartDateTime < EndDateTime
                 AND v_NewEnd           > StartDateTime) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Requested time overlaps an existing appointment for this staff member';
    END IF;

    UPDATE Appointment
       SET StaffID       = v_NewStaffID,
           LocationID    = v_NewLocationID,
           StartDateTime = p_NewStartDateTime,
           EndDateTime   = v_NewEnd
     WHERE AppointmentID = p_AppointmentID;

    INSERT INTO AppointmentHistory
        (AppointmentID, EventType, ChangedByUserID, ChangedAt,
         PreviousStatusID, NewStatusID,
         PreviousStartDateTime, NewStartDateTime, PreviousEndDateTime, NewEndDateTime,
         PreviousStaffID, NewStaffID, PreviousServiceID, NewServiceID,
         Reason, RequestID)
    VALUES
        (p_AppointmentID, 'Rescheduled', p_ActorUserID, v_Now,
         v_StatusID, v_StatusID,
         v_OldStart, p_NewStartDateTime, v_OldEnd, v_NewEnd,
         v_OldStaffID, v_NewStaffID, v_ServiceID, v_ServiceID,
         NULLIF(TRIM(p_Reason), ''), UUID());

    IF v_OwnTxn THEN COMMIT; ELSE RELEASE SAVEPOINT sp_resched; END IF;
END$$

CREATE DEFINER = 'hfs_definer'@'localhost' PROCEDURE sp_ApplyStatusChange(IN p_AppointmentID BIGINT UNSIGNED,
                                      IN p_ActorUserID   BIGINT UNSIGNED,
                                      IN p_RoleName      VARCHAR(30),
                                      IN p_NewStatusName VARCHAR(30),
                                      IN p_Reason        VARCHAR(500))
BEGIN
    DECLARE v_OldStatusID     TINYINT UNSIGNED;
    DECLARE v_OldStatusName   VARCHAR(30);
    DECLARE v_OldIsFinal      BOOLEAN;
    DECLARE v_NewStatusID     TINYINT UNSIGNED;
    DECLARE v_StaffID         BIGINT UNSIGNED;
    DECLARE v_CustomerID      BIGINT UNSIGNED;
    DECLARE v_LocationID      SMALLINT UNSIGNED;
    DECLARE v_Start           DATETIME;
    DECLARE v_Now             DATETIME;
    DECLARE v_CustAllowed     BOOLEAN;
    DECLARE v_StaffAllowed    BOOLEAN;
    DECLARE v_AdminAllowed    BOOLEAN;
    DECLARE v_RequiresReason  BOOLEAN;
    DECLARE v_Reason          VARCHAR(500) DEFAULT NULLIF(TRIM(p_Reason), '');
    DECLARE v_Msg             VARCHAR(128);

    SELECT a.StatusID, st.StatusName, st.IsFinal, a.StaffID, a.CustomerID, a.LocationID, a.StartDateTime
      INTO v_OldStatusID, v_OldStatusName, v_OldIsFinal, v_StaffID, v_CustomerID, v_LocationID, v_Start
      FROM Appointment       AS a
      JOIN AppointmentStatus AS st ON st.StatusID = a.StatusID
     WHERE a.AppointmentID = p_AppointmentID
       FOR UPDATE OF a;
    IF v_OldStatusID IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Appointment not found';
    END IF;

    SET v_NewStatusID = (SELECT StatusID FROM AppointmentStatus WHERE StatusName = p_NewStatusName);
    IF v_NewStatusID IS NULL THEN
        SET v_Msg = CONCAT('Unknown appointment status: ', COALESCE(p_NewStatusName, 'NULL'));
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_Msg;
    END IF;

    IF v_OldIsFinal THEN
        SET v_Msg = CONCAT('Appointment is ', v_OldStatusName, ', a final status, and cannot change');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_Msg;
    END IF;

    SELECT CustomerAllowed, StaffAllowed, AdministratorAllowed, RequiresReason
      INTO v_CustAllowed, v_StaffAllowed, v_AdminAllowed, v_RequiresReason
      FROM AppointmentStatusTransition
     WHERE FromStatusID = v_OldStatusID AND ToStatusID = v_NewStatusID;
    IF v_RequiresReason IS NULL THEN
        SET v_Msg = CONCAT('Status change from ', v_OldStatusName, ' to ', p_NewStatusName, ' is not allowed');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_Msg;
    END IF;

    SET v_Now = fn_SalonNow(v_LocationID);

    IF p_RoleName = 'Customer' THEN
        IF NOT v_CustAllowed THEN
            SET v_Msg = CONCAT('Customers cannot change status to ', p_NewStatusName);
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_Msg;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM Customer
                       WHERE CustomerID = v_CustomerID AND UserID = p_ActorUserID) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Customers can change only their own appointments';
        END IF;
        IF TIMESTAMPDIFF(MINUTE, v_Now, v_Start) < 1440 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Customers must cancel at least 24 hours before the start';
        END IF;
    ELSEIF p_RoleName = 'Staff' THEN
        IF NOT v_StaffAllowed THEN
            SET v_Msg = CONCAT('Staff cannot change status to ', p_NewStatusName);
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_Msg;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM Staff
                       WHERE StaffID = v_StaffID AND UserID = p_ActorUserID) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Staff can change only appointments assigned to them';
        END IF;
    ELSEIF p_RoleName = 'Administrator' THEN
        IF NOT v_AdminAllowed THEN
            SET v_Msg = CONCAT('Administrators cannot change status to ', p_NewStatusName);
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_Msg;
        END IF;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Role is not allowed to change appointment status';
    END IF;

    IF (v_RequiresReason OR p_NewStatusName IN ('Cancelled', 'No-Show')) AND v_Reason IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A reason is required for this status change';
    END IF;

    UPDATE Appointment
       SET StatusID    = v_NewStatusID,
           CancelledAt = IF(p_NewStatusName = 'Cancelled', v_Now, CancelledAt)
     WHERE AppointmentID = p_AppointmentID;

    INSERT INTO AppointmentHistory
        (AppointmentID, EventType, ChangedByUserID, ChangedAt,
         PreviousStatusID, NewStatusID, Reason, RequestID)
    VALUES
        (p_AppointmentID, IF(p_NewStatusName = 'Cancelled', 'Cancelled', 'StatusChanged'),
         p_ActorUserID, v_Now,
         v_OldStatusID, v_NewStatusID, v_Reason, UUID());
END$$

CREATE DEFINER = 'hfs_definer'@'localhost' PROCEDURE sp_CancelAppointment(IN p_AppointmentID BIGINT UNSIGNED,
                                      IN p_ActorUserID   BIGINT UNSIGNED,
                                      IN p_Reason        VARCHAR(500))
BEGIN
    DECLARE v_OwnTxn BOOLEAN DEFAULT (NOT fn_InCallerTransaction());
    DECLARE v_Role   VARCHAR(30);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        IF v_OwnTxn THEN ROLLBACK; ELSE ROLLBACK TO SAVEPOINT sp_cancel; END IF;
        RESIGNAL;
    END;

    IF v_OwnTxn THEN START TRANSACTION; ELSE SAVEPOINT sp_cancel; END IF;

    CALL sp_ResolveActor(p_ActorUserID, v_Role);
    CALL sp_ApplyStatusChange(p_AppointmentID, p_ActorUserID, v_Role, 'Cancelled', p_Reason);

    IF v_OwnTxn THEN COMMIT; ELSE RELEASE SAVEPOINT sp_cancel; END IF;
END$$

CREATE DEFINER = 'hfs_definer'@'localhost' PROCEDURE sp_ChangeAppointmentStatus(IN p_AppointmentID BIGINT UNSIGNED,
                                            IN p_ActorUserID   BIGINT UNSIGNED,
                                            IN p_NewStatusName VARCHAR(30),
                                            IN p_Reason        VARCHAR(500))
BEGIN
    DECLARE v_OwnTxn BOOLEAN DEFAULT (NOT fn_InCallerTransaction());
    DECLARE v_Role   VARCHAR(30);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        IF v_OwnTxn THEN ROLLBACK; ELSE ROLLBACK TO SAVEPOINT sp_status; END IF;
        RESIGNAL;
    END;

    IF v_OwnTxn THEN START TRANSACTION; ELSE SAVEPOINT sp_status; END IF;

    CALL sp_ResolveActor(p_ActorUserID, v_Role);
    CALL sp_ApplyStatusChange(p_AppointmentID, p_ActorUserID, v_Role, p_NewStatusName, p_Reason);

    IF v_OwnTxn THEN COMMIT; ELSE RELEASE SAVEPOINT sp_status; END IF;
END$$

CREATE DEFINER = 'hfs_definer'@'localhost' PROCEDURE sp_SaveStaffSchedule(IN  p_ActorUserID          BIGINT UNSIGNED,
                                      IN  p_StaffID              BIGINT UNSIGNED,
                                      IN  p_ScheduleType         VARCHAR(30),
                                      IN  p_DayOfWeek            TINYINT UNSIGNED,
                                      IN  p_ScheduleDate         DATE,
                                      IN  p_StartTime            TIME,
                                      IN  p_EndTime              TIME,
                                      IN  p_EffectiveStartDate   DATE,
                                      IN  p_EffectiveEndDate     DATE,
                                      IN  p_Reason               VARCHAR(255),
                                      OUT p_ScheduleID           BIGINT UNSIGNED,
                                      OUT p_AffectedAppointments INT)
BEGIN
    DECLARE v_OwnTxn       BOOLEAN DEFAULT (NOT fn_InCallerTransaction());
    DECLARE v_Role         VARCHAR(30);
    DECLARE v_StaffActive  BOOLEAN;
    DECLARE v_StaffAccount VARCHAR(12);
    DECLARE v_CancelledID  TINYINT UNSIGNED;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        IF v_OwnTxn THEN ROLLBACK; ELSE ROLLBACK TO SAVEPOINT sp_sched; END IF;
        SET p_ScheduleID = NULL;
        SET p_AffectedAppointments = NULL;
        RESIGNAL;
    END;

    IF v_OwnTxn THEN START TRANSACTION; ELSE SAVEPOINT sp_sched; END IF;
    SET p_ScheduleID = NULL;
    SET p_AffectedAppointments = 0;

    CALL sp_ResolveActor(p_ActorUserID, v_Role);
    IF v_Role <> 'Administrator' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only administrators can maintain staff schedules';
    END IF;

    SELECT s.ActiveFlag, u.AccountStatus
      INTO v_StaffActive, v_StaffAccount
      FROM Staff       AS s
      JOIN UserAccount AS u ON u.UserID = s.UserID
     WHERE s.StaffID = p_StaffID
       FOR UPDATE OF s;
    IF v_StaffActive IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Staff member not found';
    END IF;
    IF NOT v_StaffActive OR v_StaffAccount <> 'Active' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Staff member or staff account is not active';
    END IF;

    IF p_ScheduleType IS NULL
       OR p_ScheduleType NOT IN ('RecurringAvailability', 'DateAvailability', 'BlockedTime') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Schedule type must be RecurringAvailability, DateAvailability, or BlockedTime';
    END IF;
    IF p_StartTime IS NULL OR p_EndTime IS NULL OR p_EndTime <= p_StartTime THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'End time must be later than start time';
    END IF;

    IF p_ScheduleType = 'RecurringAvailability' THEN
        IF p_DayOfWeek IS NULL OR p_DayOfWeek NOT BETWEEN 1 AND 7 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Recurring availability needs a day of week from 1 (Sunday) to 7';
        END IF;
        IF p_EffectiveStartDate IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Recurring availability needs an effective start date';
        END IF;
        IF p_EffectiveEndDate IS NOT NULL AND p_EffectiveEndDate < p_EffectiveStartDate THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Effective end date cannot be before effective start date';
        END IF;
        IF p_ScheduleDate IS NOT NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Recurring availability cannot have a schedule date';
        END IF;

        IF EXISTS (SELECT 1 FROM StaffSchedule
                   WHERE StaffID = p_StaffID
                     AND ScheduleType = 'RecurringAvailability'
                     AND DayOfWeek = p_DayOfWeek
                     AND EffectiveStartDate <= COALESCE(p_EffectiveEndDate, '9999-12-31')
                     AND p_EffectiveStartDate <= COALESCE(EffectiveEndDate, '9999-12-31')
                     AND p_StartTime < EndTime
                     AND p_EndTime   > StartTime) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Overlaps an existing recurring availability entry';
        END IF;
    ELSE
        IF p_ScheduleDate IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Date availability and blocked time need a schedule date';
        END IF;
        IF p_DayOfWeek IS NOT NULL OR p_EffectiveStartDate IS NOT NULL OR p_EffectiveEndDate IS NOT NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Date availability and blocked time cannot have recurring fields';
        END IF;

        IF EXISTS (SELECT 1 FROM StaffSchedule
                   WHERE StaffID = p_StaffID
                     AND ScheduleType = p_ScheduleType
                     AND ScheduleDate = p_ScheduleDate
                     AND p_StartTime < EndTime
                     AND p_EndTime   > StartTime) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Overlaps an existing entry of the same type on this date';
        END IF;
    END IF;

    INSERT INTO StaffSchedule
        (StaffID, ScheduleType, DayOfWeek, ScheduleDate, StartTime, EndTime,
         EffectiveStartDate, EffectiveEndDate, Reason)
    VALUES
        (p_StaffID, p_ScheduleType, p_DayOfWeek, p_ScheduleDate, p_StartTime, p_EndTime,
         p_EffectiveStartDate, p_EffectiveEndDate, NULLIF(TRIM(p_Reason), ''));
    SET p_ScheduleID = LAST_INSERT_ID();

    IF p_ScheduleType = 'BlockedTime' THEN
        SET v_CancelledID = (SELECT StatusID FROM AppointmentStatus WHERE StatusName = 'Cancelled');
        SET p_AffectedAppointments =
            (SELECT COUNT(*) FROM Appointment
              WHERE StaffID = p_StaffID
                AND StatusID <> v_CancelledID
                AND StartDateTime < TIMESTAMP(p_ScheduleDate, p_EndTime)
                AND EndDateTime   > TIMESTAMP(p_ScheduleDate, p_StartTime));
    END IF;

    IF v_OwnTxn THEN COMMIT; ELSE RELEASE SAVEPOINT sp_sched; END IF;
END$$

CREATE DEFINER = 'hfs_definer'@'localhost' PROCEDURE sp_RecordPayment(IN  p_ActorUserID       BIGINT UNSIGNED,
                                  IN  p_AppointmentID     BIGINT UNSIGNED,
                                  IN  p_Amount            DECIMAL(10,2),
                                  IN  p_TransactionType   VARCHAR(10),
                                  IN  p_PaymentMethodID   SMALLINT UNSIGNED,
                                  IN  p_PaymentStatus     VARCHAR(12),
                                  IN  p_TransactionDate   DATETIME,
                                  IN  p_ExternalReference VARCHAR(100),
                                  OUT p_TransactionID     BIGINT UNSIGNED)
BEGIN
    DECLARE v_OwnTxn       BOOLEAN DEFAULT (NOT fn_InCallerTransaction());
    DECLARE v_Role         VARCHAR(30);
    DECLARE v_StaffID      BIGINT UNSIGNED;
    DECLARE v_LocationID   SMALLINT UNSIGNED;
    DECLARE v_MethodActive BOOLEAN;
    DECLARE v_Reference    VARCHAR(100) DEFAULT NULLIF(TRIM(p_ExternalReference), '');

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        IF v_OwnTxn THEN ROLLBACK; ELSE ROLLBACK TO SAVEPOINT sp_pay; END IF;
        SET p_TransactionID = NULL;
        RESIGNAL;
    END;

    IF v_OwnTxn THEN START TRANSACTION; ELSE SAVEPOINT sp_pay; END IF;
    SET p_TransactionID = NULL;

    CALL sp_ResolveActor(p_ActorUserID, v_Role);
    IF v_Role NOT IN ('Staff', 'Administrator') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Only assigned staff or administrators can record payments';
    END IF;

    SELECT StaffID, LocationID INTO v_StaffID, v_LocationID
      FROM Appointment
     WHERE AppointmentID = p_AppointmentID
       FOR SHARE;
    IF v_StaffID IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Appointment not found';
    END IF;

    IF v_Role = 'Staff'
       AND NOT EXISTS (SELECT 1 FROM Staff WHERE StaffID = v_StaffID AND UserID = p_ActorUserID) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Staff can record payments only for appointments assigned to them';
    END IF;

    IF p_Amount IS NULL OR p_Amount <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment amount must be greater than zero';
    END IF;
    IF p_TransactionType IS NULL OR p_TransactionType NOT IN ('Charge', 'Refund') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Transaction type must be Charge or Refund';
    END IF;
    IF p_PaymentStatus IS NULL OR p_PaymentStatus NOT IN ('Pending', 'Succeeded', 'Failed', 'Voided') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Payment status must be Pending, Succeeded, Failed, or Voided';
    END IF;

    SET v_MethodActive = (SELECT ActiveFlag FROM PaymentMethod WHERE PaymentMethodID = p_PaymentMethodID);
    IF NOT COALESCE(v_MethodActive, FALSE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment method not found or not active';
    END IF;

    IF v_Reference IS NOT NULL THEN
        IF REGEXP_LIKE(REGEXP_REPLACE(v_Reference, '[ -]', ''), '[0-9]{13,19}') THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'External reference looks like a card number; store a receipt ID only';
        END IF;
        IF EXISTS (SELECT 1 FROM PaymentTransaction WHERE ExternalReference = v_Reference) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'External reference is already used';
        END IF;
    END IF;

    INSERT INTO PaymentTransaction
        (AppointmentID, Amount, TransactionType, PaymentMethodID, PaymentStatus,
         TransactionDate, RecordedByUserID, ExternalReference)
    VALUES
        (p_AppointmentID, p_Amount, p_TransactionType, p_PaymentMethodID, p_PaymentStatus,
         COALESCE(p_TransactionDate, fn_SalonNow(v_LocationID)), p_ActorUserID, v_Reference);
    SET p_TransactionID = LAST_INSERT_ID();

    IF v_OwnTxn THEN COMMIT; ELSE RELEASE SAVEPOINT sp_pay; END IF;
END$$

CREATE DEFINER = 'hfs_definer'@'localhost' PROCEDURE sp_GetAvailableSlots(
                                      IN p_ActorUserID BIGINT UNSIGNED,
                                      IN p_ServiceID   INT UNSIGNED,
                                      IN p_Date        DATE,
                                      IN p_StaffID     BIGINT UNSIGNED)
BEGIN
    DECLARE v_Role        VARCHAR(30);
    DECLARE v_Duration    SMALLINT UNSIGNED;
    DECLARE v_CancelledID TINYINT UNSIGNED;

    CALL sp_ResolveActor(p_ActorUserID, v_Role);

    SET v_Duration = (SELECT DurationMinutes FROM Service WHERE ServiceID = p_ServiceID AND ActiveFlag);
    IF v_Duration IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Service not found or not active';
    END IF;
    IF p_Date IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Date is required';
    END IF;
    SET v_CancelledID = (SELECT StatusID FROM AppointmentStatus WHERE StatusName = 'Cancelled');

    WITH RECURSIVE steps AS (
        SELECT 0 AS m UNION ALL SELECT m + 15 FROM steps WHERE m < 1425
    ),
    candidates AS (
        SELECT st.StaffID,
               CONCAT(u.FirstName, ' ', u.LastName)      AS StaffName,
               st.LocationID,
               TIMESTAMP(p_Date) + INTERVAL steps.m MINUTE AS SlotStart
        FROM Staff        AS st
        JOIN UserAccount  AS u  ON u.UserID = st.UserID AND u.AccountStatus = 'Active'
        JOIN Location     AS l  ON l.LocationID = st.LocationID AND l.ActiveFlag
        JOIN StaffService AS ss ON ss.StaffID = st.StaffID AND ss.ServiceID = p_ServiceID AND ss.IsActive
        CROSS JOIN steps
        WHERE st.ActiveFlag
          AND (p_StaffID IS NULL OR st.StaffID = p_StaffID)
    )
    SELECT c.StaffID, c.StaffName, c.SlotStart AS StartDateTime,
           c.SlotStart + INTERVAL v_Duration MINUTE AS EndDateTime
    FROM candidates AS c
    WHERE c.SlotStart > fn_SalonNow(c.LocationID)
      AND fn_IsStaffAvailable(c.StaffID, c.SlotStart, c.SlotStart + INTERVAL v_Duration MINUTE)
      AND NOT EXISTS (SELECT 1 FROM Appointment AS a
                      WHERE a.StaffID = c.StaffID
                        AND a.StatusID <> v_CancelledID
                        AND c.SlotStart < a.EndDateTime
                        AND c.SlotStart + INTERVAL v_Duration MINUTE > a.StartDateTime)
    ORDER BY c.SlotStart, c.StaffName;
END$$

CREATE DEFINER = 'hfs_definer'@'localhost' PROCEDURE sp_GetMyAppointments(
                                      IN p_ActorUserID BIGINT UNSIGNED,
                                      IN p_From        DATETIME,
                                      IN p_To          DATETIME)
BEGIN
    DECLARE v_Role VARCHAR(30);
    CALL sp_ResolveActor(p_ActorUserID, v_Role);

    SELECT a.AppointmentID, a.StartDateTime, a.EndDateTime,
           CONCAT(cu.FirstName, ' ', cu.LastName) AS CustomerName,
           CONCAT(su.FirstName, ' ', su.LastName) AS StaffName,
           sv.ServiceName, a.BookedPrice, a.BookedDurationMinutes, ast.StatusName, a.Notes,
           (SELECT COALESCE(SUM(CASE WHEN p.PaymentStatus = 'Succeeded' AND p.TransactionType = 'Charge' THEN  p.Amount
                                     WHEN p.PaymentStatus = 'Succeeded' AND p.TransactionType = 'Refund' THEN -p.Amount
                                     ELSE 0 END), 0)
              FROM PaymentTransaction AS p WHERE p.AppointmentID = a.AppointmentID) AS NetPaid
    FROM Appointment       AS a
    JOIN Customer          AS c   ON c.CustomerID = a.CustomerID
    JOIN UserAccount       AS cu  ON cu.UserID    = c.UserID
    JOIN Staff             AS st  ON st.StaffID   = a.StaffID
    JOIN UserAccount       AS su  ON su.UserID    = st.UserID
    JOIN Service           AS sv  ON sv.ServiceID = a.ServiceID
    JOIN AppointmentStatus AS ast ON ast.StatusID = a.StatusID
    WHERE (v_Role = 'Administrator'
           OR (v_Role = 'Customer' AND c.UserID  = p_ActorUserID)
           OR (v_Role = 'Staff'    AND st.UserID = p_ActorUserID))
      AND (p_From IS NULL OR a.StartDateTime >= p_From)
      AND (p_To   IS NULL OR a.StartDateTime <  p_To)
    ORDER BY a.StartDateTime;
END$$

CREATE DEFINER = 'hfs_definer'@'localhost' PROCEDURE sp_GetAppointmentTrail(
                                      IN p_ActorUserID   BIGINT UNSIGNED,
                                      IN p_AppointmentID BIGINT UNSIGNED)
BEGIN
    DECLARE v_Role       VARCHAR(30);
    DECLARE v_CustUserID BIGINT UNSIGNED;
    DECLARE v_StaffUser  BIGINT UNSIGNED;

    CALL sp_ResolveActor(p_ActorUserID, v_Role);

    SELECT c.UserID, st.UserID INTO v_CustUserID, v_StaffUser
      FROM Appointment AS a
      JOIN Customer    AS c  ON c.CustomerID = a.CustomerID
      JOIN Staff       AS st ON st.StaffID   = a.StaffID
     WHERE a.AppointmentID = p_AppointmentID;
    IF v_CustUserID IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Appointment not found';
    END IF;
    IF NOT (v_Role = 'Administrator'
            OR (v_Role = 'Customer' AND v_CustUserID = p_ActorUserID)
            OR (v_Role = 'Staff'    AND v_StaffUser  = p_ActorUserID)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Not authorized to view this appointment';
    END IF;

    SELECT h.HistoryID, h.ChangedAt, h.EventType,
           ps.StatusName AS FromStatus, ns.StatusName AS ToStatus,
           h.PreviousStartDateTime, h.NewStartDateTime,
           h.PreviousStaffID, h.NewStaffID,
           CONCAT(u.FirstName, ' ', u.LastName) AS ChangedBy, r.RoleName AS ChangedByRole,
           h.Reason, h.RequestID
    FROM AppointmentHistory     AS h
    JOIN UserAccount            AS u  ON u.UserID = h.ChangedByUserID
    JOIN Role                   AS r  ON r.RoleID = u.RoleID
    LEFT JOIN AppointmentStatus AS ps ON ps.StatusID = h.PreviousStatusID
    LEFT JOIN AppointmentStatus AS ns ON ns.StatusID = h.NewStatusID
    WHERE h.AppointmentID = p_AppointmentID
    ORDER BY h.ChangedAt, h.HistoryID;

    SELECT p.TransactionID, p.TransactionDate, p.TransactionType, p.Amount, p.PaymentStatus,
           pm.MethodName, CONCAT(u.FirstName, ' ', u.LastName) AS RecordedBy, p.ExternalReference
    FROM PaymentTransaction AS p
    JOIN PaymentMethod      AS pm ON pm.PaymentMethodID = p.PaymentMethodID
    JOIN UserAccount        AS u  ON u.UserID = p.RecordedByUserID
    WHERE p.AppointmentID = p_AppointmentID
    ORDER BY p.TransactionDate, p.TransactionID;
END$$

CREATE DEFINER = 'hfs_definer'@'localhost' PROCEDURE sp_GetStaffSchedule(
                                      IN p_ActorUserID BIGINT UNSIGNED,
                                      IN p_StaffID     BIGINT UNSIGNED,
                                      IN p_FromDate    DATE,
                                      IN p_ToDate      DATE)
BEGIN
    DECLARE v_Role    VARCHAR(30);
    DECLARE v_StaffID BIGINT UNSIGNED;

    CALL sp_ResolveActor(p_ActorUserID, v_Role);

    IF v_Role = 'Staff' THEN
        SET v_StaffID = (SELECT StaffID FROM Staff WHERE UserID = p_ActorUserID);
        IF p_StaffID IS NOT NULL AND p_StaffID <> v_StaffID THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Staff can view only their own schedule';
        END IF;
    ELSEIF v_Role = 'Administrator' THEN
        SET v_StaffID = p_StaffID;
        IF v_StaffID IS NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Staff member is required';
        END IF;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only staff or administrators can view staff schedules';
    END IF;

    SELECT ScheduleID, ScheduleType, DayOfWeek, ScheduleDate, StartTime, EndTime,
           EffectiveStartDate, EffectiveEndDate, Reason
    FROM StaffSchedule
    WHERE StaffID = v_StaffID
      AND ((ScheduleType = 'RecurringAvailability'
            AND (p_ToDate   IS NULL OR EffectiveStartDate <= p_ToDate)
            AND (p_FromDate IS NULL OR EffectiveEndDate IS NULL OR EffectiveEndDate >= p_FromDate))
        OR (ScheduleType <> 'RecurringAvailability'
            AND (p_FromDate IS NULL OR ScheduleDate >= p_FromDate)
            AND (p_ToDate   IS NULL OR ScheduleDate <= p_ToDate)))
    ORDER BY ScheduleType, DayOfWeek, ScheduleDate, StartTime;
END$$

CREATE DEFINER = 'hfs_definer'@'localhost' PROCEDURE sp_UpdateMyProfile(
                                      IN p_ActorUserID       BIGINT UNSIGNED,
                                      IN p_FirstName         VARCHAR(60),
                                      IN p_LastName          VARCHAR(60),
                                      IN p_Phone             VARCHAR(25),
                                      IN p_ContactPreference VARCHAR(10))
BEGIN
    DECLARE v_OwnTxn BOOLEAN DEFAULT (NOT fn_InCallerTransaction());
    DECLARE v_Role   VARCHAR(30);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        IF v_OwnTxn THEN ROLLBACK; ELSE ROLLBACK TO SAVEPOINT sp_profile; END IF;
        RESIGNAL;
    END;

    IF v_OwnTxn THEN START TRANSACTION; ELSE SAVEPOINT sp_profile; END IF;

    CALL sp_ResolveActor(p_ActorUserID, v_Role);

    IF NULLIF(TRIM(p_FirstName), '') IS NULL AND p_FirstName IS NOT NULL
       OR NULLIF(TRIM(p_LastName), '') IS NULL AND p_LastName IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Names cannot be blank';
    END IF;

    UPDATE UserAccount
       SET FirstName = COALESCE(TRIM(p_FirstName), FirstName),
           LastName  = COALESCE(TRIM(p_LastName),  LastName)
     WHERE UserID = p_ActorUserID;

    IF v_Role = 'Customer' THEN
        UPDATE Customer
           SET Phone             = COALESCE(p_Phone, Phone),
               ContactPreference = COALESCE(p_ContactPreference, ContactPreference)
         WHERE UserID = p_ActorUserID;
    ELSEIF v_Role = 'Staff' THEN
        IF p_ContactPreference IS NOT NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Contact preference applies to customers only';
        END IF;
        UPDATE Staff SET Phone = COALESCE(p_Phone, Phone) WHERE UserID = p_ActorUserID;
    ELSEIF p_Phone IS NOT NULL OR p_ContactPreference IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Administrators have no phone or contact profile';
    END IF;

    IF v_OwnTxn THEN COMMIT; ELSE RELEASE SAVEPOINT sp_profile; END IF;
END$$

DELIMITER ;