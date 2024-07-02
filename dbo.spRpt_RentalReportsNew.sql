USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRpt_RentalReportsNew]
	@ReportType [int],
	@FromDate [datetime],
	@ToDate [datetime],
	@WHERE1 [nvarchar](max),
	@WHERE2 [nvarchar](max),
	@FromTag [nvarchar](max),
	@SelectTag [nvarchar](max),
	@MaxSelectTag [nvarchar](max),
	@OrderBy [nvarchar](max),
	@UserID [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
Begin Try    
SET NOCOUNT ON;  
DECLARE @SQL NVARCHAR(MAX),@From nvarchar(50),@To nvarchar(50)
SET @From=convert(nvarchar,CONVERT(FLOAT,@FromDate))
SET @To=convert(nvarchar,CONVERT(FLOAT,@ToDate))

IF @OrderBy<>''
BEGIN
	IF @ReportType=73
		SET @OrderBy=','+@OrderBy
	ELSE
		SET @OrderBy=@OrderBy+','
END

IF @ReportType=73--GetPropertyProfitSummary
BEGIN
	SET @SQL=' SELECT P.Name [Property],P.Name [PropertySORT],U.Name [Unit],T.FirstName [Tenant],P.NodeID [Property_ID],U.UnitID [Unit_ID],T.TenantID [Tenant_ID],C.CONTRACTID [SNO_ID],CONVERT(DATETIME,C.StartDate) [StartDate],CONVERT(DATETIME,C.EndDate) EndDate,CONVERT(DATETIME,C.TerminationDate) TerminationDate,RS.Status ContractStatus,C.ContractNumber,U.AnnualRent,
ISNULL(CP.Amount,0) TotalAmount,CASE WHEN CONVERT(DATETIME,C.EndDate)  >= '+@From+'  THEN  CP.Amount  else 0 end AS ActiveAmount,
0.0 RentDay,0.0 ReportDays,0.0 RentMonth,0.0 RentAmountMonth,0.0 RentTotMonths,0.0 Rent,C.SNO,C.SNO TrackNo,T.Phone1 Phone1,U.Lft UnitLft '+@SelectTag+'
FROM REN_Property P with(nolock) 
JOIN REN_Contract C with(nolock) ON C.PropertyID=P.NodeID AND C.IsGroup <> 1 AND C.COSTCENTERID = 95
LEFT JOIN COM_STATUS RS with(nolock) ON  RS.StatusID=C.StatusID 
JOIN REN_Units U with(nolock)  ON C.UnitID=U.UnitID AND CONVERT(DATETIME,C.StartDate) <= '+@To+' AND CONVERT(DATETIME,ISNULL(C.TerminationDate,C.EndDate)) >= '+@From+'     
JOIN REN_Tenant T with(nolock) ON  C.TenantID=T.TenantID 
JOIN REN_ContractParticulars CP with(nolock) ON C.CONTRACTID = CP.CONTRACTID  AND CP.SNO = 1'+@FromTag+'
where C.StatusID not in (451,440,466)  AND C.CONTRACTID NOT IN (SELECT RenewRefID FROM REN_Contract with(nolock) 
WHERE RenewRefID>0 AND CONVERT(DATETIME,StartDate) <= '+@To+' AND CONVERT(DATETIME,ISNULL(TerminationDate,EndDate)) >= '+@From+' )  
'+@WHERE1+'
order by PropertySORT'+@OrderBy  -- AND C.STATUSID <> 428 earlier we were filtering terminated records here
	EXEC sp_executesql @SQL
END
ELSE IF @ReportType=209--Contract Due for Renewal
BEGIN
	SET @SQL='declare @todate float
set @todate='+@To+'

select UnitID,max(EndDate) EndDate into #tab from
		(select C.UnitID,max(ISNULL(ISNULL(C.TerminationDate,c.RefundDate),C.EndDate)) EndDate from ren_contract C with(nolock) left join ren_contract CU with(nolock) on CU.RefContractID=C.ContractID where CU.ContractID is null AND c.statusid NOT IN (441) group by C.UnitID
		union all
		select CU.UnitID,max(ISNULL(ISNULL(C.TerminationDate,c.RefundDate),C.EndDate)) EndDate from ren_contract C with(nolock) inner join ren_contract CU with(nolock) on CU.RefContractID=C.ContractID where c.statusid NOT IN (451) group by CU.UnitID) as t
	group by UnitID

SELECT contractid,MAX(Sno) Sno,MAX(Property) Property,MAX(Unit) Unit,MAX(Property) PropertySORT,MAX(Unit) UnitSORT,MAX(Tenant) Tenant,MAX(Phone1) Phone1,MAX(Phone2) Phone2,MAX(Purpose) Purpose,
MAX(StartDate) StartDate,MAX(EndDate) EndDate,MAX(Rent) Rent,MAX(TotalAmount) TotalAmount,MAX(UnitStatus) UnitStatus,MAX(NoOfDays) NoOfDays,MAX([Property_ID]) [Property_ID],MAX([Unit_ID]) [Unit_ID],MAX([Tenant_ID]) [Tenant_ID],contractid Sno_ID,MIN([Status]) [Status],MAX(UnitID) UnitID'+@MaxSelectTag+'
FROM (
SELECT distinct C.contractid,C.Sno, 
P.Name Property,U.Name Unit,P.NodeID [Property_ID],U.UnitID [Unit_ID],T.TenantID [Tenant_ID],
T.FirstName Tenant,T.Phone1 Phone1,
T.Phone2 Phone2,C.Purpose Purpose,
CONVERT(DATETIME,C.StartDate) StartDate,
CONVERT(DATETIME,C.EndDate) EndDate,
(CP.RentAmount -isnull(Discount,0))  Rent,
ISNULL(C.TotalAmount,0) TotalAmount, L.Name UnitStatus,
@todate-C.EndDate NoOfDays,''Pending'' [Status],U.UnitID'+@SelectTag+'
FROM REN_Contract C with(nolock)
left join ren_contract CU on CU.RefContractID=C.ContractID
join REN_Property P with(nolock) on C.PropertyID=P.NodeID
join REN_Units U with(nolock) on C.UnitID=U.UnitID
left join com_lookup L with(nolock) on U.unitstatus=L.nodeid
join REN_Tenant T with(nolock) on C.TenantID=T.TenantID 
left join REN_ContractParticulars CP with(nolock) on C.CONTRACTID=CP.CONTRACTID  and CP.CCNodeID=3 '+@FromTag+'
join #tab T6 with(nolock) ON (CU.UnitID is not null and T6.UnitID=CU.UnitID and T6.EndDate=C.EndDate) or (T6.UnitID=C.UnitID and T6.EndDate=C.EndDate)
WHERE C.StatusID not in (451,440,466) AND C.EndDate <= @todate and (C.statusid=427 or C.statusid=426) AND C.RefContractID=0 '+@WHERE1+'
union all
SELECT distinct C.contractid,C.Sno, 
P.Name Property,U.Name Unit,P.NodeID [Property_ID],U.UnitID [Unit_ID],T.TenantID [Tenant_ID],
T.FirstName Tenant,T.Phone1 Phone1,
T.Phone2 Phone2,C.Purpose Purpose,
CONVERT(DATETIME,C.StartDate) StartDate,
CONVERT(DATETIME,C.EndDate) EndDate,
(CP.RentAmount -isnull(Discount,0)) Rent,
ISNULL(C.TotalAmount,0) TotalAmount, L.Name UnitStatus,
@todate-C.EndDate NoOfDays,''Un-Approved'' [Status],U.UnitID'+@SelectTag+'
FROM REN_Contract C with(nolock)
left join ren_contract CU on CU.RefContractID=C.ContractID
join REN_Property P with(nolock) on C.PropertyID=P.NodeID
join REN_Units U with(nolock) on C.UnitID=U.UnitID
left join com_lookup L with(nolock) on U.unitstatus=L.nodeid
join REN_Tenant T with(nolock) on C.TenantID=T.TenantID 
left join REN_ContractParticulars CP with(nolock) on C.CONTRACTID=CP.CONTRACTID  and CP.CCNodeID=3 '+@FromTag+'
join #tab T6 with(nolock) ON (CU.UnitID is not null and T6.UnitID=CU.UnitID and T6.EndDate=C.EndDate) or (T6.UnitID=C.UnitID and T6.EndDate=C.EndDate)
WHERE C.StatusID not in (451,440,466) AND C.EndDate <= @todate and  (C.statusid=427 or C.statusid=426) AND C.RefContractID=0 '+@WHERE1+' )
AS T
GROUP BY contractid
ORDER BY '+@OrderBy+'PropertySORT,UnitSORT

drop table #tab'
print(@SQL)
print substring(@SQL,4001,4000)
	EXEC sp_executesql @SQL
END
ELSE IF @ReportType=210--Contract Due for Renewal
BEGIN
	SET @SQL='declare @From float,@To float
set @From=floor(convert(float,getdate()))
set @To=floor(convert(float,getdate()))+'+convert(nvarchar,@MaxSelectTag)+'
SELECT P.Name PName,U.Name UName,P.Name PNameSORT,U.Name UNameSORT,T.LeaseSignatory LeaseSignatory,T.Email TEmail,T.Phone1 TPhone1,T.Fax TFax,
CONVERT(DATETIME,C.StartDate) StartDate,CONVERT(DATETIME,C.EndDate) EndDate,P.NodeID [PName_ID],U.UnitID [UName_ID],T.TenantID [Tenant_ID],
CP.RentAmount RentAmount,CP.Discount Discount,CP.Amount Amount,ISNULL(C.TotalAmount,0) TotalAmount'+@SelectTag+'
FROM REN_Contract C with(nolock)
join REN_Property P with(nolock) on C.PropertyID=P.NodeID
join REN_Units U with(nolock) on C.UnitID=U.UnitID
join REN_Tenant T with(nolock) on C.TenantID=T.TenantID
join REN_ContractParticulars CP with(nolock) on C.CONTRACTID=CP.CONTRACTID  AND CP.SNO = 1
'+@FromTag+'
WHERE C.STATUSID not in (428,450,451,480) and U.unitid not in (select unitid from REN_Contract with(nolock) where ContractID in  (SELECT CASE WHEN STATUSID=450 OR STATUSID=480 THEN MAX(CONTRACTID) ELSE MIN(ContractID) END
 FROM REN_Contract with(nolock)
WHERE  UnitID=U.UnitID  AND PropertyID=C.PropertyID  AND STARTDATE<=@To AND EndDate>=@To
GROUP BY UnitID,PropertyID,StatusID, StartDate))   
and C.EndDate between @From and @To
'+@WHERE1+'
ORDER BY '+@OrderBy+'PNameSORT,UNameSORT'
print(@SQL)
 	EXEC sp_executesql @SQL
END
ELSE IF @ReportType=211--Daily Activity Report
BEGIN
	SET @SQL='
DECLARE @FROM FLOAT,@TO FLOAT
SET @FROM='+@From+'
SET @TO='+@To+'

SELECT P.Name PropertyName,P.Name PropertyNameSORT,P.Code PropertyCode,U.Name UnitName,U.Name UnitNameSORT,U.Code UnitCode,T.FirstName TenantName,ISNULL(C.TotalAmount,0) TotalAmount,CP.Amount,CP.RentAmount,CS.[Status],C.CreatedBy,C.SNO SNO,P.NodeID [PropertyName_ID],U.UnitID [UnitName_ID],T.TenantID [TenantName_ID],C.ContractID SNO_ID,P.NodeID [PropertyCode_ID],U.UnitID [UnitCode_ID],CONVERT(DATETIME,C.ContractDate) ContractDate,CONVERT(DATETIME,C.StartDate) StartDate,CONVERT(DATETIME,C.EndDate) EndDate,CONVERT(DATETIME,C.TerminationDate) TerminationDate,CONVERT(DATETIME,C.VacancyDate) VacancyDate,CONVERT(DATETIME,C.RefundDate) RefundDate,
CONVERT(DATETIME,(CASE when C.StatusID=450 then ISNULL(C.RefundDate,C.VacancyDate) when C.StatusID=480 then C.VacancyDate when C.StatusID=428 then C.TerminationDate else C.ContractDate END)) TransactionDate
'+@SelectTag+'
FROM REN_Contract C WITH(NOLOCK)
JOIN REN_Property P WITH(NOLOCK) ON P.NodeID=C.PropertyID
JOIN REN_Units U WITH(NOLOCK) ON U.UnitID=C.UnitID
JOIN REN_Tenant T WITH(NOLOCK) ON T.TenantID=C.TenantID
JOIN REN_ContractParticulars CP WITH(NOLOCK) ON CP.ContractID=C.ContractID AND CP.Sno=1 
JOIN COM_Status CS WITH(NOLOCK) ON CS.StatusID=C.StatusID AND CS.CostCenterID=95
'+@FromTag+'
WHERE C.CostCenterID=95 
AND (Case when C.statusid=450 then ISNULL(C.RefundDate,C.VacancyDate) when C.statusid=480 then C.VacancyDate when C.Statusid=428 then TerminationDate else ContractDate END) BETWEEN @FROM AND @TO
'+@WHERE1+'
ORDER BY '+@OrderBy+'PropertyNameSORT,UnitNameSORT'
 	EXEC sp_executesql @SQL
END
ELSE IF @ReportType=212 or @ReportType=213--Unit Vacant List
BEGIN
	SET @SQL='
DECLARE @FROM FLOAT
SET @FROM='+@To+'
DECLARE @UnitID INT,@StatusID INT,@TotalAmount FLOAT,@I INT,@COUNT INT,@ContractID INT,@DiscountAmount FLOAT
DECLARE @NoofDays INT,@VacantSince DATETIME,@EndDate FLOAT,@NewContractID INT

DECLARE @TAB TABLE(ID INT IDENTITY(1,1) PRIMARY KEY,UnitID INT,CurrentRent FLOAT,Status NVARCHAR(10),NoofDays INT,VacantSince DATETIME,ContractID INT,DiscountAmount FLOAT,NewContractID INT)

INSERT INTO @TAB (UnitID)
SELECT U.UnitID
FROM REN_Units U WITH(NOLOCK) 
LEFT JOIN REN_Property P WITH(NOLOCK) ON P.NodeID=U.PropertyID
LEFT JOIN COM_Lookup LK WITH(NOLOCK) ON U.UnitStatus=LK.NodeID
WHERE U.UnitID>1 AND P.Name <> U.Name AND U.IsGroup=0 AND U.Status=424 and (U.UnitStatus=306 OR U.UnitStatus IS NULL OR U.UnitStatus=0) AND NOT (ContractID>0)
'+@WHERE1

SET @SQL=@SQL+'
SELECT @I=1,@COUNT=COUNT(*) FROM @TAB
WHILE(@I<=@COUNT)
BEGIN
	SET @StatusID=0
	SET @TotalAmount=0
	SET @DiscountAmount=0
	SET @ContractID=0
	SET @NewContractID=0
	SELECT @UnitID=UnitID FROM @TAB WHERE ID=@I

	SELECT TOP 1 @ContractID=(CASE WHEN C.RefContractID>0 THEN C.RefContractID ELSE C.ContractID END)
	,@StatusID=C.StatusID
	,@VacantSince=(CASE WHEN C.StatusID=450 THEN CONVERT(DATETIME,ISNULL(C.RefundDate,C.VacancyDate)) WHEN C.StatusID=480 THEN CONVERT(DATETIME,C.VacancyDate) ELSE CONVERT(DATETIME,C.TerminationDate) END)
	,@NoofDays=(CASE WHEN C.StatusID=450 THEN DATEDIFF(DAY, CONVERT(DATETIME,ISNULL(C.RefundDate,C.VacancyDate)),CONVERT(DATETIME,@FROM)) WHEN C.StatusID=480 THEN DATEDIFF(DAY, CONVERT(DATETIME,C.VacancyDate),CONVERT(DATETIME,@FROM)) 
			ELSE DATEDIFF(DAY, CONVERT(DATETIME,C.TerminationDate),CONVERT(DATETIME,@FROM)) END )  
	,@EndDate=C.EndDate
	FROM REN_Contract C WITH(NOLOCK) WHERE C.StatusID<>451 AND C.StartDate<=@FROM AND C.UNITID=@UnitID 
	ORDER BY C.StartDate DESC,C.StatusID
	
	SELECT TOP 1 @NewContractID=(CASE WHEN C.RefContractID>0 THEN C.RefContractID ELSE C.ContractID END) 
	FROM REN_Contract C WITH(NOLOCK) 
	WHERE C.StatusID<>451 AND C.StartDate>@FROM AND C.UNITID=@UnitID 
	ORDER BY C.StartDate ASC,C.StatusID
	
	SELECT @TotalAmount=ISNULL(ISNULL(SUM(RPD.ActAmount),SUM(T.ActAmount)),MAX(RentAmount)/(CASE WHEN MAX(RC.NoOfUnits)=0 THEN 1 ELSE MAX(RC.NoOfUnits) END))
	,@DiscountAmount=ISNULL(ISNULL(SUM(RPD.Discount),SUM(T.Discount)),MAX(RP.Discount)/(CASE WHEN MAX(RC.NoOfUnits)=0 THEN 1 ELSE MAX(RC.NoOfUnits) END)) 
	FROM REN_Contract RC WITH(NOLOCK)
	JOIN REN_ContractParticulars RP WITH(NOLOCK) ON RP.ContractID=RC.ContractID AND RP.Sno=1
	LEFT JOIN REN_ContractParticularsDetail RPD WITH(NOLOCK) ON RPD.ParticularNodeID=RP.NodeID AND RPD.Unit=@UnitID 
	AND @FROM BETWEEN ISNULL(RPD.FromDate,@FROM) AND ISNULL(RPD.ToDate,@FROM)
	LEFT JOIN (SELECT TOP 1 TRPD.Unit,TRPD.ActAmount,TRPD.Discount  
	FROM REN_ContractParticulars TRP WITH(NOLOCK) 
	JOIN REN_ContractParticularsDetail TRPD WITH(NOLOCK) ON TRPD.ParticularNodeID=TRP.NodeID AND TRPD.Unit=@UnitID 
	AND TRPD.ToDate<@FROM
	WHERE TRP.ContractID=@ContractID AND TRP.Sno=1
	ORDER BY TRPD.ToDate DESC) AS T ON T.Unit=@UnitID
	WHERE RC.ContractID=@ContractID
	
	UPDATE @TAB SET CurrentRent=@TotalAmount,NoofDays=@NoofDays,VacantSince=@VacantSince,ContractID=@ContractID,DiscountAmount=@DiscountAmount,NewContractID=@NewContractID 
	WHERE ID=@I
	
	IF @StatusID=427 OR @StatusID=426 OR @StatusID=466
		UPDATE @TAB SET Status=CASE WHEN @EndDate<@FROM THEN ''Expired'' ELSE ''Occupied'' END WHERE ID=@I
	ELSE IF @StatusID=440
		UPDATE @TAB SET Status=''UnAproved'' WHERE ID=@I
	ELSE IF @StatusID=428 OR @StatusID=450 OR @StatusID=480
	BEGIN 
		IF EXISTS (SELECT * FROM REN_Quotation WITH(NOLOCK) WHERE COSTCENTERID=129 AND UNITID=@UnitID AND CONVERT(DATETIME,@FROM) BETWEEN CONVERT(DATETIME,STARTDATE) AND CONVERT(DATETIME,ENDDATE) and statusid=467 )
			UPDATE @TAB SET Status=''Reserved'' WHERE ID=@I
		ELSE IF EXISTS (SELECT * FROM REN_Quotation WITH(NOLOCK) WHERE COSTCENTERID=103 AND UNITID=@UnitID AND CONVERT(DATETIME,@FROM) BETWEEN CONVERT(DATETIME,STARTDATE) AND CONVERT(DATETIME,ENDDATE) and statusid=426 )
			UPDATE @TAB SET Status=''Quoted'' WHERE ID=@I
		ELSE
			UPDATE @TAB SET Status=''Vacant'' WHERE ID=@I
	END
	ELSE
	BEGIN 
		IF EXISTS (SELECT * FROM REN_Quotation WITH(NOLOCK) WHERE COSTCENTERID=129 AND UNITID=@UnitID AND CONVERT(DATETIME,@FROM) BETWEEN CONVERT(DATETIME,STARTDATE) AND CONVERT(DATETIME,ENDDATE) and statusid=467 )
			UPDATE @TAB SET Status=''Reserved'' WHERE ID=@I
		ELSE IF EXISTS (SELECT * FROM REN_Quotation WITH(NOLOCK) WHERE COSTCENTERID=103 AND UNITID=@UnitID AND CONVERT(DATETIME,@FROM) BETWEEN CONVERT(DATETIME,STARTDATE) AND CONVERT(DATETIME,ENDDATE) and statusid=426 )
			UPDATE @TAB SET Status=''Quoted'' WHERE ID=@I
		ELSE
			UPDATE @TAB SET Status=''Vacant'' WHERE ID=@I
	END
	SET @I=@I+1
END'

DECLARE @I INT,@COUNT INT,@CCName nvarchar(max)
DECLARE @TblCOL AS TABLE(ID INT IDENTITY(1,1),CCName nvarchar(max))

INSERT INTO @TblCOL(CCName)
EXEC SPSplitString @SelectTag,']'

SELECT @I=2,@COUNT=COUNT(*) FROM @TblCOL
WHILE(@I<=@COUNT)
BEGIN
	SELECT @CCName=CCName FROM @TblCOL WHERE ID=@I
	
	IF (@CCName LIKE '%C.%' OR (@CCName LIKE '%T.%' AND @CCName NOT LIKE '%EXT.%'))
	BEGIN
		IF (@CCName LIKE '%T.%')
		BEGIN
			SET @CCName=REPLACE(@CCName,'T.','NT.')
			
			IF(@FromTag NOT LIKE '% NT %')
				SET @FromTag=@FromTag+' LEFT JOIN REN_Tenant NT WITH(NOLOCK) ON NT.TenantID=NC.TenantID'
		END
		ELSE
			SET @CCName=REPLACE(@CCName,'C.','NC.')
		SET @SelectTag=@SelectTag+@CCName+'_New]'
	END
	SET @I=@I+1
END

SET @SQL=@SQL+'
SELECT TEMP.*,P.NodeID Building_ID,P.Name Building,P.Name BuildingSORT,TEMP.UnitID UnitNo_ID,U.NAME UnitNo,C18.NAME UnitType,U.UnitStatus,U.RentableArea UnitArea,U.RentPerSQFT UnitRate,U.AnnualRent EstimatedRent
,CONVERT(DATETIME,NC.StartDate) NewStartDate '+@SelectTag+'
FROM @TAB TEMP
JOIN REN_Units U WITH(NOLOCK) ON TEMP.UnitID=U.UnitID
JOIN REN_Property P WITH(NOLOCK) ON P.NodeID=U.PropertyID
LEFT JOIN COM_CC50018 C18 WITH(NOLOCK) ON C18.NodeID=U.NodeID
LEFT JOIN REN_Contract C WITH(NOLOCK) ON TEMP.ContractID=C.ContractID
LEFT JOIN REN_ContractParticulars CP with(nolock) on C.CONTRACTID=CP.CONTRACTID  AND CP.SNO = 1
LEFT JOIN REN_Tenant T WITH(NOLOCK) ON T.TenantID=C.TenantID
LEFT JOIN REN_Contract NC WITH(NOLOCK) ON TEMP.NewContractID=NC.ContractID
'+REPLACE(REPLACE(REPLACE(REPLACE(@FromTag,'C.UnitID','U.UnitID'),'C.PropertyID','U.PropertyID'),'JOIN REN_ContractExtended','LEFT JOIN REN_ContractExtended'),'JOIN REN_TenantExtended','LEFT JOIN REN_TenantExtended')
IF @ReportType=212
	SET @SQL=@SQL+' WHERE (TEMP.Status=''Vacant'' OR TEMP.Status=''Reserved'')'
SET @SQL=@SQL+' order by '+@OrderBy+'BuildingSORT,VacantSince'
PRINT @SQL
PRINT SUBSTRING(@SQL,4001,4000)
PRINT SUBSTRING(@SQL,8001,4000)
EXEC sp_executesql @SQL
END
ELSE IF @ReportType=214--Unit Status Summary
BEGIN
	SET @SQL='DECLARE @FROMDATE FLOAT
SET @FROMDATE=FLOOR(CONVERT(FLOAT,GETDATE()))
DECLARE @TAB TABLE (ID INT IDENTITY(1,1),ContractID INT,StatusID INT,PropertyID INT,UnitID INT,TenantID INT,StartDate FLOAT,EndDate FLOAT)
INSERT INTO @TAB
SELECT RC.ContractID,RC.StatusID,RC.PropertyID,RC.UnitID,RC.TenantID,RC.StartDate,
CASE WHEN RC.StatusID=428 THEN RC.TerminationDate WHEN RC.StatusID=450 THEN ISNULL(RC.RefundDate,RC.VacancyDate) WHEN RC.StatusID=480 THEN RC.VacancyDate ELSE RC.EndDate END EndDate
FROM REN_Contract RC WITH(NOLOCK)
WHERE RC.ContractID>1 AND RC.CostCenterID=95 AND RC.StartDate<=@FROMDATE

SELECT Property,Property PropertySORT,MAX([Property_ID]) [Property_ID],UnitType,COUNT(*) NoOfUnits'+@MaxSelectTag+'
,SUM(CASE WHEN UnitStatus=''Occupied'' THEN 1 ELSE 0 END) Occupied
,SUM(CASE WHEN UnitStatus=''Expired '' THEN 1 ELSE 0 END) Expired 
,SUM(CASE WHEN UnitStatus=''Vacant'' THEN 1 ELSE 0 END) Vacant FROM (
SELECT P.Name Property,P.NodeID [Property_ID],U.Name Unit,UT.Name UnitType
,CASE WHEN RC.StatusID=428 OR RC.StatusID=450 OR RC.StatusID=480 THEN ''Vacant'' WHEN RC.EndDate <= @FROMDATE THEN ''Expired'' ELSE ''Occupied''  END UnitStatus 
'+@SelectTag+'
FROM @TAB RC
JOIN (SELECT UnitID ,MAX(StartDate) StartDate FROM @TAB GROUP BY UnitID) AS T2 ON T2.UnitID=RC.UnitID AND T2.StartDate=RC.StartDate
JOIN REN_Units U WITH(NOLOCK) ON U.UnitID=RC.UnitID
JOIN REN_Property P WITH(NOLOCK) ON P.NodeID=RC.PropertyID
JOIN COM_CC50018 UT WITH(NOLOCK) ON UT.NodeID=U.NodeID'+@FromTag+'
WHERE U.ContractID=0 '+@WHERE1+'
UNION
SELECT P.Name Property,P.NodeID [Property_ID],U.Name Unit,UT.Name UnitType,''Vacant''
'+@SelectTag+'
FROM REN_Units U WITH(NOLOCK)
JOIN REN_Property P WITH(NOLOCK) ON P.NodeID=U.PropertyID
JOIN COM_CC50018 UT WITH(NOLOCK) ON UT.NodeID=U.NodeID'+@FromTag+'
WHERE U.UnitID>1 AND U.ContractID=0 AND U.IsGroup=0 AND U.UnitID NOT IN (SELECT DISTINCT UnitID FROM @TAB) '+@WHERE1+'
) AS T

GROUP BY Property,UnitType'+@MaxSelectTag+'
order by '+@OrderBy+'PropertySORT'
	EXEC sp_executesql @SQL
END
ELSE IF @ReportType=215--Unit Municipality Case Report
BEGIN
	SET @SQL='
Select * from (

SELECT T.FirstName TenantName,
CONVERT(DATETIME,C.StartDate) CStartDate,CONVERT(DATETIME,C.EndDate) CEndDate,
U.Name UnitName, p.Name Tower,MAX(P.NodeID) [Tower_ID],MAX(U.UnitID) [UnitName_ID],MAX(T.TenantID) [TenantName_ID],
ISNULL(C.TotalAmount,0) TotalAmount,l.name as UnitStatus,u.TermsConditions'+@SelectTag+'
FROM REN_Contract C with(nolock) 
left join REN_Tenant T with(nolock) on C.TenantID=T.TenantID 
left join REN_Units U with(nolock) on C.UnitID=U.UnitID   
left join REN_Property p with(nolock) on C.propertyid=p.Nodeid 
left join com_lookup l with(nolock) on u.UnitStatus=l.nodeid'+@FromTag+'
WHERE 1=1  '+@WHERE1+'
group by l.name  ,T.FirstName,C.StartDate, C.EndDate,U.Name,p.Name ,C.TotalAmount ,u.TermsConditions
union 
select null,null,null,
U.name, P.name ,MAX(P.NodeID) [Tower_ID],MAX(U.UnitID) [UnitName_ID],NULL,
0,l.name,U.TermsConditions'+@SelectTag+'
from ren_units U with(nolock) 
left join com_lookup l with(nolock) on U.UnitStatus=l.nodeid  
left join ren_property P with(nolock) on U.propertyid=P.nodeid'+@FromTag+'
where U.unitid not in (select isnull(unitid,0) from ren_contract with(nolock)) '+@WHERE1+'
group by l.name,U.name,P.name,U.TermsConditions) as t
order by '+@OrderBy+'UnitStatus
'
	EXEC sp_executesql @SQL
END   

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
