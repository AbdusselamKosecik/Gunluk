/* 01_harici_durum_ekle.sql ile eklenen kayitlari geri alir. */
USE [TechtsioMerkez];
SET XACT_ABORT ON;
DECLARE @Etiket nvarchar(100) = N'TOPLU HARICI DURUM 2026-11-04 12:05-12:20';

BEGIN TRAN;
DELETE r FROM TransectionLostTimeReason r JOIN Transections t ON t.Id = r.Id WHERE t.ChangedExp = @Etiket;
DELETE FROM Transections WHERE ChangedExp = @Etiket AND CreatedType = 4 AND IsLostTime = 1;
PRINT CONCAT(N'Silinen: ', @@ROWCOUNT);
COMMIT;
