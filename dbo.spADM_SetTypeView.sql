USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetTypeView]
	@CallType [int],
	@COSTCENTERID [int],
	@TypeCCID [int],
	@TypeID [int],
	@StrXml [nvarchar](max),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
SET NOCOUNT ON    
BEGIN TRY    
	declare @XML xml,@cols nvarchar(max),@vals nvarchar(max),@sql nvarchar(max),@where nvarchar(max)

	if @CallType=1
	begin
		if(@StrXml is not null and @StrXml<>'')
		BEGIN
			set @sql=' select TypeID,CostCenterColID,Hide,Mandatory,IsTab from ADM_TypeRestrictions with(nolock)
			where CostCenterID='+convert(nvarchar(max),@CostCenterID)+' and TypeID='+convert(nvarchar(max),@TypeID)+@StrXml			
			exec(@sql)
		END
		ELSE
			select TypeID,CostCenterColID,Hide,Mandatory,IsTab from ADM_TypeRestrictions with(nolock)
			where CostCenterID=@CostCenterID and TypeID=@TypeID and TypeCCID=@TypeCCID
			
	end
	else if @CallType=2
	begin
		set @XML=@StrXml
		
		select @cols=X.value('@Cols','nvarchar(max)'),@vals=X.value('@vals','nvarchar(max)'),@where=X.value('@where','nvarchar(max)')
		from @XML.nodes('/XML')as Data(X)
		if(@vals is not null and @vals<>'')
		BEGIN
			set @sql=' delete from ADM_TypeRestrictions
			where CostCenterID='+convert(nvarchar(max),@CostCenterID)+' and TypeID='+convert(nvarchar(max),@TypeID)+@where+'
			insert into ADM_TypeRestrictions(CostCenterID,TypeID,CostCenterColID,Hide,Mandatory,IsTab'+@cols+')
			select '+convert(nvarchar(max),@CostCenterID)+','+convert(nvarchar(max),@TypeID)+',X.value(''@ColID'',''INT''),X.value(''@Hide'',''smallint''),X.value(''@Mand'',''smallint''),X.value(''@IsTab'',''smallint'')'+@vals+'
			from @XML.nodes(''/XML/R'') as Data(X)'
			
			EXEC sp_executesql @sql,N'@XML xml',@XML
			
		END
		ELSE
		BEGIN
			delete from ADM_TypeRestrictions
			where CostCenterID=@CostCenterID and TypeID=@TypeID and TypeCCID=@TypeCCID

			insert into ADM_TypeRestrictions(CostCenterID,TypeCCID,TypeID,CostCenterColID,Hide,Mandatory,IsTab)
			select @CostCenterID,@TypeCCID,@TypeID,X.value('@ColID','INT'),X.value('@Hide','smallint'),X.value('@Mand','smallint'),X.value('@IsTab','smallint')
			from @XML.nodes('/XML/R') as Data(X)  
		END	
	end

SET NOCOUNT OFF;     
COMMIT TRANSACTION 
 
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=100 AND LanguageID=@LangID        
SET NOCOUNT OFF;      
RETURN 1
END TRY      
BEGIN CATCH      
 --Return exception info [Message,Number,ProcedureName,LineNumber]      
 IF ERROR_NUMBER()=50000    
 BEGIN    
  SELECT * FROM ADM_CostCenterTab WITH(NOLOCK) WHERE COSTCENTERID=@COSTCENTERID     
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
 END    
 ELSE    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine    
  FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID    
 END    
 ROLLBACK TRANSACTION    
 SET NOCOUNT OFF      
 RETURN -999       
END CATCH
GO
