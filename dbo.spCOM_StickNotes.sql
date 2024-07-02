USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_StickNotes]
	@Type [int],
	@NoteID [bigint],
	@Notes [nvarchar](max),
	@UserName [nvarchar](50)
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY
SET NOCOUNT ON
	DECLARE @XML XML, @Dt FLOAT
	SET @Dt=convert(float,getdate())
	
	if @Type=1
	begin
		select NoteID,Note from COM_Notes with(nolock) where NoteType=1 and CreatedBy=@UserName
	end
	else if @Type=2
	begin
		delete from COM_Notes where NoteID=@NoteID
	end
	else if @Type=3
	begin
		select NoteID,Note from COM_Notes with(nolock) where NoteID=@NoteID
	end
	else if @Type=4
	begin
		IF @NoteID=0
		begin
			INSERT INTO COM_Notes(FeatureID,CostCenterID,FeaturePK,Note, 
			GUID,CreatedBy,CreatedDate,NoteType)
			VALUES(132,132,0,Replace(@Notes,'@~','
'),  
			newid(),@UserName,@Dt,1)
			select SCOPE_IDENTITY() NoteID
		end
		ELSE
			UPDATE COM_Notes  
			SET Note=Replace(@Notes,'@~','
'),ModifiedBy=@UserName,ModifiedDate=@Dt
			 where NoteID=@NoteID
	end

COMMIT TRANSACTION
SET NOCOUNT OFF;
RETURN 1
END TRY  
  
BEGIN CATCH   
	--Return exception info [Message,Number,ProcedureName,LineNumber]    
	IF ERROR_NUMBER()=50000  
	BEGIN  
		IF ISNUMERIC(ERROR_MESSAGE())=1
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=1  
		ELSE
			SELECT ERROR_MESSAGE() ErrorMessage
	END  
	ELSE  
	BEGIN  
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=1  
	END  
	ROLLBACK TRANSACTION  
	SET NOCOUNT OFF    
	RETURN -999     
END CATCH  
GO
