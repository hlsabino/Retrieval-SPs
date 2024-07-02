USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_SetBioMetricConfig]
	@ConfigXml [nvarchar](max) = '',
	@ROffTimingsXml [nvarchar](max) = '',
	@DColXml [nvarchar](max) = '',
	@UserName [nvarchar](50)
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;    
      
	--Declaration Section    
	DECLARE @DATA XML,@COUNT INT,@I INT,@KEY NVARCHAR(500),@VALUE NVARCHAR(MAX),@Section NVARCHAR(50)    
	declare @ColID INT, @Rid INT, @CCID INT,@TabID int,@SQL nvarchar(MAX),@TblName nvarchar(50),@PMDim INT
	DECLARE @TEMP TABLE (ID INT IDENTITY(1,1),[KEY] NVARCHAR(500),[VALUE] NVARCHAR(MAX),Section NVARCHAR(50))    
    
  --UPDATE PAY_BioMetricConfig         
  SET @I=1    
  SET @DATA=@ConfigXml    
    
  INSERT INTO @TEMP ([KEY],[VALUE],Section)    
  SELECT X.value('@Name','nvarchar(500)'),X.value('@Value','nvarchar(max)'),X.value('@Section','nvarchar(50)')    
  FROM @DATA.nodes('/XML/Row') as DATA(X)    
   
  SELECT @COUNT=COUNT(*) FROM @TEMP    
    
  WHILE @I<=@COUNT    
  BEGIN          

	SELECT @KEY=[KEY],@VALUE=[VALUE],@Section=Section FROM @TEMP WHERE ID=@I    
      
	UPDATE PAY_BioMetricConfig     
	SET [Value]=@VALUE,
	Section=@Section,    
	[ModifiedBy]=@UserName,    
	[ModifiedDate]=convert(float,getdate())    
	WHERE [Name]=@KEY    
      
	SET @I=@I+1    
       
  END

  UPDATE PAY_BioMetricConfig     
	SET [Value]=@ROffTimingsXml,
	Section='ROTConfig',    
	[ModifiedBy]=@UserName,    
	[ModifiedDate]=convert(float,getdate())    
	WHERE [Name]='ROffTimingsXML'    

  UPDATE PAY_BioMetricConfig     
	SET [Value]=@DColXml,
	Section='DPConfig',    
	[ModifiedBy]=@UserName,    
	[ModifiedDate]=convert(float,getdate())    
	WHERE [Name]='DocColumnsXML'  
	
--ROLLBACK TRANSACTION
COMMIT TRANSACTION

SELECT * FROM PAY_BioMetricConfig WITH(NOLOCK)     
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=100 AND LanguageID=1       
SET NOCOUNT OFF;      
RETURN 1      
END TRY      
BEGIN CATCH      
 --Return exception info [Message,Number,ProcedureName,LineNumber]      
 IF ERROR_NUMBER()=50000    
 BEGIN    
  SELECT * FROM PAY_BioMetricConfig WITH(NOLOCK)     
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=1    
 END    
 ELSE    
 BEGIN    
       
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine    
  FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=1    
 END    
 ROLLBACK TRANSACTION    
 SET NOCOUNT OFF      
 RETURN -999       
END CATCH
GO
