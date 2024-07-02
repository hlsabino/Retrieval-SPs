﻿USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetCCCCMapDetailsByID]
	@PARENTFEATUREID [int],
	@PNodeID [int] = 0,
	@CHILDFEATUREID [int],
	@UserID [int] = 1,
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY      
SET NOCOUNT ON;      
  --Declaration Section    
  DECLARE @HasAccess bit    
    
  --SP Required Parameters Check    
  IF @PARENTFEATUREID =0    
  BEGIN    
   RAISERROR('-100',16,1)    
  END    
     
  
   
    SELECT *   FROM    COM_CostCenterCostCenterMap WITH (NOLOCK)   
 WHERE  CostCenterId=@CHILDFEATUREID and PARENTCOSTCENTERID  = 6 AND PARENTNODEID =@RoleID
  
     SELECT *   FROM COM_CostCenterCostCenterMap WITH(NOLOCK)  
      WHERE ParentCostCenterID=@PARENTFEATUREID AND ParentNodeID=@PNodeID  
  AND CostCenterId=@CHILDFEATUREID  
  
  
 CREATE TABLE #TBL(ID INT IDENTITY(1,1),NODEID INT,CCID INT)  
 CREATE TABLE #TBLdATA(ID INT IDENTITY(1,1),NODEID INT, PARENTID INT,CCID INT)  
 INSERT INTO #TBL  
 SELECT NODEID,CostCenterId FROM COM_CostCenterCostCenterMap WHERE ParentCostCenterID=@PARENTFEATUREID AND ParentNodeID=@PNodeID  
 AND CostCenterId=@CHILDFEATUREID 
 
 DECLARE @I INT,@COUNT INT,@LOCATION INT,@CCID INT,@SQL NVARCHAR(MAX),@TABLENAME NVARCHAR(MAX)  
 SET @I=1  
 SELECT @COUNT=COUNT(*) FROM #TBL  
 WHILE @I<=@COUNT  
 BEGIN  
 SELECT @LOCATION=NODEID,@CCID=CCID FROM #TBL WHERE ID=@I  
    
 SELECT @TABLENAME=TABLENAME FROM ADM_FEATURES WHERE FEATUREID=@CCID 
 PRINT @CCID
	IF( @CCID = 7) 
	BEGIN 
		SET @SQL='  
		IF ((SELECT COUNT(*) FROM '+@TABLENAME+' WHERE USERID='+CONVERT(VARCHAR,@LOCATION)+'  )>0)  
		BEGIN  
		INSERT INTO #TBLdATA (NODEID,CCID) VALUES ('+CONVERT(VARCHAR,@LOCATION)+','+CONVERT(VARCHAR,@CCID)+')  
		INSERT INTO #TBLdATA  (NODEID,CCID, PARENTID)   
		SELECT USERID  , '+CONVERT(VARCHAR,@CCID)+','+CONVERT(VARCHAR,@LOCATION)+' FROM '+@TABLENAME+' WHERE USERID='+CONVERT(VARCHAR,@LOCATION)+'  
		END  
		ELSE  
		INSERT INTO #TBLdATA  (NODEID,CCID) VALUES ('+CONVERT(VARCHAR,@LOCATION)+','+CONVERT(VARCHAR,@CCID)+')'  
	END
	ELSE IF( @CCID = 6) 
	BEGIN 
		SET @SQL='  
		IF ((SELECT COUNT(*) FROM '+@TABLENAME+' WHERE ROLEID='+CONVERT(VARCHAR,@LOCATION)+'  )>0)  
		BEGIN  
		INSERT INTO #TBLdATA (NODEID,CCID) VALUES ('+CONVERT(VARCHAR,@LOCATION)+','+CONVERT(VARCHAR,@CCID)+')  
		INSERT INTO #TBLdATA  (NODEID,CCID, PARENTID)   
		SELECT ROLEID  , '+CONVERT(VARCHAR,@CCID)+','+CONVERT(VARCHAR,@LOCATION)+' FROM '+@TABLENAME+' WHERE ROLEID='+CONVERT(VARCHAR,@LOCATION)+'  
		END  
		ELSE  
		INSERT INTO #TBLdATA  (NODEID,CCID) VALUES ('+CONVERT(VARCHAR,@LOCATION)+','+CONVERT(VARCHAR,@CCID)+')'  
	END		
	ELSE IF( @CCID = 300) 
	BEGIN 
		SET @SQL='  
		IF ((SELECT COUNT(*) FROM '+@TABLENAME+' WHERE CostCenterID='+CONVERT(VARCHAR,@LOCATION)+')>0)  
		BEGIN  
		INSERT INTO #TBLdATA (NODEID,CCID) VALUES ('+CONVERT(VARCHAR,@LOCATION)+','+CONVERT(VARCHAR,@CCID)+')  
		INSERT INTO #TBLdATA  (NODEID,CCID, PARENTID)   
		SELECT CostCenterID NODEID, '+CONVERT(VARCHAR,@CCID)+','+CONVERT(VARCHAR,@LOCATION)+' FROM '+@TABLENAME+' WHERE CostCenterID='+CONVERT(VARCHAR,@LOCATION)+'  
		END  
		ELSE  
		INSERT INTO #TBLdATA  (NODEID,CCID) VALUES ('+CONVERT(VARCHAR,@LOCATION)+','+CONVERT(VARCHAR,@CCID)+')'  
	END		
	ELSE IF( @CCID = 8) 
	BEGIN 
		SET @SQL='  
		IF ((SELECT COUNT(*) FROM '+@TABLENAME+' WHERE CostCenterID='+CONVERT(VARCHAR,@LOCATION)+')>0)  
		BEGIN  
		INSERT INTO #TBLdATA (NODEID,CCID) VALUES ('+CONVERT(VARCHAR,@LOCATION)+','+CONVERT(VARCHAR,@CCID)+')  
		INSERT INTO #TBLdATA  (NODEID,CCID, PARENTID)   
		SELECT Top 1 CostCenterID NODEID, '+CONVERT(VARCHAR,@CCID)+','+CONVERT(VARCHAR,@LOCATION)+' FROM '+@TABLENAME+' WHERE CostCenterID='+CONVERT(VARCHAR,@LOCATION)+'  
		END  
		ELSE  
		INSERT INTO #TBLdATA  (NODEID,CCID) VALUES ('+CONVERT(VARCHAR,@LOCATION)+','+CONVERT(VARCHAR,@CCID)+')'  
	END		
	ELSE
	BEGIN
		SET @SQL='  
		IF ((SELECT COUNT(*) FROM '+@TABLENAME+' WHERE NODEID='+CONVERT(VARCHAR,@LOCATION)+' AND ISGROUP=1)>0)  
		BEGIN  
		INSERT INTO #TBLdATA (NODEID,CCID) VALUES ('+CONVERT(VARCHAR,@LOCATION)+','+CONVERT(VARCHAR,@CCID)+')  
		INSERT INTO #TBLdATA  (NODEID,CCID, PARENTID)   
		SELECT NODEID, '+CONVERT(VARCHAR,@CCID)+','+CONVERT(VARCHAR,@LOCATION)+' FROM '+@TABLENAME+' WHERE PARENTID='+CONVERT(VARCHAR,@LOCATION)+'  
		END  
		ELSE  
		INSERT INTO #TBLdATA  (NODEID,CCID) VALUES ('+CONVERT(VARCHAR,@LOCATION)+','+CONVERT(VARCHAR,@CCID)+')'  
	END
 --select @SQL
EXEC (@SQL)  
SET @I=@I+1  
END  

SELECT * FROM #TBLdATA  
DROP TABLE #TBLdATA  
DROP TABLE #TBL  
  -- GET CCCCC MAP DATA    
--      SELECT *   FROM COM_CostCenterCostCenterMap WITH(NOLOCK) WHERE ParentCostCenterID=@PARENTFEATUREID AND ParentNodeID=@PNodeID  
--    AND CostCenterId=@CHILDFEATUREID  
  
  
COMMIT TRANSACTION    
SET NOCOUNT OFF;      
RETURN 1    
END TRY    
BEGIN CATCH      
 --Return exception info [Message,Number,ProcedureName,LineNumber]      
 IF ERROR_NUMBER()=50000    
 BEGIN    
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
 END    
 ELSE    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine    
  FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID    
 END    
ROLLBACK TRANSACTION    
SET NOCOUNT OFF      
RETURN -999       
END CATCH
GO
