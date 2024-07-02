USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_ExtGetESSWeekdays]
	@STARTDATE1 [nvarchar](max),
	@ToDate1 [nvarchar](max),
	@EmployeeID [int] = 0,
	@userid [int] = 1,
	@langid [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY
declare @PayrollDate datetime,@STARTDATE datetime,@ToDate datetime

DECLARE @NOOFHOLIDAYS INT,@WEEKLYOFFCOUNT INT

print 'k'
SET @PayrollDate=DATEADD(MONTH,DATEDIFF(MONTH,0,CONVERT(DATETIME,@STARTDATE1)),0)

print @PayrollDate
		SET @STARTDATE=convert(datetime,@STARTDATE1)
		SET @ToDate=convert(datetime,@ToDate1)

print @STARTDATE
print @ToDate


IF(@PayrollDate is not null)
BEGIN			
		--START WEEKLYOFF COUNT
		--LOADING WEEKLYOFF INFORMATION OF EMPLOYEE
		DECLARE @EMPWEEKLYOFF TABLE (WK11 varchar(50),WK12 varchar(50),WK21 varchar(50),WK22 varchar(50), WK31 varchar(50),
								   WK32 varchar(50),WK41 varchar(50),WK42 varchar(50),WK51 varchar(50),WK52 varchar(50))
		DECLARE @WEEKLYOFF TABLE (WEEKLYWEEKOFFNO int,DAYNAME varchar(100))										   
								   
		--LOADING DATA FROM WEEKLYOFF MASTER											   
		--INSERT INTO @EMPWEEKLYOFF 
		--SELECT TOP 1 TD.dcAlpha2 WK11,TD.dcAlpha3 WK12,TD.dcAlpha4 WK21,TD.dcAlpha5 WK22,TD.dcAlpha6 WK31,TD.dcAlpha7 WK32,TD.dcAlpha8 WK41,TD.dcAlpha9 WK42,
		--	         TD.dcAlpha10 WK51,TD.dcAlpha11 WK52	FROM COM_DocCCData DC WITH(NOLOCK),INV_DOCDETAILS ID WITH(NOLOCK),COM_DocTextData TD WITH(NOLOCK)
 	--	WHERE        DC.INVDOCDETAILSID=ID.INVDOCDETAILSID AND TD.INVDOCDETAILSID=ID.INVDOCDETAILSID AND ID.COSTCENTERID=40053 AND DC.dcCCNID51=@EmployeeID AND	
		--  		     CONVERT(DATETIME,ID.DUEDATE)<=CONVERT(DATETIME,@PayrollDate)											
		--ORDER BY     CONVERT(DATETIME,ID.DUEDATE) DESC
		
		
DECLARE @WeeklyOffsDefBasedOn NVARCHAR(MAX),@WhereCond NVARCHAR(MAX),@HCCID INT,@CCType NVARCHAR(50),@SQL nvarchar(max)
SELECT @WeeklyOffsDefBasedOn=ISNULL(Value,'') From ADM_GlobalPreferences WITH(NOLOCK) Where Name='WeeklyOffsDefBasedOn'
SET @SQL='' SET @WhereCond=''
IF(@WeeklyOffsDefBasedOn<>'')
BEGIN
	DECLARE @HBOn TABLE (HCCID INT)  
	INSERT INTO @HBOn  
	EXEC SPSplitString @WeeklyOffsDefBasedOn,','  
	
	print 'khhd'
	
	DECLARE CUR CURSOR FOR SELECT HCCID FROM @HBOn
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
												CONVERT(DATETIME,FromDate) BETWEEN CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@STARTDATE)+''') AND CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@ToDate)+''')) 
											AND (CONVERT(DATETIME,ToDate)>=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollDate)+''') OR ToDate IS NULL) )) ORDER BY     CONVERT(DATETIME,ID.DUEDATE) DESC '
									
			END
		END
	FETCH NEXT FROM CUR INTO @HCCID
	END
	CLOSE CUR
	DEALLOCATE CUR	
END

SET @SQL='
SELECT TOP 1 TD.dcAlpha2 WK11,TD.dcAlpha3 WK12,TD.dcAlpha4 WK21,TD.dcAlpha5 WK22,TD.dcAlpha6 WK31,TD.dcAlpha7 WK32,TD.dcAlpha8 WK41,TD.dcAlpha9 WK42,
			         TD.dcAlpha10 WK51,TD.dcAlpha11 WK52	
FROM INV_DOCDETAILS ID WITH(NOLOCK)
Left Join COM_DocTextData TD WITH(NOLOCK) on TD.InvDocdetailsID=ID.InvDocDetailsId
Left Join COM_DocCCData c WITH(NOLOCK) on c.InvDocdetailsID=ID.InvDocDetailsId
left join com_status status WITH(NOLOCK) on status.statusId=369
Where ID.StatusID=369 AND ID.CostCenterID=40053  and TD.dcAlpha1=''No'' and CONVERT(DATETIME,ID.DUEDATE)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollDate)+''')											
		'
IF(@WhereCond IS NOT NULL AND @WhereCond <>'' AND LEN(@WhereCond)>0)
BEGIN
	SET @SQL=@SQL+ @WhereCond
END
PRINT @SQL

INSERT INTO @EMPWEEKLYOFF
EXEC sp_executesql @SQL		

		--select * from @EMPWEEKLYOFF
		--CHECKING FOR EMPLOYEE WEEKLY OFF COUNT FROM WEEKLYOFF MASTER IF NO DATA FOUND
		--LOADING DATA FROM EMPLOYEE MASTER
		IF (SELECT COUNT(*) FROM @EMPWEEKLYOFF)<=0
		BEGIN
			INSERT INTO @EMPWEEKLYOFF 
			SELECT WeeklyOff1,WeeklyOff2,WeeklyOff1,WeeklyOff2,WeeklyOff1,WeeklyOff2,WeeklyOff1,WeeklyOff2,
			       WeeklyOff1,WeeklyOff2	FROM COM_CC50051 WITH(NOLOCK)
			WHERE  NODEID=@EmployeeID
			DELETE FROM @EMPWEEKLYOFF WHERE ISNULL(WK11,'None')='None' OR ISNULL(WK11,'0')='0'
		END
		--CHECKING FOR EMPLOYEE WEEKLY OFF COUNT FROM EMPLOYEE MASTER IF NO DATA FOUND
		--LOADING DATA FROM PREFERENCES
		IF (SELECT COUNT(*) FROM @EMPWEEKLYOFF)<=0
		BEGIN
			INSERT INTO @WEEKLYOFF 
			SELECT case isnull(VALUE,'') when '' then 0 else 1 end,VALUE	FROM ADM_GlobalPreferences WITH(NOLOCK)  WHERE NAME='WeeklyOff1'
			UNION ALL
			SELECT case isnull(VALUE,'') when '' then 0 else 1 end,VALUE	FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE NAME='WeeklyOff2'
			UNION ALL
			SELECT case isnull(VALUE,'') when '' then 0 else 2 end,VALUE	FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE NAME='WeeklyOff1'
			UNION ALL
			SELECT case isnull(VALUE,'') when '' then 0 else 2 end,VALUE	FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE NAME='WeeklyOff2'					  
			UNION ALL
			SELECT case isnull(VALUE,'') when '' then 0 else 3 end,VALUE	FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE NAME='WeeklyOff1'
			UNION ALL
			SELECT case isnull(VALUE,'') when '' then 0 else 3 end,VALUE	FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE NAME='WeeklyOff2'					  
			UNION ALL
			SELECT case isnull(VALUE,'') when '' then 0 else 4 end,VALUE	FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE NAME='WeeklyOff1'
			UNION ALL
			SELECT case isnull(VALUE,'') when '' then 0 else 4 end,VALUE	FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE NAME='WeeklyOff2'					  
			UNION ALL
			SELECT case isnull(VALUE,'') when '' then 0 else 5 end,VALUE	FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE NAME='WeeklyOff1'
			UNION ALL
			SELECT case isnull(VALUE,'') when '' then 0 else 5 end,VALUE	FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE NAME='WeeklyOff2'		
		END
		--LOADING WEEKNO AND DAYNAME INTO ROWS FROM @EMPWEEKLYOFF TABLE (WEEKLYOFF AND EMPLOYEE MASTER)
		IF (SELECT COUNT(*) FROM @WEEKLYOFF)<=0
		BEGIN
			INSERT INTO @WEEKLYOFF
				select case isnull(WK11,'') when '' then 0 else 1 end,case isnull(WK11,'') when '' then '' else WK11 end FROM @EMPWEEKLYOFF
			UNION ALL
				select case isnull(WK12,'') when '' then 0 else 1 end,case isnull(WK12,'') when '' then '' else WK12 end FROM @EMPWEEKLYOFF
			UNION ALL
				select case isnull(WK21,'') when '' then 0 else 2 end,case isnull(WK21,'') when '' then '' else WK21 end FROM @EMPWEEKLYOFF
			UNION ALL
				select case isnull(WK22,'') when '' then 0 else 2 end,case isnull(WK22,'') when '' then '' else WK22 end FROM @EMPWEEKLYOFF
			UNION ALL
				select case isnull(WK31,'') when '' then 0 else 3 end,case isnull(WK31,'') when '' then '' else WK31 end FROM @EMPWEEKLYOFF
			UNION ALL
				select case isnull(WK32,'') when '' then 0 else 3 end,case isnull(WK32,'') when '' then '' else WK32 end FROM @EMPWEEKLYOFF
			UNION ALL
				select case isnull(WK41,'') when '' then 0 else 4 end,case isnull(WK41,'') when '' then '' else WK41 end FROM @EMPWEEKLYOFF
			UNION ALL
				select case isnull(WK42,'') when '' then 0 else 4 end,case isnull(WK42,'') when '' then '' else WK42 end FROM @EMPWEEKLYOFF
			UNION ALL
				select case isnull(WK51,'') when '' then 0 else 5 end,case isnull(WK51,'') when '' then '' else WK51 end FROM @EMPWEEKLYOFF
			UNION ALL
				select case isnull(WK52,'') when '' then 0 else 5 end,case isnull(WK52,'') when '' then '' else WK52 end FROM @EMPWEEKLYOFF
		END
		--START : LOADING WEEKDATE,DAYNAME AND WEEKNO FOR SELECTED DATERANGE
		DECLARE @WEEKOFFCOUNT TABLE (ID INT ,WEEKDATE DATETIME,DAYNAME VARCHAR(50),WEEKNO INT,ISVALIDDAY INT,REMARKS VARCHAR(1000))
		
			;WITH DATERANGE AS
			(
			SELECT convert(datetime,@STARTDATE) AS DT,1 AS ID
			UNION ALL
			SELECT DATEADD(DD,1,DT),DATERANGE.ID+1 FROM DATERANGE WHERE ID<=DATEDIFF("d",convert(datetime,@PayrollDate),convert(datetime,@ToDate))
			)
			INSERT INTO @WEEKOFFCOUNT
			SELECT ROW_NUMBER() OVER (ORDER BY DT) AS ID,DT AS WEEKDATE,DATENAME(DW,DT) AS DAY,0,0,'' FROM DATERANGE	--WHERE (DATEPART(DW,DT)=1 OR DATEPART(DW,DT)=7)
		--END : LOADING WEEKDATE,DAYNAME AND WEEKNO FOR SELECTED DATERANGE	
		
		--START : UPDATING ISVALIDDAY FOR WEEKLYOFF AND HOLIDAY
			--UPDATING WEEKNO IN WEEKOFFCOUNT TABLE BASED ON WEEKDATE OF MONTH
			
			--select * from @WEEKOFFCOUNT
			UPDATE @WEEKOFFCOUNT SET WEEKNO=((datepart(day,WEEKDATE)-1)/7)+1
			
			--UPDATING ISVALIDDAY TO 1 IF WEEKNO AND DAYNAME IS WEEKLYOFF
			UPDATE WEEKOFFCOUNT SET WEEKOFFCOUNT.ISVALIDDAY=1,WEEKOFFCOUNT.REMARKS='Weeklyoff' FROM @WEEKOFFCOUNT WEEKOFFCOUNT inner join @WEEKLYOFF WEEKLYOFF on WEEKLYOFF.WEEKLYWEEKOFFNO=WEEKOFFCOUNT.WEEKNO AND upper(WEEKLYOFF.DAYNAME)=upper(WEEKOFFCOUNT.DAYNAME) 

				
		--IF((SELECT COUNT(*) FROM COM_DOCTEXTDATA TD WITH(NOLOCK) JOIN INV_DOCDETAILS ID WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID JOIN COM_DOCCCDATA DC WITH(NOLOCK) ON ID.INVDOCDETAILSID=DC.INVDOCDETAILSID
		--WHERE   DC.DCCCNID51=@EmployeeID AND ID.COSTCENTERID=40059 AND ISDATE(TD.DCALPHA1)=1 and CONVERT(DATETIME,TD.DCALPHA1)=CONVERT(DATETIME,@PayrollDate))>0)
			--SELECT 0 AS ISVALIDDAY,* from @WEEKOFFCOUNT where REMARKS='Weeklyoff'
		--ELSE
		--	SELECT ISNULL(ISVALIDDAY,0) AS ISVALIDDAY,* from @WEEKOFFCOUNT  where REMARKS='Weeklyoff'
--holidays Calculation
DECLARE @HolidayBasedOn NVARCHAR(MAX)
SELECT @HolidayBasedOn=ISNULL(Value,'') From ADM_GlobalPreferences WITH(NOLOCK) Where Name='HolidaysBasedOn'
SET @SQL='' SET @WhereCond=''
IF(@HolidayBasedOn<>'')
BEGIN
	DECLARE @HBOnH TABLE (HCCID INT)  
	INSERT INTO @HBOnH  
	EXEC SPSplitString @HolidayBasedOn,','  
	
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
											AND (c.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN (1) OR c.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN (Select CCNID'+CONVERT(NVARCHAR,(@HCCID-50000))+' FROM COM_CCCCData WITH(NOLOCK) WHERE CostCenterID=50051 AND NodeID IN('+CONVERT(NVARCHAR,@EmployeeID)+'))) '
			END
			ELSE
			BEGIN
				SET @WhereCond=@WhereCond+' 
											AND (c.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN (1) OR c.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN (SELECT DISTINCT HistoryNodeID FROM COM_HistoryDetails WITH(NOLOCK) 
											WHERE NodeID IN('+convert(nvarchar,@EmployeeID)+') AND CostCenterID=50051 AND HistoryCCID='+CONVERT(NVARCHAR,@HCCID)+'   
											AND (CONVERT(DATETIME,FromDate)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollDate)+''') OR 
												CONVERT(DATETIME,FromDate) BETWEEN CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@STARTDATE)+''') AND CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@ToDate)+''')) 
											AND (CONVERT(DATETIME,ToDate)>=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollDate)+''') OR ToDate IS NULL) )) '
			END
		END
	FETCH NEXT FROM CUR INTO @HCCID
	END
	CLOSE CUR
	DEALLOCATE CUR
	
END
SET @SQL='
SELECT b.dcalpha1,b.dcalpha2
FROM INV_DOCDETAILS a WITH(NOLOCK)
Left Join COM_DocTextData b WITH(NOLOCK) on b.InvDocdetailsID=a.InvDocDetailsId
Left Join COM_DocCCData c WITH(NOLOCK) on c.InvDocdetailsID=a.InvDocDetailsId
left join com_status status WITH(NOLOCK) on status.statusId=369
Where a.StatusID=369 AND a.CostCenterID=40051  and isdate(b.dcAlpha1)=1 And convert(datetime,b.dcalpha1) BETWEEN '''+CONVERT(NVARCHAR,@STARTDATE)+''' AND '''+CONVERT(NVARCHAR,@ToDate)+''''
IF(@WhereCond IS NOT NULL AND @WhereCond <>'' AND LEN(@WhereCond)>0)
BEGIN
	SET @SQL=@SQL+ @WhereCond
END
PRINT @SQL

Declare @TEmp table (ID int Identity(1,1),WEEKDATE Nvarchar(max),Remarks nvarchar(max))
insert into @TEmp
EXEC sp_executesql @SQL

insert into @WEEKOFFCOUNT 
select ID,convert(datetime,WEEKDATE),DATENAME(DW,WEEKDATE) as day,((datepart(day,WEEKDATE)-1)/7)+1,2,Remarks from @TEmp  

select * from @WEEKOFFCOUNT where ISVALIDDAY>0 and Convert(Datetime,WEEKDATE) <= CONVERT(Datetime,@ToDate1) order by WEEKDATE 

END
END TRY  
BEGIN CATCH    
  --Return exception info [Message,Number,ProcedureName,LineNumber]    
  IF ERROR_NUMBER()=50000  
  BEGIN  
   SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
  END  
  ELSE  
  BEGIN  
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
   FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
  END   
SET NOCOUNT OFF    
RETURN -999     
END CATCH


GO
