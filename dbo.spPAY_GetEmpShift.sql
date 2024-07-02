USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_GetEmpShift]
	@FromDate [nvarchar](25) = null,
	@EmployeeID [int] = 0,
	@userid [int] = 1,
	@langid [int] = 1,
	@Shift [nvarchar](100) OUTPUT
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
SET NOCOUNT ON;
declare @PayrollDate datetime,@STARTDATE datetime,@ToDate datetime

DECLARE @ShiftBasedOn NVARCHAR(MAX),@WhereCond NVARCHAR(MAX),@HCCID INT,@CCType NVARCHAR(50),@SQL nvarchar(max)
SELECT @ShiftBasedOn=ISNULL(Value,'') From ADM_GlobalPreferences WITH(NOLOCK) Where Name='ShiftAssignBasedOn'
SET @SQL='' SET @WhereCond='' SET @Shift=''
IF(@ShiftBasedOn<>'')
BEGIN
	DECLARE @BasedOn TABLE (HCCID INT)  
	INSERT INTO @BasedOn  
	EXEC SPSplitString @ShiftBasedOn,','  
	
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
											AND (b.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN (1) OR b.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN ( Select CCNID'+CONVERT(NVARCHAR,(@HCCID-50000))+' FROM COM_CCCCData WITH(NOLOCK) WHERE CostCenterID=50051 AND NodeID IN('+CONVERT(NVARCHAR,@EmployeeID)+') )) '
			END
			ELSE
			BEGIN
				SET @WhereCond=@WhereCond+' AND (b.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN (1) OR b.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN ( SELECT DISTINCT HistoryNodeID FROM COM_HistoryDetails WITH(NOLOCK) 
WHERE NodeID IN('+convert(nvarchar,@EmployeeID)+') AND CostCenterID=50051 AND HistoryCCID='+CONVERT(NVARCHAR,@HCCID)+'   
AND (CONVERT(DATETIME,FromDate) BETWEEN CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@FromDate)+''') AND CONVERT(DATETIME,ISNULL(ToDate,CONVERT(FLOAT,CONVERT(DATETIME,''01-01-2200'')) ))) ) ) ORDER BY     CONVERT(DATETIME,a.DUEDATE) DESC '
									
			END
		END
	FETCH NEXT FROM CUR INTO @HCCID
	END
	CLOSE CUR
	DEALLOCATE CUR	

SET @SQL='
SELECT TOP 1 @Shift=sh.Name
FROM INV_DocDetails a WITH(NOLOCK) 
JOIN COM_DocCCData b WITH(NOLOCK) ON b.InvDocDetailsID=a.InvDocDetailsID
JOIN COM_DocTextData d WITH(NOLOCK) ON d.InvDocDetailsID=a.InvDocDetailsID
JOIN COM_CC50073 sh WITH(NOLOCK) ON sh.NodeID=b.dcCCNID73
WHERE a.CostCenterID=40092 and a.StatusID=369 
AND ISDATE(d.dcAlpha5)=1 AND ISDATE(d.dcAlpha6)=1 AND CONVERT(DATETIME,''' + @FromDate + ''') BETWEEN CONVERT(DATETIME,d.dcAlpha5) AND CONVERT(DATETIME,d.dcAlpha6)'

IF(@ShiftBasedOn IS NOT NULL AND @ShiftBasedOn<>'' AND @ShiftBasedOn='-2')
BEGIN
	SET @SQL=@SQL+ ' AND dcCCNID51 IN ('+CONVERT(NVARCHAR,@EmployeeID)+')'
END
ELSE IF(@WhereCond IS NOT NULL AND @WhereCond <>'' AND LEN(@WhereCond)>0)
BEGIN
	SET @SQL=@SQL+ @WhereCond
END
--PRINT @SQL

EXEC sp_executesql @SQL	,N'@Shift nvarchar(200) output',@Shift output

IF(@Shift IS NULL OR @Shift='')
	SELECT @Shift=Name From COM_CC50073 WITH(NOLOCK) WHERE NodeID=1

END
SET NOCOUNT OFF;		
END

GO
