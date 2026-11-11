-- Techio paket 2026-11-12 icin CANLI veritabani scripti
-- Hedef: 192.168.10.58 / TechtsioMerkez
-- Icerik: Kodun cagirdigi ama canlida OLMAYAN 3 SP (tanimlar TechtsioMerkezTest'ten alindi).
-- Tekrar calistirilabilir: SP varsa ustune yazar (ALTER).
-- Bagimliliklar canlida kontrol edildi: SENTEZ linked server + SentezLive.dbo.OrderSewingReport / UretimOranlari view'lari mevcut.

USE [TechtsioMerkez];
GO

-- ============================================================
-- REPORT_F_OrderCuteInfo
-- ============================================================
IF OBJECT_ID(N'dbo.REPORT_F_OrderCuteInfo', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE dbo.REPORT_F_OrderCuteInfo AS RETURN 0');
GO

ALTER PROCEDURE [dbo].[REPORT_F_OrderCuteInfo]
-- Add the parameters for the stored procedure here 
@OrderId UNIQUEIDENTIFIER

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	



	Select o.Code WorkOrder
	,orr.OrderQuantity as OrderQuantity
	,orr.InSewing as SewingInDate
	,orr.OutSewing as SewingOutDate
	,orr.ProductedQuantity as ProducedQuantity
	, c.Code as SerialCode
	,c.Descriptions
	,c.LotCode,c.BundleNo,s.Code as Size,
	Max(c.Quantity) as Quantity
	from Orders o WITH (NOLOCK)
left Join OrderItems  oi WITH (NOLOCK) on o.Id=oi.OrderId
left join OrderItemVariants ov WITH (NOLOCK) on oi.Id=ov.OrderItemId
left join Cards c WITH (NOLOCK) on ov.Id=c.OrderVariantId
left join SizeCards s WITH (NOLOCK) on s.Id=ov.SizeId
left join [SENTEZ].[SentezLive].dbo.OrderSewingReport orr on o.Code=  orr.WorkOrderNo COLLATE DATABASE_DEFAULT
where o.Id=@OrderId and c.TypeId=9 
and ParentId is null and (  (c.IsDeleted=1 and  EXISTS (Select SerialCardId from  Transections WITH (NOLOCK) where SerialCardId=c.Id)) or c.IsDeleted=0)
group by
o.Code  , c.Code,  c.Descriptions,c.LotCode,c.BundleNo,s.Code,orr.OrderQuantity
,orr.InSewing
,orr.OutSewing
,orr.ProductedQuantity

order by BundleNo

 

 

END

GO

-- ============================================================
-- REPORT_F_FabricStatusReport
-- ============================================================
IF OBJECT_ID(N'dbo.REPORT_F_FabricStatusReport', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE dbo.REPORT_F_FabricStatusReport AS RETURN 0');
GO



 

/****** Object:  StoredProcedure [dbo].[REPORT_GunlukVerimlilik]    Script Date: 17.08.2020 03:35:50 ******/
 
-- =============================================
-- Author:		Abdusselam
-- Create date: 04.07.2020
-- Description:
-- =============================================
ALTER PROCEDURE [dbo].[REPORT_F_FabricStatusReport]
-- Add the parameters for the stored procedure here
@StartDate DATE,
@EndDate DATE 

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	


	SELECT
newId() as Id,
[TITLE]
      ,[ProcessId]
      ,[YEAR]
      ,[MONTH]
      ,[StartProductionDate]
      ,[Quantity]
      ,[QuantityPerMinutes]
      ,[ProcessCode]
      ,[ProcessName]
      ,[Date]
	  from 
	[SENTEZ].[SentezLive].dbo.UretimOranlari
	where  
	 	  [StartProductionDate] >= @StartDate
	 	AND [StartProductionDate] <= @EndDate
  order by 
 [Date]

END

GO

-- ============================================================
-- REPORT_F_OrderProcessInfo
-- ============================================================
IF OBJECT_ID(N'dbo.REPORT_F_OrderProcessInfo', N'P') IS NULL
    EXEC(N'CREATE PROCEDURE dbo.REPORT_F_OrderProcessInfo AS RETURN 0');
GO




 

/****** Object:  StoredProcedure [dbo].[REPORT_GunlukVerimlilik]    Script Date: 17.08.2020 03:35:50 ******/
 
-- =============================================
-- Author:		Abdusselam
-- Create date: 04.07.2020
-- Description:
-- =============================================
ALTER PROCEDURE [dbo].[REPORT_F_OrderProcessInfo]
-- Add the parameters for the stored procedure here
@StartDate DATE,
@EndDate DATE,
@OrderId UNIQUEIDENTIFIER

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	






	Select 
	min(o.Id) as Id,
	o.Code OrderNo
	,m.Code ModelCode
	,m.Name ModelName
	,orr.OrderQuantity as OrderQuantity
	,orr.InSewing as SewingInDate
	,orr.OutSewing as SewingOutDate
	,orr.ProductedQuantity as ProducedQuantity
	,min(y.Gun) as TotalDays
	,min(y.EmployeeCount) as EmployeeCount
	,min(y.Mesai)/(60*60) as TotalWorkingHours
	,
	min(y.Mesai)/(60)/orr.ProductedQuantity
	  as ProductionMinuteOfAProduct
	,min(y.EmployeeMinCount) as EmployeeMinCount
	,min(y.EmployeeMaxCount) as EmployeeMaxCount
from Orders o
left join OrderItems oi on o.Id=oi.OrderId
left join Models m on m.id=oi.ModelId
left join [SENTEZ].[SentezLive].dbo.OrderSewingReport orr on o.Code=  orr.WorkOrderNo COLLATE DATABASE_DEFAULT
	outer apply 
		(
		Select * from [OrderEmployeeTotaView] c where c.Code=o.Code
		) y
where o.IsDeleted=0 and orr.OrderQuantity is not null
and  (oi.OrderId = @OrderId or @OrderId is null)
	 	AND orr.InSewing >= @StartDate
	 	AND orr.InSewing <= @EndDate
Group by   o.Code,m.Code,m.Name,orr.OrderQuantity,
orr.InSewing,orr.OutSewing,orr.ProductedQuantity
having   min(y.EmployeeCount)  is not null
 

 

END

GO

-- Kontrol
SELECT name, create_date, modify_date FROM sys.procedures
WHERE name IN (N'REPORT_F_OrderCuteInfo', N'REPORT_F_FabricStatusReport', N'REPORT_F_OrderProcessInfo');
GO
