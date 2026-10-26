USE hair_fix_salon;

CREATE ROLE IF NOT EXISTS hair_fix_customer, hair_fix_staff, hair_fix_administrator;

REVOKE ALL PRIVILEGES, GRANT OPTION FROM hair_fix_customer;
REVOKE ALL PRIVILEGES, GRANT OPTION FROM hair_fix_staff;
REVOKE ALL PRIVILEGES, GRANT OPTION FROM hair_fix_administrator;

GRANT SELECT (ServiceID, ServiceName, Description, CurrentPrice, DurationMinutes, ActiveFlag)
      ON hair_fix_salon.Service TO hair_fix_customer;
GRANT EXECUTE ON PROCEDURE hair_fix_salon.sp_GetAvailableSlots     TO hair_fix_customer;
GRANT EXECUTE ON PROCEDURE hair_fix_salon.sp_BookAppointment       TO hair_fix_customer;
GRANT EXECUTE ON PROCEDURE hair_fix_salon.sp_RescheduleAppointment TO hair_fix_customer;
GRANT EXECUTE ON PROCEDURE hair_fix_salon.sp_CancelAppointment     TO hair_fix_customer;
GRANT EXECUTE ON PROCEDURE hair_fix_salon.sp_GetMyAppointments     TO hair_fix_customer;
GRANT EXECUTE ON PROCEDURE hair_fix_salon.sp_GetAppointmentTrail   TO hair_fix_customer;
GRANT EXECUTE ON PROCEDURE hair_fix_salon.sp_UpdateMyProfile       TO hair_fix_customer;

GRANT SELECT (ServiceID, ServiceName, Description, CurrentPrice, DurationMinutes, ActiveFlag)
      ON hair_fix_salon.Service TO hair_fix_staff;
GRANT EXECUTE ON PROCEDURE hair_fix_salon.sp_GetAvailableSlots       TO hair_fix_staff;
GRANT EXECUTE ON PROCEDURE hair_fix_salon.sp_RescheduleAppointment   TO hair_fix_staff;
GRANT EXECUTE ON PROCEDURE hair_fix_salon.sp_CancelAppointment       TO hair_fix_staff;
GRANT EXECUTE ON PROCEDURE hair_fix_salon.sp_ChangeAppointmentStatus TO hair_fix_staff;
GRANT EXECUTE ON PROCEDURE hair_fix_salon.sp_RecordPayment           TO hair_fix_staff;
GRANT EXECUTE ON PROCEDURE hair_fix_salon.sp_GetMyAppointments       TO hair_fix_staff;
GRANT EXECUTE ON PROCEDURE hair_fix_salon.sp_GetAppointmentTrail     TO hair_fix_staff;
GRANT EXECUTE ON PROCEDURE hair_fix_salon.sp_GetStaffSchedule        TO hair_fix_staff;
GRANT EXECUTE ON PROCEDURE hair_fix_salon.sp_UpdateMyProfile         TO hair_fix_staff;

GRANT EXECUTE ON PROCEDURE hair_fix_salon.sp_GetAvailableSlots       TO hair_fix_administrator;
GRANT EXECUTE ON PROCEDURE hair_fix_salon.sp_BookAppointment         TO hair_fix_administrator;
GRANT EXECUTE ON PROCEDURE hair_fix_salon.sp_RescheduleAppointment   TO hair_fix_administrator;
GRANT EXECUTE ON PROCEDURE hair_fix_salon.sp_CancelAppointment       TO hair_fix_administrator;
GRANT EXECUTE ON PROCEDURE hair_fix_salon.sp_ChangeAppointmentStatus TO hair_fix_administrator;
GRANT EXECUTE ON PROCEDURE hair_fix_salon.sp_SaveStaffSchedule       TO hair_fix_administrator;
GRANT EXECUTE ON PROCEDURE hair_fix_salon.sp_RecordPayment           TO hair_fix_administrator;
GRANT EXECUTE ON PROCEDURE hair_fix_salon.sp_GetMyAppointments       TO hair_fix_administrator;
GRANT EXECUTE ON PROCEDURE hair_fix_salon.sp_GetAppointmentTrail     TO hair_fix_administrator;
GRANT EXECUTE ON PROCEDURE hair_fix_salon.sp_GetStaffSchedule        TO hair_fix_administrator;
GRANT EXECUTE ON PROCEDURE hair_fix_salon.sp_UpdateMyProfile         TO hair_fix_administrator;

GRANT SELECT ON hair_fix_salon.Role                        TO hair_fix_administrator;
GRANT SELECT ON hair_fix_salon.Location                    TO hair_fix_administrator;
GRANT SELECT ON hair_fix_salon.AppointmentStatus           TO hair_fix_administrator;
GRANT SELECT ON hair_fix_salon.AppointmentStatusTransition TO hair_fix_administrator;
GRANT SELECT ON hair_fix_salon.PaymentMethod               TO hair_fix_administrator;
GRANT SELECT (UserID, Email, FirstName, LastName, RoleID, AccountStatus, CreatedAt, LastUpdatedAt)
             ON hair_fix_salon.UserAccount                 TO hair_fix_administrator;
GRANT SELECT ON hair_fix_salon.Customer                    TO hair_fix_administrator;
GRANT SELECT ON hair_fix_salon.Staff                       TO hair_fix_administrator;
GRANT SELECT ON hair_fix_salon.Service                     TO hair_fix_administrator;
GRANT SELECT ON hair_fix_salon.StaffService                TO hair_fix_administrator;
GRANT SELECT ON hair_fix_salon.StaffSchedule               TO hair_fix_administrator;
GRANT SELECT ON hair_fix_salon.Appointment                 TO hair_fix_administrator;
GRANT SELECT ON hair_fix_salon.AppointmentHistory          TO hair_fix_administrator;
GRANT SELECT ON hair_fix_salon.PaymentTransaction          TO hair_fix_administrator;
GRANT SELECT ON hair_fix_salon.vw_AppointmentDetails         TO hair_fix_administrator;
GRANT SELECT ON hair_fix_salon.vw_DailySchedule              TO hair_fix_administrator;
GRANT SELECT ON hair_fix_salon.vw_CustomerAppointmentHistory TO hair_fix_administrator;
GRANT SELECT ON hair_fix_salon.vw_MonthlyRevenue             TO hair_fix_administrator;
GRANT SELECT ON hair_fix_salon.vw_PopularServices            TO hair_fix_administrator;
GRANT SELECT ON hair_fix_salon.vw_StaffWorkload              TO hair_fix_administrator;
GRANT SELECT ON hair_fix_salon.vw_CancellationNoShow         TO hair_fix_administrator;

GRANT INSERT ON hair_fix_salon.UserAccount TO hair_fix_administrator;
GRANT UPDATE (Email, PasswordHash, FirstName, LastName, RoleID, AccountStatus)
             ON hair_fix_salon.UserAccount TO hair_fix_administrator;
GRANT INSERT, UPDATE ON hair_fix_salon.Customer     TO hair_fix_administrator;
GRANT INSERT, UPDATE ON hair_fix_salon.Staff        TO hair_fix_administrator;
GRANT INSERT, UPDATE ON hair_fix_salon.Service      TO hair_fix_administrator;
GRANT INSERT, UPDATE ON hair_fix_salon.StaffService TO hair_fix_administrator;
GRANT UPDATE         ON hair_fix_salon.Location     TO hair_fix_administrator;

SHOW GRANTS FOR hair_fix_customer;
SHOW GRANTS FOR hair_fix_staff;
SHOW GRANTS FOR hair_fix_administrator;
SHOW GRANTS FOR 'hfs_definer'@'localhost';

SELECT ROUTINE_TYPE, ROUTINE_NAME, DEFINER, SECURITY_TYPE
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = 'hair_fix_salon'
ORDER BY ROUTINE_TYPE, ROUTINE_NAME;

SELECT CONCAT(User, '@', Host) AS Account, account_locked
FROM mysql.user
WHERE User = 'hfs_definer';

SELECT GRANTEE, TABLE_NAME, PRIVILEGE_TYPE
FROM information_schema.TABLE_PRIVILEGES
WHERE TABLE_SCHEMA = 'hair_fix_salon'
  AND GRANTEE LIKE '%hair_fix_%'
  AND TABLE_NAME IN ('Appointment', 'AppointmentHistory', 'PaymentTransaction', 'StaffSchedule')
  AND PRIVILEGE_TYPE IN ('INSERT', 'UPDATE', 'DELETE');

SELECT GRANTEE, TABLE_NAME, COLUMN_NAME, PRIVILEGE_TYPE
FROM information_schema.COLUMN_PRIVILEGES
WHERE TABLE_SCHEMA = 'hair_fix_salon' AND COLUMN_NAME = 'PasswordHash' AND PRIVILEGE_TYPE = 'SELECT'
UNION ALL
SELECT GRANTEE, TABLE_NAME, '(all columns)', PRIVILEGE_TYPE
FROM information_schema.TABLE_PRIVILEGES
WHERE TABLE_SCHEMA = 'hair_fix_salon' AND TABLE_NAME = 'UserAccount' AND PRIVILEGE_TYPE = 'SELECT'
  AND GRANTEE LIKE '%hair_fix_%';

SELECT GRANTEE, TABLE_SCHEMA, PRIVILEGE_TYPE
FROM information_schema.SCHEMA_PRIVILEGES
WHERE GRANTEE LIKE '%hair_fix_%'
UNION ALL
SELECT GRANTEE, '(global)', PRIVILEGE_TYPE
FROM information_schema.USER_PRIVILEGES
WHERE GRANTEE LIKE '%hair_fix_%' AND PRIVILEGE_TYPE <> 'USAGE';

SELECT User AS RoleName, Routine_name, Proc_priv
FROM mysql.procs_priv
WHERE Db = 'hair_fix_salon' AND User LIKE 'hair_fix_%'
ORDER BY User, Routine_name;