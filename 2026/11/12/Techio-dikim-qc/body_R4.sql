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
