USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_WidgetHRM]
	@TypeID [int],
	@Groups [nvarchar](max),
	@DateVariables [nvarchar](max),
	@WHERE [nvarchar](max),
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  

	DECLARE @SQL NVARCHAR(MAX),@Select1 nvarchar(max),@GroupBy nvarchar(max),@OuterGroupBy nvarchar(max),@JOIN nvarchar(max)
	set @JOIN=''
	set @Select1=''
	set @GroupBy=''
	set @OuterGroupBy=''
	if @Groups='YrWise'
	begin	
		set @Select1=@Select1+'year(convert(datetime,D.DocDate)) Yr,'
        set @GroupBy='year(convert(datetime,D.DocDate))'
    end
    else if  @Groups='MnWise' or @Groups='QtrWise'
	begin
		set @Select1=@Select1+'year(convert(datetime,D.DocDate)) Yr,month(convert(datetime,D.DocDate)) Mn,'
        set @GroupBy='year(convert(datetime,D.DocDate)),month(convert(datetime,D.DocDate))'
	end
	else if @Groups like 'DIM_%'
	begin
		set @Groups=substring(@Groups,5,len(@Groups))
		set @Select1=@Select1+'DIM.Name Name,'
        set @GroupBy='DIM.Name'
        set @OuterGroupBy='Name,'
        set @JOIN=@JOIN+' join '+(select TableName from ADM_Features with(nolock) where FeatureID=@Groups)
        +' DIM with(nolock) on DIM.NodeID='
        if @TypeID=22 or @TypeID=23 or @TypeID=24
			set @JOIN=@JOIN+'DCC.CCNID'+convert(nvarchar,convert(int,@Groups)-50000)
		else
	        set @JOIN=@JOIN+'DCC.dcCCNID'+convert(nvarchar,convert(int,@Groups)-50000)
    end

	SET @SQL=@DateVariables

	IF @TypeID=21
	BEGIN
		set @SQL=@SQL+'
SELECT '+@Select1+'isnull(sum(convert(float,TXT.dcAlpha3)),0.0) Balance
FROM INV_DocDetails D with(nolock)
join COM_DocCCData DCC with(nolock) on D.InvDocDetailsID=DCC.InvDocDetailsID
join COM_CC50051 E with(nolock) on DCC.dcCCNID51=E.NodeID
join COM_DocTextData TXT with(nolock) on D.INVDOCDETAILSID=TXT.INVDOCDETAILSID
'+@JOIN+'
WHERE TXT.tCostCenterID=40054 and D.VoucherType=11 AND D.DueDate between @Fr and @To'+@WHERE
		if @GroupBy!=''
			set @SQL=@SQL+' GROUP BY '+@GroupBy
	END
	ELSE IF @TypeID=22 or @TypeID=23 or @TypeID=24
	BEGIN
		if @WHERE like '%DCC.CCNID%' or @JOIN like '%DCC.CCNID%'
			set @JOIN=' join COM_CCCCData DCC with(nolock) on DCC.NodeID=E.NodeID and DCC.CostCenterID=50051'+@JOIN
		set @SQL=@SQL+'
select '+@Select1+'count(*) Balance
from COM_CC50051 E with(nolock)
'+@JOIN+'
where E.StatusID=250 and E.IsGroup=0 and E.DOJ<=@To'
		if @TypeID=22
			set @SQL=@SQL+' and (E.DORelieve is null or E.DORelieve>@To)'
		else if @TypeID=23
			set @SQL=@SQL+' and (E.DOJ between @Fr and @To)'
		else if @TypeID=24
			set @SQL=@SQL+' and (E.DORelieve between @Fr and @To)'

		set @SQL=@SQL+@WHERE
		if @GroupBy!=''
			set @SQL=@SQL+' GROUP BY '+@GroupBy
	END
	ELSE IF @TypeID=25
	BEGIN
		if @WHERE like '% and E.%'
			set @JOIN=' join COM_CC50051 E with(nolock) on E.NodeID=DCC.dcCCNID51'+@JOIN
		set @SQL=@SQL+'
SELECT '+@OuterGroupBy+'COUNT(*) Balance from (
SELECT '+@Select1+'DCC.dcCCNID51
FROM INV_DocDetails D with(nolock)
join COM_DocCCData DCC with(nolock) on D.INVDOCDETAILSID=DCC.INVDOCDETAILSID
join COM_DocTextData TXT with(nolock) on D.INVDOCDETAILSID=TXT.INVDOCDETAILSID
'+@JOIN+'
WHERE TXT.tCostCenterID=40062 AND 
(convert(float,CONVERT(DATETIME,TXT.dcAlpha4)) between @Fr and @To 
or @Fr between convert(float,CONVERT(DATETIME,TXT.dcAlpha4)) and convert(float,CONVERT(DATETIME,TXT.dcAlpha5)))
'+@WHERE
		set @SQL=@SQL+' GROUP BY DCC.dcCCNID51'
		if @GroupBy!=''
			set @SQL=@SQL+','+@GroupBy		
		set @SQL=@SQL+') AS T'
		if @OuterGroupBy!=''
			set @SQL=@SQL+' GROUP BY '+substring(@OuterGroupBy,1,len(@OuterGroupBy)-1)
	END
	ELSE IF @TypeID=26
	BEGIN
		set @SQL=@SQL+'
		SELECT case when isdate(T1.dcAlpha1)=1 and isNumeric(T1.dcAlpha1)=0 then CONVERT(DATETIME,T1.dcAlpha1) else null end [Date]
,case when max(T1.dcAlpha2) is not null then 1 else 0 end InTime
,case when max(T1.dcAlpha4) is not null then 1 else 0 end OutTime
FROM INV_DocDetails INV with(nolock)
left join COM_DocTextData T1 with(nolock) on INV.INVDOCDETAILSID=T1.INVDOCDETAILSID
left join COM_DocCCData TDCC with(nolock) on INV.InvDocDetailsID=TDCC.InvDocDetailsID
WHERE T1.tCostCenterID=40089 and INV.StatusID=369 and TDCC.dcCCNID51=@EMPID
and isdate(T1.dcAlpha1)=1 and isNumeric(T1.dcAlpha1)=0 and CONVERT(DATETIME,T1.dcAlpha1) between @Fr and @To'+@WHERE+'
group by T1.dcAlpha1

UNION ALL

SELECT case when isdate(T1.dcAlpha3)=1 and isNumeric(T1.dcAlpha3)=0 then CONVERT(DATETIME,T1.dcAlpha3) else null end [Date]
,case when max(T1.dcAlpha2) is not null then 1 else 0 end InTime
,case when max(T1.dcAlpha4) is not null then 1 else 0 end OutTime
FROM INV_DocDetails INV with(nolock)
left join COM_DocTextData T1 with(nolock) on INV.INVDOCDETAILSID=T1.INVDOCDETAILSID
left join COM_DocCCData TDCC with(nolock) on INV.InvDocDetailsID=TDCC.InvDocDetailsID
WHERE T1.tCostCenterID=40089 and INV.StatusID=369 and TDCC.dcCCNID51=@EMPID
and isdate(T1.dcAlpha3)=1 and isNumeric(T1.dcAlpha3)=0 and CONVERT(DATETIME,T1.dcAlpha3) between @Fr and @To'+@WHERE+'
group by T1.dcAlpha3

'

		set @SQL=@SQL+'
SELECT convert(datetime,d.dcAlpha1) as HolidayDate,d.dcAlpha2 as HolidayName
FROM INV_DocDetails a WITH(NOLOCK) 
JOIN COM_DocCCData TDCC WITH(NOLOCK) ON TDCC.InvDocDetailsID=a.InvDocDetailsID
JOIN COM_DocTextData d WITH(NOLOCK) ON d.InvDocDetailsID=a.InvDocDetailsID'
		if @Groups!=''
			set @SQL=@SQL+' join COM_CCCCDATA EDCC with(nolock) on EDCC.CostCenterID=50051 and EDCC.NodeID=@EMPID'+@Groups
		set @SQL=@SQL+'
WHERE d.tCostCenterID=40051 and a.StatusID=369 AND ISDATE(dcAlpha1)=1
AND CONVERT(DATETIME,dcAlpha1) between @Fr and @To'
	END
	ELSE IF @TypeID=27
	BEGIN
		set @SQL=@SQL+'
select [Date],sum(TotalMin) TotalMin from (
SELECT CONVERT(DATETIME,T1.dcAlpha1) [Date]--,T1.dcAlpha5 TotalTime
		,datediff(mi,convert(datetime,T1.dcAlpha2) ,convert(datetime,T1.dcAlpha4))  TotalMin
--,convert(datetime,T1.dcAlpha2) InTime,convert(datetime,T1.dcAlpha4) OutTime
FROM INV_DocDetails INV with(nolock)
left join COM_DocTextData T1 with(nolock) on INV.INVDOCDETAILSID=T1.INVDOCDETAILSID
left join COM_DocCCData TDCC with(nolock) on INV.InvDocDetailsID=TDCC.InvDocDetailsID
WHERE T1.tCostCenterID=40089 and INV.StatusID=369 and TDCC.dcCCNID51=@EMPID
and isdate(T1.dcAlpha1)=1 and isNumeric(T1.dcAlpha1)=0 and CONVERT(DATETIME,T1.dcAlpha1) between @Fr and @To'+@WHERE+'
) AS T
group by [Date]
'

		set @SQL=@SQL+'
SELECT convert(datetime,d.dcAlpha1) as HolidayDate,d.dcAlpha2 as HolidayName
FROM INV_DocDetails a WITH(NOLOCK) 
JOIN COM_DocCCData TDCC WITH(NOLOCK) ON TDCC.InvDocDetailsID=a.InvDocDetailsID
JOIN COM_DocTextData d WITH(NOLOCK) ON d.InvDocDetailsID=a.InvDocDetailsID'
		if @Groups!=''
			set @SQL=@SQL+' join COM_CCCCDATA EDCC with(nolock) on EDCC.CostCenterID=50051 and EDCC.NodeID=@EMPID'+@Groups
		set @SQL=@SQL+'
WHERE d.tCostCenterID=40051 and a.StatusID=369 AND ISDATE(dcAlpha1)=1
AND CONVERT(DATETIME,dcAlpha1) between @Fr and @To'

		set @SQL=@SQL+'
select [Date],sum(TotalMin) TotalMin from (
SELECT CONVERT(DATETIME,T1.dcAlpha1) [Date]--,T1.dcAlpha5 TotalTime
,datediff(mi,convert(datetime,T1.dcAlpha2) ,convert(datetime,T1.dcAlpha4)) TotalMin
--,convert(datetime,T1.dcAlpha2) InTime,convert(datetime,T1.dcAlpha4) OutTime
FROM INV_DocDetails INV with(nolock)
left join COM_DocTextData T1 with(nolock) on INV.INVDOCDETAILSID=T1.INVDOCDETAILSID
left join COM_DocCCData TDCC with(nolock) on INV.InvDocDetailsID=TDCC.InvDocDetailsID
WHERE T1.tCostCenterID=40090 and INV.StatusID=369 and TDCC.dcCCNID51=@EMPID
and isdate(T1.dcAlpha1)=1 and isNumeric(T1.dcAlpha1)=0 and CONVERT(DATETIME,T1.dcAlpha1) between @Fr and @To'+@WHERE+'
) AS T
group by [Date]
'
	END
	ELSE IF(@TypeID=28)	---- Department wise Employee Count
	BEGIN
		SET @SQL=@SQL+' 
			DECLARE @AsOnDate DATETIME
			SET @AsOnDate=CONVERT(varchar(11),GETDATE(),106)

			SELECT c.Name as Name,COUNT(a1.NodeID) as Balance 
			FROM COM_CC50051 a1 WITH(NOLOCK)
			LEFT JOIN ( SELECT a.NodeID,MAX(a.FromDate) as FromDate,MAX(a.HistoryNodeID) as HistoryNodeID
			From COM_HistoryDetails a WITH(NOLOCK)
			WHERE a.CostCenterID=50051 AND a.HistoryCCID=50004
			AND DATEDIFF(day,CONVERT(DATETIME,a.FromDate),@AsOnDate)>=0
			GROUP BY a.NodeID) b on b.NodeID=a1.NodeID
			LEFT JOIN COM_Department c WITH(NOLOCK) on c.NodeID=ISNULL(b.HistoryNodeID,1)
			WHERE a1.IsGroup=0 AND a1.NodeID<>1 AND a1.DOJ IS NOT NULL AND a1.StatusID=250
			AND DATEDIFF(day,CONVERT(DATETIME,a1.DOJ),@AsOnDate)>=0
			AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a1.DORelieve),''01-Jan-2200''),@AsOnDate)<=0
			GROUP BY c.Name
			ORDER BY Balance DESC '
	END
	ELSE IF(@TypeID=29)	---- Location wise Employee Count
	BEGIN
		SET @SQL=@SQL+' 
			DECLARE @AsOnDate DATETIME
			SET @AsOnDate=CONVERT(varchar(11),GETDATE(),106)

			SELECT c.Name as Name,COUNT(a1.NodeID) as Balance 
			FROM COM_CC50051 a1 WITH(NOLOCK)
			LEFT JOIN ( SELECT a.NodeID,MAX(a.FromDate) as FromDate,MAX(a.HistoryNodeID) as HistoryNodeID
			From COM_HistoryDetails a WITH(NOLOCK)
			WHERE a.CostCenterID=50051 AND a.HistoryCCID=50002
			AND DATEDIFF(day,CONVERT(DATETIME,a.FromDate),@AsOnDate)>=0
			GROUP BY a.NodeID) b on b.NodeID=a1.NodeID
			LEFT JOIN COM_Location c WITH(NOLOCK) on c.NodeID=ISNULL(b.HistoryNodeID,1)
			WHERE a1.IsGroup=0 AND a1.NodeID<>1 AND a1.DOJ IS NOT NULL AND a1.StatusID=250
			AND DATEDIFF(day,CONVERT(DATETIME,a1.DOJ),@AsOnDate)>=0
			AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a1.DORelieve),''01-Jan-2200''),@AsOnDate)<=0
			GROUP BY c.Name
			ORDER BY Balance DESC '
	END
	ELSE IF(@TypeID=30)	---- Grade wise Employee Count
	BEGIN
		SET @SQL=@SQL+' 
			DECLARE @AsOnDate DATETIME
			SET @AsOnDate=CONVERT(varchar(11),GETDATE(),106)

			SELECT c.Name as Name,COUNT(a1.NodeID) as Balance 
			FROM COM_CC50051 a1 WITH(NOLOCK)
			LEFT JOIN ( SELECT a.NodeID,MAX(a.FromDate) as FromDate,MAX(a.HistoryNodeID) as HistoryNodeID
			From COM_HistoryDetails a WITH(NOLOCK)
			WHERE a.CostCenterID=50051 AND a.HistoryCCID=50053
			AND DATEDIFF(day,CONVERT(DATETIME,a.FromDate),@AsOnDate)>=0
			GROUP BY a.NodeID) b on b.NodeID=a1.NodeID
			LEFT JOIN COM_CC50053 c WITH(NOLOCK) on c.NodeID=ISNULL(b.HistoryNodeID,1)
			WHERE a1.IsGroup=0 AND a1.NodeID<>1 AND a1.DOJ IS NOT NULL AND a1.StatusID=250
			AND DATEDIFF(day,CONVERT(DATETIME,a1.DOJ),@AsOnDate)>=0
			AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a1.DORelieve),''01-Jan-2200''),@AsOnDate)<=0
			GROUP BY c.Name
			ORDER BY Balance DESC '
	END
	ELSE IF(@TypeID=31)	---- Designation wise Employee Count
	BEGIN
		SET @SQL=@SQL+' 
			DECLARE @AsOnDate DATETIME
			SET @AsOnDate=CONVERT(varchar(11),GETDATE(),106)

			SELECT c.Name as Name,COUNT(a1.NodeID) as Balance 
			FROM COM_CC50051 a1 WITH(NOLOCK)
			LEFT JOIN ( SELECT a.NodeID,MAX(a.FromDate) as FromDate,MAX(a.HistoryNodeID) as HistoryNodeID
			From COM_HistoryDetails a WITH(NOLOCK)
			WHERE a.CostCenterID=50051 AND a.HistoryCCID=50069
			AND DATEDIFF(day,CONVERT(DATETIME,a.FromDate),@AsOnDate)>=0
			GROUP BY a.NodeID) b on b.NodeID=a1.NodeID
			LEFT JOIN COM_CC50069 c WITH(NOLOCK) on c.NodeID=ISNULL(b.HistoryNodeID,1)
			WHERE a1.IsGroup=0 AND a1.NodeID<>1 AND a1.DOJ IS NOT NULL AND a1.StatusID=250
			AND DATEDIFF(day,CONVERT(DATETIME,a1.DOJ),@AsOnDate)>=0
			AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a1.DORelieve),''01-Jan-2200''),@AsOnDate)<=0
			GROUP BY c.Name
			ORDER BY Balance DESC '
	END
	ELSE IF(@TypeID=32)	---- Employee Type wise Employee Count
	BEGIN
		SET @SQL=@SQL+' 
			DECLARE @AsOnDate DATETIME
			SET @AsOnDate=CONVERT(varchar(11),GETDATE(),106)

			SELECT b.Name as Name, COUNT(a1.NodeID) as Balance 
			FROM COM_CC50051 a1 WITH(NOLOCK)
			LEFT JOIN COM_Lookup b WITH(NOLOCK) on b.NodeID=a1.EmpType
			WHERE a1.IsGroup=0 AND a1.NodeID<>1 AND a1.DOJ IS NOT NULL AND a1.StatusID=250
			AND DATEDIFF(day,CONVERT(DATETIME,a1.DOJ),@AsOnDate)>=0
			AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a1.DORelieve),''01-Jan-2200''),@AsOnDate)<=0
			GROUP BY b.Name
			ORDER BY Balance DESC '
	END
	ELSE IF(@TypeID=33)	---- Gender wise Employee Count
	BEGIN
		SET @SQL=@SQL+' 
			DECLARE @AsOnDate DATETIME
			SET @AsOnDate=CONVERT(varchar(11),GETDATE(),106)

			SELECT ISNULL(b.Name,'''') as Name, COUNT(a1.NodeID) as Balance 
			FROM COM_CC50051 a1 WITH(NOLOCK)
			LEFT JOIN COM_Lookup b WITH(NOLOCK) on b.NodeID=a1.Gender
			WHERE a1.IsGroup=0 AND a1.NodeID<>1 AND a1.DOJ IS NOT NULL AND a1.StatusID=250
			AND DATEDIFF(day,CONVERT(DATETIME,a1.DOJ),@AsOnDate)>=0
			AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a1.DORelieve),''01-Jan-2200''),@AsOnDate)<=0
			GROUP BY b.Name
			ORDER BY Balance DESC '
	END
	ELSE IF(@TypeID=34)	---- Nationality wise Employee Count
	BEGIN
		SET @SQL=@SQL+' 
			DECLARE @AsOnDate DATETIME
			SET @AsOnDate=CONVERT(varchar(11),GETDATE(),106)

			SELECT ISNULL(b.Name,'''') as Name, COUNT(a1.NodeID) as Balance 
			FROM COM_CC50051 a1 WITH(NOLOCK)
			LEFT JOIN COM_Lookup b WITH(NOLOCK) on b.NodeID=a1.Nationality
			WHERE a1.IsGroup=0 AND a1.NodeID<>1 AND a1.DOJ IS NOT NULL AND a1.StatusID=250
			AND DATEDIFF(day,CONVERT(DATETIME,a1.DOJ),@AsOnDate)>=0
			AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a1.DORelieve),''01-Jan-2200''),@AsOnDate)<=0
			GROUP BY b.Name
			ORDER BY Balance DESC '
	END
	ELSE IF(@TypeID=35)	---- Religion wise Employee Count
	BEGIN
		SET @SQL=@SQL+' 
			DECLARE @AsOnDate DATETIME
			SET @AsOnDate=CONVERT(varchar(11),GETDATE(),106)

			SELECT ISNULL(b.Name,'''') as Name, COUNT(a1.NodeID) as Balance 
			FROM COM_CC50051 a1 WITH(NOLOCK)
			LEFT JOIN COM_Lookup b WITH(NOLOCK) on b.NodeID=a1.Religion
			WHERE a1.IsGroup=0 AND a1.NodeID<>1 AND a1.DOJ IS NOT NULL AND a1.StatusID=250
			AND DATEDIFF(day,CONVERT(DATETIME,a1.DOJ),@AsOnDate)>=0
			AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a1.DORelieve),''01-Jan-2200''),@AsOnDate)<=0
			GROUP BY b.Name
			ORDER BY Balance DESC '
	END
	ELSE IF(@TypeID=36)	---- Total Employee Count
	BEGIN
		SET @SQL=@SQL+' 
			DECLARE @AsOnDate DATETIME
			SET @AsOnDate=CONVERT(varchar(11),GETDATE(),106)

			SELECT COUNT(a1.NodeID) as Balance 
			FROM COM_CC50051 a1 WITH(NOLOCK)
			WHERE a1.IsGroup=0 AND a1.NodeID<>1 AND a1.DOJ IS NOT NULL
			AND DATEDIFF(day,CONVERT(DATETIME,a1.DOJ),@AsOnDate)>=0 
			AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a1.DORelieve),''01-Jan-2200''),@AsOnDate)<=0'
	END
	ELSE IF(@TypeID=37)	---- New Joinees Between the Dates
	BEGIN
		SET @SQL=@SQL+' 
			SELECT COUNT(NodeID) as Balance
			FROM COM_CC50051 a1 WITH(NOLOCK)
			WHERE a1.IsGroup=0 AND a1.NodeID<>1 AND a1.DOJ IS NOT NULL
			AND a1.DOJ BETWEEN @Fr AND @To '
	END
	ELSE IF(@TypeID=38)	---- Relieved Employees Between the Dates
	BEGIN
		SET @SQL=@SQL+' 
			SELECT COUNT(NodeID) as Balance
			FROM COM_CC50051 a1 WITH(NOLOCK)
			WHERE a1.IsGroup=0 AND a1.NodeID<>1 AND a1.DORelieve IS NOT NULL
			AND a1.DORelieve BETWEEN @Fr AND @To '
	END
	ELSE IF(@TypeID=39)	---- In Office Employees Count As on Date
	BEGIN
		SET @SQL=@SQL+' 
			DECLARE @AsOnDate DATETIME
			SET @AsOnDate=CONVERT(varchar(11),GETDATE(),106)

			SELECT COUNT(DISTINCT c.dcCCNID51) as Balance
			FROM INV_DocDetails a WITH(NOLOCK)
			JOIN COM_DocTextData b WITH(NOLOCK) on b.InvDocDetailsID=a.InvDocDetailsID
			JOIN COM_DocCCData c WITH(NOLOCK) on c.InvDocDetailsID=a.InvDocDetailsID
			WHERE b.tCostCenterID=40089 AND a.StatusID IN(369,371,441)
			AND ISDATE(b.dcAlpha1)=1 
			AND DATEDIFF(day,CONVERT(DATETIME,b.dcAlpha1),@AsOnDate)=0 '
	END
	ELSE IF(@TypeID=40)	---- On Vacation Employees Count As on Date
	BEGIN
		SET @SQL=@SQL+' 
			DECLARE @AsOnDate DATETIME
			SET @AsOnDate=CONVERT(varchar(11),GETDATE(),106)

			SELECT COUNT(DISTINCT c.dcCCNID51) as Balance
			FROM INV_DocDetails a WITH(NOLOCK)
			JOIN COM_DocTextData b WITH(NOLOCK) on b.InvDocDetailsID=a.InvDocDetailsID
			JOIN COM_DocCCData c WITH(NOLOCK) on c.InvDocDetailsID=a.InvDocDetailsID
			WHERE b.tCostCenterID=40072 AND a.StatusID IN(369,371,441)
			AND LEN(b.dcAlpha2)=11 AND LEN(b.dcAlpha3)=11 
			AND ISDATE(b.dcAlpha2)=1 AND ISDATE(b.dcAlpha3)=1 
			AND @AsOnDate BETWEEN CONVERT(DATETIME,b.dcAlpha2) AND CONVERT(DATETIME,b.dcAlpha3) '
	END
	ELSE IF(@TypeID=41)	---- On Leave Employees Count As on Date
	BEGIN
		SET @SQL=@SQL+' 
			DECLARE @AsOnDate DATETIME
			SET @AsOnDate=CONVERT(varchar(11),GETDATE(),106)

			SELECT COUNT(DISTINCT c.dcCCNID51) as Balance
			FROM INV_DocDetails a WITH(NOLOCK)
			JOIN COM_DocTextData b WITH(NOLOCK) on b.InvDocDetailsID=a.InvDocDetailsID
			JOIN COM_DocCCData c WITH(NOLOCK) on c.InvDocDetailsID=a.InvDocDetailsID
			WHERE b.tCostCenterID=40062 AND a.StatusID IN(369,371,441)
			AND LEN(b.dcAlpha4)=11 AND LEN(b.dcAlpha5)=11 
			AND ISDATE(b.dcAlpha4)=1 AND ISDATE(b.dcAlpha5)=1 
			AND @AsOnDate BETWEEN CONVERT(DATETIME,b.dcAlpha4) AND CONVERT(DATETIME,b.dcAlpha5) '
	END
	ELSE IF(@TypeID=42)	---- On Leave Employees Count - Between the Dates
	BEGIN
		SET @SQL=@SQL+' 
			DECLARE @FromDate DATETIME,@ToDate DATETIME
			SET @FromDate=@Fr
			SET @ToDate=@To

			SELECT COUNT(c.dcCCNID51) as Balance
			FROM INV_DocDetails a WITH(NOLOCK)
			JOIN COM_DocTextData b WITH(NOLOCK) on b.InvDocDetailsID=a.InvDocDetailsID
			JOIN COM_DocCCData c WITH(NOLOCK) on c.InvDocDetailsID=a.InvDocDetailsID
			WHERE b.tCostCenterID=40062 AND a.StatusID IN(369,371,441)
			AND LEN(b.dcAlpha4)=11 AND LEN(b.dcAlpha5)=11 
			AND ISDATE(b.dcAlpha4)=1 AND ISDATE(b.dcAlpha5)=1 

			AND ( @FromDate BETWEEN CONVERT(DATETIME,b.dcAlpha4) AND CONVERT(DATETIME,b.dcAlpha5) OR
				  @ToDate BETWEEN CONVERT(DATETIME,b.dcAlpha4) AND CONVERT(DATETIME,b.dcAlpha5) OR
				  CONVERT(DATETIME,b.dcAlpha4) BETWEEN @FromDate AND @ToDate OR
				  CONVERT(DATETIME,b.dcAlpha5) BETWEEN @FromDate AND @ToDate 
				) '
	END
	ELSE IF(@TypeID=43)	---- Late Arrival Employees Count 
	BEGIN
		SET @SQL=@SQL+' 
			DECLARE @AsOnDate DATETIME
			SET @AsOnDate=CONVERT(varchar(11),GETDATE(),106)

			SELECT COUNT(dcCCNID51) as Balance FROM (
			SELECT c.dcCCNID51,b.dcAlpha1 as CheckInDate,
			CONVERT(DATETIME,(b.dcAlpha1+'' ''+CONVERT(VARCHAR(8), CONVERT(DATETIME,b.dcAlpha2), 108))) as CheckInTime,
			e.dcCCNID73,sh1.Name,
			CONVERT(DATETIME,(b.dcAlpha1+'' ''+CONVERT(VARCHAR(8), CONVERT(DATETIME,sh1.ccAlpha2), 108))) as ShiftStartTime
			FROM INV_DocDetails a WITH(NOLOCK)
			JOIN COM_DocTextData b WITH(NOLOCK) on b.InvDocDetailsID=a.InvDocDetailsID
			JOIN COM_DocCCData c WITH(NOLOCK) on c.InvDocDetailsID=a.InvDocDetailsID
			LEFT JOIN (SELECT ISNULL(b1.dcCCNID51,1) as dcCCNID51,ISNULL(b1.dcCCNID73,1) as dcCCNID73,CONVERT(DATETIME,d1.dcAlpha5) as FDate,CONVERT(DATETIME,d1.dcAlpha6) as TDate 
			FROM INV_DocDetails a1 WITH(NOLOCK) 
			LEFT JOIN COM_DocCCData b1 WITH(NOLOCK) ON b1.InvDocDetailsID=a1.InvDocDetailsID 
			LEFT JOIN COM_DocTextData d1 WITH(NOLOCK) ON d1.InvDocDetailsID=a1.InvDocDetailsID
			WHERE d1.tCostCenterID=40092 and a1.StatusID=369 
			AND ISDATE(d1.dcAlpha5)=1 AND ISDATE(d1.dcAlpha6)=1
			) e on e.dcCCNID51=c.dcCCNID51 AND CONVERT(DATETIME,b.dcAlpha1) BETWEEN CONVERT(DATETIME,e.FDate) AND CONVERT(DATETIME,e.TDate)  
			LEFT JOIN COM_CC50073 sh1 WITH(NOLOCK) ON ISNULL(e.dcCCNID73,1)=sh1.NodeID
			WHERE b.tCostCenterID=40089 AND a.StatusID IN(369,371,441)
			AND LEN(b.dcAlpha1)=11 AND ISDATE(b.dcAlpha1)=1 
			AND DATEDIFF(day,CONVERT(DATETIME,b.dcAlpha1),@AsOnDate)=0
			) as Tbl
			WHERE ShiftStartTime<CheckInTime '
	END
	ELSE IF(@TypeID=44)	---- Late Arrival (Prev.Day) Employees Count 
	BEGIN
		SET @SQL=@SQL+' 
			DECLARE @AsOnDate DATETIME
			SET @AsOnDate=CONVERT(varchar(11),GETDATE(),106)

			SELECT COUNT(dcCCNID51) as Balance FROM (
			SELECT c.dcCCNID51,b.dcAlpha1 as CheckInDate,
			CONVERT(DATETIME,(b.dcAlpha1+'' ''+CONVERT(VARCHAR(8), CONVERT(DATETIME,b.dcAlpha2), 108))) as CheckInTime,
			e.dcCCNID73,sh1.Name,
			CONVERT(DATETIME,(b.dcAlpha1+'' ''+CONVERT(VARCHAR(8), CONVERT(DATETIME,sh1.ccAlpha2), 108))) as ShiftStartTime
			FROM INV_DocDetails a WITH(NOLOCK)
			JOIN COM_DocTextData b WITH(NOLOCK) on b.InvDocDetailsID=a.InvDocDetailsID
			JOIN COM_DocCCData c WITH(NOLOCK) on c.InvDocDetailsID=a.InvDocDetailsID
			LEFT JOIN (SELECT ISNULL(b1.dcCCNID51,1) as dcCCNID51,ISNULL(b1.dcCCNID73,1) as dcCCNID73,CONVERT(DATETIME,d1.dcAlpha5) as FDate,CONVERT(DATETIME,d1.dcAlpha6) as TDate 
			FROM INV_DocDetails a1 WITH(NOLOCK) 
			LEFT JOIN COM_DocCCData b1 WITH(NOLOCK) ON b1.InvDocDetailsID=a1.InvDocDetailsID 
			LEFT JOIN COM_DocTextData d1 WITH(NOLOCK) ON d1.InvDocDetailsID=a1.InvDocDetailsID
			WHERE d1.tCostCenterID=40092 and a1.StatusID=369 
			AND ISDATE(d1.dcAlpha5)=1 AND ISDATE(d1.dcAlpha6)=1
			) e on e.dcCCNID51=c.dcCCNID51 AND CONVERT(DATETIME,b.dcAlpha1) BETWEEN CONVERT(DATETIME,e.FDate) AND CONVERT(DATETIME,e.TDate)  
			LEFT JOIN COM_CC50073 sh1 WITH(NOLOCK) ON ISNULL(e.dcCCNID73,1)=sh1.NodeID
			WHERE b.tCostCenterID=40089 AND a.StatusID IN(369,371,441)
			AND LEN(b.dcAlpha1)=11 AND ISDATE(b.dcAlpha1)=1 
			AND DATEDIFF(day,CONVERT(DATETIME,b.dcAlpha1),DATEADD(day,-1,@AsOnDate))=0
			) as Tbl
			WHERE ShiftStartTime<CheckInTime '
	END
	ELSE IF(@TypeID=45)	---- Early Going Employees Count 
	BEGIN
		SET @SQL=@SQL+' 
			DECLARE @AsOnDate DATETIME
			SET @AsOnDate=CONVERT(varchar(11),GETDATE(),106)

			SELECT COUNT(dcCCNID51) as Balance FROM (
			SELECT c.dcCCNID51,b.dcAlpha1 as CheckInDate,
			CONVERT(DATETIME,(b.dcAlpha1+'' ''+CONVERT(VARCHAR(8), CONVERT(DATETIME,b.dcAlpha4), 108))) as CheckOutTime,
			e.dcCCNID73,sh1.Name,
			CONVERT(DATETIME,(b.dcAlpha1+'' ''+CONVERT(VARCHAR(8), CONVERT(DATETIME,sh1.ccAlpha3), 108))) as ShiftEndTime
			FROM INV_DocDetails a WITH(NOLOCK)
			JOIN COM_DocTextData b WITH(NOLOCK) on b.InvDocDetailsID=a.InvDocDetailsID
			JOIN COM_DocCCData c WITH(NOLOCK) on c.InvDocDetailsID=a.InvDocDetailsID
			LEFT JOIN (SELECT ISNULL(b1.dcCCNID51,1) as dcCCNID51,ISNULL(b1.dcCCNID73,1) as dcCCNID73,CONVERT(DATETIME,d1.dcAlpha5) as FDate,CONVERT(DATETIME,d1.dcAlpha6) as TDate 
			FROM INV_DocDetails a1 WITH(NOLOCK) 
			LEFT JOIN COM_DocCCData b1 WITH(NOLOCK) ON b1.InvDocDetailsID=a1.InvDocDetailsID 
			LEFT JOIN COM_DocTextData d1 WITH(NOLOCK) ON d1.InvDocDetailsID=a1.InvDocDetailsID
			WHERE d1.tCostCenterID=40092 and a1.StatusID=369 
			AND ISDATE(d1.dcAlpha5)=1 AND ISDATE(d1.dcAlpha6)=1
			) e on e.dcCCNID51=c.dcCCNID51 AND CONVERT(DATETIME,b.dcAlpha1) BETWEEN CONVERT(DATETIME,e.FDate) AND CONVERT(DATETIME,e.TDate)  
			LEFT JOIN COM_CC50073 sh1 WITH(NOLOCK) ON ISNULL(e.dcCCNID73,1)=sh1.NodeID
			WHERE b.tCostCenterID=40089 AND a.StatusID IN(369,371,441)
			AND LEN(b.dcAlpha1)=11 AND ISDATE(b.dcAlpha1)=1 
			AND DATEDIFF(day,CONVERT(DATETIME,b.dcAlpha1),@AsOnDate)=0
			) as Tbl
			WHERE ShiftEndTime>CheckOutTime '
	END
	ELSE IF(@TypeID=46)	---- Early Going (Prev.Day) Employees Count 
	BEGIN
		SET @SQL=@SQL+' 
			DECLARE @AsOnDate DATETIME
			SET @AsOnDate=CONVERT(varchar(11),GETDATE(),106)

			SELECT COUNT(dcCCNID51) as Balance FROM (
			SELECT c.dcCCNID51,b.dcAlpha1 as CheckInDate,
			CONVERT(DATETIME,(b.dcAlpha1+'' ''+CONVERT(VARCHAR(8), CONVERT(DATETIME,b.dcAlpha4), 108))) as CheckOutTime,
			e.dcCCNID73,sh1.Name,
			CONVERT(DATETIME,(b.dcAlpha1+'' ''+CONVERT(VARCHAR(8), CONVERT(DATETIME,sh1.ccAlpha3), 108))) as ShiftEndTime
			FROM INV_DocDetails a WITH(NOLOCK)
			JOIN COM_DocTextData b WITH(NOLOCK) on b.InvDocDetailsID=a.InvDocDetailsID
			JOIN COM_DocCCData c WITH(NOLOCK) on c.InvDocDetailsID=a.InvDocDetailsID
			LEFT JOIN (SELECT ISNULL(b1.dcCCNID51,1) as dcCCNID51,ISNULL(b1.dcCCNID73,1) as dcCCNID73,CONVERT(DATETIME,d1.dcAlpha5) as FDate,CONVERT(DATETIME,d1.dcAlpha6) as TDate 
			FROM INV_DocDetails a1 WITH(NOLOCK) 
			LEFT JOIN COM_DocCCData b1 WITH(NOLOCK) ON b1.InvDocDetailsID=a1.InvDocDetailsID 
			LEFT JOIN COM_DocTextData d1 WITH(NOLOCK) ON d1.InvDocDetailsID=a1.InvDocDetailsID
			WHERE d1.tCostCenterID=40092 and a1.StatusID=369 
			AND ISDATE(d1.dcAlpha5)=1 AND ISDATE(d1.dcAlpha6)=1
			) e on e.dcCCNID51=c.dcCCNID51 AND CONVERT(DATETIME,b.dcAlpha1) BETWEEN CONVERT(DATETIME,e.FDate) AND CONVERT(DATETIME,e.TDate)  
			LEFT JOIN COM_CC50073 sh1 WITH(NOLOCK) ON ISNULL(e.dcCCNID73,1)=sh1.NodeID
			WHERE b.tCostCenterID=40089 AND a.StatusID IN(369,371,441)
			AND LEN(b.dcAlpha1)=11 AND ISDATE(b.dcAlpha1)=1 
			AND DATEDIFF(day,CONVERT(DATETIME,b.dcAlpha1),DATEADD(day,-1,@AsOnDate))=0
			) as Tbl
			WHERE ShiftEndTime>CheckOutTime '
	END
	ELSE IF(@TypeID=47)	---- Single Punch Employees Count 
	BEGIN
		SET @SQL=@SQL+' 
			DECLARE @AsOnDate DATETIME
			SET @AsOnDate=CONVERT(varchar(11),GETDATE(),106)

			SELECT COUNT(c.dcCCNID51) as Balance
			FROM INV_DocDetails a WITH(NOLOCK)
			JOIN COM_DocTextData b WITH(NOLOCK) on b.InvDocDetailsID=a.InvDocDetailsID
			JOIN COM_DocCCData c WITH(NOLOCK) on c.InvDocDetailsID=a.InvDocDetailsID
			WHERE b.tCostCenterID=40089 AND a.StatusID IN(369,371,441)
			AND (DATEDIFF(day,CONVERT(DATETIME,b.dcAlpha1),@AsOnDate)=0 OR DATEDIFF(day,CONVERT(DATETIME,b.dcAlpha3),@AsOnDate)=0)
			AND (b.dcAlpha2 IS NULL OR b.dcAlpha2='''' OR b.dcAlpha4 IS NULL OR b.dcAlpha4='''')  '
	END
	ELSE IF(@TypeID=48)	---- Single Punch (Prev.Day) Employees Count 
	BEGIN
		SET @SQL=@SQL+' 
			DECLARE @AsOnDate DATETIME
			SET @AsOnDate=CONVERT(varchar(11),GETDATE(),106)

			SELECT COUNT(c.dcCCNID51) as Balance
			FROM INV_DocDetails a WITH(NOLOCK)
			JOIN COM_DocTextData b WITH(NOLOCK) on b.InvDocDetailsID=a.InvDocDetailsID
			JOIN COM_DocCCData c WITH(NOLOCK) on c.InvDocDetailsID=a.InvDocDetailsID
			WHERE b.tCostCenterID=40089 AND a.StatusID IN(369,371,441)
			AND (DATEDIFF(day,CONVERT(DATETIME,b.dcAlpha1),DATEADD(day,-1,@AsOnDate))=0 OR DATEDIFF(day,CONVERT(DATETIME,b.dcAlpha3),DATEADD(day,-1,@AsOnDate))=0)
			AND (b.dcAlpha2 IS NULL OR b.dcAlpha2='''' OR b.dcAlpha4 IS NULL OR b.dcAlpha4='''')   '
	END
	ELSE IF(@TypeID=49)	---- Attendance Trend 
	BEGIN
		SET @SQL=@SQL+' 
			DECLARE @AsOnDate DATETIME,@i INT,@Fdt DATETIME,@EC INT
			SET @AsOnDate=CONVERT(varchar(11),GETDATE(),106)

			SELECT c.dcCCNID51,CONVERT(DATETIME,(b.dcAlpha1+'' ''+CONVERT(VARCHAR(8), CONVERT(DATETIME,b.dcAlpha2), 108))) as CheckInTime INTO #ATT
			FROM INV_DocDetails a WITH(NOLOCK)
			JOIN COM_DocTextData b WITH(NOLOCK) on b.InvDocDetailsID=a.InvDocDetailsID
			JOIN COM_DocCCData c WITH(NOLOCK) on c.InvDocDetailsID=a.InvDocDetailsID
			WHERE b.tCostCenterID=40089 AND a.StatusID IN(369,371,441)
			AND LEN(b.dcAlpha1)=11 AND ISDATE(b.dcAlpha1)=1 
			AND DATEDIFF(day,CONVERT(DATETIME,b.dcAlpha1),@AsOnDate)=0

			DECLARE @TS TABLE(FSlot NVARCHAR(30),TSlot NVARCHAR(30),ECount INT)
			SET @i=1
			SET @Fdt=CONVERT(varchar(11),GETDATE(),106)

			WHILE(@i<=48)
			BEGIN
				SET @EC=0
				SET @Fdt=DATEADD(MINUTE,1,@Fdt)
				SELECT @EC=COUNT(dcCCNID51) FROM #ATT WHERE CheckInTime BETWEEN @FDt AND DATEADD(MINUTE,29,@FDt)
				INSERT INTO @TS
				SELECT @FDt,DATEADD(MINUTE,29,@FDt),@EC
				SET @Fdt=DATEADD(MINUTE,29,@Fdt)
			SET @i=@i+1
			END

			DELETE FROM @TS WHERE ECount=0
			DROP TABLE #ATT

			SELECT CONVERT(VARCHAR(5),CONVERT(DATETIME,FSlot), 108)+RIGHT(CONVERT(VARCHAR(30),CONVERT(DATETIME,FSlot),9),2) +'' - ''+CONVERT(VARCHAR(5),CONVERT(DATETIME,TSlot), 108)+RIGHT(CONVERT(VARCHAR(30),CONVERT(DATETIME,TSlot),9),2) as Name,ECount as Balance
			FROM @TS
			ORDER BY CONVERT(DATETIME,FSlot)  '
	END
	ELSE IF(@TypeID=50)	---- Absent Employee Count
	BEGIN
		SET @SQL=@SQL+' 
			DECLARE @AsOnDate DATETIME
			SET @AsOnDate=CONVERT(varchar(11),GETDATE(),106)

			DECLARE @Total INT,@Present INT,@Vacation INT,@Leave INT

			SELECT @Total=COUNT(a1.NodeID)
			FROM COM_CC50051 a1 WITH(NOLOCK)
			WHERE a1.StatusID=250 AND a1.IsGroup=0 AND a1.NodeID<>1 AND a1.DOJ IS NOT NULL
			AND DATEDIFF(day,CONVERT(DATETIME,a1.DOJ),@AsOnDate)>=0
			AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a1.DORelieve),''01-Jan-2200''),@AsOnDate)<=0 

			SELECT @Present=COUNT(DISTINCT c.dcCCNID51) 
			FROM INV_DocDetails a WITH(NOLOCK)
			JOIN COM_DocTextData b WITH(NOLOCK) on b.InvDocDetailsID=a.InvDocDetailsID
			JOIN COM_DocCCData c WITH(NOLOCK) on c.InvDocDetailsID=a.InvDocDetailsID
			WHERE b.tCostCenterID=40089 AND a.StatusID IN(369,371,441)
			AND ISDATE(b.dcAlpha1)=1 
			AND DATEDIFF(day,CONVERT(DATETIME,b.dcAlpha1),@AsOnDate)=0

			SELECT @Vacation= COUNT(DISTINCT c.dcCCNID51)
			FROM INV_DocDetails a WITH(NOLOCK)
			JOIN COM_DocTextData b WITH(NOLOCK) on b.InvDocDetailsID=a.InvDocDetailsID
			JOIN COM_DocCCData c WITH(NOLOCK) on c.InvDocDetailsID=a.InvDocDetailsID
			WHERE b.tCostCenterID=40072 AND a.StatusID IN(369,371,441)
			AND LEN(b.dcAlpha2)=11 AND LEN(b.dcAlpha3)=11 
			AND ISDATE(b.dcAlpha2)=1 AND ISDATE(b.dcAlpha3)=1 
			AND @AsOnDate BETWEEN CONVERT(DATETIME,b.dcAlpha2) AND CONVERT(DATETIME,b.dcAlpha3) 


			SELECT @Leave=COUNT(DISTINCT c.dcCCNID51)
			FROM INV_DocDetails a WITH(NOLOCK)
			JOIN COM_DocTextData b WITH(NOLOCK) on b.InvDocDetailsID=a.InvDocDetailsID
			JOIN COM_DocCCData c WITH(NOLOCK) on c.InvDocDetailsID=a.InvDocDetailsID
			WHERE b.tCostCenterID=40062 AND a.StatusID IN(369,371,441)
			AND LEN(b.dcAlpha4)=11 AND LEN(b.dcAlpha5)=11 
			AND ISDATE(b.dcAlpha4)=1 AND ISDATE(b.dcAlpha5)=1 
			AND @AsOnDate BETWEEN CONVERT(DATETIME,b.dcAlpha4) AND CONVERT(DATETIME,b.dcAlpha5)

			SELECT @Total-@Present-@Vacation-@Leave as Balance    '
	END
	ELSE IF(@TypeID=51)	---- On Time Arrival Employees Count 
	BEGIN
		SET @SQL=@SQL+' 
			DECLARE @AsOnDate DATETIME
			SET @AsOnDate=CONVERT(varchar(11),GETDATE(),106)

			SELECT COUNT(dcCCNID51) as Balance FROM (
			SELECT c.dcCCNID51,b.dcAlpha1 as CheckInDate,
			CONVERT(DATETIME,(b.dcAlpha1+'' ''+CONVERT(VARCHAR(8), CONVERT(DATETIME,b.dcAlpha2), 108))) as CheckInTime,
			e.dcCCNID73,sh1.Name,
			CONVERT(DATETIME,(b.dcAlpha1+'' ''+CONVERT(VARCHAR(8), CONVERT(DATETIME,sh1.ccAlpha2), 108))) as ShiftStartTime
			FROM INV_DocDetails a WITH(NOLOCK)
			JOIN COM_DocTextData b WITH(NOLOCK) on b.InvDocDetailsID=a.InvDocDetailsID
			JOIN COM_DocCCData c WITH(NOLOCK) on c.InvDocDetailsID=a.InvDocDetailsID
			LEFT JOIN (SELECT ISNULL(b1.dcCCNID51,1) as dcCCNID51,ISNULL(b1.dcCCNID73,1) as dcCCNID73,CONVERT(DATETIME,d1.dcAlpha5) as FDate,CONVERT(DATETIME,d1.dcAlpha6) as TDate 
			FROM INV_DocDetails a1 WITH(NOLOCK) 
			LEFT JOIN COM_DocCCData b1 WITH(NOLOCK) ON b1.InvDocDetailsID=a1.InvDocDetailsID 
			LEFT JOIN COM_DocTextData d1 WITH(NOLOCK) ON d1.InvDocDetailsID=a1.InvDocDetailsID
			WHERE d1.tCostCenterID=40092 and a1.StatusID=369 
			AND ISDATE(d1.dcAlpha5)=1 AND ISDATE(d1.dcAlpha6)=1
			) e on e.dcCCNID51=c.dcCCNID51 AND CONVERT(DATETIME,b.dcAlpha1) BETWEEN CONVERT(DATETIME,e.FDate) AND CONVERT(DATETIME,e.TDate)  
			LEFT JOIN COM_CC50073 sh1 WITH(NOLOCK) ON ISNULL(e.dcCCNID73,1)=sh1.NodeID
			WHERE b.tCostCenterID=40089 AND a.StatusID IN(369,371,441)
			AND LEN(b.dcAlpha1)=11 AND ISDATE(b.dcAlpha1)=1 
			AND DATEDIFF(day,CONVERT(DATETIME,b.dcAlpha1),@AsOnDate)=0
			) as Tbl
			WHERE ShiftStartTime>CheckInTime '
	END
	ELSE IF(@TypeID=52)	---- Day Summary
	BEGIN
		SET @SQL=@SQL+' 
			DECLARE @AsOnDate DATETIME
			SET @AsOnDate=CONVERT(varchar(11),GETDATE(),106)

			DECLARE @Total INT,@Present INT,@Vacation INT,@Leave INT
			SELECT @Total=COUNT(a1.NodeID)
			FROM COM_CC50051 a1 WITH(NOLOCK)
			WHERE a1.IsGroup=0 AND a1.NodeID<>1 AND a1.DOJ IS NOT NULL
			AND DATEDIFF(day,CONVERT(DATETIME,a1.DOJ),@AsOnDate)>=0
			AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a1.DORelieve),''01-Jan-2200''),@AsOnDate)<=0 

			SELECT @Present=COUNT(DISTINCT c.dcCCNID51) 
			FROM INV_DocDetails a WITH(NOLOCK)
			JOIN COM_DocTextData b WITH(NOLOCK) on b.InvDocDetailsID=a.InvDocDetailsID
			JOIN COM_DocCCData c WITH(NOLOCK) on c.InvDocDetailsID=a.InvDocDetailsID
			WHERE b.tCostCenterID=40089 AND a.StatusID IN(369,371,441)
			AND ISDATE(b.dcAlpha1)=1 
			AND DATEDIFF(day,CONVERT(DATETIME,b.dcAlpha1),@AsOnDate)=0

			SELECT @Vacation= COUNT(DISTINCT c.dcCCNID51)
			FROM INV_DocDetails a WITH(NOLOCK)
			JOIN COM_DocTextData b WITH(NOLOCK) on b.InvDocDetailsID=a.InvDocDetailsID
			JOIN COM_DocCCData c WITH(NOLOCK) on c.InvDocDetailsID=a.InvDocDetailsID
			WHERE b.tCostCenterID=40072 AND a.StatusID IN(369,371,441)
			AND LEN(b.dcAlpha2)=11 AND LEN(b.dcAlpha3)=11 
			AND ISDATE(b.dcAlpha2)=1 AND ISDATE(b.dcAlpha3)=1 
			AND @AsOnDate BETWEEN CONVERT(DATETIME,b.dcAlpha2) AND CONVERT(DATETIME,b.dcAlpha3) 

			SELECT @Leave=COUNT(DISTINCT c.dcCCNID51)
			FROM INV_DocDetails a WITH(NOLOCK)
			JOIN COM_DocTextData b WITH(NOLOCK) on b.InvDocDetailsID=a.InvDocDetailsID
			JOIN COM_DocCCData c WITH(NOLOCK) on c.InvDocDetailsID=a.InvDocDetailsID
			WHERE b.tCostCenterID=40062 AND a.StatusID IN(369,371,441)
			AND LEN(b.dcAlpha4)=11 AND LEN(b.dcAlpha5)=11 
			AND ISDATE(b.dcAlpha4)=1 AND ISDATE(b.dcAlpha5)=1 
			AND @AsOnDate BETWEEN CONVERT(DATETIME,b.dcAlpha4) AND CONVERT(DATETIME,b.dcAlpha5) '

			SET @SQL=@SQL+' SELECT ''Absent'' as Name,@Total-@Present-@Vacation-@Leave as Balance,5 as Seq
			UNION ALL
			SELECT ''On Time'' as Name,COUNT(dcCCNID51) as Balance,1  FROM (
			SELECT c.dcCCNID51,b.dcAlpha1 as CheckInDate,
			CONVERT(DATETIME,(b.dcAlpha1+'' ''+CONVERT(VARCHAR(8), CONVERT(DATETIME,b.dcAlpha2), 108))) as CheckInTime,
			e.dcCCNID73,sh1.Name,
			CONVERT(DATETIME,(b.dcAlpha1+'' ''+CONVERT(VARCHAR(8), CONVERT(DATETIME,sh1.ccAlpha2), 108))) as ShiftStartTime
			FROM INV_DocDetails a WITH(NOLOCK)
			JOIN COM_DocTextData b WITH(NOLOCK) on b.InvDocDetailsID=a.InvDocDetailsID
			JOIN COM_DocCCData c WITH(NOLOCK) on c.InvDocDetailsID=a.InvDocDetailsID
			LEFT JOIN (SELECT ISNULL(b1.dcCCNID51,1) as dcCCNID51,ISNULL(b1.dcCCNID73,1) as dcCCNID73,CONVERT(DATETIME,d1.dcAlpha5) as FDate,CONVERT(DATETIME,d1.dcAlpha6) as TDate 
			FROM INV_DocDetails a1 WITH(NOLOCK) 
			LEFT JOIN COM_DocCCData b1 WITH(NOLOCK) ON b1.InvDocDetailsID=a1.InvDocDetailsID 
			LEFT JOIN COM_DocTextData d1 WITH(NOLOCK) ON d1.InvDocDetailsID=a1.InvDocDetailsID
			WHERE d1.tCostCenterID=40092 and a1.StatusID=369 
			AND ISDATE(d1.dcAlpha5)=1 AND ISDATE(d1.dcAlpha6)=1
			) e on e.dcCCNID51=c.dcCCNID51 AND CONVERT(DATETIME,b.dcAlpha1) BETWEEN CONVERT(DATETIME,e.FDate) AND CONVERT(DATETIME,e.TDate)  
			LEFT JOIN COM_CC50073 sh1 WITH(NOLOCK) ON ISNULL(e.dcCCNID73,1)=sh1.NodeID
			WHERE b.tCostCenterID=40089 AND a.StatusID IN(369,371,441)
			AND LEN(b.dcAlpha1)=11 AND ISDATE(b.dcAlpha1)=1 
			AND DATEDIFF(day,CONVERT(DATETIME,b.dcAlpha1),@AsOnDate)=0
			) as Tbl
			WHERE ShiftStartTime>CheckInTime '
			SET @SQL=@SQL+' UNION ALL
			SELECT ''On Vacation'',COUNT(DISTINCT c.dcCCNID51) as Balance,2
			FROM INV_DocDetails a WITH(NOLOCK)
			JOIN COM_DocTextData b WITH(NOLOCK) on b.InvDocDetailsID=a.InvDocDetailsID
			JOIN COM_DocCCData c WITH(NOLOCK) on c.InvDocDetailsID=a.InvDocDetailsID
			WHERE b.tCostCenterID=40072 AND a.StatusID IN(369,371,441)
			AND LEN(b.dcAlpha2)=11 AND LEN(b.dcAlpha3)=11 
			AND ISDATE(b.dcAlpha2)=1 AND ISDATE(b.dcAlpha3)=1 
			AND @AsOnDate BETWEEN CONVERT(DATETIME,b.dcAlpha2) AND CONVERT(DATETIME,b.dcAlpha3) '
			SET @SQL=@SQL+' UNION ALL
			SELECT ''On Leave'',COUNT(DISTINCT c.dcCCNID51) as Balance,3
			FROM INV_DocDetails a WITH(NOLOCK)
			JOIN COM_DocTextData b WITH(NOLOCK) on b.InvDocDetailsID=a.InvDocDetailsID
			JOIN COM_DocCCData c WITH(NOLOCK) on c.InvDocDetailsID=a.InvDocDetailsID
			WHERE b.tCostCenterID=40062 AND a.StatusID IN(369,371,441)
			AND LEN(b.dcAlpha4)=11 AND LEN(b.dcAlpha5)=11 
			AND ISDATE(b.dcAlpha4)=1 AND ISDATE(b.dcAlpha5)=1 
			AND @AsOnDate BETWEEN CONVERT(DATETIME,b.dcAlpha4) AND CONVERT(DATETIME,b.dcAlpha5) '
			SET @SQL=@SQL+' UNION ALL
			SELECT ''Late Arrival'',COUNT(dcCCNID51),4 FROM (
			SELECT c.dcCCNID51,b.dcAlpha1 as CheckInDate,
			CONVERT(DATETIME,(b.dcAlpha1+'' ''+CONVERT(VARCHAR(8), CONVERT(DATETIME,b.dcAlpha2), 108))) as CheckInTime,
			e.dcCCNID73,sh1.Name,
			CONVERT(DATETIME,(b.dcAlpha1+'' ''+CONVERT(VARCHAR(8), CONVERT(DATETIME,sh1.ccAlpha2), 108))) as ShiftStartTime
			FROM INV_DocDetails a WITH(NOLOCK)
			JOIN COM_DocTextData b WITH(NOLOCK) on b.InvDocDetailsID=a.InvDocDetailsID
			JOIN COM_DocCCData c WITH(NOLOCK) on c.InvDocDetailsID=a.InvDocDetailsID
			LEFT JOIN (SELECT ISNULL(b1.dcCCNID51,1) as dcCCNID51,ISNULL(b1.dcCCNID73,1) as dcCCNID73,CONVERT(DATETIME,d1.dcAlpha5) as FDate,CONVERT(DATETIME,d1.dcAlpha6) as TDate 
			FROM INV_DocDetails a1 WITH(NOLOCK) 
			LEFT JOIN COM_DocCCData b1 WITH(NOLOCK) ON b1.InvDocDetailsID=a1.InvDocDetailsID 
			LEFT JOIN COM_DocTextData d1 WITH(NOLOCK) ON d1.InvDocDetailsID=a1.InvDocDetailsID
			WHERE d1.tCostCenterID=40092 and a1.StatusID=369 
			AND ISDATE(d1.dcAlpha5)=1 AND ISDATE(d1.dcAlpha6)=1
			) e on e.dcCCNID51=c.dcCCNID51 AND CONVERT(DATETIME,b.dcAlpha1) BETWEEN CONVERT(DATETIME,e.FDate) AND CONVERT(DATETIME,e.TDate)  
			LEFT JOIN COM_CC50073 sh1 WITH(NOLOCK) ON ISNULL(e.dcCCNID73,1)=sh1.NodeID
			WHERE b.tCostCenterID=40089 AND a.StatusID IN(369,371,441)
			AND LEN(b.dcAlpha1)=11 AND ISDATE(b.dcAlpha1)=1 
			AND DATEDIFF(day,CONVERT(DATETIME,b.dcAlpha1),@AsOnDate)=0
			) as Tbl
			WHERE ShiftStartTime<CheckInTime
			ORDER BY Seq
			  '
	END
	ELSE IF(@TypeID=53)	---- Documents Expiry in Next 30 days
	BEGIN
		SET @SQL=@SQL+' 
			DECLARE @AsOnDate DATETIME,@Days INT
			SET @AsOnDate=CONVERT(varchar(11),GETDATE(),106)
			SET @Days=30

			SELECT ''Passport'' as Name, COUNT(a.NodeID) as Balance
			FROM COM_CC50051 a WITH(NOLOCK)
			WHERE a.IsGroup=0 AND a.NodeID>1
			AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a.DORelieve),''01-Jan-2200''),@AsOnDate)<=0
			AND PassportNo IS NOT NULL AND PassportNo <> '''' AND PassportExpDate IS NOT NULL AND PassportExpDate<>''''
			AND CONVERT(DATETIME,PassportExpDate) BETWEEN @AsOnDate AND DATEADD(day,@Days,@AsOnDate) '
			SET @SQL=@SQL+' UNION ALL
			SELECT ''Visa'' as Name, COUNT(a.NodeID) as Balance
			FROM COM_CC50051 a WITH(NOLOCK)
			WHERE a.IsGroup=0 AND a.NodeID>1
			AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a.DORelieve),''01-Jan-2200''),@AsOnDate)<=0
			AND VisaNo IS NOT NULL AND VisaNo <> '''' AND VisaExpDate IS NOT NULL AND VisaExpDate<>''''
			AND CONVERT(DATETIME,VisaExpDate) BETWEEN @AsOnDate AND DATEADD(day,@Days,@AsOnDate) '
			SET @SQL=@SQL+' UNION ALL
			SELECT ''Labour Card'' as Name, COUNT(a.NodeID) as Balance
			FROM COM_CC50051 a WITH(NOLOCK)
			WHERE a.IsGroup=0 AND a.NodeID>1
			AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a.DORelieve),''01-Jan-2200''),@AsOnDate)<=0
			AND IqamaNo IS NOT NULL AND IqamaNo <> '''' AND IqamaExpDate IS NOT NULL AND IqamaExpDate<>''''
			AND CONVERT(DATETIME,IqamaExpDate) BETWEEN @AsOnDate AND DATEADD(day,@Days,@AsOnDate) '
			SET @SQL=@SQL+' UNION ALL
			SELECT ''ID Card'' as Name, COUNT(a.NodeID) as Balance
			FROM COM_CC50051 a WITH(NOLOCK)
			WHERE a.IsGroup=0 AND a.NodeID>1
			AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a.DORelieve),''01-Jan-2200''),@AsOnDate)<=0
			AND IDNo IS NOT NULL AND IDNo <> '''' AND IDExpDate IS NOT NULL AND IDExpDate<>''''
			AND CONVERT(DATETIME,IDExpDate) BETWEEN @AsOnDate AND DATEADD(day,@Days,@AsOnDate) '
			SET @SQL=@SQL+' UNION ALL
			SELECT ''Driving License'' as Name, COUNT(a.NodeID) as Balance
			FROM COM_CC50051 a WITH(NOLOCK)
			WHERE a.IsGroup=0 AND a.NodeID>1
			AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a.DORelieve),''01-Jan-2200''),@AsOnDate)<=0
			AND LicenseNo IS NOT NULL AND LicenseNo <> '''' AND LicenseExpDate IS NOT NULL AND LicenseExpDate<>''''
			AND CONVERT(DATETIME,LicenseExpDate) BETWEEN @AsOnDate AND DATEADD(day,@Days,@AsOnDate) '
			SET @SQL=@SQL+' UNION ALL
			SELECT ''Medical'' as Name, COUNT(a.NodeID) as Balance
			FROM COM_CC50051 a WITH(NOLOCK)
			WHERE a.IsGroup=0 AND a.NodeID>1
			AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a.DORelieve),''01-Jan-2200''),@AsOnDate)<=0
			AND MedicalNo IS NOT NULL AND MedicalNo <> '''' AND MedicalExpDate IS NOT NULL AND MedicalExpDate<>''''
			AND CONVERT(DATETIME,MedicalExpDate) BETWEEN @AsOnDate AND DATEADD(day,@Days,@AsOnDate) '
	END
	ELSE IF(@TypeID=54)	---- Documents Expiry in Next 60 days
	BEGIN
		SET @SQL=@SQL+' 
			DECLARE @AsOnDate DATETIME,@Days INT
			SET @AsOnDate=CONVERT(varchar(11),GETDATE(),106)
			SET @Days=60

			SELECT ''Passport'' as Name, COUNT(a.NodeID) as Balance
			FROM COM_CC50051 a WITH(NOLOCK)
			WHERE a.IsGroup=0 AND a.NodeID>1
			AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a.DORelieve),''01-Jan-2200''),@AsOnDate)<=0
			AND PassportNo IS NOT NULL AND PassportNo <> '''' AND PassportExpDate IS NOT NULL AND PassportExpDate<>''''
			AND CONVERT(DATETIME,PassportExpDate) BETWEEN @AsOnDate AND DATEADD(day,@Days,@AsOnDate) '
			SET @SQL=@SQL+' UNION ALL
			SELECT ''Visa'' as Name, COUNT(a.NodeID) as Balance
			FROM COM_CC50051 a WITH(NOLOCK)
			WHERE a.IsGroup=0 AND a.NodeID>1
			AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a.DORelieve),''01-Jan-2200''),@AsOnDate)<=0
			AND VisaNo IS NOT NULL AND VisaNo <> '''' AND VisaExpDate IS NOT NULL AND VisaExpDate<>''''
			AND CONVERT(DATETIME,VisaExpDate) BETWEEN @AsOnDate AND DATEADD(day,@Days,@AsOnDate) '
			SET @SQL=@SQL+' UNION ALL
			SELECT ''Labour Card'' as Name, COUNT(a.NodeID) as Balance
			FROM COM_CC50051 a WITH(NOLOCK)
			WHERE a.IsGroup=0 AND a.NodeID>1
			AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a.DORelieve),''01-Jan-2200''),@AsOnDate)<=0
			AND IqamaNo IS NOT NULL AND IqamaNo <> '''' AND IqamaExpDate IS NOT NULL AND IqamaExpDate<>''''
			AND CONVERT(DATETIME,IqamaExpDate) BETWEEN @AsOnDate AND DATEADD(day,@Days,@AsOnDate) '
			SET @SQL=@SQL+' UNION ALL
			SELECT ''ID Card'' as Name, COUNT(a.NodeID) as Balance
			FROM COM_CC50051 a WITH(NOLOCK)
			WHERE a.IsGroup=0 AND a.NodeID>1
			AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a.DORelieve),''01-Jan-2200''),@AsOnDate)<=0
			AND IDNo IS NOT NULL AND IDNo <> '''' AND IDExpDate IS NOT NULL AND IDExpDate<>''''
			AND CONVERT(DATETIME,IDExpDate) BETWEEN @AsOnDate AND DATEADD(day,@Days,@AsOnDate) '
			SET @SQL=@SQL+' UNION ALL
			SELECT ''Driving License'' as Name, COUNT(a.NodeID) as Balance
			FROM COM_CC50051 a WITH(NOLOCK)
			WHERE a.IsGroup=0 AND a.NodeID>1
			AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a.DORelieve),''01-Jan-2200''),@AsOnDate)<=0
			AND LicenseNo IS NOT NULL AND LicenseNo <> '''' AND LicenseExpDate IS NOT NULL AND LicenseExpDate<>''''
			AND CONVERT(DATETIME,LicenseExpDate) BETWEEN @AsOnDate AND DATEADD(day,@Days,@AsOnDate) '
			SET @SQL=@SQL+' UNION ALL
			SELECT ''Medical'' as Name, COUNT(a.NodeID) as Balance
			FROM COM_CC50051 a WITH(NOLOCK)
			WHERE a.IsGroup=0 AND a.NodeID>1
			AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a.DORelieve),''01-Jan-2200''),@AsOnDate)<=0
			AND MedicalNo IS NOT NULL AND MedicalNo <> '''' AND MedicalExpDate IS NOT NULL AND MedicalExpDate<>''''
			AND CONVERT(DATETIME,MedicalExpDate) BETWEEN @AsOnDate AND DATEADD(day,@Days,@AsOnDate) '
	END
	ELSE IF(@TypeID=55)	---- Documents Expiry in Next 90 days
	BEGIN
		SET @SQL=@SQL+' 
			DECLARE @AsOnDate DATETIME,@Days INT
			SET @AsOnDate=CONVERT(varchar(11),GETDATE(),106)
			SET @Days=90

			SELECT ''Passport'' as Name, COUNT(a.NodeID) as Balance
			FROM COM_CC50051 a WITH(NOLOCK)
			WHERE a.IsGroup=0 AND a.NodeID>1
			AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a.DORelieve),''01-Jan-2200''),@AsOnDate)<=0
			AND PassportNo IS NOT NULL AND PassportNo <> '''' AND PassportExpDate IS NOT NULL AND PassportExpDate<>''''
			AND CONVERT(DATETIME,PassportExpDate) BETWEEN @AsOnDate AND DATEADD(day,@Days,@AsOnDate) '
			SET @SQL=@SQL+' UNION ALL
			SELECT ''Visa'' as Name, COUNT(a.NodeID) as Balance
			FROM COM_CC50051 a WITH(NOLOCK)
			WHERE a.IsGroup=0 AND a.NodeID>1
			AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a.DORelieve),''01-Jan-2200''),@AsOnDate)<=0
			AND VisaNo IS NOT NULL AND VisaNo <> '''' AND VisaExpDate IS NOT NULL AND VisaExpDate<>''''
			AND CONVERT(DATETIME,VisaExpDate) BETWEEN @AsOnDate AND DATEADD(day,@Days,@AsOnDate) '
			SET @SQL=@SQL+' UNION ALL
			SELECT ''Labour Card'' as Name, COUNT(a.NodeID) as Balance
			FROM COM_CC50051 a WITH(NOLOCK)
			WHERE a.IsGroup=0 AND a.NodeID>1
			AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a.DORelieve),''01-Jan-2200''),@AsOnDate)<=0
			AND IqamaNo IS NOT NULL AND IqamaNo <> '''' AND IqamaExpDate IS NOT NULL AND IqamaExpDate<>''''
			AND CONVERT(DATETIME,IqamaExpDate) BETWEEN @AsOnDate AND DATEADD(day,@Days,@AsOnDate) '
			SET @SQL=@SQL+' UNION ALL
			SELECT ''ID Card'' as Name, COUNT(a.NodeID) as Balance
			FROM COM_CC50051 a WITH(NOLOCK)
			WHERE a.IsGroup=0 AND a.NodeID>1
			AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a.DORelieve),''01-Jan-2200''),@AsOnDate)<=0
			AND IDNo IS NOT NULL AND IDNo <> '''' AND IDExpDate IS NOT NULL AND IDExpDate<>''''
			AND CONVERT(DATETIME,IDExpDate) BETWEEN @AsOnDate AND DATEADD(day,@Days,@AsOnDate) '
			SET @SQL=@SQL+' UNION ALL
			SELECT ''Driving License'' as Name, COUNT(a.NodeID) as Balance
			FROM COM_CC50051 a WITH(NOLOCK)
			WHERE a.IsGroup=0 AND a.NodeID>1
			AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a.DORelieve),''01-Jan-2200''),@AsOnDate)<=0
			AND LicenseNo IS NOT NULL AND LicenseNo <> '''' AND LicenseExpDate IS NOT NULL AND LicenseExpDate<>''''
			AND CONVERT(DATETIME,LicenseExpDate) BETWEEN @AsOnDate AND DATEADD(day,@Days,@AsOnDate) '
			SET @SQL=@SQL+' UNION ALL
			SELECT ''Medical'' as Name, COUNT(a.NodeID) as Balance
			FROM COM_CC50051 a WITH(NOLOCK)
			WHERE a.IsGroup=0 AND a.NodeID>1
			AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a.DORelieve),''01-Jan-2200''),@AsOnDate)<=0
			AND MedicalNo IS NOT NULL AND MedicalNo <> '''' AND MedicalExpDate IS NOT NULL AND MedicalExpDate<>''''
			AND CONVERT(DATETIME,MedicalExpDate) BETWEEN @AsOnDate AND DATEADD(day,@Days,@AsOnDate) '
	END
	ELSE IF(@TypeID=56)	---- Leave Summary
	BEGIN
		SET @SQL=@SQL+' 
			DECLARE @FromDate DATETIME,@ToDate DATETIME,@tDate DATETIME
			SET @FromDate=DATEADD(m,DATEDIFF(m,0,GETDATE()),0)
			SET @ToDate= DATEADD(D,-1,DATEADD(M,DATEDIFF(M,0,GETDATE())+1,0))
			
			--SET @FromDate=@Fr
			--SET @ToDate=@To

			SET @tDate=@FromDate
			DECLARE @Tbl TABLE (Name NVARCHAR(15),Balance INT)

			SELECT c.dcCCNID51,CONVERT(DATETIME,b.dcAlpha4) as dcAlpha4,CONVERT(DATETIME,b.dcAlpha5) as dcAlpha5 INTO #t1
			FROM INV_DocDetails a WITH(NOLOCK)
			JOIN COM_DocTextData b WITH(NOLOCK) on b.InvDocDetailsID=a.InvDocDetailsID
			JOIN COM_DocCCData c WITH(NOLOCK) on c.InvDocDetailsID=a.InvDocDetailsID
			WHERE b.tCostCenterID=40062 AND a.StatusID IN(369,371,441)
			AND LEN(b.dcAlpha4)=11 AND LEN(b.dcAlpha5)=11 
			AND ISDATE(b.dcAlpha4)=1 AND ISDATE(b.dcAlpha5)=1 

			WHILE (@tDate<=@ToDate)
			BEGIN
				INSERT INTO @Tbl 
				SELECT CONVERT(VARCHAR(11),@tDate,106),COUNT(DISTINCT dcCCNID51) 
				FROM #t1 a WITH(NOLOCK)
				WHERE @tDate BETWEEN CONVERT(DATETIME,dcAlpha4) AND CONVERT(DATETIME,dcAlpha5) 

				SET @tDate=DATEADD(day,1,@tDate)
			END

			SELECT * FROM @Tbl

			DROP TABLE #T1 '
	END
	ELSE IF(@TypeID=57)	---- Salary Range (Actuals) wise Employee Count
	BEGIN
		SET @SQL=@SQL+'
		DECLARE @AsOnDate DATETIME,@i INT,@Fdt INT,@EC INT
		SET @AsOnDate=CONVERT(varchar(11),GETDATE(),106)

		SELECT a1.NodeID,c1.NetSalary INTO #ANS
		FROM COM_CC50051 a1 WITH(NOLOCK)
		JOIN (SELECT p.EmployeeID,MAX(p.EffectFrom) EffectFrom  FROM PAY_EmpPay p WITH(NOLOCK) GROUP BY p.EmployeeID) b on b.EmployeeID=a1.NodeID
		JOIN PAY_EmpPay c1 WITH(NOLOCK) on c1.EmployeeID=a1.NodeID AND c1.EffectFrom=b.EffectFrom
		WHERE a1.IsGroup=0 AND a1.NodeID<>1 AND a1.DOJ IS NOT NULL
		AND DATEDIFF(day,CONVERT(DATETIME,a1.DOJ),@AsOnDate)>=0
		AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a1.DORelieve),''01-Jan-2200''),@AsOnDate)<=0

		DECLARE @TS TABLE(FSlot INT,TSlot INT,ECount INT)
		SET @i=1
		SET @Fdt=0

		WHILE(@i<=100)
		BEGIN
			SET @EC=0
			SET @Fdt+=1
			SELECT @EC=COUNT(NodeID) FROM #ANS WHERE NetSalary BETWEEN @FDt AND (@FDt+9999)
			INSERT INTO @TS
			SELECT @FDt,@FDt+9999,@EC
			SET @Fdt+=9999
		SET @i=@i+1
		END

		DELETE FROM @TS WHERE ECount=0
		DROP TABLE #ANS

		SELECT CAST(FSlot as varchar) +'' - ''+CAST(TSlot as varchar) as Name,ECount as Balance
		FROM @TS
		ORDER BY FSlot '
	END
	ELSE IF(@TypeID=58)	---- Salary Range (Earned) wise Employee Count
	BEGIN
		SET @SQL=@SQL+'
		DECLARE @AsOnDate DATETIME,@i INT,@Fdt INT,@EC INT
		SET @AsOnDate=CONVERT(varchar(11),GETDATE(),106)

		SELECT a1.NodeID,CONVERT(FLOAT,ct.dcAlpha3) NetSalary INTO #ENS
		FROM COM_CC50051 a1 WITH(NOLOCK)
		JOIN (SELECT pc.dcCCNID51,MAX(p.DueDate) as DueDate  
			FROM INV_DocDetails p WITH(NOLOCK) 
			JOIN COM_DocTextData pt WITH(NOLOCK) on pt.InvDocDetailsID=p.InvDocDetailsID
			JOIN COM_DocCCData pc WITH(NOLOCK) on pc.InvDocDetailsID=p.InvDocDetailsID
			WHERE pt.tCostCenterID=40054 AND p.StatusID=369 AND p.VoucherType=11
			AND DATEDIFF(day,CONVERT(DATETIME,p.DueDate),@AsOnDate)>=0 
			GROUP BY pc.dcCCNID51
			) b on b.dcCCNID51=a1.NodeID

		JOIN INV_DocDetails c1 WITH(NOLOCK) on c1.DueDate=b.DueDate 
		JOIN COM_DocCCData cc WITH(NOLOCK) on cc.InvDocDetailsID=c1.InvDocDetailsID AND cc.dcCCNID51=b.dcCCNID51
		JOIN COM_DocTextData ct WITH(NOLOCK) on ct.InvDocDetailsID=c1.InvDocDetailsID

		WHERE a1.IsGroup=0 AND a1.NodeID<>1 AND a1.DOJ IS NOT NULL
		AND DATEDIFF(day,CONVERT(DATETIME,a1.DOJ),@AsOnDate)>=0
		AND DATEDIFF(day,ISNULL(CONVERT(DATETIME,a1.DORelieve),''01-Jan-2200''),@AsOnDate)<=0
		AND c1.VoucherType=11 

		DECLARE @TS TABLE(FSlot INT,TSlot INT,ECount INT)
		SET @i=1
		SET @Fdt=0

		WHILE(@i<=100)
		BEGIN
			SET @EC=0
			SET @Fdt+=1
			SELECT @EC=COUNT(NodeID) FROM #ENS WHERE NetSalary BETWEEN @FDt AND (@FDt+9999)
			INSERT INTO @TS
			SELECT @FDt,@FDt+9999,@EC
			SET @Fdt+=9999
		SET @i=@i+1
		END

		DELETE FROM @TS WHERE ECount=0
		DROP TABLE #ENS

		SELECT CAST(FSlot as varchar) +'' - ''+CAST(TSlot as varchar) as Name,ECount as Balance
		FROM @TS
		ORDER BY FSlot '
	END
	ELSE IF(@TypeID=59)	---- Inactive Employee Count
	BEGIN
		SET @SQL=@SQL+'
		select count(*) Balance
		from COM_CC50051 E with(nolock)
		where E.StatusID=251 and E.IsGroup=0 and E.NodeID<>1 AND E.DOJ<=@To'
	END
	ELSE IF(@TypeID=60)	---- Employee CheckIn-Out
	BEGIN
		SET @SQL=@SQL+'

		DECLARE @Cnt INT
		SET @Cnt=0
		SELECT @Cnt=a.InvDocDetailsID 
		FROM INV_DocDetails a WITH(NOLOCK)
		JOIN COM_DocTextData b WITH(NOLOCK) ON b.InvDocDetailsID=a.InvDocDetailsID
		JOIN COM_DocCCData c WITH(NOLOCK) ON c.InvDocDetailsID=a.InvDocDetailsID
		WHERE b.tCostCenterID=40089 AND StatusID=369
		AND c.dcCCNID51=@EMPID
		AND DATEDIFF(day,CONVERT(DATETIME,dcAlpha1),@To)=0
		IF(@Cnt>0)
		BEGIN
			Select CASE WHEN (dcAlpha2 IS NULL OR dcAlpha2='''') AND (dcAlpha4 IS NULL OR dcAlpha4='''') THEN ''* - *''
			WHEN (dcAlpha2 IS NULL OR dcAlpha2='''') AND (dcAlpha4 IS NOT NULL AND dcAlpha4<>'''') THEN ''* - ''+SUBSTRING(dcAlpha4,13,5)
			WHEN (dcAlpha2 IS NOT NULL AND dcAlpha2<>'''') AND (dcAlpha4 IS NULL OR dcAlpha4='''') THEN SUBSTRING(dcAlpha2,13,5)+'' - *''
			WHEN (dcAlpha2 IS NOT NULL AND dcAlpha2<>'''') AND (dcAlpha4 IS NOT NULL AND dcAlpha4<>'''') THEN SUBSTRING(dcAlpha2,13,5)+'' - ''+SUBSTRING(dcAlpha4,13,5) END as Balance
			FROM INV_DocDetails a WITH(NOLOCK)
			JOIN COM_DocTextData b WITH(NOLOCK) ON b.InvDocDetailsID=a.InvDocDetailsID
			JOIN COM_DocCCData c WITH(NOLOCK) ON c.InvDocDetailsID=a.InvDocDetailsID
			WHERE b.tCostCenterID=40089 AND StatusID=369
			AND c.dcCCNID51=@EMPID
			AND DATEDIFF(day,CONVERT(DATETIME,dcAlpha1),@To)=0
		END
		ELSE
		SELECT ''* - *'' as Balance '
	END
	ELSE IF(@TypeID=61)	---- Month wise Net Salary
	BEGIN
		SET @SQL=@SQL+'
		SELECT SUBSTRING(CONVERT(VARCHAR(11),CONVERT(DATETIME,a.DueDate), 113), 4, 8) as Name,SUM(CONVERT(FLOAT,b.dcAlpha3)) as Balance
		FROM INV_DocDetails a WITH(NOLOCK)
		JOIN COM_DocTextData b WITH(NOLOCK) ON b.InvDocDetailsID=a.InvDocDetailsID
		JOIN COM_DocCCData c WITH(NOLOCK) ON c.InvDocDetailsID=a.InvDocDetailsID
		WHERE ISNUMERIC(b.dcAlpha3)=1 AND b.tCostCenterID=40054 AND StatusID=369 AND a.VoucherType=11
		AND a.DueDate BETWEEN @Fr AND @To
		GROUP BY a.DueDate
		ORDER BY a.DueDate '
	END
	ELSE IF(@TypeID=62)	---- Month wise Employee Count
	BEGIN
		SET @SQL=@SQL+'
		SELECT SUBSTRING(CONVERT(VARCHAR(11),CONVERT(DATETIME,a.DueDate), 113), 4, 8) as Name,COUNT(CONVERT(FLOAT,c.dcCCNID51)) as Balance
		FROM INV_DocDetails a WITH(NOLOCK)
		JOIN COM_DocTextData b WITH(NOLOCK) ON b.InvDocDetailsID=a.InvDocDetailsID
		JOIN COM_DocCCData c WITH(NOLOCK) ON c.InvDocDetailsID=a.InvDocDetailsID
		WHERE ISNUMERIC(b.dcAlpha3)=1 AND b.tCostCenterID=40054 AND StatusID=369 AND a.VoucherType=11
		AND a.DueDate BETWEEN @Fr AND @To
		GROUP BY a.DueDate
		ORDER BY a.DueDate '
	END
	ELSE IF(@TypeID=63)	---- Year wise Service Distribution
	BEGIN
		SET @SQL=@SQL+'
		DECLARE @i INT,@Fdt INT,@EC INT
		Select FLOOR(DATEDIFF(d,CONVERT(DATETIME,DOJ),GETDATE())/365.25) as Exp,COUNT(a.NodeID) as NodeID INTO #YWD
		From COM_CC50051 a WITH(NOLOCK)
		WHERE a.StatusID=250 and a.IsGroup=0 and a.DOJ<=@To AND a.NodeID<>1
		AND (a.DORelieve is null or a.DORelieve>@To)
		GROUP BY FLOOR(DATEDIFF(d,CONVERT(DATETIME,DOJ),GETDATE())/365.25)
		ORDER BY Exp

		DECLARE @TS TABLE(FSlot INT,TSlot INT,ECount INT)
		SET @i=0
		SET @Fdt=0

		WHILE(@i<=39)
		BEGIN
			SET @EC=0
			SET @Fdt+=0
			SELECT @EC=SUM(NodeID) FROM #YWD WHERE Exp BETWEEN @FDt AND (@FDt+2)
			INSERT INTO @TS
			SELECT @FDt,@FDt+2,@EC
			SET @Fdt+=2
		SET @i=@i+1
		END

		DELETE FROM @TS WHERE ECount=0
		DROP TABLE #YWD

		SELECT CAST(FSlot as varchar) +'' - ''+CAST(TSlot as varchar) as Name,ISNULL(ECount,0) as Balance
		FROM @TS
		ORDER BY FSlot '

		END
	ELSE IF(@TypeID=64)	---- Age wise Service Distribution
	BEGIN
		SET @SQL=@SQL+'
		DECLARE @i INT,@Fdt INT,@EC INT
		Select FLOOR(DATEDIFF(d,CONVERT(DATETIME,DOB),GETDATE())/365.25) as Age,COUNT(a.NodeID) as NodeID INTO #AWD
		From COM_CC50051 a WITH(NOLOCK)
		WHERE a.StatusID=250 and a.IsGroup=0 and a.DOJ<=@To AND a.NodeID<>1
		AND (a.DORelieve is null or a.DORelieve>@To)
		AND FLOOR(DATEDIFF(d,CONVERT(DATETIME,DOB),GETDATE())/365.25)>14
		GROUP BY FLOOR(DATEDIFF(d,CONVERT(DATETIME,DOB),GETDATE())/365.25)
		ORDER BY Age

		DECLARE @TS TABLE(FSlot INT,TSlot INT,ECount INT)
		SET @i=0
		SET @Fdt=15

		WHILE(@i<=12)
		BEGIN
			SET @EC=0
			SET @Fdt+=0
			SELECT @EC=SUM(NodeID) FROM #AWD WHERE Age BETWEEN @FDt AND (@FDt+5)
			INSERT INTO @TS
			SELECT @FDt,@FDt+5,@EC
			SET @Fdt+=5
		SET @i=@i+1
		END

		DELETE FROM @TS WHERE ECount=0
		DROP TABLE #AWD

		SELECT CAST(FSlot as varchar) +'' - ''+CAST(TSlot as varchar) as Name,ISNULL(ECount,0) as Balance
		FROM @TS
		ORDER BY FSlot '

	END
	ELSE IF(@TypeID=65)	---- Employee Last Salary Processed
	BEGIN
		SET @SQL=@SQL+'
		SELECT TOP 1 REPLACE(SUBSTRING(CONVERT(VARCHAR(11), CONVERT(DATETIME,a.DueDate), 113), 4, 8),'' '',''-'') as Balance
		FROM INV_DocDetails a WITH(NOLOCK)
		JOIN COM_DocCCData c WITH(NOLOCK) ON c.InvDocDetailsID=a.InvDocDetailsID
		WHERE a.CostCenterID=40054 AND StatusID=369 AND a.VoucherType=11
		AND c.dcCCNID51=@EMPID
		ORDER BY CONVERT(DATETIME,a.DueDate) DESC
		'
	END
	ELSE IF(@TypeID=67)	---- Employee Leaves Statistics
	BEGIN
		DECLARE @LT NVARCHAR(100)
		SELECT @LT=Value from ADM_GlobalPreferences WITH(NOLOCK) WHERE Name like 'ConsiderLOPBasedOn'
		SET @SQL=@SQL+'
		SELECT ISNULL(SUM(ISNULL(AssignedLeaves,0)),0) Assigned,ISNULL(SUM(ISNULL(DeductedLeaves,0)),0) Deducted,ISNULL(SUM(ISNULL(BalanceLeaves,0)),0) as Balance
		FROM PAY_EmployeeLeaveDetails WITH(NOLOCK)
		WHERE YEAR(LeaveYear)=YEAR(GETDATE())
		AND EmployeeID=@EMPID '
		IF(@LT IS NOT NULL AND LEN(@LT)>0)
		BEGIN
		SET @SQL=@SQL+' AND LeaveTypeID NOT IN('+@LT+')'
		END
	END
	ELSE IF(@TypeID=68)	---- Employee Month wise Leaves Taken
	BEGIN
		SET @SQL=@SQL+'
		SELECT REPLACE(SUBSTRING(CONVERT(VARCHAR(11), CONVERT(DATETIME,a.DueDate), 113), 4, 8),'' '',''-'') as Name,SUM(ISNULL(CONVERT(FLOAT,d.dcAlpha6),0)) as Balance
		FROM INV_DocDetails a WITH(NOLOCK)
		JOIN COM_DocCCData c WITH(NOLOCK) ON c.InvDocDetailsID=a.InvDocDetailsID
		JOIN COM_DocTextData d WITH(NOLOCK) ON d.InvDocDetailsID=a.InvDocDetailsID
		WHERE d.tCostCenterID=40054 AND StatusID=369 AND a.VoucherType=11
		AND c.dcCCNID51=@EMPID
		AND a.DueDate BETWEEN @Fr AND @To
		GROUP BY a.DueDate
		ORDER BY CONVERT(DATETIME,a.DueDate) '
	END
	ELSE IF(@TypeID=69)	---- Employee Last Increment done
	BEGIN
		SET @SQL=@SQL+'
		SELECT TOP 1 REPLACE(SUBSTRING(CONVERT(VARCHAR(11), CONVERT(DATETIME,a.EffectFrom), 113), 4, 8),'' '',''-'') as Balance
		FROM PAY_EmpPay a WITH(NOLOCK)
		WHERE EmployeeID=@EMPID 
		ORDER BY a.EffectFrom DESC '
	END
	ELSE IF(@TypeID=70)	---- Employee Month wise Net Salary
	BEGIN
		SET @SQL=@SQL+'
		SELECT SUBSTRING(CONVERT(VARCHAR(11),CONVERT(DATETIME,a.DueDate), 113), 4, 8) as Name,SUM(CONVERT(FLOAT,b.dcAlpha3)) as Balance
		FROM INV_DocDetails a WITH(NOLOCK)
		JOIN COM_DocTextData b WITH(NOLOCK) ON b.InvDocDetailsID=a.InvDocDetailsID
		JOIN COM_DocCCData c WITH(NOLOCK) ON c.InvDocDetailsID=a.InvDocDetailsID
		WHERE ISNUMERIC(b.dcAlpha3)=1 AND b.tCostCenterID=40054 AND StatusID=369 AND a.VoucherType=11
		AND a.DueDate BETWEEN @Fr AND @To
		AND c.dcCCNID51=@EMPID
		GROUP BY a.DueDate
		ORDER BY a.DueDate '
	END
	ELSE IF(@TypeID=71)	---- Employee Loan Summary
	BEGIN
		SET @SQL=@SQL+'
		SELECT CONVERT(NVARCHAR,SUM(PaidAmount)) +''/''+CONVERT(NVARCHAR,SUM(M.ApprovedAmount)) as Balance 
		FROM (
		SELECT distinct CONVERT(FLOAT,dcAlpha2) ApprovedAmount,Voucherno,ISNULL(PaidAmount,0) PaidAmount
		FROM INV_DocDetails a WITH(NOLOCK)
		LEFT JOIN COM_DocCCData b WITH(NOLOCK) ON B.InvDocDetailsID=a.InvDocDetailsID
		LEFT JOIN COM_DocTextData d WITH(NOLOCK) ON d.InvDocDetailsID=a.InvDocDetailsID
		LEFT JOIN (SELECT B.dcCCNID51,SUM(n.dcCalcNum3) PaidAmount,A.RefNo
		FROM INV_DocDetails a WITH(NOLOCK)
		LEFT JOIN COM_DocCCData b WITH(NOLOCK) ON B.InvDocDetailsID=a.InvDocDetailsID
		LEFT JOIN COM_DocNumData n WITH(NOLOCK) ON n.InvDocDetailsID=a.InvDocDetailsID
		WHERE a.CostCenterID=40057  AND a.StatusID=369
		GROUP BY B.dcCCNID51,A.RefNo) AS O ON O.dcCCNID51=b.dcCCNID51 AND O.RefNo=A.VoucherNo
		WHERE d.tCostCenterID=40056  AND a.StatusID=369 
		AND b.dcCCNID51=@EMPID
		) AS M
		'
	END




	PRINT(@SQL)
	EXEC (@SQL)

SET NOCOUNT OFF;  
RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
SET NOCOUNT OFF  
RETURN -999   
END CATCH

GO
