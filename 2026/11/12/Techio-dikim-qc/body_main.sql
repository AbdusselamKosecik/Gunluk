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
