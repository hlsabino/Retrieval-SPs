USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetCostCenterContactEmails]
	@IsEmail [bit],
	@CostCenterID [bigint],
	@IDList [nvarchar](max),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON

	declare @sql nvarchar(max),@Column nvarchar(20)
	
	if @IsEmail=1
		set @Column='Email1'
	else
		set @Column='Phone1'
	
	IF @CostCenterID=65
	BEGIN
		if(CHARINDEX(',',@IDList,1)=0)
			set @sql='SELECT '+@Column+' Data FROM COM_Contacts with(nolock) WHERE ContactID='+@IDList
		else
			set @sql='SELECT '+@Column+' Data FROM COM_Contacts with(nolock) WHERE ContactID IN ('+@IDList+') GROUP BY '+@Column
	END
	ELSE
	BEGIN
		if(CHARINDEX(',',@IDList,1)=0)
			set @sql='SELECT '+@Column+' Data FROM COM_Contacts with(nolock) WHERE FeatureID='+convert(nvarchar,@CostCenterID)+' AND FeaturePK='+@IDList
		else
			set @sql='SELECT '+@Column+' Data FROM COM_Contacts with(nolock) WHERE FeatureID='+convert(nvarchar,@CostCenterID)+' AND FeaturePK IN ('+@IDList+') GROUP BY '+@Column
	END

	--print(@sql)
	exec(@sql)

	
SET NOCOUNT OFF;
RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END

SET NOCOUNT OFF  
RETURN -999   
END CATCH  
GO
