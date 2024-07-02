USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_UpdateColAllDimension]
	@CCID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
-- =============================================    
-- Author      :  Waseem    
-- Create date : 19 04 2024    
-- Description : ADD WFID,WFLevel 2 COLUMN TO ALL DIMENSION BASED ON LICENSE    
-- Example     : spADM_UpdateColAllDimension 
-- =============================================    
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;    
DECLARE @TableName nvarchar(3000)  
DECLARE @UpdateSql varchar(1000)  
DECLARE @iFlag INT,@iTotCount INT;    
  
CREATE TABLE #CCTABLE (ID INT IDENTITY(1,1) PRIMARY KEY,DimensionID INT,DimensionName NVARCHAR(MAX))    
  
IF(@CCID=0)  
BEGIN  
 INSERT INTO #CCTABLE    
   SELECT  FeatureID,TableName from ADM_Features  WITH(NOLOCK) where   IsEnabled=1  AND (FeatureID BETWEEN 50000 AND 59999)
    
 --INSERT INTO #CCTABLE   
 --SELECT  FeatureID,TableName from ADM_Features  WITH(NOLOCK) where   IsEnabled=1  AND  FeatureID 
  
END  
ELSE  
BEGIN  
 INSERT INTO #CCTABLE   
  SELECT  FeatureID,TableName from ADM_Features  WITH(NOLOCK) where   IsEnabled=1  AND  FeatureID=@CCID   
END  
    
    
   
 SELECT @iFlag=1,@iTotCount=Count(*) FROM #CCTABLE WITH(NOLOCK)    
      
   While (@iFlag<=@iTotCount)    
   BEGIN   
    set @TableName ='';  
    SELECT @TableName=DimensionName FROM #CCTABLE WITH(NOLOCK) WHERE ID=@iFlag  
    if ISNULL(col_length(@TableName,'WFID'),0)=0  
    Begin  
	   set @UpdateSql=''  
	   set @UpdateSql='Alter Table '+ @TableName+' Add WFID int NULL'  
	   exec (@UpdateSql)   
	End  
    if ISNULL(col_length(@TableName,'WFLevel'),0)=0  
    Begin   
	   set @UpdateSql=''  
	   set @UpdateSql='Alter Table  '+ @TableName+' Add WFLevel int NULL'   
	   PRINT @UpdateSql  
	   exec (@UpdateSql)   
    End   
	SET @iFlag=@iFlag+1    
   END  
  
Drop table  #CCTABLE       
COMMIT TRANSACTION     
SET NOCOUNT OFF;       
RETURN 1    
END TRY    
BEGIN CATCH      
 IF ERROR_NUMBER()=50000    
 BEGIN    
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
 END    
 ELSE    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine    
 FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID    
 END    
ROLLBACK TRANSACTION    
SET NOCOUNT OFF      
RETURN -999       
END CATCH 
GO
