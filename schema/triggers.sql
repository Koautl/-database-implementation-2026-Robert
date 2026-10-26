USE hair_fix_salon;

DROP TRIGGER IF EXISTS trg_AppointmentHistory_BlockUpdate;
DROP TRIGGER IF EXISTS trg_AppointmentHistory_BlockDelete;
DROP TRIGGER IF EXISTS trg_Appointment_BlockFinalChange;

DELIMITER $$

CREATE DEFINER = 'hfs_definer'@'localhost' TRIGGER trg_AppointmentHistory_BlockUpdate
BEFORE UPDATE ON AppointmentHistory
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'AppointmentHistory is append-only; add a Correction event instead';
END$$

CREATE DEFINER = 'hfs_definer'@'localhost' TRIGGER trg_AppointmentHistory_BlockDelete
BEFORE DELETE ON AppointmentHistory
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'AppointmentHistory is append-only; rows cannot be deleted';
END$$

CREATE DEFINER = 'hfs_definer'@'localhost' TRIGGER trg_Appointment_BlockFinalChange
BEFORE UPDATE ON Appointment
FOR EACH ROW
BEGIN
    IF (SELECT IsFinal FROM AppointmentStatus WHERE StatusID = OLD.StatusID) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Appointment is in a final status (Completed, Cancelled, No-Show) and cannot be changed';
    END IF;
END$$

DELIMITER ;