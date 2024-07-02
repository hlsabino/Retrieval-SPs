USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_MoveMultipleCases]
	@SelectedNodeID [bigint],
	@CaseXML [nvarchar](max),
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN 
--BEGIN TRY  
--SET NOCOUNT ON; 
 
		--Declaration Section  
  		DECLARE @HasAccess BIT,@CaseID BIGINT,@return_value int,@XML xml,@I int,@Cnt int

		--Check for manadatory paramters  
		IF(@CaseXML='' OR @SelectedNodeID=0)
		BEGIN  
			RAISERROR('-100',16,1)   
		END

		--User acces check
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,73,5)
		
		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END

		SET @XML=@CaseXML

		--Create temporary table to read xml data into table
		CREATE TABLE #tblList(ID int identity(1,1),CaseID BIGINT)  


		--Read XML data into temporary table only to delete records
		INSERT INTO #tblList
		SELECT X.value('@CaseID','BIGINT')
		from @XML.nodes('/XML/Row') as Data(X)
		 
 		--Set loop initialization varaibles
		SELECT @I=1, @Cnt=count(*) FROM #tblList  

		WHILE(@I<=@Cnt)  
		BEGIN
			
			SELECT @CaseID=CaseID FROM #tblList WITH(nolock) WHERE ID=@I  			
			SET @I=@I+1
			EXEC	@return_value = [dbo].[spCRM_MoveCase]
					@CaseID = @CaseID,
					@SelectedNodeID = @SelectedNodeID,
					@RoleID = @RoleID,
					@LangID = @LangID 
					 
					 IF @return_value=-999
					 BEGIN 
						 RETURN @return_value
					 END
					 
		END

END
 
--SET NOCOUNT OFF;
--SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
--WHERE ErrorNumber=101 AND LanguageID=@LangID
RETURN  @return_value
--END TRY
--BEGIN CATCH  
--	----Return exception info [Message,Number,ProcedureName,LineNumber]  
--	--IF ERROR_NUMBER()=50000
--	--BEGIN
--	--	 SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
--	--	 FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
--	--END
--	--ELSE
--	--BEGIN
--	--	SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
--	--	FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
--	--END
--ROLLBACK TRANSACTION
--SET NOCOUNT OFF  
--RETURN -999   
--END CATCH
GO
