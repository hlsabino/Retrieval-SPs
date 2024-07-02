USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spINV_SetQucikBatchMumtiple]
	@BatchID [bigint],
	@IsBatchSeqNoExists [bit],
	@BatchNumber [nvarchar](200),
	@ManufactureDate [datetime] = NULL,
	@ExpiryDate [datetime] = NULL,
	@MRPRate [float],
	@RetailRate [float],
	@StockistRate [float],
	@ProductID [bigint] = NULL,
	@RetestDate [datetime] = NULL,
	@SelectedNodeID [bigint],
	@Count [int],
	@tempstrbatch [nvarchar](200),
	@tempnumbatch [nvarchar](200),
	@SeqLength [int],
	@IsGroup [bit],
	@StaticFieldsQuery [nvarchar](max) = null,
	@CustomFieldsQuery [nvarchar](max) = NULL,
	@CustomCostCenterFieldsQuery [nvarchar](max) = NULL,
	@BatchCode [nvarchar](200) = null,
	@CodePrefix [nvarchar](200) = null,
	@CodeNumber [bigint] = 0,
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [bigint],
	@RoleID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;    
	declare @i int,@retval int,@tempDOc nvarchar(200)
	set @i=0
	declare @temp table(id bigint)
	WHILE(@i<@Count)
	BEGIN
		set @i=@i+1
		if(@i>1)
		BEGIN
			set @tempnumbatch=@tempnumbatch+1
			set @tempDOc=convert(nvarchar(200),@tempnumbatch)
			while(len(@tempDOc)<@SeqLength)      
			begin      
				SET @tempDOc='0'+@tempDOc      
			end   
			set @BatchNumber=replace(@tempstrbatch,'#SEQ#',@tempDOc)
		END	
			
		exec @retval= spINV_SetQucikBatch      			
			@BatchID= @BatchID,
			@IsBatchSeqNoExists=  @IsBatchSeqNoExists,
			@BatchNumber = @BatchNumber,      
			@ManufactureDate = @ManufactureDate,      
			@ExpiryDate = @ExpiryDate,      
			@MRPRate = @MRPRate,      
			@RetailRate = @RetailRate,      
			@StockistRate=  @StockistRate,    
			@ProductID = @ProductID,       
			@RetestDate=  @RetestDate,    
			@SelectedNodeID = @SelectedNodeID,    
			@IsGroup = @IsGroup,        
			@StaticFieldsQuery = @StaticFieldsQuery, 
			@CustomFieldsQuery = @CustomFieldsQuery,   
			@CustomCostCenterFieldsQuery=  @CustomCostCenterFieldsQuery,     
			@BatchCode = @BatchCode,
			@CodePrefix = @CodePrefix,
			@CodeNumber = @CodeNumber,
			@CompanyGUID = @CompanyGUID,    
			@GUID=  @GUID,    
			@UserName=  @UserName,    
			@UserID=  @UserID,
			@RoleID=  @RoleID,
			@LangID = @LangID 
			
			insert into @temp(id)values(@retval)
			  
	END
	
	select * from @temp
COMMIT TRANSACTION
return 1	  
END TRY    
BEGIN CATCH      
	--Return exception info [Message,Number,ProcedureName,LineNumber]      
	IF ERROR_NUMBER()=50000    
	BEGIN    
		SELECT * FROM [INV_Batches] WITH(NOLOCK) WHERE BatchID=@BatchID    
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
	END    
	ELSE IF ERROR_NUMBER()=547    
	BEGIN    
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine 
		FROM COM_ErrorMessages WITH(nolock)    
		WHERE ErrorNumber=-110 AND LanguageID=@LangID    
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
