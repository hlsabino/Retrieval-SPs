USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetNotifEventTemp]
	@TYPE [int] = 1,
	@CostCenterID [int],
	@NodeID [nvarchar](max),
	@SubCostCenterid [int],
	@SubNodeID [int],
	@TemplateType [int],
	@From [nvarchar](max) = NULL,
	@DisplayName [nvarchar](max) = NULL,
	@To [nvarchar](max) = NULL,
	@CC [nvarchar](max) = NULL,
	@BCC [nvarchar](max) = NULL,
	@AttachmentType [nvarchar](50) = NULL,
	@AttachmentID [int],
	@Subject [nvarchar](max) = NULL,
	@Body [nvarchar](max) = NULL,
	@FilterXML [nvarchar](max) = NULL,
	@TempTemplateID [int] = null,
	@LocationID [int],
	@MapColumn [nvarchar](max) = NULL,
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON; 
select @AttachmentID
	--Declaration Section    
	DECLARE @Dt FLOAT,@ID INT
	SET @Dt=CONVERT(FLOAT,GETDATE())

	IF @TYPE=1
	BEGIN
		
		IF( @NodeID LIKE '%,%')
		BEGIN
				declare @TblNodes1 table(ID nvarchar(50))  
				insert into @TblNodes1  
				exec SPSplitString @NodeID,',' 
				
				INSERT INTO COM_SchEvents
				(ScheduleID,EventTime,StatusID,StartFlag,StartDate,EndDate
				,[CostCenterID],[NodeID],[SubCostCenterid],[SubNodeID],TemplateID,[TemplateType]
				,[From],[DisplayName],[To],[CC],[BCC],[AttachmentType],[AttachmentID]
				,[Subject],[Body],FilterXML,TempTemplateID,LocationID,MapColumn
      			,CompanyGUID,[GUID],CreatedBy,CreatedDate)
      			
				SELECT 0,@Dt,1,0,@Dt,@Dt
				,@CostCenterID,ID,@SubCostCenterid,@SubNodeID,0,@TemplateType
				,@From,@DisplayName,@To,@CC,@BCC,@AttachmentType,@AttachmentID
				,@Subject,@Body,@FilterXML,@TempTemplateID,@LocationID,@MapColumn
				,@CompanyGUID,newid(),@UserName,@Dt FROM @TblNodes1
		END
		ELSE
		BEGIN
			INSERT INTO COM_SchEvents
				(ScheduleID,EventTime,StatusID,StartFlag,StartDate,EndDate
				,[CostCenterID],[NodeID],[SubCostCenterid],[SubNodeID],TemplateID,[TemplateType]
				,[From],[DisplayName],[To],[CC],[BCC],[AttachmentType],[AttachmentID]
				,[Subject],[Body],FilterXML,TempTemplateID,LocationID,MapColumn
      			,CompanyGUID,[GUID],CreatedBy,CreatedDate)
			VALUES
				(0,@Dt,1,0,@Dt,@Dt
				,@CostCenterID,CONVERT(INT,@NodeID),@SubCostCenterid,@SubNodeID,0,@TemplateType
				,@From,@DisplayName,@To,@CC,@BCC,@AttachmentType,@AttachmentID
				,@Subject,@Body,@FilterXML,@TempTemplateID,@LocationID,@MapColumn
				,@CompanyGUID,newid(),@UserName,@Dt)
		END 

		--To get inserted record primary key    
		SET @ID=SCOPE_IDENTITY()
	END
	ELSE IF @TYPE=2
	BEGIN
		declare @TblNodes table(ID nvarchar(50))  
		insert into @TblNodes  
		exec SPSplitString @Body,','  

		INSERT INTO COM_SchEvents(CostCenterID,NodeID,TemplateID,OtherDocsNos,StatusID,EventTime,ScheduleID,StartFlag,StartDate,EndDate,CompanyGUID,GUID,  
			CreatedBy,CreatedDate,SUBCostCenterID,SUBNodeID,FilterXML,TempTemplateID,LocationID,MapColumn)
		SELECT @CostCenterID,ID,@AttachmentID,@Subject,1,@Dt,0,0,@Dt,@Dt,@CompanyGUID,@GUID,
			@UserName,@Dt,@SUBCostCenterID,@SUBNodeID,@FilterXML,@TempTemplateID,@LocationID,@MapColumn
		FROM @TblNodes      

		SET @ID=1
	END
	
COMMIT TRANSACTION  
--ROLLBACK TRANSACTION

SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;      
RETURN  @ID    
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
