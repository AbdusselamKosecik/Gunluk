-- =============================================
-- Author:		Abdusselam
-- Create date: 04.07.2020
-- Description: CalculatorQuantity çoklama düzeltildi
-- =============================================
CREATE PROCEDURE [dbo].[REPORT_F_QualityControlQuantityListR4]
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