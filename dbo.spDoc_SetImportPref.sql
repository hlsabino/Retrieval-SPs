USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_SetImportPref]
	@CCID [int],
	@Preferences [nvarchar](max),
	@UserID [int],
	@userName [nvarchar](200),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY                
SET NOCOUNT ON;              
    --Declaration Section              
  DECLARE @dt float 
  
  --SP Required Parameters Check              
  IF @CCID=0              
  BEGIN              
   RAISERROR('-100',16,1)              
  END              
        
		set @dt=convert(float,getdate())
		        
		declare @tab table(prefname nvarchar(200))		
        insert into @tab  
		exec SPSplitString @Preferences,','  
        
        
        INSERT INTO [com_documentpreferences] ([CostCenterID],[DocumentTypeID],[DocumentType],[ResourceID],[PreferenceTypeID],[PreferenceTypeName],[PrefValueType],[PrefName],[PrefValue],[PrefDefalutValue],[IsPrefValid],[PrefColOrder],[PrefRowOrder],[UnderGroupBox],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate])
		select a.costcenterid,a.DocumentTypeID,a.DocumentType,p.[ResourceID],p.[PreferenceTypeID],p.[PreferenceTypeName],p.[PrefValueType],p.[PrefName],p.[PrefValue],p.[PrefDefalutValue],p.[IsPrefValid],p.[PrefColOrder],p.[PrefRowOrder],p.[UnderGroupBox],p.[CompanyGUID],p.[GUID],p.[Description],@userName,@dt
		from adm_documenttypes  a WITH(NOLOCK) 
		join COM_DocumentPreferences P WITH(NOLOCK) on p.CostCenterID = 0
		join @tab t on p.prefname=t.prefname
		where  a.CostCenterID=@CCID
      

		SELECT  DocumentPrefID,P.PrefValueType,PrefDefalutValue,L.ResourceData [Text],PrefValue Value,P.PrefName [DBText],P.PreferenceTypeName [Group],
		PrefRowOrder,PrefColOrder FROM COM_DocumentPreferences P WITH(NOLOCK)               
		LEFT JOIN COM_LanguageResources L WITH(NOLOCK) ON L.ResourceID=P.ResourceID  and LanguageID=@LangID              
		where CostCenterID=@CCID      
		ORDER BY P.PrefValueType  DESC   
		

SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) 
WHERE ErrorNumber=100 AND LanguageID=@LangID	

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
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine              
		FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID              
	END              
	SET NOCOUNT OFF                
	RETURN -999                 
END CATCH
GO
