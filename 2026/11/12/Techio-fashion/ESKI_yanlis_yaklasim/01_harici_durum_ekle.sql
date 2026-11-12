/*
  FASHION (10.10.10.200 / TechtsioMerkez)
  04.11.2026 12:05-12:20 arasi herkese 15 dk HARICI DURUM (LostTimes.Code='10')

  Kimlere: o gun cihaz kaydi olan ve 12:05-12:20 araliginda iste olan personel
           (ilk kaydi < 12:05 VE son kaydi > 12:20). Hesaplanan: 165 kisi.
  Nasil:   Her kisiye 1 Transections satiri (IsLostTime=1) + 1 TransectionLostTimeReason satiri.
           Cihaz/makine/bant/vardiya/operasyon/siparis alanlari, kisinin 12:05'te (veya hemen oncesinde)
           acik olan kaydindan kopyalanir. Adet 0. CreatedType=4 (UI'daki elle kayip zaman girisi ile ayni).
  Iz:      ChangedExp = 'TOPLU HARICI DURUM 2026-11-04 12:05-12:20'  -> geri alma bununla yapilir.
  Tekrar:  Etiketli kayit varsa ikinci kez eklemez.
*/
USE [TechtsioMerkez];
SET XACT_ABORT ON;
SET NOCOUNT ON;

DECLARE @Bas      datetime         = '2026-11-04 12:05:00';
DECLARE @Bit      datetime         = '2026-11-04 12:20:00';
DECLARE @Gun      date             = '2026-11-04';
DECLARE @Harici   uniqueidentifier = (SELECT Id FROM LostTimes WHERE Code = '10' AND IsDeleted = 0);
DECLARE @Etiket   nvarchar(100)    = N'TOPLU HARICI DURUM 2026-11-04 12:05-12:20';

IF @Harici IS NULL
BEGIN RAISERROR(N'HARICI DURUM (Code=10) bulunamadi', 16, 1); RETURN; END

IF EXISTS (SELECT 1 FROM Transections WHERE ChangedExp = @Etiket)
BEGIN RAISERROR(N'Bu toplu kayit zaten eklenmis, tekrar eklenmedi', 16, 1); RETURN; END

BEGIN TRAN;

DECLARE @Yeni TABLE (Id uniqueidentifier PRIMARY KEY);

;WITH Kisi AS (
    SELECT t.EmployeeId
    FROM Transections t
    JOIN Devices  d  ON d.Id  = t.DeviceId
    JOIN Employee em ON em.Id = t.EmployeeId
    WHERE t.Date = @Gun AND d.DeviceType <> 4 AND LEN(em.Code) > 3
    GROUP BY t.EmployeeId
    HAVING MIN(t.StartDate) < @Bas AND MAX(ISNULL(t.EndDate, t.StartDate)) > @Bit
),
Kaynak AS (   -- kisinin 12:05'te acik olan (yoksa hemen onceki) kaydi
    SELECT k.EmployeeId, s.*
    FROM Kisi k
    CROSS APPLY (
        SELECT TOP 1 t.DeviceId, t.MachineId, t.OperationId, t.OrderVariantId, t.ProductionLineId,
                     t.StandartTime, t.SerialCardId, t.ShiftId, t.ModelId
        FROM Transections t
        JOIN Devices d ON d.Id = t.DeviceId
        WHERE t.EmployeeId = k.EmployeeId AND t.Date = @Gun AND d.DeviceType <> 4 AND t.StartDate <= @Bas
        ORDER BY t.StartDate DESC
    ) s
)
INSERT INTO Transections
    (Id, DeviceId, EmployeeId, MachineId, OperationId, OrderVariantId, ProductionLineId, StandartTime,
     SerialCardId, StartDate, EndDate, IsLostTime, StartQuantity, EndQuantity, CreatedType, IsClosed,
     IsLastOperation, IsFirstOperation, ShiftId, ModelId, IsRepair, IsIllegal, IsInOutOperation,
     Multiplier, ChangedDate, ChangedExp)
OUTPUT inserted.Id INTO @Yeni
SELECT NEWID(), DeviceId, EmployeeId, MachineId, OperationId, OrderVariantId, ProductionLineId, StandartTime,
       SerialCardId, @Bas, @Bit, 1, 0, 0, 4, 1,
       0, 0, ShiftId, ModelId, 0, 0, 0,
       1, GETDATE(), @Etiket
FROM Kaynak;

INSERT INTO TransectionLostTimeReason (Id, LostTimeId)
SELECT Id, @Harici FROM @Yeni;

DECLARE @n int = (SELECT COUNT(*) FROM @Yeni);
PRINT CONCAT(N'Eklenen harici durum satiri: ', @n);

IF @n NOT BETWEEN 150 AND 180
BEGIN
    ROLLBACK;
    RAISERROR(N'Beklenmeyen kayit sayisi (%d), geri alindi', 16, 1, @n);
    RETURN;
END

COMMIT;
PRINT N'Tamam.';
