USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetBatchMapping]
	@DocumentTypeID [bigint],
	@MapXml [nvarchar](max),
	@CCID [bigint],
	@isDoc [bit],
	@AutoCode [nvarchar](50),
	@IsSeq [nvarchar](50),
	@Inactiveonsuspend [nvarchar](50),
	@OnPosted [nvarchar](50),
	@BasedOnValue [bigint] = 0,
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](200),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  
   
	Declare @XML XML,@CostCenterID bigint,@dt float
	--SP Required Parameters Check  
	IF @DocumentTypeID=0  
	BEGIN  
	RAISERROR('-100',16,1)  
	END  

	if(@isDoc=0)
		set @CostCenterID=@DocumentTypeID
	else if(@DocumentTypeID>0)
	begin
		SELECT @CostCenterID=COSTCENTERID FROM ADM_DocumentTypes             
		WITH(NOLOCK) WHERE  DocumentTypeID=@DocumentTypeID
	end  
	  
	set @XML=@MapXml
	set @dt=convert(float,getdate())

	delete from COM_DocumentBatchLinkDetails
	where [CostCenterID]=@CostCenterID and LinkDimCCID=@CCID AND BasedOnValue=@BasedOnValue

	insert into COM_DocumentBatchLinkDetails([CostCenterID],[CostCenterColIDBase],[BatchColID],
	LinkDimCCID,[CompanyGUID],[GUID],[CreatedBy],[CreatedDate],BasedOnValue)
	select @CostCenterID,X.value('@CostCenterColID','BIGINT'),X.value('@BatchColID','BIGINT'),@CCID,@CompanyGUID
	,newid(),@UserName,@dt,@BasedOnValue
	from @XML.nodes('/XML/Row') as Data(X)

	if(@isDoc<>0)
	BEGIN
		UPDATE COM_DocumentPreferences               
		SET [PrefValue]=@AutoCode,              
		[ModifiedBy]=@UserName,              
		[ModifiedDate]=@dt            
		WHERE [PrefName]='AutoCode' AND CostCenterID=@CostCenterID 
		
		UPDATE COM_DocumentPreferences               
		SET [PrefValue]=@IsSeq,              
		[ModifiedBy]=@UserName,              
		[ModifiedDate]=@dt            
		WHERE [PrefName]='GenerateSeq' AND CostCenterID=@CostCenterID 
		
		UPDATE COM_DocumentPreferences               
		SET [PrefValue]=@Inactiveonsuspend,              
		[ModifiedBy]=@UserName,              
		[ModifiedDate]=@dt            
		WHERE [PrefName]='Inactiveonsuspend' AND CostCenterID=@CostCenterID 
	
		UPDATE COM_DocumentPreferences               
		SET [PrefValue]=@OnPosted,              
		[ModifiedBy]=@UserName,              
		[ModifiedDate]=@dt            
		WHERE [PrefName]='OnPosted' AND CostCenterID=@CostCenterID
		 
		declare @PostAsset NVARCHAR(10),@EnableAssetSerialNo NVARCHAR(10),@AssetBasedOn NVARCHAR(10)
		
		if exists (select X.value('@EnableAssetSerialNo','NVARCHAR(10)') from @XML.nodes('/XML/Pref') as Data(X))
		begin 
			select @EnableAssetSerialNo=ISNULL(X.value('@EnableAssetSerialNo','NVARCHAR(10)'),'false')
			,@PostAsset=ISNULL(X.value('@PostAsset','NVARCHAR(10)'),'false')
			,@AssetBasedOn=ISNULL(X.value('@AssetBasedOn','NVARCHAR(10)'),'')
			from @XML.nodes('/XML/Pref') as Data(X)
			
			UPDATE COM_DocumentPreferences               
			SET [PrefValue]=@EnableAssetSerialNo,              
			[ModifiedBy]=@UserName,              
			[ModifiedDate]=@dt            
			WHERE [PrefName]='EnableAssetSerialNo' AND CostCenterID=@CostCenterID 
			
			UPDATE COM_DocumentPreferences               
			SET [PrefValue]=@PostAsset,              
			[ModifiedBy]=@UserName,              
			[ModifiedDate]=@dt            
			WHERE [PrefName]='PostAsset' AND CostCenterID=@CostCenterID 
			
			UPDATE COM_DocumentPreferences               
			SET [PrefValue]=@AssetBasedOn,              
			[ModifiedBy]=@UserName,              
			[ModifiedDate]=@dt            
			WHERE [PrefName]='AssetBasedOn' AND CostCenterID=@CostCenterID 
		end
		UPDATE ADM_DocumentTypes SET GUID=NEWID()where CostCenterID=@CostCenterID 
	END
	
	COMMIT TRANSACTION   
	SET NOCOUNT OFF;  
	SELECT * FROM COM_DocumentBatchLinkDetails WITH(nolock) WHERE CostCenterid=@CostCenterID
	SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
	WHERE ErrorNumber=100 AND LanguageID=@LangID 
	RETURN @DocumentTypeID
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
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
		FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
	END  
	ROLLBACK TRANSACTION  
	SET NOCOUNT OFF    
	RETURN -999     
END CATCH  
  
  
   
   
   
GO
