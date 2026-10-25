USE hair_fix_salon;

-- UNIQUE constraints
ALTER TABLE Role
    ADD CONSTRAINT uq_Role_RoleName UNIQUE (RoleName);
 
ALTER TABLE AppointmentStatus
    ADD CONSTRAINT uq_AppointmentStatus_StatusName UNIQUE (StatusName),
    ADD CONSTRAINT uq_AppointmentStatus_SortOrder  UNIQUE (SortOrder);
 
ALTER TABLE PaymentMethod
    ADD CONSTRAINT uq_PaymentMethod_MethodName UNIQUE (MethodName);
 
ALTER TABLE Service
    ADD CONSTRAINT uq_Service_ServiceName UNIQUE (ServiceName);

-- BR-01: one account per email.
ALTER TABLE UserAccount
    ADD CONSTRAINT ux_UserAccount_Email UNIQUE (Email);

-- One-to-one: an account has at most one Customer and one Staff profile
ALTER TABLE Customer
    ADD CONSTRAINT uq_Customer_UserID UNIQUE (UserID);
 
ALTER TABLE Staff
    ADD CONSTRAINT uq_Staff_UserID UNIQUE (UserID);

-- Foreign keys 

-- Accounts and profiles (4)
ALTER TABLE UserAccount
    ADD CONSTRAINT fk_UserAccount_RoleID
        FOREIGN KEY (RoleID) REFERENCES Role (RoleID)
        ON DELETE RESTRICT ON UPDATE RESTRICT;
 
ALTER TABLE Customer
    ADD CONSTRAINT fk_Customer_UserID
        FOREIGN KEY (UserID) REFERENCES UserAccount (UserID)
        ON DELETE RESTRICT ON UPDATE RESTRICT;
 
ALTER TABLE Staff
    ADD CONSTRAINT fk_Staff_UserID
        FOREIGN KEY (UserID) REFERENCES UserAccount (UserID)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_Staff_LocationID
        FOREIGN KEY (LocationID) REFERENCES Location (LocationID)
        ON DELETE RESTRICT ON UPDATE RESTRICT;
 
-- Qualifications and schedules (3)
ALTER TABLE StaffService
    ADD CONSTRAINT fk_StaffService_StaffID
        FOREIGN KEY (StaffID) REFERENCES Staff (StaffID)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_StaffService_ServiceID
        FOREIGN KEY (ServiceID) REFERENCES Service (ServiceID)
        ON DELETE RESTRICT ON UPDATE RESTRICT;
 
ALTER TABLE StaffSchedule
    ADD CONSTRAINT fk_StaffSchedule_StaffID
        FOREIGN KEY (StaffID) REFERENCES Staff (StaffID)
        ON DELETE RESTRICT ON UPDATE RESTRICT;
 
-- Status workflow: both ends point at AppointmentStatus (2)
ALTER TABLE AppointmentStatusTransition
    ADD CONSTRAINT fk_AppointmentStatusTransition_FromStatusID
        FOREIGN KEY (FromStatusID) REFERENCES AppointmentStatus (StatusID)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_AppointmentStatusTransition_ToStatusID
        FOREIGN KEY (ToStatusID) REFERENCES AppointmentStatus (StatusID)
        ON DELETE RESTRICT ON UPDATE RESTRICT;
 
-- Appointments (5)
ALTER TABLE Appointment
    ADD CONSTRAINT fk_Appointment_CustomerID
        FOREIGN KEY (CustomerID) REFERENCES Customer (CustomerID)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_Appointment_StaffID
        FOREIGN KEY (StaffID) REFERENCES Staff (StaffID)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_Appointment_ServiceID
        FOREIGN KEY (ServiceID) REFERENCES Service (ServiceID)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_Appointment_LocationID
        FOREIGN KEY (LocationID) REFERENCES Location (LocationID)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_Appointment_StatusID
        FOREIGN KEY (StatusID) REFERENCES AppointmentStatus (StatusID)
        ON DELETE RESTRICT ON UPDATE RESTRICT;
 
-- Audit history (8). The six Previous*/New* columns are NULL-able:
-- a NULL is allowed (optional end), a non-NULL value must exist.
ALTER TABLE AppointmentHistory
    ADD CONSTRAINT fk_AppointmentHistory_AppointmentID
        FOREIGN KEY (AppointmentID) REFERENCES Appointment (AppointmentID)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_AppointmentHistory_ChangedByUserID
        FOREIGN KEY (ChangedByUserID) REFERENCES UserAccount (UserID)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_AppointmentHistory_PreviousStatusID
        FOREIGN KEY (PreviousStatusID) REFERENCES AppointmentStatus (StatusID)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_AppointmentHistory_NewStatusID
        FOREIGN KEY (NewStatusID) REFERENCES AppointmentStatus (StatusID)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_AppointmentHistory_PreviousStaffID
        FOREIGN KEY (PreviousStaffID) REFERENCES Staff (StaffID)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_AppointmentHistory_NewStaffID
        FOREIGN KEY (NewStaffID) REFERENCES Staff (StaffID)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_AppointmentHistory_PreviousServiceID
        FOREIGN KEY (PreviousServiceID) REFERENCES Service (ServiceID)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    ADD CONSTRAINT fk_AppointmentHistory_NewServiceID
        FOREIGN KEY (NewServiceID) REFERENCES Service (ServiceID)
        ON DELETE RESTRICT ON UPDATE RESTRICT;

