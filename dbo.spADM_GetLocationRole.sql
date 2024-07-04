USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetLocationRole]
	@CostCenterId [int],
	@LangID [int] = 1,
	@Where [nvarchar](max) = ''
WITH ENCRYPTION, EXECUTE AS CALLER
AS
       
BEGIN TRY        
SET NOCOUNT ON;      
   DECLARE @TABLENAME NVARCHAR(200),@SQL NVARCHAR(MAX)  
     
	IF(@CostCenterId = 7)
	BEGIN
		SELECT @TABLENAME=TABLENAME FROM ADM_FEATURES with(nolock) WHERE FEATUREID=@CostCenterId     
		SET @SQL=' SELECT 0 AS NodeID, ''Users'' as Name , 1 IsGroup , 0 Depth , 1 AS ParentID , 0 AS LFT, 0 AS RGT 
		UNION  SELECT UserID as NodeID , UserName as Name , 0 IsGroup , 1 Depth , 0 AS ParentID ,1 AS LFT, 1 AS RGT   FROM   '+@TABLENAME +' with(nolock)'
		if(@Where<>'')
			set @SQL=@SQL+@Where
	END
	ELSE IF(@CostCenterId = 300)
	BEGIN
		SELECT @TABLENAME=TABLENAME FROM ADM_FEATURES with(nolock) WHERE FEATUREID=@CostCenterId     
		SET @SQL=' SELECT 0 AS NodeID, ''Documents'' as Name , 1 IsGroup , 0 Depth , 1 AS ParentID , 0 AS LFT, 0 AS RGT 
		UNION  SELECT CostCenterID as NodeID , DocumentName as Name , 0 IsGroup , 1 Depth , 0 AS ParentID ,1 AS LFT, 1 AS RGT   FROM   '+@TABLENAME +' with(nolock)'
		if(@Where<>'')
			set @SQL=@SQL+@Where
	END
	ELSE IF(@CostCenterId = 8)
	BEGIN
		SELECT @TABLENAME=TABLENAME FROM ADM_FEATURES with(nolock) WHERE FEATUREID=@CostCenterId     
		SET @SQL=' SELECT 0 AS NodeID, ''Dimensions'' as Name , 1 IsGroup , 0 Depth , 1 AS ParentID , 0 AS LFT, 0 AS RGT 
		UNION  SELECT FeatureID as NodeID , Name , 0 IsGroup , 1 Depth , 0 AS ParentID ,1 AS LFT, 1 AS RGT   FROM   ADM_Features with(nolock) where (FeatureID IN (2,3,92,93,94,95,103,104,150,129) or FeatureID>50000)'
		if(@Where<>'')
			set @SQL=@SQL+@Where
			
		print @SQL
	END
	ELSE
	BEGIN
		SELECT @TABLENAME=TABLENAME FROM ADM_FEATURES with(nolock) WHERE FEATUREID=@CostCenterId     
		SET @SQL='SELECT * FROM '+@TABLENAME + ' with(nolock)'
		if(@Where<>'')
			set @SQL=@SQL+@Where
		SET @SQL=@SQL+'  ORDER BY LFT   '   
	END
	PRINT @SQL
	EXEC(@SQL)  
        
 --IF @CostCenterId = 50002  
 --BEGIN  
 --SELECT * FROM COM_Location  ORDER BY LFT     
 --END   
 --ELSE  IF @CostCenterId = 50001  
 --BEGIN  
 --SELECT * FROM COM_Division  ORDER BY LFT     
 --END         
     
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)       
WHERE ErrorNumber=100 AND LanguageID=@LangID          
SET NOCOUNT OFF;        
RETURN @LangID        
END TRY        
BEGIN CATCH        
 --Return exception info [Message,Number,ProcedureName,LineNumber]        
 IF ERROR_NUMBER()=50000      
 BEGIN      
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID      
 END      
 ELSE IF ERROR_NUMBER()=547      
 BEGIN      
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)      
  WHERE ErrorNumber=-110 AND LanguageID=@LangID      
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
