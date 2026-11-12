-- Duzeltmeyi geri alir: eski tanimlar geri yuklenir.
USE [TechtsioMerkez];
GO
/****** Object:  StoredProcedure [dbo].[REPORT_GunlukVerimlilik]    Script Date: 17.08.2020 03:35:50 ******/
 
-- =============================================
-- Author:		Abdusselam
-- Create date: 04.07.2020
-- Description:
-- =============================================
ALTER PROCEDURE [dbo].[REPORT_F_QualityControlQuantityList]
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
 
	
	 
	 
	 
 
END


GO
-- =============================================
-- Author:		Abdusselam
-- Create date: 04.07.2020
-- Description: CalculatorQuantity çoklama düzeltildi
-- =============================================
ALTER PROCEDURE [dbo].[REPORT_F_QualityControlQuantityListR2]
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
END
GO
-- =============================================
-- Author:		Abdusselam
-- Create date: 04.07.2020
-- Description: CalculatorQuantity çoklama düzeltildi
-- =============================================
ALTER PROCEDURE [dbo].[REPORT_F_QualityControlQuantityListR4]
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
END
GO
