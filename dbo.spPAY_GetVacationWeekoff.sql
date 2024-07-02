USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_GetVacationWeekoff]
	@FromDate [datetime],
	@ToDate [datetime],
	@EmployeeID [int] = 0,
	@Flag [int] = 0,
	@userid [int] = 1,
	@langid [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
SET NOCOUNT ON;
DECLARE @WeeklyOffsDefBasedOn NVARCHAR(MAX),@WhereCond NVARCHAR(MAX),@HCCID INT,@CCType NVARCHAR(50),@SQL nvarchar(max),@HolidayBasedOn NVARCHAR(MAX)
declare @PayrollDate datetime,@PayrollStart datetime,@PayrollEnd datetime,@FD DATETIME,@TD DATETIME

EXEC spPAY_GetPayrollDate @FROMDATE,@PayrollDate OUTPUT,@PayrollStart OUTPUT, @PayrollEnd OUTPUT 

IF (ISNULL(@Flag,0)=0)--WeekOff
BEGIN
	DECLARE @ALStartMonth Int,@ALStartMonthYear DateTime,@ALEndMonthYear DateTime
	DECLARE @MONTH111 DATETIME,@MONTH222 DATETIME
	DECLARE @MONTH13 DATETIME,@MONTH14 DATETIME


	Declare @Month1 DateTime,@Month2 DateTime,@Month3 DateTime,@Month4 DateTime,@Month5 DateTime,@Month6 DateTime
	Declare @Month7 DateTime,@Month8 DateTime,@Month9 DateTime,@Month10 DateTime,@Month11 DateTime,@Month12 DateTime

	Declare @MonthTab Table(ID INT Identity(1,1),STDATE DateTime,EDDATE DateTime)

	--START:FOR START DATE AND END DATE OF LEAVE YEAR
	EXEC [spPAY_EXTGetLeaveyearDates] @FromDate,@ALStartMonthYear OUTPUT,@ALEndMonthYear OUTPUT
	----START : LOADING MONTHS BASED ON GIVEN DATE RANGE FROM FROMDATE AND TODATE

	SET @MONTH111 =dateadd(m,-2,@ALStartMonthYear)
	SET @MONTH222 =DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear),0))

	SET @Month1 =@ALStartMonthYear
	SET @Month2 =DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+2,0))
	SET @Month3 = DATEADD(d,1,DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+2,0)))
	SET @Month4 =DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+4,0))
	SET @Month5 = DATEADD(d,1,DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+4,0)))
	SET @Month6 = DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+6,0))
	SET @Month7 = DATEADD(d,1,DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+6,0)))
	SET @Month8 = DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+8,0))
	SET @Month9 = DATEADD(d,1,DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+8,0)))
	SET @Month10 = DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+10,0))
	SET @Month11 = DATEADD(d,1,DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+10,0)))
	SET @Month12 = DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+12,0))

	SET @MONTH13 = DATEADD(d,1,DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+12,0)))
	SET @MONTH14 = DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+14,0))
				
	INSERT INTO @MONTHTAB VALUES(@MONTH111,@MONTH222)

	INSERT INTO @MonthTab VALUES(@Month1,@Month2)
	INSERT INTO @MonthTab VALUES(@Month3,@Month4)
	INSERT INTO @MonthTab VALUES(@Month5,@Month6)
	INSERT INTO @MonthTab VALUES(@Month7,@Month8)
	INSERT INTO @MonthTab VALUES(@Month9,@Month10)
	INSERT INTO @MonthTab VALUES(@Month11,@Month12)

	INSERT INTO @MONTHTAB VALUES(@MONTH13,@MONTH14)
	--END : LOADING MONTHS BASED ON GIVEN DATE RANGE FROM FROMDATE AND TODATE

	--START WEEKLYOFF COUNT
			--LOADING WEEKLYOFF INFORMATION OF EMPLOYEE
			DECLARE @STRQUERY NVARCHAR(MAX),@I INT,@J INT,@COLNAME VARCHAR(15)
			CREATE TABLE #EMPWEEKLYOFF (WK11 varchar(50),WK12 varchar(50),WK21 varchar(50),WK22 varchar(50), WK31 varchar(50),
									   WK32 varchar(50),WK41 varchar(50),WK42 varchar(50),WK51 varchar(50),WK52 varchar(50),WEFDATE DATETIME)
			CREATE TABLE #EMPWEEKLYOFF1 (WK11 varchar(50),WK12 varchar(50),WK21 varchar(50),WK22 varchar(50), WK31 varchar(50),
									   WK32 varchar(50),WK41 varchar(50),WK42 varchar(50),WK51 varchar(50),WK52 varchar(50),WEFDATE DATETIME)											   
			CREATE TABLE #WEEKLYOFF  (WEEKLYWEEKOFFNO int,DAYNAME varchar(100),WeekNo INT,WkDate DATETIME,WEFDATE DATETIME)										   
			CREATE TABLE #WEEKLYOFF1  (WEEKLYWEEKOFFNO int,DAYNAME varchar(100),WeekNo INT,WkDate DATETIME,WEFDATE DATETIME)										   
			SET @STRQUERY=''	   
								   

	-- START	 -- LOADING DATA FROM WEEKLYOFF MASTER	

	SELECT @WeeklyOffsDefBasedOn=ISNULL(Value,'') From ADM_GlobalPreferences WITH(NOLOCK) Where Name='WeeklyOffsDefBasedOn'
	SET @SQL='' SET @WhereCond=''
	IF(@WeeklyOffsDefBasedOn<>'')
	BEGIN
		DECLARE @BasedOn TABLE (HCCID INT)  
		INSERT INTO @BasedOn   
		Select * From dbo.fnCOM_SplitString(@WeeklyOffsDefBasedOn,',')

		DECLARE CUR CURSOR FOR SELECT HCCID FROM @BasedOn
		OPEN CUR
		FETCH NEXT FROM CUR INTO @HCCID
		WHILE @@FETCH_STATUS=0
		BEGIN
			IF EXISTS(SELECT CostCenterColID FROM ADM_COSTCENTERDEF WITH(NOLOCK) WHERE CostCenterID=50051 AND ColumnCostCenterID=@HCCID AND IsColumnInUse=1)
			BEGIN
				SELECT @CCType= ISNULL(UserProbableValues,'') FROM ADM_COSTCENTERDEF WITH(NOLOCK) WHERE CostCenterID=50051 AND ColumnCostCenterID=@HCCID AND IsColumnInUse=1  
				IF(@CCType='')
				BEGIN
				print @WhereCond
					SET @WhereCond=@WhereCond+' 
												AND (c.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN (1) OR c.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN ( Select CCNID'+CONVERT(NVARCHAR,(@HCCID-50000))+' FROM COM_CCCCData WITH(NOLOCK) WHERE CostCenterID=50051 AND NodeID IN('+CONVERT(NVARCHAR,@EmployeeID)+') )) '
				END
				ELSE
				BEGIN
					SET @WhereCond=@WhereCond+' AND (c.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN (1) OR c.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN ( SELECT DISTINCT HistoryNodeID FROM COM_HistoryDetails WITH(NOLOCK) 
												WHERE NodeID IN('+convert(nvarchar,@EmployeeID)+') AND CostCenterID=50051 AND HistoryCCID='+CONVERT(NVARCHAR,@HCCID)+'   
												AND (CONVERT(DATETIME,FromDate)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollDate)+''') OR 
													CONVERT(DATETIME,FromDate) BETWEEN CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollStart)+''') AND CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')) 
												AND (CONVERT(DATETIME,ToDate)>=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollDate)+''') OR ToDate IS NULL) )) '
									
				END
			END
		FETCH NEXT FROM CUR INTO @HCCID
		END
		CLOSE CUR
		DEALLOCATE CUR	

	SET @SQL='SELECT TOP 1  @FD=CONVERT(DATETIME,ID.DUEDATE)
					FROM COM_DocCCData C WITH(NOLOCK),INV_DOCDETAILS ID WITH(NOLOCK),COM_DocTextData TD WITH(NOLOCK)
	WHERE        C.INVDOCDETAILSID=ID.INVDOCDETAILSID AND TD.INVDOCDETAILSID=ID.INVDOCDETAILSID AND ID.COSTCENTERID=40053	
					AND CONVERT(DATETIME,ID.DUEDATE)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@FromDate)+''')'

	IF(@WhereCond IS NOT NULL AND @WhereCond <>'' AND LEN(@WhereCond)>0)
	BEGIN
		SET @SQL=@SQL+ @WhereCond
	END

	SET @SQL=@SQL+' ORDER BY     CONVERT(DATETIME,ID.DUEDATE) DESC'

	EXEC sp_executesql @SQL,N'@FD DATETIME OUTPUT',@FD OUTPUT

	SET @SQL=''
	SET @SQL='SELECT TOP 1  @TD=CONVERT(DATETIME,ID.DUEDATE)
				FROM COM_DocCCData C WITH(NOLOCK),INV_DOCDETAILS ID WITH(NOLOCK),COM_DocTextData TD WITH(NOLOCK)
				WHERE C.INVDOCDETAILSID=ID.INVDOCDETAILSID AND TD.INVDOCDETAILSID=ID.INVDOCDETAILSID AND ID.COSTCENTERID=40053 	
				AND CONVERT(DATETIME,ID.DUEDATE)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@ToDate)+''')'

	IF(@WhereCond IS NOT NULL AND @WhereCond <>'' AND LEN(@WhereCond)>0)
	BEGIN
		SET @SQL=@SQL+ @WhereCond
	END

	SET @SQL=@SQL+' ORDER BY     CONVERT(DATETIME,ID.DUEDATE) DESC'

	EXEC sp_executesql @SQL,N'@TD DATETIME OUTPUT',@TD OUTPUT


	SET @SQL=''
	
	SET @SQL='INSERT INTO #EMPWEEKLYOFF
	SELECT TD.dcAlpha2 Week1_W1,TD.dcAlpha3 Week1_W2,TD.dcAlpha4 Week2_W1,TD.dcAlpha5 Week2_W2,TD.dcAlpha6 Week3_W1,TD.dcAlpha7 Week3_W2,TD.dcAlpha8 Week4_W1,TD.dcAlpha9 Week4_W2,
	TD.dcAlpha10 Week5_W1,TD.dcAlpha11 Week5_W2,CONVERT(DATETIME,ID.DUEDATE)	
	FROM INV_DOCDETAILS ID WITH(NOLOCK)
	Left Join COM_DocTextData TD WITH(NOLOCK) on TD.InvDocdetailsID=ID.InvDocDetailsId
	Left Join COM_DocCCData c WITH(NOLOCK) on c.InvDocdetailsID=ID.InvDocDetailsId
	left join com_status status WITH(NOLOCK) on status.statusId=369
	Where ID.StatusID=369 AND ID.CostCenterID=40053  and TD.dcAlpha1=''No'' 
	AND CONVERT(DATETIME,ID.DUEDATE)>=CONVERT(DATETIME,''' + CONVERT(NVARCHAR,@FD)+''')
	AND CONVERT(DATETIME,ID.DUEDATE)<=CONVERT(DATETIME,''' + CONVERT(NVARCHAR,@TD)+''')'									

	IF(@WhereCond IS NOT NULL AND @WhereCond <>'' AND LEN(@WhereCond)>0)
	BEGIN
		SET @SQL=@SQL+ @WhereCond
	END
	SET @SQL=@SQL+' ORDER BY     CONVERT(DATETIME,ID.DUEDATE) DESC'
	PRINT @SQL
		
	EXEC sp_executesql @SQL

	END
								   
	-- END -- LOADING DATA FROM WEEKLYOFF MASTER											   


			--CHECKING FOR EMPLOYEE WEEKLY OFF COUNT FROM WEEKLYOFF MASTER IF NO DATA FOUND
			--LOADING DATA FROM EMPLOYEE MASTER
			IF (SELECT COUNT(*) FROM #EMPWEEKLYOFF WITH(NOLOCK))<=0
			BEGIN
				INSERT INTO #EMPWEEKLYOFF 
				SELECT WeeklyOff1,WeeklyOff2,WeeklyOff1,WeeklyOff2,WeeklyOff1,WeeklyOff2,WeeklyOff1,WeeklyOff2,
					   WeeklyOff1,WeeklyOff2,'01-01-1900'	FROM COM_CC50051 WITH(NOLOCK)
				WHERE  NODEID=@EmployeeID
				DELETE FROM #EMPWEEKLYOFF WHERE ISNULL(WK11,'None')='None' OR ISNULL(WK11,'0')='0'
				--EMPLOYEE MASTER
				SET @I=1
				SET @STRQUERY=''
				WHILE(@I<=5)
				BEGIN
					SET @J=1
					WHILE(@J<=2)
					BEGIN
						SET @COLNAME='WK'+CONVERT(VARCHAR,@I)+CONVERT(VARCHAR,@J)
						SET @STRQUERY=@STRQUERY+' UPDATE #EMPWEEKLYOFF SET '+ @COLNAME +'='''' where '+ @COLNAME +'=''None'''
					
					SET @J=@J+1
					END
				SET @I=@I+1
				END
				--PRINT @STRQUERY
				EXEC sp_executesql @STRQUERY
			END
			ELSE
			BEGIN
				INSERT INTO #EMPWEEKLYOFF1  SELECT * FROM #EMPWEEKLYOFF WITH(NOLOCK)
				--SET NULL
				IF (SELECT COUNT(*) FROM #EMPWEEKLYOFF1 WITH(NOLOCK))>0
				BEGIN
					SET @I=1
					SET @STRQUERY=''
					WHILE(@I<=5)
					BEGIN
						SET @J=1
						WHILE(@J<=2)
						BEGIN
							SET @COLNAME='WK'+CONVERT(VARCHAR,@I)+CONVERT(VARCHAR,@J)
							SET @STRQUERY=@STRQUERY+' update #EMPWEEKLYOFF1 set '+ @COLNAME +'='''' where '+ @COLNAME +'=''None'''
						
						SET @J=@J+1
						END
					SET @I=@I+1
					END
					--PRINT @STRQUERY
					EXEC sp_executesql @STRQUERY
				END
				--EMPLOYEE MASTER
				IF((SELECT COUNT(*) FROM COM_CC50051 WITH(NOLOCK) WHERE NODEID=@EmployeeID AND (ISNULL(WeeklyOff1,'')<>'' AND ISNULL(WeeklyOff1,'None')<>'None') AND (ISNULL(WeeklyOff2,'')<>'' AND ISNULL(WeeklyOff2,'None')<>'None'))>0)
				BEGIN
					SET @I=1
					SET @STRQUERY=''
					WHILE(@I<=5)
					BEGIN
						SET @J=1
						WHILE(@J<=2)
						BEGIN
							SET @COLNAME='WK'+CONVERT(VARCHAR,@I)+CONVERT(VARCHAR,@J)
							SET @STRQUERY=@STRQUERY+' UPDATE #EMPWEEKLYOFF1 SET '+ @COLNAME +'=WeeklyOff'+CONVERT(VARCHAR,@J)+' FROM COM_CC50051 WITH(NOLOCK)	WHERE  NODEID='+CONVERT(VARCHAR,@EmployeeID) +' AND ISNULL('+ @COLNAME +','''')=''''  AND ISNULL(WeeklyOff'+CONVERT(VARCHAR,@J)+',''None'')<>''None'''
						SET @J=@J+1
						END
					SET @I=@I+1
					END
					--PRINT @STRQUERY
					EXEC sp_executesql @STRQUERY
				END
				ELSE
				BEGIN
					--GLOBAL PREFERENCE
					SET @I=1
					SET @STRQUERY=''
					WHILE(@I<=5)
					BEGIN
						SET @J=1
						WHILE(@J<=2)
						BEGIN
							SET @COLNAME='WK'+CONVERT(VARCHAR,@I)+CONVERT(VARCHAR,@J)
							--SET @STRQUERY=@STRQUERY+' update #EMPWEEKLYOFF set '+ @COLNAME +'='''' where '+ @COLNAME +'=''None'''
							SET @STRQUERY=@STRQUERY+' UPDATE #EMPWEEKLYOFF1 SET '+ @COLNAME +'=isnull(VALUE,'''') FROM ADM_GlobalPreferences WITH(NOLOCK)	WHERE  NAME=''WeeklyOff'+CONVERT(VARCHAR,@J)+''' AND ISNULL('+ @COLNAME +','''')=''''  AND ISNULL(VALUE,''None'')<>''None'''
						SET @J=@J+1
						END
					SET @I=@I+1
					END
					--PRINT @STRQUERY
					EXEC sp_executesql @STRQUERY
				END
			END
			--CHECKING FOR EMPLOYEE WEEKLY OFF COUNT FROM EMPLOYEE MASTER IF NO DATA FOUND
			--LOADING DATA FROM PREFERENCES
			DECLARE @FROMWEEKOFDEF BIT
			IF (SELECT COUNT(*) FROM #EMPWEEKLYOFF WITH(NOLOCK))<=0
			BEGIN
				INSERT INTO #WEEKLYOFF 
				SELECT case isnull(VALUE,'') when '' then 0 else 1 end,VALUE, 0, null,'01-01-1900' FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE NAME='WeeklyOff1'
				UNION ALL
				SELECT case isnull(VALUE,'') when '' then 0 else 1 end,VALUE, 0, null,'01-01-1900'	FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE NAME='WeeklyOff2'
				UNION ALL
				SELECT case isnull(VALUE,'') when '' then 0 else 2 end,VALUE, 0, null,'01-01-1900'	FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE NAME='WeeklyOff1'
				UNION ALL
				SELECT case isnull(VALUE,'') when '' then 0 else 2 end,VALUE, 0, null,'01-01-1900'	FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE NAME='WeeklyOff2'					  
				UNION ALL
				SELECT case isnull(VALUE,'') when '' then 0 else 3 end,VALUE, 0, null,'01-01-1900'	FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE NAME='WeeklyOff1'
				UNION ALL
				SELECT case isnull(VALUE,'') when '' then 0 else 3 end,VALUE, 0, null,'01-01-1900'	FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE NAME='WeeklyOff2'					  
				UNION ALL
				SELECT case isnull(VALUE,'') when '' then 0 else 4 end,VALUE, 0, null,'01-01-1900'	FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE NAME='WeeklyOff1'
				UNION ALL
				SELECT case isnull(VALUE,'') when '' then 0 else 4 end,VALUE, 0, null,'01-01-1900'	FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE NAME='WeeklyOff2'					  
				UNION ALL
				SELECT case isnull(VALUE,'') when '' then 0 else 5 end,VALUE, 0, null,'01-01-1900'	FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE NAME='WeeklyOff1'
				UNION ALL
				SELECT case isnull(VALUE,'') when '' then 0 else 5 end,VALUE, 0, null,'01-01-1900'	FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE NAME='WeeklyOff2'		
			END
						
			--LOADING WEEKNO AND DAYNAME INTO ROWS FROM #EMPWEEKLYOFF TABLE (WEEKLYOFF AND EMPLOYEE MASTER)
			IF (SELECT COUNT(*) FROM #WEEKLYOFF WITH(NOLOCK))<=0
			BEGIN
				INSERT INTO #WEEKLYOFF
					select case isnull(WK11,'') when '' then 0 else 1 end,case isnull(WK11,'') when '' then '' else WK11 end, 0, null,convert(Datetime,WEFDATE) FROM #EMPWEEKLYOFF WITH(NOLOCK) 
				UNION ALL
					select case isnull(WK12,'') when '' then 0 else 1 end,case isnull(WK12,'') when '' then '' else WK12 end, 0, null,convert(Datetime,WEFDATE) FROM #EMPWEEKLYOFF  WITH(NOLOCK)
				UNION ALL
					select case isnull(WK21,'') when '' then 0 else 2 end,case isnull(WK21,'') when '' then '' else WK21 end, 0, null,convert(Datetime,WEFDATE) FROM #EMPWEEKLYOFF WITH(NOLOCK)
				UNION ALL
					select case isnull(WK22,'') when '' then 0 else 2 end,case isnull(WK22,'') when '' then '' else WK22 end, 0, null,convert(Datetime,WEFDATE) FROM #EMPWEEKLYOFF WITH(NOLOCK) 
				UNION ALL
					select case isnull(WK31,'') when '' then 0 else 3 end,case isnull(WK31,'') when '' then '' else WK31 end, 0, null,convert(Datetime,WEFDATE) FROM #EMPWEEKLYOFF  WITH(NOLOCK)
				UNION ALL
					select case isnull(WK32,'') when '' then 0 else 3 end,case isnull(WK32,'') when '' then '' else WK32 end, 0, null,convert(Datetime,WEFDATE) FROM #EMPWEEKLYOFF WITH(NOLOCK) 
				UNION ALL
					select case isnull(WK41,'') when '' then 0 else 4 end,case isnull(WK41,'') when '' then '' else WK41 end, 0, null,convert(Datetime,WEFDATE) FROM #EMPWEEKLYOFF  WITH(NOLOCK)
				UNION ALL
					select case isnull(WK42,'') when '' then 0 else 4 end,case isnull(WK42,'') when '' then '' else WK42 end, 0, null,convert(Datetime,WEFDATE) FROM #EMPWEEKLYOFF WITH(NOLOCK) 
				UNION ALL
					select case isnull(WK51,'') when '' then 0 else 5 end,case isnull(WK51,'') when '' then '' else WK51 end, 0, null,convert(Datetime,WEFDATE) FROM #EMPWEEKLYOFF WITH(NOLOCK) 
				UNION ALL
					select case isnull(WK52,'') when '' then 0 else 5 end,case isnull(WK52,'') when '' then '' else WK52 end, 0, null,convert(Datetime,WEFDATE) FROM #EMPWEEKLYOFF WITH(NOLOCK) 
			END
			IF((SELECT COUNT(*) FROM #EMPWEEKLYOFF1 WITH(NOLOCK))>0)
			BEGIN	
			SET @FROMWEEKOFDEF=1
				INSERT INTO #WEEKLYOFF1
					select case isnull(WK11,'') when '' then 0 else 1 end,case isnull(WK11,'') when '' then '' else WK11 end, 0, null,convert(Datetime,WEFDATE) FROM #EMPWEEKLYOFF1 WITH(NOLOCK) 
				UNION ALL
					select case isnull(WK12,'') when '' then 0 else 1 end,case isnull(WK12,'') when '' then '' else WK12 end, 0, null,convert(Datetime,WEFDATE) FROM #EMPWEEKLYOFF1 WITH(NOLOCK)
				UNION ALL
					select case isnull(WK21,'') when '' then 0 else 2 end,case isnull(WK21,'') when '' then '' else WK21 end, 0, null,convert(Datetime,WEFDATE) FROM #EMPWEEKLYOFF1 WITH(NOLOCK) 
				UNION ALL
					select case isnull(WK22,'') when '' then 0 else 2 end,case isnull(WK22,'') when '' then '' else WK22 end, 0, null,convert(Datetime,WEFDATE) FROM #EMPWEEKLYOFF1 WITH(NOLOCK) 
				UNION ALL
					select case isnull(WK31,'') when '' then 0 else 3 end,case isnull(WK31,'') when '' then '' else WK31 end, 0, null,convert(Datetime,WEFDATE) FROM #EMPWEEKLYOFF1 WITH(NOLOCK) 
				UNION ALL
					select case isnull(WK32,'') when '' then 0 else 3 end,case isnull(WK32,'') when '' then '' else WK32 end, 0, null,convert(Datetime,WEFDATE) FROM #EMPWEEKLYOFF1 WITH(NOLOCK) 
				UNION ALL
					select case isnull(WK41,'') when '' then 0 else 4 end,case isnull(WK41,'') when '' then '' else WK41 end, 0, null,convert(Datetime,WEFDATE) FROM #EMPWEEKLYOFF1 WITH(NOLOCK) 
				UNION ALL
					select case isnull(WK42,'') when '' then 0 else 4 end,case isnull(WK42,'') when '' then '' else WK42 end, 0, null,convert(Datetime,WEFDATE) FROM #EMPWEEKLYOFF1 WITH(NOLOCK) 
				UNION ALL
					select case isnull(WK51,'') when '' then 0 else 5 end,case isnull(WK51,'') when '' then '' else WK51 end, 0, null,convert(Datetime,WEFDATE) FROM #EMPWEEKLYOFF1 WITH(NOLOCK) 
				UNION ALL
					select case isnull(WK52,'') when '' then 0 else 5 end,case isnull(WK52,'') when '' then '' else WK52 end, 0, null,convert(Datetime,WEFDATE) FROM #EMPWEEKLYOFF1 WITH(NOLOCK) 
			END
			--LOADING WEEKDATE,DAYNAME AND WEEKNO FOR SELECTED DATERANGE
			CREATE TABLE #WEEKOFFCOUNT (ID INT ,WEEKDATE DateTime,DAYNAME Varchar(50),WEEKNO Int,COUNT Int,WEEKNOMANUAL Int)
			Declare @STARTDATE DateTime,@STARTDATE2 DateTime,@ENDATE2 DateTime
			Declare @MRC2 AS Int,@MC2 AS Int,@MID2 Int
		
			SET @MC2=1
			SELECT @MRC2=COUNT(*) FROM @MonthTab
			WHILE (@MC2<=@MRC2)
			BEGIN
				SELECT @STARTDATE2=CONVERT(DateTime,STDATE),@ENDATE2=CONVERT(DateTime,EDDATE) FROM @MonthTab WHERE ID=@MC2
				;WITH DATERANGE AS
				(
				SELECT @STARTDATE2 AS DT,1 AS ID
				UNION ALL
				SELECT DATEADD(DD,1,DT),DATERANGE.ID+1 FROM DATERANGE WHERE ID<=DATEDIFF("d",convert(Varchar,@STARTDATE2,101),convert(Varchar,@ENDATE2,101))
				)
			
				INSERT INTO #WEEKOFFCOUNT
				SELECT ROW_NUMBER() OVER (ORDER BY DT) AS ID,DT AS WEEKDATE,DATENAME(DW,DT) AS DAY,0,0,0 FROM DATERANGE	--WHERE (DATEPART(DW,DT)=1 OR DATEPART(DW,DT)=7)
			SET @MC2=@MC2+1
			END
			
			--UPDATING WEEKNO IN WEEKOFFCOUNT Table BASED ON WEEKDATE OF MONTH
			--UPDATE #WEEKOFFCOUNT SET WEEKNO=((datepart(day,WEEKDATE)-1)/7)+1
			--------------------
							declare @PMS int,@PME int
							select @PMS=Value From ADM_GlobalPreferences WITH(NOLOCK) where name='PayDayStart'
							select @PME=Value From ADM_GlobalPreferences WITH(NOLOCK) where name='PayDayEnd'

							declare @PS INT,@PE INT
							declare @wd datetime,@TSwd datetime,@TEwd datetime,@dme datetime
							declare @wno int
							set @wno=0
							select @TSwd=MIN(Weekdate),@TEwd=MAX(Weekdate) FROM #WEEKOFFCOUNT WITH(NOLOCK)
							--SET @TSwd='01-Nov-2019' SET @TEwd='01-Dec-2019'
							WHILE(@TSwd<=@TEwd)
							BEGIN
								IF(DAY(@TSwd)=@PMS)
								BEGIN
									set @wno=1
									Update #WEEKOFFCOUNT SET WEEKNo=@wno WHERE WeekDate=@TSwd
									set @dme=dateadd(day,-1,dateadd(m,1,@TSwd))
								
									Update #WEEKOFFCOUNT SET WEEKNo=@wno 
									where WeekDate between @TSwd AND DATEADD(day,6,@TSwd)
								
									SET @TSwd=DATEADD(day,7,@TSwd)
									set @wno=@wno+1
								END
								ELSE
								BEGIN
									if(@wno=0)
										SET @TSwd=DATEADD(day,1,@TSwd)
									else
									begin
										IF(DAY(DATEADD(day,6,@TSwd))<=@PME)
										begin
											Update #WEEKOFFCOUNT SET WEEKNo=@wno 
											where WeekDate between @TSwd AND DATEADD(day,6,@TSwd)
											SET @TSwd=DATEADD(day,7,@TSwd)
											set @wno=@wno+1

											if(DATEADD(day,6,@TSwd)>@dme)
											BEGIN
												Update #WEEKOFFCOUNT SET WEEKNo=@wno 
												where WeekDate between @TSwd AND @dme
												SET @TSwd=DATEADD(day,1,@dme)
											END
										
										end
										else 
										begin
											Update #WEEKOFFCOUNT SET WEEKNo=@wno 
											where WeekDate between @TSwd AND @dme
											SET @TSwd=DATEADD(day,1,@dme)
										end
									
									end
								END	
							
							END 

			--------------------------

			--UPDATING COUNT TO 1 IF WEEKNO AND DAYNAME IS WEEKLYOFF
			IF(@FROMWEEKOFDEF=1)
			BEGIN
				SET @SQL=''
				SET @SQL='UPDATE WEEKOFFCOUNT SET WEEKOFFCOUNT.count=1 FROM #WEEKOFFCOUNT WEEKOFFCOUNT  WITH(NOLOCK)
				inner join #WEEKLYOFF WEEKLYOFF WITH(NOLOCK) on WEEKLYOFF.WEEKLYWEEKOFFNO=WEEKOFFCOUNT.WEEKNO  
				AND upper(WEEKLYOFF.DAYNAME)=upper(WEEKOFFCOUNT.DAYNAME) 
				AND WeekDate Between CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@FromDate)+''') AND CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@ToDate)+''') AND WEEKLYOFF.WEFDate=(
				SELECT TOP 1  CONVERT(DATETIME,ID.DUEDATE)
								FROM COM_DocCCData C WITH(NOLOCK),INV_DOCDETAILS ID WITH(NOLOCK),COM_DocTextData TD WITH(NOLOCK)
				WHERE        C.INVDOCDETAILSID=ID.INVDOCDETAILSID AND TD.INVDOCDETAILSID=ID.INVDOCDETAILSID AND ID.COSTCENTERID=40053  AND ISNULL(TD.DCALPHA1,''No'')=''No''	
								AND CONVERT(DATETIME,ID.DUEDATE)<=CONVERT(DATETIME,WEEKOFFCOUNT.WeekDate)'

				IF(@WhereCond IS NOT NULL AND @WhereCond <>'' AND LEN(@WhereCond)>0)
				BEGIN
					SET @SQL=@SQL+ @WhereCond
				END
				SET @SQL=@SQL+' ORDER BY     CONVERT(DATETIME,ID.DUEDATE) DESC)'
				--PRINT @SQL
				EXEC sp_executesql @SQL

			END
			ELSE
			BEGIN
				UPDATE WEEKOFFCOUNT SET WEEKOFFCOUNT.count=1 FROM #WEEKOFFCOUNT WEEKOFFCOUNT WITH(NOLOCK) inner join #WEEKLYOFF WEEKLYOFF WITH(NOLOCK) on WEEKLYOFF.WEEKLYWEEKOFFNO=WEEKOFFCOUNT.WEEKNO  AND upper(WEEKLYOFF.DAYNAME)=upper(WEEKOFFCOUNT.DAYNAME) 
			END
				----------------------- 
	--END WEEKLYOFF COUNT

	SELECT * FROM #WEEKOFFCOUNT WITH(NOLOCK)
END
ELSE IF (ISNULL(@Flag,0)=1)--HOLIDAY
BEGIN
	--holidays Calculation
	CREATE table #HOLIDAYCOUNT  (ID int Identity(1,1),WEEKDATE Nvarchar(max),Remarks nvarchar(max))
	

	SELECT @HolidayBasedOn=ISNULL(Value,'') From ADM_GlobalPreferences WITH(NOLOCK) Where Name='HolidaysBasedOn'
	SET @SQL='' SET @WhereCond=''
	IF(@HolidayBasedOn<>'')
	BEGIN
		DECLARE @HBOnH TABLE (HCCID INT)  
		--INSERT INTO @HBOnH  
		--EXEC SPSplitString @HolidayBasedOn,','  

		-----------
		declare @Data nvarchar(max),@Pos INT ,@SplitChar nvarchar(2)
		SET @SplitChar=','
		SET @HolidayBasedOn=LTRIM(RTRIM(@HolidayBasedOn))+@SplitChar  
		SET @Pos=CHARINDEX(@SplitChar,@HolidayBasedOn,1)  
		IF REPLACE(@HolidayBasedOn,@SplitChar,'')<>''  
		BEGIN  
		WHILE @Pos > 0  
		BEGIN  
		SET @Data=LTRIM(RTRIM(LEFT(@HolidayBasedOn,@Pos-1)))  
		INSERT INTO @HBOnH VALUES(@Data)  
		SET @HolidayBasedOn=RIGHT(@HolidayBasedOn,LEN(@HolidayBasedOn)-@Pos)  
		SET @Pos=CHARINDEX(@SplitChar,@HolidayBasedOn,1)  
		END    
		END  
		-----------

		DECLARE CUR CURSOR FOR SELECT HCCID FROM @HBOnH
		OPEN CUR
		FETCH NEXT FROM CUR INTO @HCCID
		WHILE @@FETCH_STATUS=0
		BEGIN
			IF EXISTS(SELECT CostCenterColID FROM ADM_COSTCENTERDEF WITH(NOLOCK) WHERE CostCenterID=50051 AND ColumnCostCenterID=@HCCID AND IsColumnInUse=1)
			BEGIN
				SELECT @CCType= ISNULL(UserProbableValues,'') FROM ADM_COSTCENTERDEF WITH(NOLOCK) WHERE CostCenterID=50051 AND ColumnCostCenterID=@HCCID AND IsColumnInUse=1  
				IF(@CCType='')
				BEGIN
					SET @WhereCond=@WhereCond+' 
												AND (c.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN (1) OR c.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN ( Select CCNID'+CONVERT(NVARCHAR,(@HCCID-50000))+' FROM COM_CCCCData WITH(NOLOCK) WHERE CostCenterID=50051 AND NodeID IN('+convert(nvarchar,@EmployeeID)+'))) '
				END
				ELSE
				BEGIN
					SET @WhereCond=@WhereCond+' 
												AND (c.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN (1) OR c.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN ( SELECT DISTINCT HistoryNodeID FROM COM_HistoryDetails WITH(NOLOCK) 
												WHERE NodeID IN('+convert(nvarchar,@EmployeeID)+') AND CostCenterID=50051 AND HistoryCCID='+CONVERT(NVARCHAR,@HCCID)+'   
												AND (CONVERT(DATETIME,FromDate)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollDate)+''') OR 
													CONVERT(DATETIME,FromDate) BETWEEN CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollStart)+''') AND CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollEnd)+''')) 
												AND (CONVERT(DATETIME,ToDate)>=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollDate)+''') OR ToDate IS NULL)) ) '
				END
			END
		FETCH NEXT FROM CUR INTO @HCCID
		END
		CLOSE CUR
		DEALLOCATE CUR
	
	END
	SET @SQL='INSERT INTO #HOLIDAYCOUNT
	SELECT b.dcalpha1,b.dcalpha2
	FROM INV_DOCDETAILS a WITH(NOLOCK)
	Left Join COM_DocTextData b WITH(NOLOCK) on b.InvDocdetailsID=a.InvDocDetailsId
	Left Join COM_DocCCData c WITH(NOLOCK) on c.InvDocdetailsID=a.InvDocDetailsId
	left join com_status status WITH(NOLOCK) on status.statusId=369
	Where a.StatusID=369 AND a.CostCenterID=40051  and isdate(b.dcAlpha1)=1 And convert(datetime,b.dcalpha1) BETWEEN '''+CONVERT(NVARCHAR,@FromDate)+''' AND '''+CONVERT(NVARCHAR,@ToDate)+''''
	IF(@WhereCond IS NOT NULL AND @WhereCond <>'' AND LEN(@WhereCond)>0)
	BEGIN
		SET @SQL=@SQL+ @WhereCond
	END
	--PRINT @SQL
	EXEC sp_executesql @SQL
	SELECT WEEKDATE,Remarks FROM #HOLIDAYCOUNT WITH(NOLOCK)
END
SET NOCOUNT OFF;
END

GO
