USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRpt_RentalReports]
	@ReportType [int],
	@FromDate [datetime],
	@ToDate [datetime],
	@WHERE1 [nvarchar](max),
	@WHERE2 [nvarchar](max),
	@UserID [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
Begin Try    
SET NOCOUNT ON;  
DECLARE @SQL NVARCHAR(MAX),@From FLOAT,@To FLOAT,@Tbl nvarchar(20),@TblCol nvarchar(50)
SET @From=CONVERT(FLOAT,@FromDate)
SET @To=CONVERT(FLOAT,@ToDate)


IF @ReportType=140--Unit Wise Contract Expiry Report
BEGIN

	SELECT @Tbl = TABLENAME FROM ADM_FEATURES with(nolock) WHERE FEATUREID IN (
	SELECT  VALUE FROM COM_COSTCENTERPREFERENCES with(nolock) WHERE COSTCENTERID = 92 AND NAME  = 'Landlord')
	
	SET @SQL= 'SELECT UnitID,Units,PropertyID,Property,LandlordID,Landlord,ContractNumber,StartDate, 
	EndDate,ContractID,TENANTID,Tenant,TenantEmail,ExtendTill,Location,TermDate,USTATUS,VatType   
	FROM (  SELECT DISTINCT UNT.UnitID,UNT.Name Units,UNT.PropertyID,PROP.NAME Property,
			PROP.LandlordID,LLTBL.NAME Landlord,'''' ContractNumber,null StartDate,null  EndDate,0 ContractID,
			0 TENANTID,'''' Tenant,null TenantEmail,null ExtendTill,LOC.NAME Location,null TermDate,STS.STATUS USTATUS 
			,UC70.Name VatType
			FROM REN_Property PROP with(nolock)   
			LEFT JOIN '+@Tbl+' LLTBL with(nolock) ON PROP.LANDLORDID = LLTBL.NODEID  
			LEFT JOIN COM_LOCATION LOC with(nolock) ON PROP.LOCATIONID = LOC.NODEID	 
			JOIN REN_Units UNT with(nolock) ON PROP.NodeID = UNT.PropertyID AND UNT.UNITID NOT IN  (SELECT DISTINCT UNITID FROM REN_Contract with(nolock) WHERE UNITID IS NOT NULL AND UNITID > 0 )
			JOIN COM_CCCCData CCDU with(nolock) ON CCDU.NODEID=UNT.UnitID AND CCDU.CostCenterID=93
			JOIN COM_CC50070 UC70 with(nolock) ON UC70.NodeID=CCDU.CCNID70 
			JOIN COM_STATUS STS with(nolock) ON STS.STATUSID = UNT.STATUS ' + @WHERE1 + ' 
			UNION ALL 
			SELECT DISTINCT UNT.UnitID,UNT.Name Units,UNT.PropertyID,PROP.NAME Property,
			PROP.LandlordID,LLTBL.NAME,CNT.ContractNumber,CONVERT(DATETIME,CNT.StartDate),CONVERT(DATETIME,CNT.EndDate),CNT.ContractID,
			CNT.TENANTID,TNT.FIRSTNAME,max(TNT.Email),CONVERT(DATETIME,CNT.ExtendTill), 
			LOC.NAME Location,CONVERT(DATETIME,CNT.TerminationDate) TermDate,STS.STATUS USTATUS 
			,UC70.Name VatType
			FROM REN_Property PROP with(nolock)
			JOIN REN_Units UNT with(nolock) ON PROP.NodeID = UNT.PropertyID	 
			JOIN COM_CCCCData CCDU with(nolock) ON CCDU.NODEID=UNT.UnitID AND CCDU.CostCenterID=93
			JOIN COM_CC50070 UC70 with(nolock) ON UC70.NodeID=CCDU.CCNID70
			LEFT JOIN REN_Contract CNT with(nolock) ON UNT.UnitID = CNT.UnitID 
			LEFT JOIN COM_LOCATION LOC with(nolock) ON CNT.LOCATIONID = LOC.NODEID
			LEFT JOIN COM_STATUS STS  with(nolock) ON CNT.STATUSID = STS.STATUSID 
			LEFT JOIN '+@Tbl+' LLTBL with(nolock) ON PROP.LANDLORDID = LLTBL.NODEID 
			LEFT JOIN REN_TENANT TNT with(nolock) ON CNT.TENANTID =  TNT.TENANTID '
	
	IF (@WHERE2<>'' AND @WHERE2 IS NOT NULL)
		SET @SQL=@SQL+@WHERE2 +' AND CNT.ENDDATE<='+Convert(nvarchar,@To)+''
	ELSE
		SET @SQL=@SQL+  ' WHERE CNT.ENDDATE<='+Convert(nvarchar,@To)+''

	SET @SQL=@SQL+' GROUP BY UNT.UnitID,UNT.Name,UNT.PropertyID,PROP.NAME,PROP.LandlordID,LLTBL.NAME,CNT.TENANTID,TNT.FIRSTNAME,CNT.ContractID,CONVERT(DATETIME,CNT.EndDate),
	CNT.ContractNumber,CONVERT(DATETIME,CNT.StartDate),CONVERT(DATETIME,CNT.ExtendTill),LOC.NAME,CONVERT(DATETIME,CNT.TerminationDate),STS.STATUS,UC70.Name) AS T 
	ORDER BY UNITID,EndDate Desc'
	
	PRINT @SQL
	EXEC(@SQL)
                
END
ELSE IF @ReportType=127--Unit Vacant report
BEGIN

	SELECT @Tbl=TABLENAME FROM ADM_FEATURES WITH(NOLOCK) 
	WHERE FEATUREID IN (SELECT   DISTINCT CCID FROM REN_UNITS WITH(NOLOCK)) 
	
 	SET @SQL= 'SELECT UnitID,Unit,PropertyID,PropertyName,VacantSince,SUM(RentperYear) RentPerYear,
 	CONVERT(NVARCHAR,NoofDays) NoofDays,UnitStatus,UnitType,BUILDUPAREA,RENTABLEAREA ,VatType
 	FROM (  SELECT UNT.UnitID UnitID,UNT.Name Unit,UNT.PropertyID PropertyID,PROP.NAME PropertyName, 
			CASE WHEN CNT.StatusID = 450 THEN ( CASE WHEN RefundDate IS NOT NULL THEN CONVERT(DATETIME,RefundDate) ELSE CONVERT(DATETIME,VacancyDate) END ) 
			ELSE CONVERT(DATETIME,TerminationDate) END VacantSince,MAX(UNT.ANNUALRENT) RentperYear,
			CASE WHEN CNT.StatusID = 450 THEN ( CASE WHEN RefundDate IS NOT NULL THEN DATEDIFF(DAY, CONVERT(DATETIME,RefundDate),'''+CONVERT(nvarchar,@ToDate)+''' ) 
			ELSE DATEDIFF(DAY, CONVERT(DATETIME,VacancyDate),'''+CONVERT(nvarchar,@ToDate)+''' ) END )
			ELSE DATEDIFF(DAY, CONVERT(DATETIME,TerminationDate),'''+CONVERT(nvarchar,@ToDate)+''' ) END NoofDays,
			US.Name UnitStatus,UnitType.Name UnitType,UNT.BUILDUPAREA, UNT.RENTABLEAREA,UC70.Name VatType
			FROM REN_Property PROP with(nolock) 
			JOIN COM_CCCCData CCD with(nolock) ON CCD.NODEID=PROP.NODEID AND CCD.CostCenterID=92
			JOIN REN_Units UNT with(nolock) ON PROP.NodeID = UNT.PropertyID
			JOIN COM_CCCCData CCDU with(nolock) ON CCDU.NODEID=UNT.UnitID AND CCDU.CostCenterID=93
			JOIN COM_CC50070 UC70 with(nolock) ON UC70.NodeID=CCDU.CCNID70	
			left join COM_Lookup US with(nolock) on US.NodeID=UNT.UnitStatus 
			LEFT JOIN '+@Tbl+' UnitType with(nolock) ON UNT.NODEID=UnitType.NODEID
			JOIN REN_Contract CNT with(nolock) ON UNT.UnitID = CNT.UnitID  
			AND UNT.UNITID NOT IN (SELECT UNITID FROM REN_Contract with(nolock) WHERE CONVERT(DATETIME,STARTDATE) <='''+CONVERT(nvarchar,@ToDate)+''' 
									and CONVERT(DATETIME,ENDDATE) >='''+CONVERT(nvarchar,@ToDate)+''' AND StatusID <>428 )
									and (((CONVERT(DATETIME,TerminationDate)) <='''+CONVERT(nvarchar,@ToDate)+''' AND CNT.StatusID = 428 )  
									OR (((CONVERT(DATETIME,RefundDate)) <='''+CONVERT(nvarchar,@ToDate)+''' 
									OR (CONVERT(DATETIME,VacancyDate)) <='''+CONVERT(nvarchar,@ToDate)+''') AND CNT.StatusID = 450 ))
			AND CNT.ContractID NOT IN (SELECT RC11.ContractID FROM REN_Contract RC1 with(nolock)
								   LEFT JOIN REN_Contract RC11 with(nolock) ON RC11.STARTDATE < RC1.STARTDATE 
								   WHERE RC11.UNITID=RC1.UNITID)
			AND UNT.Status=424 '+@WHERE1+'
			GROUP BY UNT.PropertyID,PROP.NAME,UNT.UnitID,UNT.Name,CNT.StatusID,TerminationDate,RefundDate,VacancyDate,CNT.RecurAmount,US.Name,UnitType.Name,BUILDUPAREA,RENTABLEAREA,UC70.Name) AS T 
	GROUP BY UnitID,Unit,PropertyID,PropertyName,VacantSince,CONVERT(NVARCHAR,NoofDays),UnitStatus,UnitType,BUILDUPAREA,RENTABLEAREA,VatType '
	
	if(@WHERE2 is not null and @WHERE2 <>'')
	BEGIN
		SET @SQL=@SQL+' UNION '
		SET @SQL=@SQL+' SELECT UNT.UnitID UnitID,UNT.Name Unit,UNT.PropertyID PropertyID,PROP.NAME PropertyName
		,'''' VacantSince,UNT.ANNUALRENT RentperYear,0 NoofDays,US.Name UnitStatus,UnitType.Name UnitType,UNT.BUILDUPAREA,UNT.RENTABLEAREA,UC70.Name VatType
		FROM REN_Property PROP with(nolock) 
		JOIN COM_CCCCData CCD with(nolock) ON CCD.NODEID=PROP.NODEID AND CCD.CostCenterID=92
		JOIN REN_Units UNT with(nolock) ON PROP.NodeID = UNT.PropertyID
		JOIN COM_CCCCData CCDU with(nolock) ON CCDU.NODEID=UNT.UnitID AND CCDU.CostCenterID=93
		JOIN COM_CC50070 UC70 with(nolock) ON UC70.NodeID=CCDU.CCNID70	
		LEFT JOIN '+@Tbl+' UnitType with(nolock) ON UNT.NODEID=UnitType.NODEID
		left join COM_Lookup US with(nolock) on US.NodeID=UNT.UnitStatus
		WHERE UNT.ContractID=0 AND UNT.UNITID NOT IN (SELECT ISNULL(UNITID,0) FROM REN_Contract with(nolock) ) AND UNT.IsGroup=0 AND UNT.Status=424 '+@WHERE1 	
	END
	SET @SQL=@SQL+' ORDER BY PropertyName'
	EXEC(@SQL) 
 
END
ELSE IF @ReportType=113--GetPropertyProfitSummaryAll
BEGIN
	DECLARE @Dim INT,@SubQuery NVARCHAR(MAX),@CCTBL NVARCHAR(100)
	SELECT @Dim=ISNULL(Value,0) FROM COM_CostCenterPreferences WITH(NOLOCK) 
	WHERE CostCenterID=94 AND Name='EIDNationalityDimension'
	
	IF( @Dim > 50000)
	BEGIN
		SELECT TOP 1 @CCTBL = TABLENAME FROM ADM_FEATURES with(nolock) WHERE FEATUREID = @Dim 
		SET @TblCol='NAT.Name'
		SET @SubQuery=' LEFT JOIN COM_CCCCData CCDT WITH(NOLOCK) ON  CCDT.NodeID=T2.TenantID AND CCDT.CostCenterID=94 
		LEFT JOIN '+@CCTBL+' NAT WITH(NOLOCK) ON NAT.NodeID=CCDT.CCNID'+CONVERT(NVARCHAR(MAX),@Dim-50000)
	END
	
	select @Tbl=F.TableName from ADM_GlobalPreferences G with(nolock) 
	inner join ADM_Features F with(nolock) ON F.FeatureID=G.value
	where G.Name='UnitLinkDimension'
	
	SET @SQL='SELECT SNO,TrackingID,Property,Property_ID,Unit,Unit_ID,UnitStatus,Tenant,Tenant_ID,Nationality,ContractDate,StartDate,EndDate,TerminationDate,RefundDate,ContractAge,ToDate ,AllTotalAmount, TotalAmount,RentAmount,Discount,RentDay,ReportDays,Rent,ContractID,UnearnedDays,UnearnedAmount ,Profession,UnitType,TenantExtra1,[Floor],PrevRent,BaseRent,StatusID,[Status],NationalityName,ExcessDaysAmt,VatType,VatPer,VatAmount,Phone,alpha9,Purpose
	from (  SELECT 0 SNO,T3.Sno TrackingID,T0.Name AS [Property],T0.NodeID Property_ID,T1.Name AS [Unit],T1.UnitID Unit_ID,US.Name UnitStatus,T2.FirstName AS [Tenant],T2.TenantID Tenant_ID,T2.Nationality,CONVERT(DATETIME,T3.ContractDate) ContractDate,CONVERT(DATETIME,T3.StartDate) AS [StartDate],CONVERT(DATETIME,T3.EndDate) AS EndDate,CONVERT(DATETIME,T3.TerminationDate) TerminationDate,CONVERT(DATETIME,T3.RefundDate) RefundDate,CE.Alpha1 ContractAge,'''' AS ToDate
			,T3.TotalAmount AS AllTotalAmount,T4.Amount AS TotalAmount,T4.RentAmount,T4.Discount,'''' AS RentDay,'''' AS ReportDays,'''' AS Rent,T3.ContractID ContractID,0 UnearnedDays ,0 UnearnedAmount,T2.Profession,UT.Name UnitType,T2E.Alpha1 TenantExtra1
			,FL.Name [Floor],T1E.alpha32 PrevRent,PU.Rent BaseRent,T3.StatusID,ST.Status,'+ISNULL(@TblCol,'''''')+' NationalityName,T3.SecurityDeposit ExcessDaysAmt
			,UC70.Name VatType,T4.VatPer,T4.VatAmount
			,T2.Phone1 Phone,CE.alpha9 alpha9,T3.Purpose
			FROM REN_Property T0 with(nolock) 
			JOIN COM_CCCCData CCD with(nolock) ON CCD.NODEID=T0.NODEID AND CCD.CostCenterID=92
			JOIN REN_Contract T3 with(nolock) ON T3.PropertyID=T0.NodeID AND T3.COSTCENTERID=95 
			JOIN REN_ContractExtended CE with(nolock) on CE.NodeID=T3.ContractID  
			JOIN REN_ContractParticulars T4 with(nolock) ON T3.CONTRACTID=T4.CONTRACTID AND T4.SNO=1
			JOIN REN_Tenant T2 with(nolock) ON  T3.TenantID=T2.TenantID AND T3.IsGroup <> 1
			JOIN REN_TenantExtended T2E with(nolock) ON  T2E.TenantID=T2.TenantID
			JOIN REN_Units T1 with(nolock) ON T3.UnitID=T1.UnitID
			JOIN REN_UnitsExtended T1E with(nolock) ON  T1E.UnitID=T1.UnitID 
			JOIN COM_CCCCData CCDU with(nolock) ON CCDU.NODEID=T1.UnitID AND CCDU.CostCenterID=93
			JOIN COM_CC50070 UC70 with(nolock) ON UC70.NodeID=CCDU.CCNID70 
			left join COM_Lookup US with(nolock) on US.NodeID=T1.UnitStatus
			left join '+@Tbl+' UT with(nolock) on UT.NodeID=T1.NodeID
			left join COM_Lookup FL with(nolock) on FL.NodeID=T1.FloorLookupID
			left join REN_PropertyUnits PU with(nolock) ON PU.PropertyID=T0.NodeID AND PU.Type=UT.NodeID
			LEFT JOIN COM_Status ST WITH(NOLOCK) ON ST.StatusID=T3.StatusID '+ISNULL(@SubQuery,'')+'
			WHERE (T1.UnitStatus is null or T1.UnitStatus!=321) '+@WHERE1+' 
			and T3.StatusID!=451 AND T3.StartDate <= '+CONVERT(nvarchar,@To)+' AND T3.EndDate>= '+CONVERT(nvarchar,@From)+'  
			union all   
			select 0 SNO,null TrackingID,T0.Name [Property],T0.NodeID Property_ID,T1.Name [Unit],T1.UnitID Unit_ID,US.Name UnitStatus,CASE WHEN (SELECT TOP 1 StatusID FROM REN_Contract with(nolock) where UnitID=T1.UnitID and StatusID<>451 and CONVERT(DATETIME,EndDate)<'+CONVERT(nvarchar,@To)+' ORDER BY StartDate DESC) IN (426,427) THEN ''EXPIRED'' ELSE ''VACANT'' END Tenant,
			null Tenant_ID,null Nationality,null ContractDate,NULL StartDate,NULL EndDate,NULL TerminationDate,NULL RefundDate,null ContractAge,'''' ToDate
			,'''' [AllTotalAmount],'''' TotalAmount,'''' RentAmount,'''' Discount,'''' RentDay,'''' ReportDays, '''' [Rent],'''' ContractID,0 UnearnedDays,0 UnearnedAmount,null Profession,UT.Name UnitType,null TenantExtra1
			,FL.Name [Floor],T1E.alpha32 PrevRent,PU.Rent BaseRent,0,'''','''',0
			,UC70.Name VatType,'''' VatPer,'''' VatAmount
			,'''','''',''''
			from REN_Units T1 with(nolock) 
			JOIN REN_UnitsExtended T1E with(nolock) ON T1E.UnitID=T1.UnitID
			JOIN COM_CCCCData CCDU with(nolock) ON CCDU.NODEID=T1.UnitID AND CCDU.CostCenterID=93
			join REN_Property T0 with(nolock) on T1.propertyid = T0.nodeid 
			JOIN COM_CCCCData CCD with(nolock) ON CCD.NODEID=T0.NODEID AND CCD.CostCenterID=92
			JOIN COM_CC50070 UC70 with(nolock) ON UC70.NodeID=CCDU.CCNID70 
			left join COM_Lookup US with(nolock) on US.NodeID=T1.UnitStatus 
			left join '+@Tbl+' UT with(nolock) on UT.NodeID=T1.NodeID 
			left join COM_Lookup FL with(nolock) on FL.NodeID=T1.FloorLookupID
			left join REN_PropertyUnits PU with(nolock) ON PU.PropertyID=T0.NodeID AND PU.Type=UT.NodeID
			where (T1.UnitStatus is null or T1.UnitStatus!=321) '+@WHERE1+' 
			AND T1.unitid not in (select unitid from REN_Contract with(nolock) where CONVERT(DATETIME,EndDate)>='+CONVERT(nvarchar,@To)+')) as FinalTable 
	Order by Property,Unit,EndDate DESC'
	print (substring(@SQL,0,4000))
	print (substring(@SQL,4000,4000))
	EXEC(@SQL)

	
	select @CCTBL = MAX(CCID) from REN_ContractParticulars with(nolock) 
	SELECT TOP 1 @CCTBL = TABLENAME FROM ADM_FEATURES with(nolock) WHERE FEATUREID = @CCTBL
	SET @SQL =  ' SELECT PRT.ContractID,CCT.NodeID PartID,CCT.NAME as NAME
	,CASE WHEN C.TerminationDate IS NOT NULL AND (select top 1 UP.Refund from REN_Particulars UP with(nolock) where UP.UnitID=C.UnitID AND UP.PropertyID=C.PropertyID AND UP.ParticularID=PRT.CCNODEID)=1 THEN 0 ELSE PRT.Amount END Amount
	,PRT.VatPer,PRT.VatAmount
	FROM REN_ContractParticulars PRT with(nolock)
	INNER JOIN '+ @CCTBL+' CCT with(nolock) ON PRT.CCNODEID = CCT.NODEID 
	JOIN COM_STATUS CCTS WITH(NOLOCK) ON CCTS.STATUSID=CCT.STATUSID AND STATUS<>''In Active''
	INNER JOIN REN_Contract C with(nolock) ON C.ContractID=PRT.ContractID
	join REN_Property T0 with(nolock) on C.PropertyID = T0.nodeid 
	JOIN COM_CCCCData CCD with(nolock) ON CCD.NODEID=T0.NODEID AND CCD.CostCenterID=92
	where PRT.sno<>1'
	print(@SQL)
	EXEC(@SQL)

	SET @SQL= 'select NodeID,Code,Name from '+@CCTBL+' with(nolock) where IsGroup=0 order by lft'
	print(@SQL)
	EXEC(@SQL)
END	
ELSE IF @ReportType=168--Share Holder's Report
BEGIN
	declare @CCWHERE NVARCHAR(MAX)
	select @TblCol='DCC.dcCCNID'+CONVERT(NVARCHAR,(CONVERT(INT,Value)-50000)) from com_costcenterPreferences with(nolock) where CostCenterID=92 and Name='LinkDocument'
	select @Tbl=TableName FROM ADM_Features with(nolock) WHERE FeatureID IN (select Value from com_costcenterPreferences with(nolock) where CostCenterID=92 and Name='LinkDocument')
	
	if(@WHERE1!='')
		set @CCWHERE=' AND '+@TblCol+' IN ('+@WHERE1+')'
	else
		set @CCWHERE=''

	SET @SQL='
		--Income
		SELECT P.Name Property,PID,SUM(CR)-SUM(DR) Balance FROM
		(
		select '+@TblCol+' PID, D.Amount Dr,0 Cr
		from acc_docdetails D with(nolock)
		inner join ACC_Accounts A with(nolock) ON A.AccountID=D.DebitAccount
		inner join COM_DocCCData DCC with(nolock) on DCC.AccDocDetailsID=D.AccDocDetailsID
		inner join '+@Tbl+' P with(nolock) on P.NodeID='+@TblCol+'
		WHERE (A.AccountTypeID=4 OR A.AccountTypeID=8 OR A.AccountTypeID=11) AND D.DocDate<='+CONVERT(nvarchar,@To)+@CCWHERE+'
		UNION ALL
		select '+@TblCol+' PID,0 Dr,D.Amount  Cr
		from acc_docdetails D with(nolock)
		inner join ACC_Accounts A with(nolock) ON A.AccountID=D.CreditAccount
		inner join COM_DocCCData DCC with(nolock) on DCC.AccDocDetailsID=D.AccDocDetailsID
		inner join '+@Tbl+' P with(nolock) on P.NodeID='+@TblCol+'
		WHERE (A.AccountTypeID=4 OR A.AccountTypeID=8 OR A.AccountTypeID=11) AND D.DocDate<='+CONVERT(nvarchar,@To)+@CCWHERE+'
		) AS T 
		INNER JOIN '+@Tbl+' P with(nolock) ON P.NodeID=T.PID
		GROUP BY T.PID,P.Name
		ORDER BY P.Name

		--Expenses
		SELECT P.Name,PID,SUM(DR)-SUM(CR) Balance FROM
		(
		select '+@TblCol+' PID, D.Amount Dr,0 Cr
		from acc_docdetails D with(nolock)
		inner join ACC_Accounts A with(nolock) ON A.AccountID=D.DebitAccount
		inner join COM_DocCCData DCC with(nolock) on DCC.AccDocDetailsID=D.AccDocDetailsID
		inner join '+@Tbl+' P with(nolock) on P.NodeID='+@TblCol+'
		WHERE (A.AccountTypeID=5 OR A.AccountTypeID=9 OR A.AccountTypeID=12) AND D.DocDate<='+CONVERT(nvarchar,@To)+@CCWHERE+'
		UNION ALL
		select '+@TblCol+' PID,0 Dr,D.Amount  Cr
		from acc_docdetails D with(nolock)
		inner join ACC_Accounts A with(nolock) ON A.AccountID=D.CreditAccount
		inner join COM_DocCCData DCC with(nolock) on DCC.AccDocDetailsID=D.AccDocDetailsID
		inner join '+@Tbl+' P with(nolock) on P.NodeID='+@TblCol+'
		WHERE (A.AccountTypeID=5 OR A.AccountTypeID=9 OR A.AccountTypeID=12) AND D.DocDate<='+CONVERT(nvarchar,@To)+@CCWHERE+'
		) AS T 
		INNER JOIN '+@Tbl+' P with(nolock) ON P.NodeID=T.PID
		GROUP BY T.PID,P.Name'
	--print(@SQL)
	EXEC(@SQL)

	SET @SQL='
	SELECT A.AccountName,P.CCNodeID PID,A.AccountID,Income,Expenses,OpIncome-OpExpenses OpBalance,	
	(isnull((select sum(Amount) Dr from ACC_DocDetails D with(nolock)
			WHERE DebitAccount=A.AccountID and D.DocDate<='+CONVERT(nvarchar,@To)+'),0)
		-isnull((select sum(Amount) Cr from ACC_DocDetails D with(nolock)
			WHERE CreditAccount=A.AccountID and D.DocDate<='+CONVERT(nvarchar,@To)+'),0)) Balance
	FROM REN_PropertyShareHolder S with(nolock)
	INNER JOIN REN_Property P with(nolock) ON P.NodeID=S.PropertyID
	INNER JOIN ACC_Accounts A with(nolock) ON A.AccountID=S.Account
	WHERE 1=1
	'
	if(@WHERE1!='')
		set @SQL=@SQL+' AND P.CCNodeID IN ('+@WHERE1+')'
		
	if(@WHERE2!='')
		set @SQL=@SQL+' AND A.AccountID IN ('+@WHERE2+')'
		
	--print(@SQL)
	EXEC(@SQL)
END
ELSE IF @ReportType=1--Worflow Level Users Info
BEGIN
--	select * from com_costcentercostcentermap C with(nolock) where ParentCostCenterID=7 and ParentNodeID=@UserID
	/*select U.UserName,U.FirstName,U.MiddleName,U.LastName from
	(
	select W.UserID
	from COM_WorkFlow W with(nolock) 
	where W.WorkFlowID=@WHERE1 and W.LevelID=@WHERE2 and W.UserID is not null
	union
	select R.UserID
	from COM_WorkFlow W with(nolock) 
	inner join adm_userrolemap R with(nolock) on R.RoleID=W.RoleID
	where W.WorkFlowID=@WHERE1 and W.LevelID=@WHERE2 and W.RoleID is not null
	union
	select G.UserID
	from COM_WorkFlow W with(nolock) 
	inner join COM_Groups G with(nolock) on W.GroupID=G.GID  
	where W.WorkFlowID=@WHERE1 and W.LevelID=@WHERE2 and W.GroupID is not null and G.UserID>0
	union
	select R.UserID
	from COM_WorkFlow W with(nolock) 
	inner join COM_Groups G with(nolock) on W.GroupID=G.GID  
	inner join adm_userrolemap R with(nolock) on R.RoleID=W.RoleID
	where W.WorkFlowID=@WHERE1 and W.LevelID=@WHERE2 and W.GroupID is not null and G.RoleID>0
	) as T
	inner join ADM_Users U with(nolock) on T.UserID=U.UserID*/

	declare @TblUsers as Table(UserID int,RoleID int)
	insert into @TblUsers
	select U.UserID,T.RoleID from
	(
	select W.UserID,R.RoleID
	from COM_WorkFlow W with(nolock) 
	inner join adm_userrolemap R with(nolock) on R.UserID=W.UserID and R.[Status]=1 and R.IsDefault=1
	where W.WorkFlowID=@WHERE1 and W.LevelID=@WHERE2 and W.UserID is not null
	union
	select R.UserID,R.RoleID
	from COM_WorkFlow W with(nolock) 
	inner join adm_userrolemap R with(nolock) on R.RoleID=W.RoleID and R.[Status]=1
	where W.WorkFlowID=@WHERE1 and W.LevelID=@WHERE2 and W.RoleID is not null
	union
	select G.UserID,R.RoleID
	from COM_WorkFlow W with(nolock) 
	inner join COM_Groups G with(nolock) on W.GroupID=G.GID  
	inner join adm_userrolemap R with(nolock) on R.UserID=G.UserID and R.[Status]=1 and R.IsDefault=1
	where W.WorkFlowID=@WHERE1 and W.LevelID=@WHERE2 and W.GroupID is not null and G.UserID>0
	union
	select R.UserID,R.RoleID
	from COM_WorkFlow W with(nolock) 
	inner join COM_Groups G with(nolock) on W.GroupID=G.GID  
	inner join adm_userrolemap R with(nolock) on R.RoleID=G.RoleID and R.[Status]=1
	where W.WorkFlowID=@WHERE1 and W.LevelID=@WHERE2 and W.GroupID is not null and G.RoleID>0
	) as T
	inner join ADM_Users U with(nolock) on T.UserID=U.UserID
	
	if(@UserID=1)
	begin
		select U.UserID,U.UserName,U.FirstName,U.MiddleName,U.LastName,R.Name RoleName
		from @TblUsers T
		inner join ADM_Users U with(nolock) on T.UserID=U.UserID
		inner join ADM_PRoles R with(nolock) on T.RoleID=R.RoleID
		WHERE U.StatusID=1
	end
	else
	begin
		
		/*select U.UserID,U.UserName,U.FirstName,U.MiddleName,U.LastName from
		(
		select distinct T.UserID
		from com_costcentercostcentermap C with(nolock) 
		inner join @TblUsers T on C.ParentCostCenterID=7 and T.UserID=C.ParentNodeID
		inner join (select CostCenterID,NodeID from com_costcentercostcentermap C with(nolock) 
			where ParentCostCenterID=7 and ParentNodeID=@UserID and NodeID!=2) as MU on MU.CostCenterID=C.CostCenterID
		where  MU.NodeID=C.NodeID
		) as T
		inner join ADM_Users U with(nolock) on T.UserID=U.UserID*/
		
		declare @Dims as table(CostCenterID int,NodeID INT)
		
		insert into @Dims
		select CostCenterID,NodeID from com_costcentercostcentermap C with(nolock) 
		where ParentCostCenterID=7 and ParentNodeID=@UserID and NodeID!=2
		
		if not exists(select * from @Dims)
		begin
			select U.UserID,U.UserName,U.FirstName,U.MiddleName,U.LastName,R.Name RoleName
			from @TblUsers T
			inner join ADM_Users U with(nolock) on T.UserID=U.UserID
			inner join ADM_PRoles R with(nolock) on T.RoleID=R.RoleID
			WHERE U.StatusID=1
		end
		else
		begin
			select U.UserID,U.UserName,U.FirstName,U.MiddleName,U.LastName,'' RoleName
			from (
				select distinct T.UserID
				from @TblUsers T 
				inner join com_costcentercostcentermap C with(nolock) on C.ParentCostCenterID=7 and T.UserID=C.ParentNodeID
				inner join @Dims UD on UD.CostCenterID=C.CostCenterID
				where UD.NodeID=C.NodeID
			) AS T
			inner join ADM_Users U with(nolock) on T.UserID=U.UserID
			WHERE U.StatusID=1
		end
	end
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
