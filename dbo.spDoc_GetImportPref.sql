USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_GetImportPref]
	@CCID [int],
	@PrefType [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY                
SET NOCOUNT ON;              
    --Declaration Section              
  DECLARE @HasAccess BIT,@PrefTypeName varchar(100)  
declare @Query varchar(Max)  

  
  --SP Required Parameters Check              
  IF @CCID=0              
  BEGIN              
   RAISERROR('-100',16,1)              
  END              
		
		declare @tabtyps table(prefTypes nvarchar(200))
		
		
        if(@PrefType=1)
        BEGIN
			insert into @tabtyps(prefTypes)values('General')
			insert into @tabtyps(prefTypes)values('Common')
		END	
        else if(@PrefType=2)
			insert into @tabtyps(prefTypes)values('Linking')
			
		declare @tab table(prefname nvarchar(200))
		insert into @tab
        select prefname from COM_DocumentPreferences p WITH(NOLOCK)
        join @tabtyps pt on pt.prefTypes=p.PreferenceTypeName
        where CostCenterID = @CCID 
        
               
		SELECT  DocumentPrefID,P.PrefValueType,L.ResourceData,PrefDefalutValue,case when prefvaluetype ='CustomTextBox' or prefvaluetype ='BarcodeFormat' or		   prefvaluetype ='TextBox' THEN '0' else 'False' end Value
		,P.PrefName,P.PreferenceTypeName [Group],PrefRowOrder,PrefColOrder              
		FROM COM_DocumentPreferences P WITH(NOLOCK)                 
		JOIN COM_LanguageResources L WITH(NOLOCK) ON L.ResourceID=P.ResourceID  and LanguageID=@LangID                 
		join @tabtyps pt on pt.prefTypes=p.PreferenceTypeName
		left join @tab t on t.prefname=p.prefname		
		where CostCenterID = 0  and t.prefname is null
		ORDER BY P.PrefValueType  DESC  

	
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
