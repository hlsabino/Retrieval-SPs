USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRpt_GetTigerReconRpt]
	@FromDate [datetime],
	@ToDate [datetime],
	@PropertyID [nvarchar](max),
	@ReportID [int],
	@UserID [bigint],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
Begin Try      
      
SET ARITHABORT ON      
  
  create  table #tblTempFlatType  ( ID INT IDENTITY(1,1),NODEID BIGINT NULL , NAME NVARCHAR(100) NULL)               
   DECLARE @TBLNAME NVARCHAR(50) ,@UnitTBLNAME NVARCHAR(50) ,@QRY NVARCHAR (MAX)  , @ReconID bigint , @StaffFlat BIGINT                  
   SELECT @TBLNAME = TABLENAME FROM  dbo.ADM_Features with(nolock)
   WHERE FEATUREID in ( select value from dbo.ADM_GlobalPreferences with(nolock) where name  = 'DepositLinkDimension')                       
     
	create  table #tblTempUnitPosition  ( ID INT IDENTITY(1,1),NODEID BIGINT NULL , NAME NVARCHAR(100) NULL)     
	select @UnitTBLNAME = tablename from adm_features with(nolock) where featureid in ( SELECT Value  FROM COM_COSTCENTERPREFERENCES with(nolock)  WHERE COSTCENTERID = 93 
	AND NAME =  'UnitPosition')
     
	IF(@UnitTBLNAME is not null and @UnitTBLNAME <>'')                   
	BEGIN                    
	SET @QRY = ' SELECT Nodeid,Name  FROM ' + @UnitTBLNAME+'  with(nolock)'                     
	INSERT INTO #tblTempUnitPosition(NODEID , NAME)                    
	EXEC (@QRY)                   
	END   

	IF(@ReportID = 1)
		SELECT @ReconID = Nodeid FROM #tblTempUnitPosition WHERE NAME  = 'Tiger Recon'
    ELSE 
		SELECT @ReconID = Nodeid FROM #tblTempUnitPosition WHERE NAME  = 'Staff'
		 
     
 
     
   IF(@TBLNAME is not null and @TBLNAME <>'')                   
   BEGIN                    
   SET @QRY = ' SELECT Nodeid,Name  FROM ' + @TBLNAME+'  with(nolock)'
   INSERT INTO #tblTempFlatType(NODEID , NAME)                    
   EXEC (@QRY)                   
   END      
 --      case when (year(CONVERT(DATETIME,T1.STARTDate)) = year(CONVERT(DATETIME,T1.EndDate))) THEN   SUM(T1.RecurAmount)  /  ( month(CONVERT(DATETIME,T1.EndDate)) - month(CONVERT(DATETIME,T1.StartDate)) )       
	-- when    (year(CONVERT(DATETIME,T1.EndDate)) > year(CONVERT(DATETIME,T1.STARTDate)) and   month(CONVERT(DATETIME,T1.EndDate)) =  month(CONVERT(DATETIME,T1.StartDate))) then  SUM(T1.RecurAmount) /  (  ( year(CONVERT(DATETIME,T1.EndDate)) - year(CONVERT(DATETIME,T1.STARTDate)) )*12  +  ( month(CONVERT(DATETIME,T1.EndDate)) - month(CONVERT(DATETIME,T1.StartDate)))   )  
	--ELSE      SUM(T1.RecurAmount) /  (  ( year(CONVERT(DATETIME,T1.EndDate)) - year(CONVERT(DATETIME,T1.STARTDate)) )*12  +  ( month(CONVERT(DATETIME,T1.EndDate)) - month(CONVERT(DATETIME,T1.StartDate))) + 1 )      END 

	SET @Qry = '    SELECT  Property  ,'''' UnitCount , monthdate , PropertyID , PropertyName , SUM(Rent)  Rent   , UNITSTATUS  , GroupName   
	FROM (      select '''' Property , count( T0.UnitID ) UnitCount , ( convert(nvarchar, month(CONVERT(DATETIME,T1.EndDate)))  + '' - ''+   convert(nvarchar,year(CONVERT(DATETIME,T1.EndDate)))) as monthdate ,T1.PropertyID,        T2.Name PropertyName         
	, SUM(T1.RecurAmount) AS  Rent                
	,  CCDATA.CCNID22 UNITSTATUS ,T2.PARENTID   
	   ,  (select PROP.Name from REN_Property PROP where  PROP.NODEID = T2.PARENTID  ) GroupName 
	FROM REN_Units T0 with(nolock),REN_Contract T1 with(nolock),REN_Property T2 with(nolock),COM_CCCCDATA CCDATA with(nolock)
	where T1.UnitID=T0.UnitID AND T1.PropertyID=T2.NodeID  and T0.Name is not null and T0.Name <>'''' AND  T1.CostCenterID = 95  
	  AND  CCDATA.NODEID = T0.UNITID AND CCDATA.COSTCENTERID= 93  AND CCDATA.CCNID22 = '+ CONVERT(VARCHAR, ISNULL(@ReconID,0) )  +'     AND T1.IsGroup <> 1 
	AND CONVERT(DATETIME,T1.EndDate) <= ''' + convert(nvarchar, @ToDate) +'''  
	AND CONVERT(DATETIME,T1.EndDate)  >= ''' + convert(nvarchar, @FromDate) +''''  
   
	IF(@PropertyID IS NOT NULL AND @PropertyID <> '' AND @PropertyID <>'0')  
	SET  @Qry = @Qry  + ' AND T1.PROPERTYID IN (' + @PropertyID + ')'  

	SET  @Qry = @Qry  + '  group by month(CONVERT(DATETIME,T1.EndDate)) ,year(CONVERT(DATETIME,T1.EndDate)) , T1.PropertyID ,T2.Name  ,T2.PARENTID           ,year(CONVERT(DATETIME,T1.STARTDate)) ,MONTH(CONVERT(DATETIME,T1.STARTDate))        ,  CCDATA.CCNID22         ) AS T   
	GROUP BY  PropertyID , PropertyName  ,Property,   monthdate , UNITSTATUS , GroupName    ORDER BY  PropertyID , PropertyName, monthdate  '  
 -- SELECT @QRY
   EXEC (@QRY)  
   

	SET @Qry = '     select '''' Property , count( T0.UnitID ) UnitCount 
	 
	,T1.PropertyID,        T2.Name PropertyName         
	 
	,  CCDATA.CCNID22 UNITSTATUS ,T2.PARENTID   
	   ,  (select PROP.Name from REN_Property PROP where  PROP.NODEID = T2.PARENTID  ) GroupName 
	FROM REN_Units T0 with(nolock),REN_Contract T1 with(nolock),REN_Property T2 with(nolock),COM_CCCCDATA  CCDATA with(nolock)
	where T1.UnitID=T0.UnitID AND T1.PropertyID=T2.NodeID  and T0.Name is not null and T0.Name <>'''' AND  T1.CostCenterID = 95  
	  AND  CCDATA.NODEID = T0.UNITID AND CCDATA.COSTCENTERID= 93  AND CCDATA.CCNID22 = '+ CONVERT(VARCHAR, ISNULL(@ReconID,0) )  +'     AND T1.IsGroup <> 1 
	AND CONVERT(DATETIME,T1.EndDate) <= ''' + convert(nvarchar, @ToDate) +'''  
	AND CONVERT(DATETIME,T1.EndDate)  >= ''' + convert(nvarchar, @FromDate) +''''  
   
	IF(@PropertyID IS NOT NULL AND @PropertyID <> '' AND @PropertyID <>'0')  
	SET  @Qry = @Qry  + ' AND T1.PROPERTYID IN (' + @PropertyID + ')'  

	SET  @Qry = @Qry  + '  group by  T1.PropertyID ,T2.Name  ,T2.PARENTID  ,  CCDATA.CCNID22            '
  
   EXEC (@QRY)  
	
     
 IF @@ERROR<>0 BEGIN  RETURN -103 END      
        
RETURN 1      
End Try      
Begin Catch      
 RETURN -12345      
End Catch     
 
GO
