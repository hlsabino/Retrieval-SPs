USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_SetPostingGroup]
	@PostingGroupID [bigint],
	@PostGroupCode [nvarchar](200),
	@PostGroupName [nvarchar](500),
	@AcqnCostACCID [bigint],
	@AccumDeprACCID [bigint],
	@AcqnCostDispACCID [bigint],
	@AccumDeprDispACCID [bigint],
	@GainsDispACCID [bigint],
	@LossDispACCID [bigint],
	@MaintExpenseACCID [bigint],
	@DeprExpenseACCID [bigint],
	@StatusID [int],
	@SelectedNodeID [bigint],
	@IsGroup [bit],
	@CompanyGUID [varchar](50),
	@GUID [varchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
		--Declaration Section
		DECLARE @Dt float,@XML xml,@TempGuid nvarchar(50),@HasAccess bit
		--User acces check FOR Customer 
		DECLARE @lft bigint,@rgt bigint,@Selectedlft bigint,@Selectedrgt bigint,@Depth int,@ParentID bigint  
		DECLARE @SelectedIsGroup bit  
  

		SET @Dt=convert(float,getdate())--Setting Current Date
		
		IF @PostingGroupID=0  
		BEGIN  
				IF EXISTS (SELECT @PostingGroupID FROM [ACC_PostingGroup] WITH(nolock) WHERE replace(PostGroupCode,' ','')=replace(@PostGroupCode,' ',''))  
				BEGIN  
					RAISERROR('-116',16,1)  
				END  
				IF EXISTS (SELECT @PostingGroupID FROM [ACC_PostingGroup] WITH(nolock) WHERE replace(PostGroupName,' ','')=replace(@PostGroupName,' ',''))  
				BEGIN  
					RAISERROR('-112',16,1)  
				END  
				
		END 
		ELSE
		BEGIN  
				IF EXISTS (SELECT @PostingGroupID FROM [ACC_PostingGroup] WITH(nolock) WHERE replace(PostGroupCode,' ','')=replace(@PostGroupCode,' ','') AND PostingGroupID<> @PostingGroupID)  
				BEGIN  
					RAISERROR('-116',16,1)  
				END  
				IF EXISTS (SELECT @PostingGroupID FROM [ACC_PostingGroup] WITH(nolock) WHERE replace(PostGroupName,' ','')=replace(@PostGroupName,' ','') AND PostingGroupID<> @PostingGroupID)  
				BEGIN  
				--select @PostGroupName
					RAISERROR('-112',16,1)  
				END  
				
		END

		IF @PostingGroupID=0--------START INSERT RECORD-----------
		BEGIN--CREATE FA Posting Group

		
				 
			INSERT INTO [ACC_PostingGroup] ([PostGroupCode] ,[PostGroupName] ,[StatusID] ,[PostGroupTypeID] ,[PostGroupTypeName] 
			,[AcqnCostACCID],[DeprExpenseACCID],[AccumDeprACCID],[AccumDeprDispACCID],[AcqnCostDispACCID],[GainsDispACCID],[LossDispACCID]
            ,[MaintExpenseACCID],[CompanyGUID],[GUID], [CreatedBy],[CreatedDate])
			VALUES
            (@PostGroupCode, @PostGroupName,@StatusID,1, 'Asset Management',
		    @AcqnCostACCID,@DeprExpenseACCID ,@AccumDeprACCID, @AccumDeprDispACCID, @AcqnCostDispACCID, @GainsDispACCID, @LossDispACCID,
		    @MaintExpenseACCID, @CompanyGUID,@GUID, @UserName, @Dt)
				--To get inserted record primary key
			SET @PostingGroupID=SCOPE_IDENTITY()
    
		END--------END INSERT RECORD-----------
		ELSE--------START UPDATE RECORD-----------
		BEGIN	
	 
			SELECT @TempGuid=[GUID] from ACC_PostingGroup  WITH(NOLOCK) 
			WHERE PostingGroupID=@PostingGroupID
			
			IF(@TempGuid!=@Guid)--IF RECORD ALREADY UPDATED BY SOME OTHER USER i.e DIRTY READ  
			BEGIN  
				   RAISERROR('-101',16,1)	
			END  
			ELSE  
			BEGIN  
				 UPDATE ACC_PostingGroup
					   SET [PostGroupCode] = @PostGroupCode
					      ,[PostGroupName] = @PostGroupName
						  ,[StatusID] = @StatusID
						  ,[AcqnCostACCID] = @AcqnCostACCID
						  ,[AccumDeprACCID] =  @AccumDeprACCID
						  ,[AcqnCostDispACCID] =  @AcqnCostDispACCID
						  ,[AccumDeprDispACCID] =  @AccumDeprDispACCID
						  ,[GainsDispACCID] = @GainsDispACCID
						  ,[LossDispACCID] =  @LossDispACCID
						  ,[MaintExpenseACCID] =  @MaintExpenseACCID
						  ,[DeprExpenseACCID] = @DeprExpenseACCID
						  ,[ModifiedBy] = @UserName
						  ,[ModifiedDate] = @Dt
					 WHERE PostingGroupID=@PostingGroupID
			END
		END

COMMIT TRANSACTION  
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID  
RETURN @PostingGroupID  
END TRY  
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT * FROM [ACC_PostingGroup] WITH(nolock) WHERE PostingGroupID=@PostingGroupID  
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE IF ERROR_NUMBER()=547
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)
		WHERE ErrorNumber=-110 AND LanguageID=@LangID
	END
	ELSE IF ERROR_NUMBER()=2627
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)
		WHERE ErrorNumber=-116 AND LanguageID=@LangID
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
