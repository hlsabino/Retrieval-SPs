USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRen_MoveMultipleUnits]
	@SelectedNodeID [bigint],
	@NodesXML [nvarchar](max),
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON; 
 
		--Declaration Section  
  		DECLARE @HasAccess BIT,@NodeID BIGINT,@return_value int,@XML xml,@I int,@Cnt int

		--Check for manadatory paramters  
		IF(@NodesXML='' OR @SelectedNodeID=0)
		BEGIN  
			RAISERROR('-100',16,1)   
		END

		--User acces check
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,93,5)
		
		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END

		SET @XML=@NodesXML

		--Create temporary table to read xml data into table
		CREATE TABLE #tblList(ID int identity(1,1),NodeID BIGINT)  


		--Read XML data into temporary table only to delete records
		INSERT INTO #tblList
		SELECT X.value('@NodeID','int')
		from @XML.nodes('/XML/Row') as Data(X)
		
 		--Set loop initialization varaibles
		SELECT @I=1, @Cnt=count(*) FROM #tblList  

		WHILE(@I<=@Cnt)  
		BEGIN

			SELECT @NodeID=NodeID FROM #tblList WITH(nolock) WHERE ID=@I  			
			SET @I=@I+1
			EXEC	@return_value = [dbo].[spRen_MoveUnits]
					@UnitID = @NodeID,
					@SelectedNodeID = @SelectedNodeID,
					@RoleID = @RoleID,
					@LangID = @LangID
	   
		END

COMMIT TRANSACTION
SET NOCOUNT OFF;
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=101 AND LanguageID=@LangID
RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		 SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		 FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
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
