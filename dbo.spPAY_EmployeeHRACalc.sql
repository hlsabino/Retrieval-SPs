﻿USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_EmployeeHRACalc]
	@EmpNode [int],
	@Year [int],
	@UserID [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
SET NOCOUNT ON;
	DECLARE @StartMonthName datetime,@EndMonthName datetime
	DECLARE @i INT,@RC INT,@TRC INT, @FDATE DATETIME,@TDATE DATETIME,@AMOUNT FLOAT,@METRO VARCHAR(3),@MONTHNO INT,@AMOUNTMONTHWISE FLOAT
	
	DECLARE @TABHRA TABLE(SNO INT IDENTITY(1,1),FROMDATE DATETIME,TODATE DATETIME,AMOUNT FLOAT,METRO VARCHAR(3))
	DECLARE @TABHRADETAILS TABLE(SNO INT IDENTITY(1,1),MONTHTEXT VARCHAR(25),FROMDATE DATETIME,TODATE DATETIME,AMOUNT FLOAT,METRO VARCHAR(3))
	
	INSERT INTO @TABHRA
		SELECT convert(datetime,FromDate) FromDt,convert(datetime,ToDate) ToDate,Amount,Metro FROM PAY_EmpTaxHRAInfo with(nolock) WHERE EmpNode=@EmpNode AND Year=@Year		

	SET @RC=1
	SELECT @TRC=COUNT(*) FROM @TABHRA	
	WHILE (@RC<=@TRC)
	BEGIN
		SELECT @FDATE=FROMDATE,@TDATE=TODATE,@AMOUNT=ISNULL(AMOUNT,0),@METRO=METRO FROM @TABHRA WHERE SNO=@RC
	    SET @MonthNo=DATEDIFF(m,CONVERT(DATETIME,@FDATE),CONVERT(DATETIME,@TDATE))+1  
	    SET @AMOUNTMONTHWISE= @AMOUNT/@MONTHNO
	    SET @i=0
		WHILE (@i<@MONTHNO)
		BEGIN
			SET @StartMonthName=CONVERT(VARCHAR,DATEADD(d,1,DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@FDATE)+@i,0))),106)
			SET @EndMonthName=DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@StartMonthName)+1,0))
			SET @EndMonthName=CONVERT(DATETIME,@EndMonthName)
			insert into @TABHRADETAILS SELECT left(datename(month,@StartMonthName),3), @StartMonthName,@EndMonthName,@AMOUNTMONTHWISE,@METRO
		SET @i=@i+1 					
		END
	SET @RC=@RC+1				 
	END
SELECT * FROM @TABHRADETAILS
END
GO
