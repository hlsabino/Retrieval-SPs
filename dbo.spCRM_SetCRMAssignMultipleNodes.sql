USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_SetCRMAssignMultipleNodes]
	@CCID [int] = 0,
	@NodesXML [nvarchar](max),
	@TeamNodeID [bigint] = 0,
	@USERID [bigint] = 0,
	@IsTeam [bit] = 0,
	@UsersList [nvarchar](max) = null,
	@RolesList [nvarchar](max) = null,
	@GroupsList [nvarchar](max) = null,
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;    
		--Declaration Section  
  		DECLARE @HasAccess BIT,@NodeID BIGINT,@return_value int,@XML xml,@I int,@Cnt int
   
		SET @XML=@NodesXML
 
		--Create temporary table to read xml data into table
		CREATE TABLE #tblList(ID int identity(1,1),NodeID BIGINT)  
 
		--Read XML data into temporary table only to delete records
		INSERT INTO #tblList
		SELECT X.value('@NodeID','int')
		from @XML.nodes('/XML/Row') as Data(X)
		
		set @I=1
		select @Cnt=COUNT(*) from #tblList
		WHILE(@I<=@Cnt)  
		BEGIN 
			SELECT @NodeID=NodeID FROM #tblList WITH(nolock) WHERE ID=@I  			
			SET @I=@I+1
			
			EXEC	@return_value = [dbo].[spCRM_SetCRMAssignment]
				@CCID = @CCID, @CCNODEID = @NodeID,@TeamNodeID = @TeamNodeID,
				@USERID = @USERID,@IsTeam = @IsTeam,@UsersList = @UsersList,
				@RolesList = @RolesList,@GroupsList = @GroupsList,
				@CompanyGUID = @CompanyGUID,@UserName = @UserName, @LangID = @LangID
			select @return_value
		END

 

COMMIT TRANSACTION  
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
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine    
  FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID    
 END    
ROLLBACK TRANSACTION    
SET NOCOUNT OFF      
RETURN -999       
END CATCH
GO
