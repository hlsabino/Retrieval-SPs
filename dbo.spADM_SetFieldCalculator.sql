USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetFieldCalculator]
	@DocumentTypeID [bigint],
	@MapXml [nvarchar](max),
	@EnableCalc [nvarchar](50),
	@DynamicFlds [nvarchar](50),
	@FooterFld [bigint],
	@TextFields [nvarchar](max),
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

	if(@DocumentTypeID>0)
	begin
		SELECT @CostCenterID=COSTCENTERID FROM ADM_DocumentTypes             
		WITH(NOLOCK) WHERE  DocumentTypeID=@DocumentTypeID
	end  
	  
	set @XML=@MapXml
	set @dt=convert(float,getdate())

	update ADM_DocumentDef 
	set ShowinCalc=0
	where [CostCenterID]=@CostCenterID


	update ADM_DocumentDef 
	set ShowinCalc=1
	from @XML.nodes('/XML/Row') as Data(X)
	where [CostCenterID]=@CostCenterID
	and X.value('@CostCenterColID','BIGINT')=CostCenterColID

	UPDATE COM_DocumentPreferences               
	SET [PrefValue]=@EnableCalc,              
	[ModifiedBy]=@UserName,              
	[ModifiedDate]=@dt            
	WHERE [PrefName]='FieldCalculator' AND CostCenterID=@CostCenterID 

	UPDATE COM_DocumentPreferences               
	SET [PrefValue]=@DynamicFlds,
	[ModifiedBy]=@UserName,              
	[ModifiedDate]=@dt             
	WHERE [PrefName]='CalcFieldsDynamic' AND CostCenterID=@CostCenterID  

	UPDATE COM_DocumentPreferences               
	SET [PrefValue]=@FooterFld,
	[ModifiedBy]=@UserName,              
	[ModifiedDate]=@dt             
	WHERE [PrefName]='CalcFooterField' AND CostCenterID=@CostCenterID

	UPDATE COM_DocumentPreferences               
	SET [PrefValue]=@TextFields,
	[ModifiedBy]=@UserName,              
	[ModifiedDate]=@dt             
	WHERE [PrefName]='FieldCalculatorTextFields' AND CostCenterID=@CostCenterID
	
	UPDATE ADM_DocumentTypes SET GUID=NEWID()where CostCenterID=@CostCenterID 
	
	COMMIT TRANSACTION   
	SET NOCOUNT OFF;  

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
