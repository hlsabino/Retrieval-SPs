USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_GetPayrollDate]
	@FromDate [datetime],
	@PayrollMonth [datetime] OUTPUT,
	@PayrollMonthStart [datetime] OUTPUT,
	@PayrollMonthEnd [datetime] OUTPUT
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN

declare @PDays INT,@dt1 DateTime,@dt2 DateTime
SELECT @PDays=ISNULL(Value,'') From ADM_GlobalPreferences WITH(NOLOCK) Where Name='ProcessPayrollbeforeCalanderdays'

IF(ISNULL(@PDays,0)>0)
BEGIN
	SET @PayrollMonth = DATEADD(MONTH,DATEDIFF(MONTH,0,@FromDate),0)
	SET @dt1 = dateadd(d,-1,DATEADD(month,1,@PayrollMonth))
	SET @PayrollMonthStart = dateadd(d,-@PDays,@PayrollMonth)
	SET @PayrollMonthEnd = dateadd(d,-@PDays,@dt1)

	if not ((@FromDate >= @PayrollMonthStart AND @FromDate <= @PayrollMonthEnd))
	BEGIN
		SET  @dt2 = DATEADD(MONTH,1,@FROMDATE)
		SET @PayrollMonth = DATEADD(MONTH,DATEDIFF(MONTH,0,@dt2),0)
		SET @dt1 = dateadd(d,-1,DATEADD(month,1,@PayrollMonth))
		SET @PayrollMonthStart = dateadd(d,-@PDays,@PayrollMonth)
		SET @PayrollMonthEnd = dateadd(d,-@PDays,@dt1)
	END


END
ELSE
BEGIN

              DECLARE  @dt DateTime ,@PayDay INT,@DinM INT,@iTemp INT
			  SELECT @PayDay=ISNULL(Value,'') From ADM_GlobalPreferences WITH(NOLOCK) Where Name='PayDayStart'
                

                if (DATEPART(D,@FromDate) <= @PayDay)
                 SET @PayrollMonth = DATEADD(MONTH,DATEDIFF(MONTH,0,@FromDate),0)
                else
                BEGIN
                  SET  @dt = DATEADD(MONTH,1,@FROMDATE)
                   SET @PayrollMonth = DATEADD(MONTH,DATEDIFF(MONTH,0,@dt),0)
                END

                if (@PayDay <= 15)
                BEGIN
                   SET @dt = @FROMDATE
                    SET @PayrollMonthStart = DATEADD(DAY,(@PayDay-DAY(@dt)),@dt)
                    SET @PayrollMonthEnd = dateadd(d,-1,DATEADD(month,1,@PayrollMonthStart))
                END
                else
                BEGIN
                    SET @dt = @FromDate
                    SET @DinM = DAY(DATEADD(DD,-1,DATEADD(MM,DATEDIFF(MM,-1,@FromDate),0)))
                    if (DATEPART(D,@dt) < @PayDay AND DATEPART(D,@dt) <> @DinM)
                      SET  @dt = DATEADD(MONTH,-1,@FROMDATE)
                    SET @iTemp = @PayDay;
                    while (1=1)
                    BEGIN

                          SET  @PayrollMonthStart = DATEADD(DAY,(@iTemp-DAY(@dt)),@dt)
                            break
                        

                        SET @iTemp=@iTemp-1;
                        
                    END
                    SET @PayrollMonthEnd = dateadd(d,-1,DATEADD(month,1,@PayrollMonthStart))

                    SET @iTemp = DAY(DATEADD(DD,-1,DATEADD(MM,DATEDIFF(MM,-1,@PayrollMonthEnd),0)))
                    if (@PayDay >= 28)
                    BEGIN
                        if (@iTemp < @PayDay)
                          SET  @PayrollMonthEnd = DATEADD(DAY,((@iTemp-1)-DAY(@PayrollMonthEnd)),@PayrollMonthEnd)
                        else
                         SET  @PayrollMonthEnd = DATEADD(DAY,((@PayDay-1)-DAY(@PayrollMonthEnd)),@PayrollMonthEnd)
                    END
                END

                if (DATEPART(M,@PayrollMonthStart) = DATEPART(M,@PayrollMonthEnd))
                  SET @PayrollMonth = DATEADD(MONTH,DATEDIFF(MONTH,0,@PayrollMonthEnd),0)
                else
                BEGIN
                    if ((DAY(DATEADD(DD,-1,DATEADD(MM,DATEDIFF(MM,-1,@PayrollMonthStart),0))) - DATEPART(D,@PayrollMonthStart)) >= DATEPART(D,@PayrollMonthEnd))
                       SET @PayrollMonth = DATEADD(MONTH,DATEDIFF(MONTH,0,@PayrollMonthStart),0)
                    else
                      SET  @PayrollMonth = DATEADD(MONTH,DATEDIFF(MONTH,0,@PayrollMonthEnd),0)
                END

END

END
GO
