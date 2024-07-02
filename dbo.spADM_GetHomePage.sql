USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetHomePage]
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY	
SET NOCOUNT ON

		declare @prof  int,@sql nvarchar(max)

		select @prof=Value from adm_globalpreferences WITH(NOLOCK)
		where name='OnlineProfile' and isnumeric(Value)=1

		select a.CCID,a.Filter,a.[Level],a.Map,a.ParentCCID,case when f.Name is null then 'Product' else f.Name end Name,f.tableName
		,isnull((select IsColumnInUse FROM ADM_CostCenterDef with(nolock)
		where costcenterid=(case when a.CCID<0 then 3 else a.CCID end) and  syscolumnname='ccnid' + convert(nvarchar,(a.ParentCCID - 50000))),0) ColumnInUse
		into #tempreg
		from ADM_POSLevelsProfiles a WITH(NOLOCK)
		left join ADM_Features f WITH(NOLOCK) on a.CCID=f.FeatureID		
		where  ProfileID=@prof
		order by Level	
		
		select * from #tempreg
		
		select a.*,b.GUID+'.'+b.FileExtension ImgPath from ADM_OnlineProfile a WITH(NOLOCK)
		left Join COM_Files b on a.NodeID=b.FeaturePK   and a.CCID=b.FeatureID and IsDefaultImage=1

	select name,value from adm_globalpreferences WITH(NOLOCK)
		where name in('OnlineProfile','MandOnlineLogin','OnlineLevel1Dim','OnlineLevel2Dim','OnlineOrderDoc','OnlineRecptDoc')  
  
		
		if exists(select * from #tempreg where [Level]=1)
		BEGIN
			select @sql='select NodeID,COde,Name,IsGroup,ParentID from '+tableName+ case when Filter<>'' then ' where '+Filter else '' end
			+' order by lft' from #tempreg where [Level]=1
			exec(@sql)
		END
		
		if exists(select * from #tempreg where [Level]=2)
		BEGIN
			select @sql='select NodeID,COde,Name,IsGroup,ParentID from '+tableName+ case when Filter<>'' then ' where '+Filter else '' end
			+' order by lft' from #tempreg where [Level]=2
			exec(@sql)
		END
		
		
COMMIT TRANSACTION
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
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH  
GO
