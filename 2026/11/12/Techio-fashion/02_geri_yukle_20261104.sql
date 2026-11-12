/* ============================================================================
   FASHION (10.10.10.200 / TechtsioMerkez)
   02 - GERI YUKLE (RESTORE)   04/11/2026'yi yedek anindaki haline dondurur.
   03_fashion_losttime_fix_20261104.sql sonrasi bir sorun olursa bu script ile geri alinir.

   Ne yapar:
     - 04/11/2026 gunune ait TUM mevcut Transections (+child) SILINIR
       (fix'in ekledigi yeni lost-time / bolunmus overlap kayitlari dahil)
     - Yedek tablolardan orijinal kayitlar aynen geri yazilir
       (computed kolonlar: Date/Hour/Time/TotalQuantity/TotalTime + TransectionHour
        otomatik hesaplandigi icin INSERT'te verilmez)

   UYARI: Bu islem 04/11'yi TAMAMEN yedek anina dondurur.

   >>> KULLANIM: @DoCommit: 0 = TEST(rollback) / 1 = UYGULA(commit)
   ============================================================================ */
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;

DECLARE @DoCommit bit = 0;          -- <<< 0 = TEST / 1 = UYGULA

IF OBJECT_ID('dbo.Transections_yedek_20261104') IS NULL
BEGIN
    RAISERROR('Yedek tablo bulunamadi (Transections_yedek_20261104). Once 01_yedek_al_20261104.sql calistirilmali.',16,1);
    RETURN;
END

DECLARE @d0 datetime = '2026-11-04', @d1 datetime = '2026-11-05';

BEGIN TRAN;

SELECT Id INTO #cur
FROM dbo.Transections
WHERE StartDate >= @d0 AND StartDate < @d1;

DECLARE @silTrans int = (SELECT COUNT(*) FROM #cur);

DELETE FROM dbo.TransectionLostTimeReason WHERE Id          IN (SELECT Id FROM #cur);
DELETE FROM dbo.TransectionItems          WHERE TransectionId IN (SELECT Id FROM #cur);
DELETE FROM dbo.Transections              WHERE Id          IN (SELECT Id FROM #cur);

INSERT INTO dbo.Transections
    (Id, DeviceId, EmployeeId, MachineId, OperationId, OrderVariantId, ProductionLineId,
     StandartTime, SerialCardId, StartDate, EndDate, IsLostTime, StartQuantity, EndQuantity,
     CreatedType, IsClosed, IsLastOperation, IsFirstOperation, ShiftId, ModelId,
     IsRepair, IsIllegal, IsInOutOperation, Multiplier, ChangedUser, ChangedDate, ChangedExp)
SELECT
     Id, DeviceId, EmployeeId, MachineId, OperationId, OrderVariantId, ProductionLineId,
     StandartTime, SerialCardId, StartDate, EndDate, IsLostTime, StartQuantity, EndQuantity,
     CreatedType, IsClosed, IsLastOperation, IsFirstOperation, ShiftId, ModelId,
     IsRepair, IsIllegal, IsInOutOperation, Multiplier, ChangedUser, ChangedDate, ChangedExp
FROM dbo.Transections_yedek_20261104;

INSERT INTO dbo.TransectionItems (Id, Quantity, TransectionId, TransectionTime, Target)
SELECT Id, Quantity, TransectionId, TransectionTime, Target
FROM dbo.TransectionItems_yedek_20261104;

INSERT INTO dbo.TransectionLostTimeReason (Id, LostTimeId)
SELECT Id, LostTimeId
FROM dbo.TransectionLostTimeReason_yedek_20261104;

SELECT 'silinen_mevcut_transection'   AS islem, @silTrans AS adet
UNION ALL SELECT 'geri_yazilan_transection',   (SELECT COUNT(*) FROM dbo.Transections_yedek_20261104)
UNION ALL SELECT 'geri_yazilan_items',         (SELECT COUNT(*) FROM dbo.TransectionItems_yedek_20261104)
UNION ALL SELECT 'geri_yazilan_losttimereason',(SELECT COUNT(*) FROM dbo.TransectionLostTimeReason_yedek_20261104);

DROP TABLE #cur;

IF @DoCommit = 1
BEGIN
    COMMIT;
    PRINT '>>> COMMIT - 04/11/2026 yedek haline geri donduruldu.';
    PRINT '    Dogruladiktan sonra yedek tablolari silebilirsin:';
    PRINT '    DROP TABLE dbo.Transections_yedek_20261104;';
    PRINT '    DROP TABLE dbo.TransectionItems_yedek_20261104;';
    PRINT '    DROP TABLE dbo.TransectionLostTimeReason_yedek_20261104;';
END
ELSE
BEGIN
    ROLLBACK;
    PRINT '>>> ROLLBACK (TEST) - hicbir sey degismedi. Uygulamak icin @DoCommit=1 yap.';
END
