USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetRegisters]
	@CCID [bigint],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY     
SET NOCOUNT ON    
    
  --Declaration Section    
  DECLARE @Ret int,@Sql nvarchar(max),@value nvarchar(max),@table nvarchar(100)
	     
	select @table=tablename from adm_features
	where featureid=@CCID
	SELECT @value=Value FROM ADM_GlobalPreferences
	WHERE Name='Dimension List'
	
	set @Sql='select DISTINCT l.NodeID,l.Code,l.Name,l.IsGroup,l.lft from '+@table+' l '
	
	declare @tblIDsList table(CCId bigint)  
	insert into @tblIDsList  
	exec SPSplitString @value,','
	if exists(select CCId from @tblIDsList where CCId=@CCID)
	begin
		set @Sql=@Sql+'join '+@table+' g on l.lft between g.lft and g.rgt 
		where   g.NodeID in (select NodeID from COM_CostCenterCostCenterMap
		where CostCenterID='+convert(nvarchar,@CCID)+' and ParentCostCenterID=7 and ParentNodeID='+convert(nvarchar,@UserID)+')
		and l.IsGroup=0 order by l.lft'
	end
	else
		set @Sql=@Sql+' where l.IsGroup=0 order by l.lft'
		print @Sql
	exec(@Sql)

COMMIT TRANSACTION    
SET NOCOUNT OFF;    
return 1
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
