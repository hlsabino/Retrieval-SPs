USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spINV_GetBins]
	@ProductID [bigint] = 0,
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY  
	SET NOCOUNT ON;  
			                            
	BEGIN    
		DECLARE @Table NVARCHAR(300),@CCBINDIMENSIION BIGINT,@IsColinuse bit,@DimCC bigint,@DimName nvarchar(500)

		SELECT @CCBINDIMENSIION=ISNULL(VALUE,0) FROM [COM_CostCenterPreferences]  WITH(NOLOCK)
		WHERE NAME='BinsDimension' and ISNUMERIC(VALUE)=1
		
		SELECT @DimCC=ISNULL(Value,0) FROM ADM_GlobalPreferences  WITH(NOLOCK)
		WHERE Name='DimensionwiseBins' and ISNUMERIC(Value)=1
		
		SELECT @DimName=Name FROM ADM_Features  WITH(NOLOCK)
		WHERE FeatureID=@DimCC
	
		select @IsColinuse=IsColumnInUse from ADM_CostCenterDef with(nolock) 
		where ISCOLUMNDELETED<>1 and CostCenterID=@CCBINDIMENSIION and ColumnCostCenterID=@DimCC
		

		SELECT @CCBINDIMENSIION BinDimension,@DimCC DimwiseBins,@DimName DimwiseBinName,@IsColinuse DimwiseBinsinUse


	END      
	    
	SET NOCOUNT OFF;     
	RETURN 1
END TRY
BEGIN CATCH    
	 --Return exception info [Message,Number,ProcedureName,LineNumber]    
	IF ERROR_NUMBER()=50000  
	BEGIN  
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) 
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
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
