USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRpt_GetCashFlowRpt]
	@FromDate [datetime],
	@ToDate [datetime],
	@PropertyID [nvarchar](max),
	@Particulars [nvarchar](max),
	@UserID [bigint],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
Begin Try      
      
SET ARITHABORT ON      
  
  create  table #tblTempFlatType  ( ID INT IDENTITY(1,1),NODEID BIGINT NULL , NAME NVARCHAR(100) NULL)               
   DECLARE @TBLNAME NVARCHAR(50) ,@UnitTBLNAME NVARCHAR(50) ,@QRY NVARCHAR (MAX)  , @ReconID bigint , @StaffFlat BIGINT                  
   SELECT @TBLNAME = TABLENAME FROM  dbo.ADM_Features   
   WHERE FEATUREID in ( select value from dbo.ADM_GlobalPreferences with(nolock) where name  = 'DepositLinkDimension')                       
     
	create  table #tblTempUnitPosition  ( ID INT IDENTITY(1,1),NODEID BIGINT NULL , NAME NVARCHAR(100) NULL)     
	select @UnitTBLNAME = tablename from adm_features with(nolock) where featureid in ( SELECT Value  FROM COM_COSTCENTERPREFERENCES  with(nolock) WHERE COSTCENTERID = 93 
	AND NAME =  'UnitPosition')
     
	IF(@UnitTBLNAME is not null and @UnitTBLNAME <>'')                   
	BEGIN                    
	SET @QRY = ' SELECT Nodeid,Name  FROM ' + @UnitTBLNAME+' with(nolock)'                     
	INSERT INTO #tblTempUnitPosition(NODEID , NAME)                    
	EXEC (@QRY)                   
	END   
		SELECT @ReconID = Nodeid FROM #tblTempUnitPosition WHERE NAME  = 'Tiger Recon'
		SELECT @StaffFlat = Nodeid FROM #tblTempUnitPosition WHERE NAME  = 'Staff'
   IF(@TBLNAME is not null and @TBLNAME <>'')                   
   BEGIN                    
   SET @QRY = ' SELECT Nodeid,Name  FROM ' + @TBLNAME+' with(nolock)' 
   
   IF(@Particulars is not null and @Particulars <>'' and @Particulars <>'0')
		SET @QRY = @QRY + ' where NodeID in ('+ @Particulars +')'  
		                  
   INSERT INTO #tblTempFlatType(NODEID , NAME)                    
   EXEC (@QRY)                   
   END      
     
  -- , case when (year(CONVERT(DATETIME,T1.STARTDate)) = year(CONVERT(DATETIME,T1.EndDate))) THEN   SUM(T1.RecurAmount)  /  ( month(CONVERT(DATETIME,T1.EndDate)) - month(CONVERT(DATETIME,T1.StartDate)) )   
  --when    (year(CONVERT(DATETIME,T1.EndDate)) > year(CONVERT(DATETIME,T1.STARTDate)) and   month(CONVERT(DATETIME,T1.EndDate)) =  month(CONVERT(DATETIME,T1.StartDate))) then  SUM(T1.RecurAmount) /  (  ( year(CONVERT(DATETIME,T1.EndDate)) - year(CONVERT(DATETIME,T1.STARTDate)) )*12  +  ( month(CONVERT(DATETIME,T1.EndDate)) - month(CONVERT(DATETIME,T1.StartDate)))   )  
  --ELSE      SUM(T1.RecurAmount) /  (  ( year(CONVERT(DATETIME,T1.EndDate)) - year(CONVERT(DATETIME,T1.STARTDate)) )*12  +  ( month(CONVERT(DATETIME,T1.EndDate)) - month(CONVERT(DATETIME,T1.StartDate))  + 1)  )  
  --END  
  
 SET @Qry = '  SELECT  Property , sum(UnitCount) UnitCount , monthdate , PropertyID , PropertyName , SUM(Rent)  Rent FROM (  
  select '''' Property , count( T0.UnitID ) UnitCount , ( convert(nvarchar, month(CONVERT(DATETIME,T1.EndDate)))  + '' - ''+   convert(nvarchar,year(CONVERT(DATETIME,T1.EndDate)))) as monthdate ,T1.PropertyID,    
  T2.Name PropertyName   ,  SUM(T1.RecurAmount)     AS  Rent  
  FROM REN_Units T0 with(nolock),REN_Contract T1 with(nolock),REN_Property T2  with(nolock)
  where T1.UnitID=T0.UnitID AND T1.PropertyID=T2.NodeID  and T0.Name is not null and T0.Name <>'''' AND  T1.CostCenterID = 95   
  AND T1.IsGroup <> 1 AND CONVERT(DATETIME,T1.EndDate) <= ''' + convert(nvarchar, @ToDate) +'''  
  AND CONVERT(DATETIME,T1.EndDate)  >= ''' + convert(nvarchar, @FromDate) +''''  
IF(@PropertyID IS NOT NULL AND @PropertyID <> '' AND @PropertyID <>'0')  
  SET  @Qry = @Qry  + ' AND T1.PROPERTYID IN (' + @PropertyID + ')'  
 SET  @Qry = @Qry  + '   group by month(CONVERT(DATETIME,T1.EndDate)) ,year(CONVERT(DATETIME,T1.EndDate)) , T1.PropertyID ,T2.Name      
  ,year(CONVERT(DATETIME,T1.STARTDate)) ,MONTH(CONVERT(DATETIME,T1.STARTDate))  
     ) AS T   GROUP BY  PropertyID , PropertyName  ,Property,   monthdate     ORDER BY  PropertyID , PropertyName, monthdate  '  
     
   EXEC (@QRY)      
     
  --, case when (year(CONVERT(DATETIME,T1.STARTDate)) = year(CONVERT(DATETIME,T1.EndDate))) THEN   SUM(T3.Amount)  /  ( month(CONVERT(DATETIME,T1.EndDate)) - month(CONVERT(DATETIME,T1.StartDate)) )   
  --when    (year(CONVERT(DATETIME,T1.EndDate)) > year(CONVERT(DATETIME,T1.STARTDate)) and   month(CONVERT(DATETIME,T1.EndDate)) =  month(CONVERT(DATETIME,T1.StartDate))) then  SUM(T3.Amount) /  (  ( year(CONVERT(DATETIME,T1.EndDate)) - year(CONVERT(DATETIME,T1.STARTDate)) )*12  +  ( month(CONVERT(DATETIME,T1.EndDate)) - month(CONVERT(DATETIME,T1.StartDate)))   )  
  --ELSE      SUM(T3.Amount) /  (  ( year(CONVERT(DATETIME,T1.EndDate)) - year(CONVERT(DATETIME,T1.STARTDate)) )*12  +  ( month(CONVERT(DATETIME,T1.EndDate)) - month(CONVERT(DATETIME,T1.StartDate)) + 1)  )  
  --END  
     
 SET @Qry = '  SELECT  Property  ,'''' UnitCount , monthdate , PropertyID , PropertyName , SUM(Rent)  Rent , ParticularName  , PARTNODEID    FROM (  
  select '''' Property , count( T0.UnitID ) UnitCount , ( convert(nvarchar, month(CONVERT(DATETIME,T1.EndDate)))  + '' - ''+   convert(nvarchar,year(CONVERT(DATETIME,T1.EndDate)))) as monthdate ,T1.PropertyID,    
  T2.Name PropertyName     , SUM(T3.Amount) AS  Rent , TMPStatusID.Name   ParticularName , T3.CCNodeID PARTNODEID     
  FROM REN_Units T0 with(nolock),REN_Contract T1 with(nolock),REN_Property T2 with(nolock) ,REN_ContractParticulars T3 with(nolock)   
  LEFT JOIN #tblTempFlatType  TMPStatusID ON  TMPStatusID.NODEID = T3.CCNODEID    
  where T1.UnitID=T0.UnitID AND T1.PropertyID=T2.NodeID  and T0.Name is not null and T0.Name <>'''' AND  T1.CostCenterID = 95 and   T3.CCNodeID <> 0  
   AND  T1.CONTRACTID = T3.CONTRACTID  
  AND T1.IsGroup <> 1 AND CONVERT(DATETIME,T1.EndDate) <= ''' + convert(nvarchar, @ToDate) +'''  
  AND CONVERT(DATETIME,T1.EndDate)  >= ''' + convert(nvarchar, @FromDate) +''''  
 IF(@PropertyID IS NOT NULL AND @PropertyID <> '' AND @PropertyID <>'0')  
	SET  @Qry = @Qry  + ' AND T1.PROPERTYID IN (' + @PropertyID + ')'  
    
  SET  @Qry = @Qry  + '   group by month(CONVERT(DATETIME,T1.EndDate)) ,year(CONVERT(DATETIME,T1.EndDate)) , T1.PropertyID ,T2.Name      
  ,year(CONVERT(DATETIME,T1.STARTDate)) ,MONTH(CONVERT(DATETIME,T1.STARTDate)), TMPStatusID.Name     , T3.CCNodeID    , TMPStatusID.NodeID  
     ) AS T   where ParticularName <> ''Rent'' GROUP BY  PropertyID , PropertyName  ,Property,   monthdate , ParticularName ,   PARTNODEID      ORDER BY  PropertyID , PropertyName, monthdate    '  
     
   EXEC (@QRY)     
   
 --  case when (year(CONVERT(DATETIME,T1.STARTDate)) = year(CONVERT(DATETIME,T1.EndDate))) THEN   SUM(T1.RecurAmount)  /  ( month(CONVERT(DATETIME,T1.EndDate)) - month(CONVERT(DATETIME,T1.StartDate)) )       
	--when    (year(CONVERT(DATETIME,T1.EndDate)) > year(CONVERT(DATETIME,T1.STARTDate)) and   month(CONVERT(DATETIME,T1.EndDate)) =  month(CONVERT(DATETIME,T1.StartDate))) then  SUM(T1.RecurAmount) /  (  ( year(CONVERT(DATETIME,T1.EndDate)) - year(CONVERT(DATETIME,T1.STARTDate)) )*12  +  ( month(CONVERT(DATETIME,T1.EndDate)) - month(CONVERT(DATETIME,T1.StartDate)))   )  
	--ELSE      SUM(T1.RecurAmount) /  (  ( year(CONVERT(DATETIME,T1.EndDate)) - year(CONVERT(DATETIME,T1.STARTDate)) )*12  +  ( month(CONVERT(DATETIME,T1.EndDate)) - month(CONVERT(DATETIME,T1.StartDate))  + 1)  )      END 
	
      
	SET @Qry = '    SELECT  Property  ,'''' UnitCount , monthdate , PropertyID , PropertyName , SUM(Rent)  Rent   , UNITSTATUS   
	FROM (      select '''' Property , count( T0.UnitID ) UnitCount , ( convert(nvarchar, month(CONVERT(DATETIME,T1.EndDate)))  + '' - ''+   convert(nvarchar,year(CONVERT(DATETIME,T1.EndDate)))) as monthdate ,T1.PropertyID,        T2.Name PropertyName         
	,   SUM(T1.RecurAmount)
	 AS  Rent                
	,  CCDATA.CCNID22 UNITSTATUS  
	FROM REN_Units T0 with(nolock),REN_Contract T1 with(nolock),REN_Property T2 with(nolock)  , COM_CCCCDATA  CCDATA  with(nolock)   
	where T1.UnitID=T0.UnitID AND T1.PropertyID=T2.NodeID  and T0.Name is not null and T0.Name <>'''' AND  T1.CostCenterID = 95  
	  AND  CCDATA.NODEID = T0.UNITID AND CCDATA.COSTCENTERID= 93  AND CCDATA.CCNID22 = '+ CONVERT(VARCHAR, ISNULL(@StaffFlat,0) )  +'     AND T1.IsGroup <> 1 
	AND CONVERT(DATETIME,T1.EndDate) <= ''' + convert(nvarchar, @ToDate) +'''  
	AND CONVERT(DATETIME,T1.EndDate)  >= ''' + convert(nvarchar, @FromDate) +''''  
 IF(@PropertyID IS NOT NULL AND @PropertyID <> '' AND @PropertyID <>'0')  
 SET  @Qry = @Qry  + ' AND T1.PROPERTYID IN (' + @PropertyID + ')'  
 
 SET  @Qry = @Qry  + '  group by month(CONVERT(DATETIME,T1.EndDate)) ,year(CONVERT(DATETIME,T1.EndDate)) , T1.PropertyID ,T2.Name          ,year(CONVERT(DATETIME,T1.STARTDate)) ,MONTH(CONVERT(DATETIME,T1.STARTDate))        ,  CCDATA.CCNID22         ) AS T   
 GROUP BY  PropertyID , PropertyName  ,Property,   monthdate , UNITSTATUS     ORDER BY  PropertyID , PropertyName, monthdate  '  
   EXEC (@QRY)  
   

	SET @Qry = '    SELECT  Property  ,'''' UnitCount , monthdate , PropertyID , PropertyName , SUM(Rent)  Rent   , UNITSTATUS    
	FROM (      select '''' Property , count( T0.UnitID ) UnitCount , ( convert(nvarchar, month(CONVERT(DATETIME,T1.EndDate)))  + '' - ''+   convert(nvarchar,year(CONVERT(DATETIME,T1.EndDate)))) as monthdate ,T1.PropertyID,        T2.Name PropertyName         
	, case when (year(CONVERT(DATETIME,T1.STARTDate)) = year(CONVERT(DATETIME,T1.EndDate))) THEN   SUM(T1.RecurAmount)  /  ( month(CONVERT(DATETIME,T1.EndDate)) - month(CONVERT(DATETIME,T1.StartDate)) )       
	when    (year(CONVERT(DATETIME,T1.EndDate)) > year(CONVERT(DATETIME,T1.STARTDate)) and   month(CONVERT(DATETIME,T1.EndDate)) =  month(CONVERT(DATETIME,T1.StartDate))) then  SUM(T1.RecurAmount) /  (  ( year(CONVERT(DATETIME,T1.EndDate)) - year(CONVERT(DATETIME,T1.STARTDate)) )*12  +  ( month(CONVERT(DATETIME,T1.EndDate)) - month(CONVERT(DATETIME,T1.StartDate)))   )  
	ELSE      SUM(T1.RecurAmount) /  (  ( year(CONVERT(DATETIME,T1.EndDate)) - year(CONVERT(DATETIME,T1.STARTDate)) )*12  +  ( month(CONVERT(DATETIME,T1.EndDate)) - month(CONVERT(DATETIME,T1.StartDate))) + 1 )      END  AS  Rent                
	,  CCDATA.CCNID22 UNITSTATUS
	FROM REN_Units T0 with(nolock),REN_Contract T1 with(nolock),REN_Property T2 with(nolock), COM_CCCCDATA CCDATA with(nolock)
	where T1.UnitID=T0.UnitID AND T1.PropertyID=T2.NodeID  and T0.Name is not null and T0.Name <>'''' AND  T1.CostCenterID = 95  
	  AND  CCDATA.NODEID = T0.UNITID AND CCDATA.COSTCENTERID= 93  AND CCDATA.CCNID22 = '+ CONVERT(VARCHAR, ISNULL(@ReconID,0) )  +'     AND T1.IsGroup <> 1 
	AND CONVERT(DATETIME,T1.EndDate) <= ''' + convert(nvarchar, @ToDate) +'''  
	AND CONVERT(DATETIME,T1.EndDate)  >= ''' + convert(nvarchar, @FromDate) +''''  
   
   IF(@PropertyID IS NOT NULL AND @PropertyID <> '' AND @PropertyID <>'0')  
	SET  @Qry = @Qry  + ' AND T1.PROPERTYID IN (' + @PropertyID + ')'  

	SET  @Qry = @Qry  + '  group by month(CONVERT(DATETIME,T1.EndDate)) ,year(CONVERT(DATETIME,T1.EndDate)) , T1.PropertyID ,T2.Name          ,year(CONVERT(DATETIME,T1.STARTDate)) ,MONTH(CONVERT(DATETIME,T1.STARTDate))        ,  CCDATA.CCNID22         ) AS T   
	GROUP BY  PropertyID , PropertyName  ,Property,   monthdate , UNITSTATUS     ORDER BY  PropertyID , PropertyName, monthdate  '  
     
   EXEC (@QRY)  
   
  -- case when (year(CONVERT(DATETIME,T1.STARTDate)) = year(CONVERT(DATETIME,T1.EndDate))) THEN   SUM(T1.RecurAmount)  /  ( month(CONVERT(DATETIME,T1.EndDate)) - month(CONVERT(DATETIME,T1.StartDate)) )       
	 --  when  (year(CONVERT(DATETIME,T1.STARTDate)) IS NULL AND year(CONVERT(DATETIME,T1.EndDate)) IS NULL ) THEN SUM(UNT.AnnualRent) / 12  
	 --  when    (year(CONVERT(DATETIME,T1.EndDate)) > year(CONVERT(DATETIME,T1.STARTDate)) and   month(CONVERT(DATETIME,T1.EndDate)) =  month(CONVERT(DATETIME,T1.StartDate))) then  SUM(T1.RecurAmount) /  (  ( year(CONVERT(DATETIME,T1.EndDate)) - year(CONVERT(DATETIME,T1.STARTDate)) )*12  +  ( month(CONVERT(DATETIME,T1.EndDate)) - month(CONVERT(DATETIME,T1.StartDate)))   )  
	 --ELSE      SUM(T1.RecurAmount) /  (  ( year(CONVERT(DATETIME,T1.EndDate)) - year(CONVERT(DATETIME,T1.STARTDate)) )*12  +  ( month(CONVERT(DATETIME,T1.EndDate)) - month(CONVERT(DATETIME,T1.StartDate))  + 1)  )      END
	 
	 
	SET  @QRY  = '  SELECT DISTINCT UNT.PROPERTYID  , '''' Property  , COUNT(UNT.Rent) Vacant 
	, SUM(T1.RecurAmount) AS  Rent  , ( convert(nvarchar, month(CONVERT(DATETIME,T1.EndDate)))  + '' - ''+   convert(nvarchar,year(CONVERT(DATETIME,T1.EndDate))))  as monthdate    
	 FROM REN_UNITS UNT with(nolock)
	JOIN REN_PROPERTY PROP with(nolock) ON PROP.NODEID = UNT.PROPERTYID AND UNT.UNITID NOT IN ( SELECT UNITID FROM REN_Contract with(nolock) WHERE CONVERT(DATETIME,EndDate) <= ''' + convert(nvarchar, @ToDate) +'''  
	AND CONVERT(DATETIME,EndDate)  >= ''' + convert(nvarchar, @FromDate) +''' )  
	LEFT JOIN REN_Contract T1 with(nolock) on UNT.unitid = T1.Unitid 
	LEFT JOIN COM_LOOKUP lkp with(nolock) ON  lkp.NODEID = UNT.UNITSTATUS AND lkp.LookupType = 46   
	WHERE  UNT.UnitID IS NOT NULL ' 
	IF(@PropertyID IS NOT NULL AND @PropertyID <> '' AND @PropertyID <>'0')
	SET  @Qry = @Qry  + ' AND UNT.PROPERTYID IN (' + @PropertyID + ')'
	SET  @QRY  =  @Qry  + 'GROUP BY month(CONVERT(DATETIME,T1.EndDate)) ,year(CONVERT(DATETIME,T1.EndDate)) ,year(CONVERT(DATETIME,T1.STARTDate)) ,MONTH(CONVERT(DATETIME,T1.STARTDate))  ,  UNT.PROPERTYID    '  
	EXEC (@QRY)
	
	DECLARE @From FLOAT,@To FLOAT , @AccID nvarchar(max), @AccIDTemp nvarchar(max) ,@Cnt int , @iCnt int  , @PropID BIGINT
	SET @From=CONVERT(FLOAT,@FromDate)
	SET @To=CONVERT(FLOAT,@ToDate)
		
	DECLARE @TEMPTABLEACCS TABLE (ID  INT IDENTITY (1,1 )NOT NULL , ACCS BIGINT NOT NULL , PropertyID BIGINT)

	INSERT INTO @TEMPTABLEACCS(ACCS, PropertyID)
    SELECT DISTINCT     ACCDOC.DebitAccount ,UNT.PROPERTYID  FROM REN_UNITS  UNT with(nolock)  
	JOIN REN_PROPERTY PROP with(nolock) ON PROP.NODEID = UNT.PROPERTYID 
	AND UNT.UNITID   IN ( SELECT distinct UNITID FROM REN_Contract with(nolock) WHERE CONVERT(DATETIME,EndDate) <= @ToDate AND CONVERT(DATETIME,EndDate)  >= @FromDate	AND COSTCENTERID = 95 )  
	JOIN REN_Contract T1 with(nolock) on UNT.unitid = T1.Unitid 
	LEFT JOIN ACC_DOCDETAILS ACCDOC with(nolock) ON ACCDOC.REFNODEID = T1.CONTRACTID    AND ACCDOC.REFCCID = 95
	JOIN ACC_Accounts Cred with(nolock) on Cred.accountid = ACCDOC.CreditAccount 
	JOIN ACC_Accounts Debt with(nolock) on Debt.accountid = ACCDOC.DebitAccount
	LEFT JOIN COM_LOOKUP lkp with(nolock) ON  lkp.NODEID = UNT.UNITSTATUS AND lkp.LookupType = 46   
	WHERE  UNT.UnitID IS NOT NULL  
	and (Cred.AccountTypeID  = 12 or Debt.AccountTypeID  = 12 )

	INSERT INTO @TEMPTABLEACCS(ACCS, PropertyID)
    SELECT DISTINCT     ACCDOC.CreditAccount ,UNT.PROPERTYID  FROM REN_UNITS  UNT with(nolock)
	JOIN REN_PROPERTY PROP with(nolock) ON PROP.NODEID = UNT.PROPERTYID 
	AND UNT.UNITID   IN ( SELECT distinct UNITID FROM REN_Contract with(nolock) WHERE CONVERT(DATETIME,EndDate) <= @ToDate AND CONVERT(DATETIME,EndDate)  >=@FromDate	AND COSTCENTERID = 95 )  
	JOIN REN_Contract T1 with(nolock) on UNT.unitid = T1.Unitid 
	LEFT JOIN ACC_DOCDETAILS ACCDOC with(nolock) ON ACCDOC.REFNODEID = T1.CONTRACTID    AND ACCDOC.REFCCID = 95
	JOIN ACC_Accounts Cred with(nolock) on Cred.accountid = ACCDOC.CreditAccount 
	JOIN ACC_Accounts Debt with(nolock) on Debt.accountid = ACCDOC.DebitAccount
	LEFT JOIN COM_LOOKUP lkp with(nolock) ON  lkp.NODEID = UNT.UNITSTATUS AND lkp.LookupType = 46   
	WHERE  UNT.UnitID IS NOT NULL  
	and (Cred.AccountTypeID  = 12 or Debt.AccountTypeID  = 12 )
	
	--SELECT @Cnt = COUNT(*) FROM @TEMPTABLEACCS
	--set @iCnt = 0
	
	--IF(@Cnt > 0)
	--BEGIN
	--	WHILE (@iCnt<=@Cnt)
	--	BEGIN
	--			SET @iCnt = @iCnt +  1
	--			SELECT @AccIDTemp = ACCS FROM @TEMPTABLEACCS WHERE ID = @iCnt
	--			IF(@iCnt = 1 )
	--			SET @AccID =  @AccIDTemp
	--			ELSE IF( @iCnt > 1 )
	--			SET @AccID = @AccID  + ','+ @AccIDTemp
				 
	--	END
	--END
	 
SELECT ACC.PropertyID,MAX(A.AccountCode) AccountCode,MAX(A.AccountName) AccountName,SUM(OP_Dr)+SUM(TR_Dr)-(SUM(OP_Cr)+SUM(TR_Cr)) Rent,
CONVERT(NVARCHAR,MONTH(ACC.DocDate))+'-'+  CONVERT(NVARCHAR,YEAR(ACC.DocDate))monthdate,A.AccountID,A.IsGroup,MAX(A.lft) lft,MAX(A.rgt) rgt,A.AccountTypeID,MAX(Depth) Depth,A.BS IsSummary
FROM (
SELECT PropertyID,AccountID,VoucherNo,DocDate,
CASE WHEN SUM(OP_Dr)-SUM(OP_Cr)>0 THEN SUM(OP_Dr)-SUM(OP_Cr) ELSE 0 END OP_Dr,
CASE WHEN SUM(OP_Dr)-SUM(OP_Cr)<0 THEN SUM(OP_Cr)-SUM(OP_Dr) ELSE 0 END OP_Cr,
CASE WHEN SUM(TR_Dr)-SUM(TR_Cr)>0 THEN SUM(TR_Dr)-SUM(TR_Cr) ELSE 0 END TR_Dr,
CASE WHEN SUM(TR_Dr)-SUM(TR_Cr)<0 THEN SUM(TR_Cr)-SUM(TR_Dr) ELSE 0 END TR_Cr
FROM (
--Opening Dr
SELECT CNT.PropertyID PropertyID , DebitAccount AccountID,VoucherNo,CONVERT(DATETIME,DocDate) DocDate,ACC.Amount OP_Dr,0 OP_Cr,0 TR_Dr,0 TR_Cr
FROM ACC_DocDetails ACC WITH(NOLOCK)
INNER JOIN REN_Contract CNT with(nolock) ON ACC.RefNodeid = CNT.CONTRACTID 
WHERE ACC.REFCCID = 95 AND  (DocDate<@From OR ACC.DocumentType=16) AND ACC.StatusID<>371  AND ACC.DocumentType<>14 AND ACC.DocumentType<>19 AND ACC.StatusID=369   
UNION ALL--Opening Cr
SELECT CNT.PropertyID PropertyID ,CreditAccount AccountID,VoucherNo,CONVERT(DATETIME,DocDate) DocDate,0 OP_Dr,ACC.Amount OP_Cr,0 TR_Dr, 0 TR_Cr
FROM ACC_DocDetails ACC WITH(NOLOCK)
INNER JOIN REN_Contract CNT with(nolock) ON ACC.RefNodeid = CNT.CONTRACTID 
WHERE ACC.REFCCID = 95 AND (DocDate<@From OR ACC.DocumentType=16) AND ACC.StatusID<>371  AND ACC.DocumentType<>14 AND ACC.DocumentType<>19 AND ACC.StatusID=369
UNION ALL--Transaction Dr
SELECT CNT.PropertyID PropertyID ,DebitAccount AccountID,VoucherNo,CONVERT(DATETIME,DocDate) DocDate,0 OP_Dr,0 OP_Cr,Amount TR_Dr,0 TR_Cr
FROM ACC_DocDetails ACC WITH(NOLOCK)
INNER JOIN REN_Contract CNT with(nolock) ON ACC.RefNodeid = CNT.CONTRACTID 
WHERE ACC.REFCCID = 95 AND (DocDate BETWEEN @From AND @To) AND ACC.DocumentType NOT IN (16,14,19) AND ACC.StatusID=369
UNION ALL--Transaction Cr
SELECT CNT.PropertyID PropertyID ,CreditAccount AccountID,VoucherNo,CONVERT(DATETIME,DocDate) DocDate,0 OP_Dr,0 OP_Cr,0 TR_Dr, Amount TR_Cr
FROM ACC_DocDetails ACC  WITH(NOLOCK)
INNER JOIN REN_Contract CNT with(nolock) ON ACC.RefNodeid = CNT.CONTRACTID 
WHERE ACC.REFCCID = 95 AND (DocDate BETWEEN @From AND @To) AND ACC.DocumentType NOT IN (16,14,19) AND ACC.StatusID=369) AS T1 GROUP BY PropertyID,AccountID,VoucherNo,DocDate
) AS ACC RIGHT JOIN ACC_Accounts A WITH(NOLOCK) ON A.AccountID=ACC.AccountID
INNER JOIN @TEMPTABLEACCS TEMPAC ON TEMPAC.ACCS = A.AccountID  
GROUP BY ACC.PropertyID,A.AccountID,A.AccountTypeID,A.IsGroup,A.BS,YEAR(ACC.DocDate), MONTH(ACC.DocDate)
HAVING A.AccountID>1  Order By lft

 IF @@ERROR<>0 BEGIN  RETURN -103 END      
        
RETURN 1      
End Try      
Begin Catch      
 RETURN -12345      
End Catch     
  
GO
