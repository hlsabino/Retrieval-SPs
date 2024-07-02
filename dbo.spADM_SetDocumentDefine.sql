USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetDocumentDefine]
	@TypeID [int],
	@CostCenterID [int],
	@Param1 [nvarchar](max),
	@Param2 [nvarchar](max),
	@Param3 [nvarchar](max),
	@CompanyGUID [nvarchar](200),
	@UserName [nvarchar](200),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION                
BEGIN TRY                
	SET NOCOUNT ON;              
	declare @dt float
	set @dt=convert(float,getdate())
	
	IF @TypeID=1
	BEGIN
		UPDATE COM_DocumentPreferences
		SET PrefValue=@Param1
		WHERE CostCenterID=@CostCenterID AND PrefName='PriceChartMapping'

	END
	ELSE IF @TypeID=2
	BEGIN

		UPDATE COM_DocumentPreferences
		SET PrefValue=@Param1
		WHERE CostCenterID=@CostCenterID AND PrefName='EnableUniqueDocument'
		
		UPDATE ADM_DocumentTypes
		SET UniqueDocumentDefn=@Param2,UniqueDocumentQuery=@Param3
		WHERE CostCenterID=@CostCenterID

	END
	ELSE IF @TypeID=3
	BEGIN
		UPDATE COM_DocumentPreferences
		SET PrefValue=@Param1
		WHERE CostCenterID=@CostCenterID AND PrefName='ResetFields'
	END
	ELSE IF @TypeID=4
	BEGIN
		declare @XML xml,@DimTransferSrc_Prev nvarchar(20),@DimTransferSrc nvarchar(20)
		set @XML=@Param1
		select @DimTransferSrc=X.value('@DimTransferSrc','nvarchar(20)') from @XML.nodes('/XML/Pref') as Data(X)
		select @DimTransferSrc_Prev=PrefValue from COM_DocumentPreferences with(nolock) WHERE CostCenterID=@CostCenterID AND PrefName='DimTransferSrc'
		
		UPDATE COM_DocumentPreferences               
		SET [PrefValue]=@DimTransferSrc,
		[ModifiedBy]=@UserName,              
		[ModifiedDate]=@dt            
		WHERE [PrefName]='DimTransferSrc' AND CostCenterID=@CostCenterID
		
		UPDATE COM_DocumentPreferences               
		SET [PrefValue]=(select X.value('@DimTransferDim','nvarchar(20)') from @XML.nodes('/XML/Pref') as Data(X)),
		[ModifiedBy]=@UserName,              
		[ModifiedDate]=@dt            
		WHERE [PrefName]='DimTransferDim' AND CostCenterID=@CostCenterID
		
		UPDATE COM_DocumentPreferences               
		SET [PrefValue]=(select X.value('@AssetShiftDate','nvarchar(20)') from @XML.nodes('/XML/Pref') as Data(X)),
		[ModifiedBy]=@UserName,              
		[ModifiedDate]=@dt
		WHERE [PrefName]='AssetShiftDate' AND CostCenterID=@CostCenterID
		
		--select * from COM_DocumentPreferences where CostCenterID=@CostCenterID and (PrefName='DimTransferSrc' or PrefName='DimTransferDim' or PrefName='AssetShiftDate')
		--select * from COM_DocumentPreferences WHERE CostCenterID=@CostCenterID AND (PrefName='DonotupdateAccounts' or PrefName='DonotupdateInventory') 
			
		if @DimTransferSrc_Prev!=@DimTransferSrc
		begin
			update adm_costcenterdef 
			set IsVisible=0
			where costcenterid=@CostCenterID and SysColumnName IN ('ProductID','DebitAccount','CreditAccount','Rate','Gross','Quantity','Unit')		
			
			UPDATE COM_DocumentPreferences               
			SET [PrefValue]='True',
			[ModifiedBy]=@UserName,              
			[ModifiedDate]=@dt            
			WHERE CostCenterID=@CostCenterID AND (PrefName='DonotupdateAccounts' or PrefName='DonotupdateInventory') 
		end
	END
	ELSE IF @TypeID=5
	BEGIN
		if @Param1='1' and not exists(select * from COM_DocumentPreferences with(nolock) WHERE [PrefName]='IsBudgetDocument' AND CostCenterID=@CostCenterID)
		begin
			INSERT INTO [com_documentpreferences] ([CostCenterID],[DocumentTypeID],[DocumentType],[ResourceID],[PreferenceTypeID],[PreferenceTypeName],[PrefValueType],[PrefName],[PrefValue],[PrefDefalutValue],[IsPrefValid],[PrefColOrder],[PrefRowOrder],[UnderGroupBox],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate])	
			SELECT CostCenterID,DocumentTypeID,DocumentType,0,1,'STATIC','CheckBox','IsBudgetDocument','1','',0,0,0,NULL,newid(),newid(),NULL,'admin',convert(float,getdate()),NULL,NULL FROM adm_documenttypes  with(nolock) where CostCenterID=@CostCenterID
			
			INSERT INTO [com_documentpreferences] ([CostCenterID],[DocumentTypeID],[DocumentType],[ResourceID],[PreferenceTypeID],[PreferenceTypeName],[PrefValueType],[PrefName],[PrefValue],[PrefDefalutValue],[IsPrefValid],[PrefColOrder],[PrefRowOrder],[UnderGroupBox],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate])	
			SELECT CostCenterID,DocumentTypeID,DocumentType,0,1,'STATIC','CheckBox','BudgetMapFields','','',0,0,0,NULL,newid(),newid(),NULL,'admin',convert(float,getdate()),NULL,NULL FROM adm_documenttypes  with(nolock) where CostCenterID=@CostCenterID
			--,'DebitAccount','CreditAccount'
			update adm_costcenterdef 
			set IsVisible=0
			where costcenterid=@CostCenterID and SysColumnName IN ('ProductID','Rate','Unit')
			
			UPDATE COM_DocumentPreferences               
			SET [PrefValue]='True',
			[ModifiedBy]=@UserName,              
			[ModifiedDate]=@dt            
			WHERE CostCenterID=@CostCenterID AND (PrefName='DonotupdateAccounts' or PrefName='DonotupdateInventory')
		end
		
		UPDATE COM_DocumentPreferences               
		SET [PrefValue]=@Param1,[ModifiedBy]=@UserName,[ModifiedDate]=@dt            
		WHERE [PrefName]='IsBudgetDocument' AND CostCenterID=@CostCenterID
			
		UPDATE COM_DocumentPreferences               
		SET [PrefValue]=@Param2,[ModifiedBy]=@UserName,[ModifiedDate]=@dt            
		WHERE [PrefName]='BudgetMapFields' AND CostCenterID=@CostCenterID		
	END
	ELSE if @TypeID=6
	BEGIN
	
		delete from [ADM_DocumentMap] where CostCenterID=@CostCenterID
	   if(@Param1<>'')
	   BEGIN
			  SET @XML=@Param1        
	    
			INSERT INTO [ADM_DocumentMap]([CostCenterID],MapCCID,[ShortCut],[IsNewTab])
			 select @CostCenterID,X.value('@MapCCID','BIGINT'),X.value('@ShortCut','NVARCHAR(50)'),X.value('@IsNewTab','BIT')
			FROM @XML.nodes('/XML/Row') as DATA(X)
	   END
	END
	

	UPDATE ADM_DocumentTypes SET GUID=NEWID()where CostCenterID=@CostCenterID    
	 
	COMMIT TRANSACTION                

	SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)               
	WHERE ErrorNumber=100 AND LanguageID=@LangID

	SET NOCOUNT OFF;                
	RETURN @CostCenterID                
END TRY                
BEGIN CATCH                
	IF ERROR_NUMBER()=50000              
	BEGIN              
		SELECT * FROM ADM_CostCenterDef WITH(nolock) WHERE CostCenterID=@CostCenterID              
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)               
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID              
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
