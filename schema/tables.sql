DROP SCHEMA IF EXISTS hair_fix_salon;
CREATE SCHEMA hair_fix_salon
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_0900_ai_ci;
USE hair_fix_salon;

CREATE TABLE Role (
    RoleID       TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
    RoleName     VARCHAR(30)      NOT NULL,
    Description  VARCHAR(255)     NULL,
    PRIMARY KEY (RoleID)
) ENGINE = InnoDB;
 
CREATE TABLE Location (
    LocationID    SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    SalonName     VARCHAR(100)      NOT NULL,
    AddressLine1  VARCHAR(120)      NOT NULL,
    AddressLine2  VARCHAR(120)      NULL,
    City          VARCHAR(60)       NOT NULL,
    StateCode     CHAR(2)           NOT NULL,
    PostalCode    VARCHAR(10)       NOT NULL,
    Phone         VARCHAR(25)       NOT NULL,
    TimeZone      VARCHAR(64)       NOT NULL,
    ActiveFlag    BOOLEAN           NOT NULL DEFAULT TRUE,
    PRIMARY KEY (LocationID)
) ENGINE = InnoDB;
 
CREATE TABLE AppointmentStatus (
    StatusID    TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
    StatusName  VARCHAR(30)      NOT NULL,
    IsFinal     BOOLEAN          NOT NULL DEFAULT FALSE,
    SortOrder   TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (StatusID)
) ENGINE = InnoDB;
 
CREATE TABLE PaymentMethod (
    PaymentMethodID  SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    MethodName       VARCHAR(40)       NOT NULL,
    ActiveFlag       BOOLEAN           NOT NULL DEFAULT TRUE,
    PRIMARY KEY (PaymentMethodID)
) ENGINE = InnoDB;
 
-- ---------------------------------------------------------------------
-- Accounts and profiles
-- ---------------------------------------------------------------------
 
CREATE TABLE UserAccount (
    UserID         BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
    Email          VARCHAR(254)     NOT NULL,
    PasswordHash   VARCHAR(255)     NOT NULL,
    FirstName      VARCHAR(60)      NOT NULL,
    LastName       VARCHAR(60)      NOT NULL,
    RoleID         TINYINT UNSIGNED NOT NULL,
    AccountStatus  VARCHAR(12)      NOT NULL,
    CreatedAt      DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    LastUpdatedAt  DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (UserID)
) ENGINE = InnoDB;
 
CREATE TABLE Customer (
    CustomerID         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    UserID             BIGINT UNSIGNED NOT NULL,
    Phone              VARCHAR(25)     NOT NULL,
    ContactPreference  VARCHAR(10)     NOT NULL,
    ProfileStatus      VARCHAR(12)     NOT NULL,
    PRIMARY KEY (CustomerID)
) ENGINE = InnoDB;
 
CREATE TABLE Staff (
    StaffID     BIGINT UNSIGNED   NOT NULL AUTO_INCREMENT,
    UserID      BIGINT UNSIGNED   NOT NULL,
    Phone       VARCHAR(25)       NOT NULL,
    Specialty   VARCHAR(100)      NULL,
    ActiveFlag  BOOLEAN           NOT NULL DEFAULT TRUE,
    HireDate    DATE              NOT NULL,
    LocationID  SMALLINT UNSIGNED NOT NULL,
    PRIMARY KEY (StaffID)
) ENGINE = InnoDB;
 
-- ---------------------------------------------------------------------
-- Services, qualifications, schedules
-- ---------------------------------------------------------------------
 
CREATE TABLE Service (
    ServiceID        INT UNSIGNED      NOT NULL AUTO_INCREMENT,
    ServiceName      VARCHAR(100)      NOT NULL,
    Description      VARCHAR(500)      NULL,
    CurrentPrice     DECIMAL(10,2)     NOT NULL,
    DurationMinutes  SMALLINT UNSIGNED NOT NULL,
    ActiveFlag       BOOLEAN           NOT NULL DEFAULT TRUE,
    PRIMARY KEY (ServiceID)
) ENGINE = InnoDB;
 
-- Junction table: composite primary key
CREATE TABLE StaffService (
    StaffID     BIGINT UNSIGNED NOT NULL,
    ServiceID   INT UNSIGNED    NOT NULL,
    IsActive    BOOLEAN         NOT NULL DEFAULT TRUE,
    AssignedAt  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (StaffID, ServiceID)
) ENGINE = InnoDB;
 
CREATE TABLE StaffSchedule (
    ScheduleID          BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
    StaffID             BIGINT UNSIGNED  NOT NULL,
    ScheduleType        VARCHAR(30)      NOT NULL,
    DayOfWeek           TINYINT UNSIGNED NULL,
    ScheduleDate        DATE             NULL,
    StartTime           TIME             NOT NULL,
    EndTime             TIME             NOT NULL,
    EffectiveStartDate  DATE             NULL,
    EffectiveEndDate    DATE             NULL,
    Reason              VARCHAR(255)     NULL,
    CreatedAt           DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (ScheduleID)
) ENGINE = InnoDB;
 
-- ---------------------------------------------------------------------
-- Appointments and status workflow
-- ---------------------------------------------------------------------
 
-- Junction table: composite primary key (self-referencing on AppointmentStatus)
CREATE TABLE AppointmentStatusTransition (
    FromStatusID          TINYINT UNSIGNED NOT NULL,
    ToStatusID            TINYINT UNSIGNED NOT NULL,
    CustomerAllowed       BOOLEAN          NOT NULL DEFAULT FALSE,
    StaffAllowed          BOOLEAN          NOT NULL DEFAULT FALSE,
    AdministratorAllowed  BOOLEAN          NOT NULL DEFAULT TRUE,
    RequiresReason        BOOLEAN          NOT NULL DEFAULT FALSE,
    PRIMARY KEY (FromStatusID, ToStatusID)
) ENGINE = InnoDB;
 
CREATE TABLE Appointment (
    AppointmentID          BIGINT UNSIGNED   NOT NULL AUTO_INCREMENT,
    CustomerID             BIGINT UNSIGNED   NOT NULL,
    StaffID                BIGINT UNSIGNED   NOT NULL,
    ServiceID              INT UNSIGNED      NOT NULL,
    LocationID             SMALLINT UNSIGNED NOT NULL,
    StartDateTime          DATETIME          NOT NULL,
    EndDateTime            DATETIME          NOT NULL,
    BookedPrice            DECIMAL(10,2)     NOT NULL,
    BookedDurationMinutes  SMALLINT UNSIGNED NOT NULL,
    StatusID               TINYINT UNSIGNED  NOT NULL,
    CreatedAt              DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt              DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP
                                             ON UPDATE CURRENT_TIMESTAMP,
    CancelledAt            DATETIME          NULL,
    Notes                  VARCHAR(500)      NULL,
    PRIMARY KEY (AppointmentID)
) ENGINE = InnoDB;
 
CREATE TABLE AppointmentHistory (
    HistoryID              BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
    AppointmentID          BIGINT UNSIGNED  NOT NULL,
    EventType              VARCHAR(30)      NOT NULL,
    ChangedByUserID        BIGINT UNSIGNED  NOT NULL,
    ChangedAt              DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PreviousStatusID       TINYINT UNSIGNED NULL,
    NewStatusID            TINYINT UNSIGNED NULL,
    PreviousStartDateTime  DATETIME         NULL,
    NewStartDateTime       DATETIME         NULL,
    PreviousEndDateTime    DATETIME         NULL,
    NewEndDateTime         DATETIME         NULL,
    PreviousStaffID        BIGINT UNSIGNED  NULL,
    NewStaffID             BIGINT UNSIGNED  NULL,
    PreviousServiceID      INT UNSIGNED     NULL,
    NewServiceID           INT UNSIGNED     NULL,
    Reason                 VARCHAR(500)     NULL,
    RequestID              CHAR(36)         NOT NULL,
    PRIMARY KEY (HistoryID)
) ENGINE = InnoDB;
 
-- ---------------------------------------------------------------------
-- Payments
-- ---------------------------------------------------------------------
 
CREATE TABLE PaymentTransaction (
    TransactionID      BIGINT UNSIGNED   NOT NULL AUTO_INCREMENT,
    AppointmentID      BIGINT UNSIGNED   NOT NULL,
    Amount             DECIMAL(10,2)     NOT NULL,
    TransactionType    VARCHAR(10)       NOT NULL,
    PaymentMethodID    SMALLINT UNSIGNED NOT NULL,
    PaymentStatus      VARCHAR(12)       NOT NULL,
    TransactionDate    DATETIME          NOT NULL,
    RecordedByUserID   BIGINT UNSIGNED   NOT NULL,
    CreatedAt          DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ExternalReference  VARCHAR(100)      NULL,
    PRIMARY KEY (TransactionID)
) ENGINE = InnoDB;