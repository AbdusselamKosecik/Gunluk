/* ============================================================================
   FASHION (10.10.10.200 / TechtsioMerkez)  HARICI DURUM kayip zaman duzeltmesi
   Tarih : 04/11/2026   Aralik: 12:05 - 12:20  (tek saat dilimi -> tek LT kaydi)
   Kapsam: bu aralikla kesisen personeller (EmployeeId bazinda sayac zinciri)

   KAYNAK: X:\Test\fashion_losttime_fix.sql (30/06/2026 15:00-15:15) birebir uyarlama.
   NOT: 12:05 saat-basi DEGIL; cogu personelin 12:05'i kapsayan kaydi var (Tip B).
          Qboundary = personelin 12:05'DEN ONCE baslayan son kaydinin EndQuantity'si
          Template  = ayni kayit (yeni LT kaydinin FK baglami)
   On analiz (salt okuma): kesisen 168 kisi = 86 normal (#P) + 82 overlap; aralik ici 77 kayit
   (122 adet, sagdaki kayda zincirle gecer); sablonsuz / sagsiz / coklu sag kayit: 0.

   SABLONDAN BILINCLI FARKLAR (2026-11-12):
     a) Yeni HARICI DURUM satirlarinda IsRepair=0, IsIllegal=0 (sablon onceki kayittan kopyaliyordu;
        REPORT_F_EfficiencyReport KZ10'u yalniz IsIllegal=0 sayar, 6 sablon kaydi IsIllegal=1).
     b) Yeni satirlara ChangedExp = 'HARICI DURUM 2026-11-04 12:05-12:20' izi.
     c) Bolunen (overlap) kayit KAYIP ZAMAN ise sag parca da ayni sebeple kayip zaman kalir.
     d) Butunluk kontrolu: gunun TUM kayit adet toplami degismemeli + aralikta baska kayit kalmamali
        + herkeste tam 1 HARICI; @DoCommit=1 iken kontrol bozuksa otomatik ROLLBACK.
   UYGULANDI: 2026-11-12 03:4x (168 HARICI satiri). Ayni etiket varsa script kendini durdurur.

   Her personel icin:
     1) (Tip B) 12:05'i kapsayan kayit varsa EndDate -> 12:05
     2) Aralik ici kayitlar (+child) SILINIR
     3) Sag sinir (12:20'i kapsayan) kaydin StartDate -> 12:20, StartQ -> Qboundary
     4) 1 yeni lost-time kaydi: 12:05-12:20  (StartQ=EndQ=Qboundary)
     5) TransectionLostTimeReason = HARICI DURUM

   *** OVERLAP personel(ler)i (tek kayit 12:05 VE 12:20'i birden kapsayan) ana akista
       DISARIDA tutulur, asagidaki OVERLAP bolumunde ikiye bolunur (uretim sol parcada).

   >>> KULLANIM: @DoCommit: 0 = TEST(rollback) / 1 = UYGULA(commit)
   ============================================================================ */
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;

DECLARE @DoCommit bit = 0;          -- <<< 0 = TEST / 1 = UYGULA

DECLARE @T1 datetime = '2026-11-04 12:05:00';
DECLARE @T2 datetime = '2026-11-04 12:20:00';
DECLARE @d0 datetime = '2026-11-04';
DECLARE @d1 datetime = '2026-11-05';
DECLARE @Reason uniqueidentifier = '1EF61346-BF68-4847-884B-CFA4B8F13D47'; -- HARICI DURUM (kod 10)

IF EXISTS (SELECT 1 FROM Transections WHERE ChangedExp = N'HARICI DURUM 2026-11-04 12:05-12:20')
BEGIN
    RAISERROR('Bu duzeltme ZATEN uygulanmis (etiketli kayit var). Islem durduruldu.',16,1);
    RETURN;
END

BEGIN TRAN;

-- Sayac zinciri TUM kayitlarin (tur fark etmeksizin) gunluk adet toplamini korur.
DECLARE @qOnce decimal(38,10) = (SELECT SUM(TotalQuantity) FROM Transections WHERE StartDate>=@d0 AND StartDate<@d1);

/* ---- Overlap personeller (tek kayit tum araligi kapsayan) - HARIC tutulur ---- */
SELECT DISTINCT EmployeeId
INTO #overlap
FROM Transections
WHERE StartDate < @T1 AND EndDate > @T2 AND StartDate >= @d0 AND StartDate < @d1;

/* ---- Etkilenen personeller + Qboundary + template (overlap haric) ----
        Qboundary/template = 12:05'dan ONCEKI son kayit */
SELECT
    a.EmployeeId,
    b.Qboundary,
    b.DeviceId, b.MachineId, b.OperationId, b.OrderVariantId, b.ProductionLineId,
    b.StandartTime, b.SerialCardId, b.ShiftId, b.ModelId, b.Multiplier,
    b.IsRepair, b.IsIllegal, b.IsInOutOperation, b.IsClosed
INTO #P
FROM (
    SELECT DISTINCT EmployeeId FROM Transections
    WHERE StartDate < @T2 AND EndDate > @T1 AND StartDate >= @d0 AND StartDate < @d1
      AND EmployeeId NOT IN (SELECT EmployeeId FROM #overlap)
) a
CROSS APPLY (
    SELECT TOP 1
        t.EndQuantity AS Qboundary,
        t.DeviceId, t.MachineId, t.OperationId, t.OrderVariantId, t.ProductionLineId,
        t.StandartTime, t.SerialCardId, t.ShiftId, t.ModelId, t.Multiplier,
        t.IsRepair, t.IsIllegal, t.IsInOutOperation, t.IsClosed
    FROM Transections t
    WHERE t.EmployeeId = a.EmployeeId AND t.StartDate < @T1 AND t.StartDate >= @d0
    ORDER BY t.StartDate DESC
) b;

/* ---- Silinecek aralik-ici kayitlar ---- */
SELECT Id INTO #del
FROM Transections
WHERE StartDate >= @T1 AND EndDate <= @T2 AND StartDate >= @d0 AND StartDate < @d1
  AND EmployeeId IN (SELECT EmployeeId FROM #P);

DECLARE @delItems  int = (SELECT COUNT(*) FROM TransectionItems         WHERE TransectionId IN (SELECT Id FROM #del));
DECLARE @delReason int = (SELECT COUNT(*) FROM TransectionLostTimeReason WHERE Id          IN (SELECT Id FROM #del));

DELETE FROM TransectionLostTimeReason WHERE Id          IN (SELECT Id FROM #del);
DELETE FROM TransectionItems          WHERE TransectionId IN (SELECT Id FROM #del);
DELETE FROM Transections              WHERE Id          IN (SELECT Id FROM #del);

/* ---- 1) (Tip B) 12:05'i kapsayan kayit -> EndDate=12:05 (EndQuantity degismez) ---- */
DECLARE @solKirp int;
UPDATE Transections SET EndDate = @T1
WHERE StartDate < @T1 AND EndDate > @T1 AND StartDate >= @d0 AND StartDate < @d1
  AND EmployeeId IN (SELECT EmployeeId FROM #P);
SET @solKirp = @@ROWCOUNT;

/* ---- 3) Sag sinir: StartDate=12:20, StartQ=Qboundary ---- */
DECLARE @sagKirp int;
UPDATE R2
   SET R2.StartDate     = @T2,
       R2.StartQuantity = P.Qboundary
FROM Transections R2
JOIN #P P ON P.EmployeeId = R2.EmployeeId
WHERE R2.StartDate < @T2 AND R2.EndDate > @T2 AND R2.StartDate >= @d0 AND R2.StartDate < @d1;
SET @sagKirp = @@ROWCOUNT;

/* ---- 4) Yeni lost-time (12:05-12:20), template = #P ---- */
SELECT
    NEWID() AS Id,
    P.DeviceId, P.EmployeeId, P.MachineId, P.OperationId, P.OrderVariantId, P.ProductionLineId,
    P.StandartTime, P.SerialCardId,
    @T1 AS StartDate, @T2 AS EndDate,
    CONVERT(bit,1)     AS IsLostTime,
    P.Qboundary        AS StartQuantity,
    P.Qboundary        AS EndQuantity,
    CONVERT(tinyint,2) AS CreatedType,
    P.IsClosed,
    CONVERT(bit,0)     AS IsLastOperation,
    CONVERT(bit,0)     AS IsFirstOperation,
    P.ShiftId, P.ModelId,
    CONVERT(bit,0) AS IsRepair, CONVERT(bit,0) AS IsIllegal, P.IsInOutOperation, P.Multiplier
INTO #new
FROM #P P;

INSERT INTO Transections
    (Id, DeviceId, EmployeeId, MachineId, OperationId, OrderVariantId, ProductionLineId,
     StandartTime, SerialCardId, StartDate, EndDate, IsLostTime, StartQuantity, EndQuantity,
     CreatedType, IsClosed, IsLastOperation, IsFirstOperation,
     ShiftId, ModelId, IsRepair, IsIllegal, IsInOutOperation, Multiplier, ChangedDate, ChangedExp)
SELECT
     Id, DeviceId, EmployeeId, MachineId, OperationId, OrderVariantId, ProductionLineId,
     StandartTime, SerialCardId, StartDate, EndDate, IsLostTime, StartQuantity, EndQuantity,
     CreatedType, IsClosed, IsLastOperation, IsFirstOperation,
     ShiftId, ModelId, IsRepair, IsIllegal, IsInOutOperation, Multiplier, GETDATE(), N'HARICI DURUM 2026-11-04 12:05-12:20'
FROM #new;

INSERT INTO TransectionLostTimeReason (Id, LostTimeId)
SELECT Id, @Reason FROM #new;

/* ======================= OVERLAP PERSONEL ISLEME =======================
   Tek kayit 12:05 VE 12:20'i kapsiyor -> ikiye bolunur, uretim SOL parcada
   kalir (kurala uygun: sol parca EndQuantity degismez). */
SELECT
    t.Id AS O_Id, t.EmployeeId, t.EndQuantity AS Qb, t.EndDate AS OrigEnd, t.EndQuantity AS OrigEndQ, t.CreatedType,
    t.DeviceId, t.MachineId, t.OperationId, t.OrderVariantId, t.ProductionLineId,
    t.StandartTime, t.SerialCardId, t.ShiftId, t.ModelId, t.Multiplier,
    t.IsRepair, t.IsIllegal, t.IsInOutOperation, t.IsClosed
INTO #ov
FROM #overlap o
JOIN Transections t ON t.EmployeeId=o.EmployeeId
   AND t.StartDate<@T1 AND t.EndDate>@T2 AND t.StartDate>=@d0 AND t.StartDate<@d1;

/* Sag parca (yeni normal uretim kaydi): 12:20 -> OrigEnd, StartQ=EndQ=Qb (0 adet) */
INSERT INTO Transections
    (Id, DeviceId, EmployeeId, MachineId, OperationId, OrderVariantId, ProductionLineId,
     StandartTime, SerialCardId, StartDate, EndDate, IsLostTime, StartQuantity, EndQuantity,
     CreatedType, IsClosed, IsLastOperation, IsFirstOperation,
     ShiftId, ModelId, IsRepair, IsIllegal, IsInOutOperation, Multiplier)
SELECT
     NEWID(), DeviceId, EmployeeId, MachineId, OperationId, OrderVariantId, ProductionLineId,
     StandartTime, SerialCardId, @T2, OrigEnd, CONVERT(bit,0), Qb, OrigEndQ,
     CreatedType, IsClosed, CONVERT(bit,0), CONVERT(bit,0),
     ShiftId, ModelId, IsRepair, IsIllegal, IsInOutOperation, Multiplier
FROM #ov;

/* (c) SABLONDAN FARK: bolunen kayit bir KAYIP ZAMAN ise sag parca da kayip zaman kalmali
   (sablon sag parcayi hep uretim aciyordu -> 12:20 sonrasi ariza/setup suresi uretime donuyordu).
   04/11'de 3 kayit: 2 MAKINE ARIZA, 1 SETUP. Ilk uygulamada sonradan ayri bir duzeltme ile yapildi
   (ChangedExp='HARICI 2026-11-04 sag parca KZ'); bu blok ayni isi tek seferde yapar. */
UPDATE R
   SET R.IsLostTime = 1, R.ChangedDate = GETDATE(), R.ChangedExp = N'HARICI 2026-11-04 sag parca KZ'
FROM Transections R
JOIN #ov o        ON o.EmployeeId = R.EmployeeId AND R.StartDate = @T2 AND R.EndDate = o.OrigEnd
JOIN Transections orig ON orig.Id = o.O_Id
WHERE orig.IsLostTime = 1 AND R.IsLostTime = 0 AND R.Id <> o.O_Id;

INSERT INTO TransectionLostTimeReason (Id, LostTimeId)
SELECT R.Id, rr.LostTimeId
FROM Transections R
JOIN #ov o        ON o.EmployeeId = R.EmployeeId AND R.StartDate = @T2 AND R.EndDate = o.OrigEnd
JOIN TransectionLostTimeReason rr ON rr.Id = o.O_Id
WHERE R.Id <> o.O_Id AND R.IsLostTime = 1
  AND NOT EXISTS (SELECT 1 FROM TransectionLostTimeReason x WHERE x.Id = R.Id);

/* Lost time (12:05-12:20) overlap personeller icin */
SELECT NEWID() AS Id, DeviceId, EmployeeId, MachineId, OperationId, OrderVariantId, ProductionLineId,
    StandartTime, SerialCardId, @T1 AS StartDate, @T2 AS EndDate, CONVERT(bit,1) AS IsLostTime,
    Qb AS StartQuantity, Qb AS EndQuantity, CONVERT(tinyint,2) AS CreatedType, IsClosed,
    CONVERT(bit,0) AS IsLastOperation, CONVERT(bit,0) AS IsFirstOperation,
    ShiftId, ModelId, CONVERT(bit,0) AS IsRepair, CONVERT(bit,0) AS IsIllegal, IsInOutOperation, Multiplier
INTO #ovLT FROM #ov;

INSERT INTO Transections
    (Id, DeviceId, EmployeeId, MachineId, OperationId, OrderVariantId, ProductionLineId,
     StandartTime, SerialCardId, StartDate, EndDate, IsLostTime, StartQuantity, EndQuantity,
     CreatedType, IsClosed, IsLastOperation, IsFirstOperation,
     ShiftId, ModelId, IsRepair, IsIllegal, IsInOutOperation, Multiplier, ChangedDate, ChangedExp)
SELECT
     Id, DeviceId, EmployeeId, MachineId, OperationId, OrderVariantId, ProductionLineId,
     StandartTime, SerialCardId, StartDate, EndDate, IsLostTime, StartQuantity, EndQuantity,
     CreatedType, IsClosed, IsLastOperation, IsFirstOperation,
     ShiftId, ModelId, IsRepair, IsIllegal, IsInOutOperation, Multiplier, GETDATE(), N'HARICI DURUM 2026-11-04 12:05-12:20'
FROM #ovLT;

INSERT INTO TransectionLostTimeReason (Id, LostTimeId) SELECT Id, @Reason FROM #ovLT;

/* Sol parca: orijinal overlap kaydi -> EndDate=12:05 (StartQ/EndQ degismez) */
DECLARE @ovBol int;
UPDATE Transections SET EndDate=@T1 WHERE Id IN (SELECT O_Id FROM #ov);
SET @ovBol = @@ROWCOUNT;

/* ============================ KONTROL RAPORU ============================ */
SELECT 'etkilenen_personel(overlap haric)' AS islem, (SELECT COUNT(*) FROM #P)      AS adet
UNION ALL SELECT 'overlap_bolunen_personel',          (SELECT COUNT(*) FROM #ov)
UNION ALL SELECT 'sol_kirpma(EndDate=12:05)',          @solKirp
UNION ALL SELECT 'sag_kirpma(StartDate=12:20)',        @sagKirp
UNION ALL SELECT 'overlap_bolundu',                    @ovBol
UNION ALL SELECT 'silinen_transection',                (SELECT COUNT(*) FROM #del)
UNION ALL SELECT 'silinen_items',                      @delItems
UNION ALL SELECT 'silinen_losttimereason',             @delReason
UNION ALL SELECT 'yeni_losttime(#P)',                  (SELECT COUNT(*) FROM #new)
UNION ALL SELECT 'yeni_losttime(overlap)',             (SELECT COUNT(*) FROM #ovLT);

/* ======================== BUTUNLUK KONTROLLERI ======================== */
DECLARE @qSonra decimal(38,10) = (SELECT SUM(TotalQuantity) FROM Transections WHERE StartDate>=@d0 AND StartDate<@d1);
DECLARE @aralikBaska int = (     -- etkilenenlerde 12:05-12:20 ile kesisen, yeni HARICI disinda kayit kalmamali
    SELECT COUNT(*) FROM Transections t
    WHERE t.StartDate<@T2 AND t.EndDate>@T1 AND t.StartDate>=@d0 AND t.StartDate<@d1
      AND (t.EmployeeId IN (SELECT EmployeeId FROM #P) OR t.EmployeeId IN (SELECT EmployeeId FROM #ov))
      AND t.Id NOT IN (SELECT Id FROM #new UNION ALL SELECT Id FROM #ovLT));
DECLARE @hariciEksik int = (     -- her etkilenen kiside tam 1 yeni HARICI olmali
    SELECT COUNT(*) FROM (SELECT EmployeeId FROM #P UNION SELECT EmployeeId FROM #ov) k
    WHERE (SELECT COUNT(*) FROM #new n WHERE n.EmployeeId=k.EmployeeId)
        + (SELECT COUNT(*) FROM #ovLT o WHERE o.EmployeeId=k.EmployeeId) <> 1);

SELECT 'gun_toplam_adet_once'  AS kontrol, CONVERT(decimal(38,2),@qOnce)  AS deger
UNION ALL SELECT 'gun_toplam_adet_sonra',  CONVERT(decimal(38,2),@qSonra)
UNION ALL SELECT 'aralikta_kalan_baska_kayit(0 olmali)', @aralikBaska
UNION ALL SELECT 'harici_sayisi_1_olmayan_kisi(0 olmali)', @hariciEksik;

PRINT '--- ORNEK: normal (#P) personel, 11:50-12:35 ---';
SELECT StartDate, EndDate, StartQuantity, EndQuantity, TotalQuantity, IsLostTime, IsIllegal, ChangedExp
FROM Transections
WHERE EmployeeId=(SELECT TOP 1 EmployeeId FROM #P ORDER BY EmployeeId)
  AND StartDate>='2026-11-04 11:50:00' AND StartDate<'2026-11-04 12:35:00'
ORDER BY StartDate;

PRINT '--- ORNEK: OVERLAP (bolunen) personel, 11:50-12:35 ---';
SELECT StartDate, EndDate, StartQuantity, EndQuantity, TotalQuantity, IsLostTime, IsIllegal, ChangedExp
FROM Transections
WHERE EmployeeId=(SELECT TOP 1 EmployeeId FROM #ov ORDER BY EmployeeId)
  AND StartDate>='2026-11-04 11:30:00' AND StartDate<'2026-11-04 12:35:00'
ORDER BY StartDate;

DECLARE @kontrolOk bit = CASE WHEN @aralikBaska=0 AND @hariciEksik=0 AND @qOnce=@qSonra THEN 1 ELSE 0 END;

DROP TABLE #overlap; DROP TABLE #P; DROP TABLE #del; DROP TABLE #new; DROP TABLE #ov; DROP TABLE #ovLT;

IF @DoCommit = 1 AND @kontrolOk = 0
BEGIN
    ROLLBACK;
    RAISERROR('Butunluk kontrolu basarisiz - ROLLBACK edildi, hicbir sey degismedi.',16,1);
    RETURN;
END

IF @DoCommit = 1
BEGIN
    COMMIT;
    PRINT '>>> COMMIT edildi - degisiklikler KALICI.';
END
ELSE
BEGIN
    ROLLBACK;
    PRINT '>>> ROLLBACK (TEST) - hicbir sey degismedi. Uygulamak icin @DoCommit=1 yap.';
END
