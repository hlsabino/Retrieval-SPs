USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRpt_GetTowerwiseRentRpt]
	@FromDate [datetime],
	@ToDate [datetime],
	@WHERE [nvarchar](max) = '',
	@UserID [bigint],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
Begin Try    
    
SET ARITHABORT ON    
     
	create  table #tblTempFlatType  ( ID INT IDENTITY(1,1),NODEID BIGINT NULL , NAME NVARCHAR(100) NULL)             
	DECLARE @TBLNAME NVARCHAR(50) ,@QRY NVARCHAR (MAX)                 
	SELECT @TBLNAME = TABLENAME FROM ADM_Features  with(nolock)
	WHERE FEATUREID in ( select value from ADM_GlobalPreferences with(nolock) where name  = 'UnitLinkDimension')                     
   
	IF(@TBLNAME is not null and @TBLNAME <>'')                 
	BEGIN                  
		SET @QRY = ' SELECT Nodeid,Name  FROM ' + @TBLNAME +' with(nolock)'                  
		INSERT INTO #tblTempFlatType(NODEID , NAME)                  
		EXEC (@QRY)                 
	END 
	 
	SET @Qry = ' SELECT  Property ,  SUM(Total) Total ,Nodeid ,  SUM(Rent) Rent , SoldStatus ,  Name , PropertyID ,UnitTypeID , PropertyName  FROM
	( SELECT  DISTINCT Property ,  (Total) Total ,Nodeid ,  (Rent) Rent , SoldStatus ,  Name , PropertyID ,UnitTypeID , PropertyName   
	FROM (  SELECT  DISTINCT '''' Property  , COUNT(UNT.NodeID) Total , UNT.Nodeid     , SUM(UNT.Rent)  Rent 
	, case when lkp.Name LIKE ''Sold%'' THEN  ''Sold'' else ''Not Sold'' end  SoldStatus , TMPStatusID.Name   Name
	, UNT.PROPERTYID PropertyID   , TMPStatusID.NodeID UnitTypeID , PROP.Name PropertyName
	FROM REN_UNITS UNT with(nolock)	
	JOIN REN_PROPERTY PROP with(nolock) ON PROP.NODEID = UNT.PROPERTYID
	JOIN COM_CCCCData CCD with(nolock) ON CCD.NODEID=PROP.NODEID AND CCD.CostCenterID=92
	LEFT JOIN com_lookup lkp with(nolock) ON  lkp.NODEID = UNT.UNITSTATUS AND lkp.LookupType = 46 
	LEFT JOIN #tblTempFlatType  TMPStatusID ON  TMPStatusID.NODEID = UNT.NODEID  
	WHERE 1=1 '+@WHERE
	
	SET  @Qry = @Qry  + '  GROUP BY UNT.NodeID  ,   lkp.Name , TMPStatusID.Name     , UNT.PROPERTYID , TMPStatusID.NodeID, PROP.Name ) AS S ) AS IKM  
	GROUP BY PROPERTY  , Nodeid  , SoldStatus ,  Name , PropertyID ,UnitTypeID  , PropertyName  order by propertyid '
	print @QRY
	EXEC (@QRY)      
	
	
	SET  @TBLNAME ='' 
	SET @QRY  =''                
	select @TBLNAME = TableName from adm_features with(nolock) 
	where featureid=(select value from ADM_GlobalPreferences with(nolock) where Name='DepositLinkDimension')                   
    
	SET  @QRY  = ' SELECT  DISTINCT UNT.PROPERTYID  , TMPStatusID.Nodeid UnitTypeID, CNTPART.PARTICULARID , CNTPARTTBL.NAME PARTNAME
	,SUM(CNTPART.DISCOUNTAMOUNT) AMOUNT , TMPStatusID.Name   UnitTypeName
	FROM  REN_UNITS UNT with(nolock)
	JOIN REN_PROPERTY PROP with(nolock) ON PROP.NODEID = UNT.PROPERTYID
	JOIN COM_CCCCData CCD with(nolock) ON CCD.NODEID=PROP.NODEID AND CCD.CostCenterID=92
	JOIN REN_PARTICULARS CNTPART with(nolock) ON UNT.UNITID = CNTPART.UNITID
	LEFT JOIN #tblTempFlatType  TMPStatusID ON  TMPStatusID.NODEID = UNT.NODEID  
	JOIN ' +@TBLNAME +' CNTPARTTBL ON 	CNTPART.PARTICULARID =  CNTPARTTBL.NODEID '
	
	SET  @QRY  =  @Qry  + ' WHERE CNTPARTTBL.NAME  <> ''Rent'' '+@WHERE
	
	SET  @QRY  =  @Qry  + ' GROUP BY  UNT.PROPERTYID, CNTPART.PARTICULARID, CNTPARTTBL.NAME , TMPStatusID.Nodeid , TMPStatusID.Name   
	order by UNT.PROPERTYID, CNTPARTTBL.NAME , TMPStatusID.Name  '
	print @QRY
	EXEC (@QRY)
	
	
	SET  @QRY  = '  SELECT DISTINCT UNT.PROPERTYID  , '''' Property  , COUNT(UNT.Rent) Vacant , SUM(UNT.Rent) Rent  , TMPStatusID.Name   UnitTypeName , TMPStatusID.Nodeid UnitTypeID
	from REN_UNITS UNT with(nolock)
    JOIN REN_PROPERTY PROP with(nolock) ON PROP.NODEID = UNT.PROPERTYID AND UNT.UNITID NOT IN ( SELECT UNITID FROM REN_Contract WITH(NOLOCK)
    WHERE (CONVERT(DATETIME,STARTDATE)    BETWEEN  ''' + convert(nvarchar, @FromDate )  + ''' AND ''' + convert(nvarchar, @ToDate) +'''  OR  CONVERT(DATETIME,ENDDATE)    BETWEEN  ''' + convert(nvarchar, @FromDate )  + ''' AND ''' + convert(nvarchar, @ToDate) +''' ) ) 
	JOIN COM_CCCCData CCD with(nolock) ON CCD.NODEID=PROP.NODEID AND CCD.CostCenterID=92
	LEFT JOIN com_lookup lkp with(nolock) ON  lkp.NODEID = UNT.UNITSTATUS AND lkp.LookupType = 46   
	LEFT JOIN #tblTempFlatType  TMPStatusID ON  TMPStatusID.NODEID = UNT.NODEID    
	where  UNT.UnitID IS NOT NULL '+@WHERE 
	 
	SET  @QRY  =  @Qry  + 'GROUP BY   UNT.PROPERTYID  ,  TMPStatusID.Name     , TMPStatusID.Nodeid  '  
	print @QRY
	EXEC (@QRY)
	
	drop table #tblTempFlatType
	IF @@ERROR<>0 BEGIN  RETURN -103 END    
	      
	RETURN 1    
End Try    
Begin Catch    
	RETURN -12345    
End Catch    




GO
