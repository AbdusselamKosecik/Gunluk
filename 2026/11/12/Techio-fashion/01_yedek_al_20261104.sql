/* ============================================================================
   FASHION (10.10.10.200 / TechtsioMerkez)
   01 - YEDEK AL   (03_fashion_losttime_fix_20261104.sql calistirmadan ONCE bir kez calistir)
   04/11/2026 gunune ait Transections + child tablolar (Items, LostTimeReason)
   3 ayri yedek tabloya kopyalanir. Geri yukleme fashion_02_geri_yukle.sql ile.

   NOT: Yedek tablolar zaten varsa script DURUR (eski yedegi ezmemek icin).
   ============================================================================ */
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID('dbo.Transections_yedek_20261104') IS NOT NULL
   OR OBJECT_ID('dbo.TransectionItems_yedek_20261104') IS NOT NULL
   OR OBJECT_ID('dbo.TransectionLostTimeReason_yedek_20261104') IS NOT NULL
BEGIN
    RAISERROR('Yedek tablolar ZATEN VAR. Eskiyi silmeden yeniden yedek alinmaz. Islem durduruldu.',16,1);
    RETURN;
END

DECLARE @d0 datetime = '2026-11-04', @d1 datetime = '2026-11-05';

SELECT *
INTO dbo.Transections_yedek_20261104
FROM dbo.Transections
WHERE StartDate >= @d0 AND StartDate < @d1;

SELECT ti.*
INTO dbo.TransectionItems_yedek_20261104
FROM dbo.TransectionItems ti
WHERE ti.TransectionId IN (SELECT Id FROM dbo.Transections_yedek_20261104);

SELECT r.*
INTO dbo.TransectionLostTimeReason_yedek_20261104
FROM dbo.TransectionLostTimeReason r
WHERE r.Id IN (SELECT Id FROM dbo.Transections_yedek_20261104);

SELECT 'Transections_yedek'          AS tablo, COUNT(*) AS satir FROM dbo.Transections_yedek_20261104
UNION ALL SELECT 'TransectionItems_yedek',          COUNT(*) FROM dbo.TransectionItems_yedek_20261104
UNION ALL SELECT 'TransectionLostTimeReason_yedek', COUNT(*) FROM dbo.TransectionLostTimeReason_yedek_20261104;

PRINT '>>> Yedek alindi. Simdi 03_fashion_losttime_fix_20261104.sql calistirilabilir.';
