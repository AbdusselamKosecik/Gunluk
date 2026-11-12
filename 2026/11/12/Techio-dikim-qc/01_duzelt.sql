-- Dikim (172.16.1.2 / TechtsioMerkez) QC ciftleme duzeltmesi 2026-11-12
-- 1) Eski SP'lerin yedegi: <ad>_yedek_20261112   2) ALTER (kolonlar ayni)
USE [TechtsioMerkez];
GO
SET XACT_ABORT ON;
BEGIN TRAN;
GO
IF OBJECT_ID(N'dbo.REPORT_F_QualityControlQuantityList_yedek_20261112', N'P') IS NULL
EXEC(N'/****** Object:  StoredProcedure [dbo].[REPORT_GunlukVerimlilik]    Script Date: 17.08.2020 03:35:50 ******/
 
-- =============================================
-- Author:		Abdusselam
-- Create date: 04.07.2020
-- Description:
-- =============================================
CREATE PROCEDURE [dbo].[REPORT_F_QualityControlQuantityList_yedek_20261112]
-- Add the parameters for the stored procedure here
@StartDate DATE,
@EndDate DATE

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	declare @table Table (
	EmployeeId uniqueidentifier
	   ,OperationId uniqueidentifier
	   ,ProductionLineId uniqueidentifier
	   ,MachineId uniqueidentifier
	   ,OrderVariantId uniqueidentifier
	   ,DeviceId uniqueidentifier
	   ,SerialCardId uniqueidentifier
	   ,ModelId  uniqueidentifier
	   , [Date] Date
	    , [Hour] int
	    ,  StartDate datetime
	    ,  EndDate   datetime
 	   ,ReelTotalQ  decimal(18,10)
	   )
	   Insert @table   (EmployeeId  
	   ,OperationId  
	   ,ProductionLineId  
	   ,MachineId  
	   ,OrderVariantId  
	   ,DeviceId  
	   ,SerialCardId  
	   ,ModelId   
	   , [Date]  
	    , [Hour]  
	    ,  StartDate  
	    ,  EndDate    
 	   ,ReelTotalQ   
	   )
	   Select *   FROM [dbo].[FC_New_Transection_OnlyQuantity_View](DateAdd(month,-2,@StartDate),@EndDate)
	   

Select  

o.Code as OrderNo
,m.Code as ModelNo
,m.Name as ModelName
,e1.Code as ControlEmployeeCode
,e1.Name as  ControlEmployeeName
,e2.Code as EmployeeCode
,e2.Name as EmployeeName
,left(o1.Code,4) as OperationMain
,o1.Code as OperationCode
,o1.Name as OperationName
,left(o2.Code,4) as RepairOperationMain
,o2.Code as RepairOperationCode
,o2.Name as RepairOperationName
,q.Code as ErrorCode
,q.Name as ErrorName
,Convert(bigint,SUM(p.Quantity)) As Quantity
,Convert(bigint,IsNULL((Select SUM(ReelTotalQ) from @table where EmployeeId=e2.Id and OperationId=o2.Id and OrderVariantId in 
(select v9.Id from
OrderItemVariants v9 
left join OrderItems oi9 on oi9.Id=v9.OrderItemId
left join Orders o9 on oi9.OrderId=o9.Id
where o9.Code= o.Code 
)
),0))  as CalculatorQuantity
from 
OrderItemVariantProduction p
Left join Operations o1 on p.OperationId=o1.Id
Left join Operations o2 on p.RepairOperationId=o2.Id
left join Employee e1 on p.EmployeeId=e1.Id
left join Employee e2 on p.RepairEmployeeId=e2.Id
left join QualityControlErrorCards q on p.QualityTypeId=q.Id
left join OrderItemVariants v on p.OrderItemVariantId=v.Id
left join SizeCards s on v.SizeId=s.Id
left join ColorCards c on v.ColorId=c.Id
left join OrderItems oi on v.OrderItemId=oi.Id
left join Models m on  oi.ModelId=m.Id
left join Orders o on oi.OrderId=o.Id

where p.QualityType>1 and p.Date>=@StartDate and p.Date<=@EndDate
Group by o.Code,m.Code,m.Name,e1.Code,e1.Name,e2.Code,e2.Name, o1.Code,o1.Name
, o2.Code,o2.Name
,q.Code,q.Name,e2.Id,o2.Id,p.OrderItemVariantId
 





	  --  Select * from @table
 
	
	 
	 
	 
 
END');
GO
IF OBJECT_ID(N'dbo.REPORT_F_QualityControlQuantityListR2_yedek_20261112', N'P') IS NULL
EXEC(N'-- =============================================
-- Author:		Abdusselam
-- Create date: 04.07.2020
-- Description: CalculatorQuantity çoklama düzeltildi
-- =============================================
CREATE PROCEDURE [dbo].[REPORT_F_QualityControlQuantityListR2_yedek_20261112]
@StartDate DATE,
@EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    declare @table Table (
        EmployeeId uniqueidentifier, OperationId uniqueidentifier, ProductionLineId uniqueidentifier,
        MachineId uniqueidentifier, OrderVariantId uniqueidentifier, DeviceId uniqueidentifier,
        SerialCardId uniqueidentifier, ModelId uniqueidentifier, [Date] Date, [Hour] int,
        StartDate datetime, EndDate datetime, ReelTotalQ decimal(18,10)
    )
    Insert @table (EmployeeId, OperationId, ProductionLineId, MachineId, OrderVariantId, DeviceId,
                   SerialCardId, ModelId, [Date], [Hour], StartDate, EndDate, ReelTotalQ)
    Select * FROM [dbo].[FC_New_Transection_OnlyQuantity_View](DateAdd(month,-2,@StartDate),@EndDate);

    ;WITH Rep AS (   -- (Sipariş, Çalışan, Operasyon, Hata) başına tek satır
        Select
            o.Code   as OrderNo,
            e2.Id    as EmployeeId,
            e2.Code  as EmployeeCode,
            e2.Name  as EmployeeName,
            o2.Id    as OperationId,
            o2.Code  as RepairOperationCode,
            o2.Name  as RepairOperationName,
            q.Code   as ErrorCode,
            q.Name   as ErrorName,
            SUM(p.Quantity) as Quantity
        from OrderItemVariantProduction p
        left join Operations o2       on p.RepairOperationId = o2.Id
        left join Employee e2         on p.RepairEmployeeId  = e2.Id
        left join QualityControlErrorCards q on p.QualityTypeId = q.Id
        left join OrderItemVariants v on p.OrderItemVariantId = v.Id
        left join OrderItems oi       on v.OrderItemId = oi.Id
        left join Orders o            on oi.OrderId = o.Id
        where p.QualityType > 1 and p.Date >= @StartDate and p.Date <= @EndDate
        group by o.Code, e2.Id, e2.Code, e2.Name, o2.Id, o2.Code, o2.Name, q.Code, q.Name
    ),
    Calc AS (        -- (Sipariş, Çalışan, Operasyon) başına bir kez
        Select
            o9.Code as OrderNo,
            t.EmployeeId,
            t.OperationId,
            SUM(t.ReelTotalQ) as CalculatorQuantity
        from @table t
        join OrderItemVariants v9 on v9.Id = t.OrderVariantId
        join OrderItems oi9       on oi9.Id = v9.OrderItemId
        join Orders o9            on o9.Id = oi9.OrderId
        group by o9.Code, t.EmployeeId, t.OperationId
    )
    Select
        r.EmployeeCode,
        r.EmployeeName,
        left(r.RepairOperationCode,4) as RepairOperationMain,
        r.RepairOperationCode,
        r.RepairOperationName,
        r.ErrorCode,
        r.ErrorName,
        CONVERT(bigint, SUM(r.Quantity)) as Quantity,
        CONVERT(bigint, SUM(ISNULL(c.CalculatorQuantity,0))) as CalculatorQuantity,
      ROUND(  Case when SUM(ISNULL(c.CalculatorQuantity,0)) > 0
             then CONVERT(decimal(18,10), SUM(r.Quantity))
                  / CONVERT(decimal(18,10), SUM(ISNULL(c.CalculatorQuantity,0))) * 100
             else CONVERT(decimal(18,10), 0) end,4) as Oran
    from Rep r
    left join Calc c
           on c.OrderNo     = r.OrderNo
          and c.EmployeeId  = r.EmployeeId
          and c.OperationId = r.OperationId
    group by r.EmployeeCode, r.EmployeeName,
             left(r.RepairOperationCode,4), r.RepairOperationCode, r.RepairOperationName,
             r.ErrorCode, r.ErrorName
END');
GO
IF OBJECT_ID(N'dbo.REPORT_F_QualityControlQuantityListR4_yedek_20261112', N'P') IS NULL
EXEC(N'-- =============================================
-- Author:		Abdusselam
-- Create date: 04.07.2020
-- Description: CalculatorQuantity çoklama düzeltildi
-- =============================================
CREATE PROCEDURE [dbo].[REPORT_F_QualityControlQuantityListR4_yedek_20261112]
@StartDate DATE,
@EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    declare @table Table (
        EmployeeId uniqueidentifier, OperationId uniqueidentifier, ProductionLineId uniqueidentifier,
        MachineId uniqueidentifier, OrderVariantId uniqueidentifier, DeviceId uniqueidentifier,
        SerialCardId uniqueidentifier, ModelId uniqueidentifier, [Date] Date, [Hour] int,
        StartDate datetime, EndDate datetime, ReelTotalQ decimal(18,10)
    )
    Insert @table (EmployeeId, OperationId, ProductionLineId, MachineId, OrderVariantId, DeviceId,
                   SerialCardId, ModelId, [Date], [Hour], StartDate, EndDate, ReelTotalQ)
    Select * FROM [dbo].[FC_New_Transection_OnlyQuantity_View](DateAdd(month,-2,@StartDate),@EndDate);

    ;WITH Rep AS (   -- (Sipariş, Çalışan, Operasyon, Hata) başına tek satır
        Select
            o.Code  as OrderNo,
            e2.Id   as EmployeeId,
            o2.Id   as OperationId,
            q.Code  as ErrorCode,
            q.Name  as ErrorName,
            SUM(p.Quantity) as Quantity
        from OrderItemVariantProduction p
        left join Operations o2       on p.RepairOperationId = o2.Id
        left join Employee e2         on p.RepairEmployeeId  = e2.Id
        left join QualityControlErrorCards q on p.QualityTypeId = q.Id
        left join OrderItemVariants v on p.OrderItemVariantId = v.Id
        left join OrderItems oi       on v.OrderItemId = oi.Id
        left join Orders o            on oi.OrderId = o.Id
        where p.QualityType > 1 and p.Date >= @StartDate and p.Date <= @EndDate
        group by o.Code, e2.Id, o2.Id, q.Code, q.Name
    ),
    Calc AS (        -- (Sipariş, Çalışan, Operasyon) başına bir kez
        Select
            o9.Code as OrderNo,
            t.EmployeeId,
            t.OperationId,
            SUM(t.ReelTotalQ) as CalculatorQuantity
        from @table t
        join OrderItemVariants v9 on v9.Id = t.OrderVariantId
        join OrderItems oi9       on oi9.Id = v9.OrderItemId
        join Orders o9            on o9.Id = oi9.OrderId
        group by o9.Code, t.EmployeeId, t.OperationId
    )
    Select
        r.ErrorCode,
        r.ErrorName,
        CONVERT(bigint, SUM(r.Quantity)) as Quantity,
        CONVERT(bigint, SUM(ISNULL(c.CalculatorQuantity,0))) as CalculatorQuantity,
     ROUND(   Case when SUM(ISNULL(c.CalculatorQuantity,0)) > 0
             then CONVERT(decimal(18,10), SUM(r.Quantity))
                  / CONVERT(decimal(18,10), SUM(ISNULL(c.CalculatorQuantity,0))) 
             else CONVERT(decimal(18,10), 0) end ,4) as Oran
    from Rep r
    left join Calc c
           on c.OrderNo     = r.OrderNo
          and c.EmployeeId  = r.EmployeeId
          and c.OperationId = r.OperationId
    group by r.ErrorCode, r.ErrorName
END');
GO
ALTER PROCEDURE [dbo].[REPORT_F_QualityControlQuantityList]
@StartDate DATE,
@EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    /* 2026-11-12 ciftleme duzeltmesi:
       - CalculatorQuantity (siparis, tamirci, tamir op) seviyesinde BIR KEZ hesaplanir ve o kombinasyonun
         ilk detay satirina yazilir; ayni kombinasyonun diger satirlarinda 0. Kolonlar ayni.
       - Gorunmeyen p.OrderItemVariantId kirilimi kaldirildi (ayni gorunen satirlar birlesir, Quantity toplami ayni). */
    declare @table Table (
        EmployeeId uniqueidentifier, OperationId uniqueidentifier, ProductionLineId uniqueidentifier,
        MachineId uniqueidentifier, OrderVariantId uniqueidentifier, DeviceId uniqueidentifier,
        SerialCardId uniqueidentifier, ModelId uniqueidentifier, [Date] Date, [Hour] int,
        StartDate datetime, EndDate datetime, ReelTotalQ decimal(18,10)
    );
    Insert @table
    Select * FROM [dbo].[FC_New_Transection_OnlyQuantity_View](DateAdd(month,-2,@StartDate),@EndDate);

    ;WITH Det AS (
        Select
            o.Code as OrderNo, m.Code as ModelNo, m.Name as ModelName,
            e1.Code as ControlEmployeeCode, e1.Name as ControlEmployeeName,
            e2.Code as EmployeeCode, e2.Name as EmployeeName,
            left(o1.Code,4) as OperationMain, o1.Code as OperationCode, o1.Name as OperationName,
            left(o2.Code,4) as RepairOperationMain, o2.Code as RepairOperationCode, o2.Name as RepairOperationName,
            q.Code as ErrorCode, q.Name as ErrorName,
            SUM(p.Quantity) as Quantity,
            e2.Id as RepEmployeeId, o2.Id as RepOperationId
        from OrderItemVariantProduction p
        Left join Operations o1 on p.OperationId=o1.Id
        Left join Operations o2 on p.RepairOperationId=o2.Id
        left join Employee e1 on p.EmployeeId=e1.Id
        left join Employee e2 on p.RepairEmployeeId=e2.Id
        left join QualityControlErrorCards q on p.QualityTypeId=q.Id
        left join OrderItemVariants v on p.OrderItemVariantId=v.Id
        left join OrderItems oi on v.OrderItemId=oi.Id
        left join Models m on oi.ModelId=m.Id
        left join Orders o on oi.OrderId=o.Id
        where p.QualityType>1 and p.Date>=@StartDate and p.Date<=@EndDate
        Group by o.Code,m.Code,m.Name,e1.Code,e1.Name,e2.Code,e2.Name,o1.Code,o1.Name,
                 o2.Code,o2.Name,q.Code,q.Name,e2.Id,o2.Id
    ),
    Calc AS (
        Select o9.Code as OrderNo, t.EmployeeId, t.OperationId, SUM(t.ReelTotalQ) as CalculatorQuantity
        from @table t
        join OrderItemVariants v9 on v9.Id = t.OrderVariantId
        join OrderItems oi9       on oi9.Id = v9.OrderItemId
        join Orders o9            on o9.Id = oi9.OrderId
        group by o9.Code, t.EmployeeId, t.OperationId
    ),
    X AS (
        Select d.*, ISNULL(c.CalculatorQuantity,0) as Calc,
               ROW_NUMBER() OVER (PARTITION BY d.OrderNo, d.RepEmployeeId, d.RepOperationId
                                  ORDER BY d.ErrorCode, d.ControlEmployeeCode, d.OperationCode, d.ModelNo) as rn
        from Det d
        left join Calc c on c.OrderNo = d.OrderNo and c.EmployeeId = d.RepEmployeeId and c.OperationId = d.RepOperationId
    )
    Select OrderNo, ModelNo, ModelName, ControlEmployeeCode, ControlEmployeeName, EmployeeCode, EmployeeName,
           OperationMain, OperationCode, OperationName, RepairOperationMain, RepairOperationCode, RepairOperationName,
           ErrorCode, ErrorName,
           Convert(bigint, Quantity) as Quantity,
           Convert(bigint, case when rn = 1 then Calc else 0 end) as CalculatorQuantity
    from X;
END
GO
ALTER PROCEDURE [dbo].[REPORT_F_QualityControlQuantityListR2]
@StartDate DATE,
@EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    /* 2026-11-12 ciftleme duzeltmesi:
       - Payda = kisinin o tamir operasyonundaki (tamir gordugu siparislerdeki) toplam uretimi (R1 ile ayni).
       - CalculatorQuantity (kisi, operasyon) basina ilk hata satirina yazilir, digerlerinde 0 -> toplam tekrar etmez.
       - Oran her satirda gercek payda ile hesaplanir (x100 korundu). Kolonlar ayni. */
    declare @table Table (
        EmployeeId uniqueidentifier, OperationId uniqueidentifier, ProductionLineId uniqueidentifier,
        MachineId uniqueidentifier, OrderVariantId uniqueidentifier, DeviceId uniqueidentifier,
        SerialCardId uniqueidentifier, ModelId uniqueidentifier, [Date] Date, [Hour] int,
        StartDate datetime, EndDate datetime, ReelTotalQ decimal(18,10)
    );
    Insert @table
    Select * FROM [dbo].[FC_New_Transection_OnlyQuantity_View](DateAdd(month,-2,@StartDate),@EndDate);

    ;WITH Rep AS (   -- (Siparis, Calisan, Operasyon, Hata)
        Select o.Code as OrderNo, e2.Id as EmployeeId, e2.Code as EmployeeCode, e2.Name as EmployeeName,
               o2.Id as OperationId, o2.Code as RepairOperationCode, o2.Name as RepairOperationName,
               q.Code as ErrorCode, q.Name as ErrorName, SUM(p.Quantity) as Quantity
        from OrderItemVariantProduction p
        left join Operations o2       on p.RepairOperationId = o2.Id
        left join Employee e2         on p.RepairEmployeeId  = e2.Id
        left join QualityControlErrorCards q on p.QualityTypeId = q.Id
        left join OrderItemVariants v on p.OrderItemVariantId = v.Id
        left join OrderItems oi       on v.OrderItemId = oi.Id
        left join Orders o            on oi.OrderId = o.Id
        where p.QualityType > 1 and p.Date >= @StartDate and p.Date <= @EndDate
        group by o.Code, e2.Id, e2.Code, e2.Name, o2.Id, o2.Code, o2.Name, q.Code, q.Name
    ),
    Calc AS (        -- (Siparis, Calisan, Operasyon)
        Select o9.Code as OrderNo, t.EmployeeId, t.OperationId, SUM(t.ReelTotalQ) as CalculatorQuantity
        from @table t
        join OrderItemVariants v9 on v9.Id = t.OrderVariantId
        join OrderItems oi9       on oi9.Id = v9.OrderItemId
        join Orders o9            on o9.Id = oi9.OrderId
        group by o9.Code, t.EmployeeId, t.OperationId
    ),
    EmpOp AS (       -- (Calisan, Operasyon) payda: her siparis bir kez
        Select k.EmployeeId, k.OperationId, SUM(ISNULL(c.CalculatorQuantity,0)) as Calc
        from (Select distinct OrderNo, EmployeeId, OperationId from Rep) k
        left join Calc c on c.OrderNo = k.OrderNo and c.EmployeeId = k.EmployeeId and c.OperationId = k.OperationId
        group by k.EmployeeId, k.OperationId
    ),
    G AS (           -- (Calisan, Operasyon, Hata)
        Select r.EmployeeId, r.OperationId, r.EmployeeCode, r.EmployeeName,
               r.RepairOperationCode, r.RepairOperationName, r.ErrorCode, r.ErrorName,
               SUM(r.Quantity) as Quantity
        from Rep r
        group by r.EmployeeId, r.OperationId, r.EmployeeCode, r.EmployeeName,
                 r.RepairOperationCode, r.RepairOperationName, r.ErrorCode, r.ErrorName
    ),
    X AS (
        Select g.*, ISNULL(eo.Calc,0) as Calc,
               ROW_NUMBER() OVER (PARTITION BY g.EmployeeId, g.OperationId ORDER BY g.ErrorCode, g.ErrorName) as rn
        from G g
        left join EmpOp eo on eo.EmployeeId = g.EmployeeId and eo.OperationId = g.OperationId
    )
    Select
        EmployeeCode, EmployeeName,
        left(RepairOperationCode,4) as RepairOperationMain, RepairOperationCode, RepairOperationName,
        ErrorCode, ErrorName,
        CONVERT(bigint, Quantity) as Quantity,
        CONVERT(bigint, case when rn = 1 then Calc else 0 end) as CalculatorQuantity,
        ROUND(case when Calc > 0
                   then CONVERT(decimal(18,10), Quantity) / CONVERT(decimal(18,10), Calc) * 100
                   else CONVERT(decimal(18,10), 0) end, 4) as Oran
    from X;
END
GO
ALTER PROCEDURE [dbo].[REPORT_F_QualityControlQuantityListR4]
@StartDate DATE,
@EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    /* 2026-11-12 ciftleme duzeltmesi:
       - Payda = donemdeki tamir goren (siparis, calisan, operasyon) uretim toplami, her kombinasyon bir kez (R0/R1/R3 ile ayni).
       - CalculatorQuantity yalnizca ilk hata satirina yazilir, digerlerinde 0 -> toplam tekrar etmez.
       - Oran her satirda gercek payda ile hesaplanir. Kolonlar ayni. */
    declare @table Table (
        EmployeeId uniqueidentifier, OperationId uniqueidentifier, ProductionLineId uniqueidentifier,
        MachineId uniqueidentifier, OrderVariantId uniqueidentifier, DeviceId uniqueidentifier,
        SerialCardId uniqueidentifier, ModelId uniqueidentifier, [Date] Date, [Hour] int,
        StartDate datetime, EndDate datetime, ReelTotalQ decimal(18,10)
    );
    Insert @table
    Select * FROM [dbo].[FC_New_Transection_OnlyQuantity_View](DateAdd(month,-2,@StartDate),@EndDate);

    ;WITH Rep AS (   -- (Siparis, Calisan, Operasyon, Hata)
        Select o.Code as OrderNo, e2.Id as EmployeeId, o2.Id as OperationId,
               q.Code as ErrorCode, q.Name as ErrorName, SUM(p.Quantity) as Quantity
        from OrderItemVariantProduction p
        left join Operations o2       on p.RepairOperationId = o2.Id
        left join Employee e2         on p.RepairEmployeeId  = e2.Id
        left join QualityControlErrorCards q on p.QualityTypeId = q.Id
        left join OrderItemVariants v on p.OrderItemVariantId = v.Id
        left join OrderItems oi       on v.OrderItemId = oi.Id
        left join Orders o            on oi.OrderId = o.Id
        where p.QualityType > 1 and p.Date >= @StartDate and p.Date <= @EndDate
        group by o.Code, e2.Id, o2.Id, q.Code, q.Name
    ),
    Calc AS (
        Select o9.Code as OrderNo, t.EmployeeId, t.OperationId, SUM(t.ReelTotalQ) as CalculatorQuantity
        from @table t
        join OrderItemVariants v9 on v9.Id = t.OrderVariantId
        join OrderItems oi9       on oi9.Id = v9.OrderItemId
        join Orders o9            on o9.Id = oi9.OrderId
        group by o9.Code, t.EmployeeId, t.OperationId
    ),
    Tot AS (         -- tum donem paydasi: her (siparis, calisan, operasyon) bir kez
        Select SUM(ISNULL(c.CalculatorQuantity,0)) as Calc
        from (Select distinct OrderNo, EmployeeId, OperationId from Rep) k
        left join Calc c on c.OrderNo = k.OrderNo and c.EmployeeId = k.EmployeeId and c.OperationId = k.OperationId
    ),
    G AS (
        Select ErrorCode, ErrorName, SUM(Quantity) as Quantity
        from Rep group by ErrorCode, ErrorName
    ),
    X AS (
        Select g.*, ISNULL(t.Calc,0) as Calc,
               ROW_NUMBER() OVER (ORDER BY g.ErrorCode, g.ErrorName) as rn
        from G g cross join Tot t
    )
    Select
        ErrorCode, ErrorName,
        CONVERT(bigint, Quantity) as Quantity,
        CONVERT(bigint, case when rn = 1 then Calc else 0 end) as CalculatorQuantity,
        ROUND(case when Calc > 0
                   then CONVERT(decimal(18,10), Quantity) / CONVERT(decimal(18,10), Calc)
                   else CONVERT(decimal(18,10), 0) end, 4) as Oran
    from X;
END
GO
COMMIT;
GO
SELECT name, modify_date FROM sys.procedures WHERE name LIKE N'REPORT_F_QualityControlQuantityList%' ORDER BY name;
GO
