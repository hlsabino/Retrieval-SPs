USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_SetDimensions]
	@Docdetid [bigint],
	@CostcenterID [bigint],
	@IsInv [bit],
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  

	declare @i int,@cnt int,@ccid int,@colname nvarchar(500),@table nvarchar(500),@sql nvarchar(max),@NID BIGINT,@NodeID BIGINT,@refccid BIGINT
	declare @tab table (id int identity(1,1),ccid int,colname nvarchar(500),RefColName nvarchar(500),tabname nvarchar(500),refccid bigint)
	
	insert into @tab
	select b.ColumnCostCenterID,b.SysColumnName,a.SysColumnName,c.TableName,a.ColumnCostCenterID from ADM_CostCenterDef a
	join ADM_CostCenterDef b on a.LocalReference=b.CostCenterColID
	join ADM_Features c on b.ColumnCostCenterID=c.FeatureID
	where a.costcenterid=@CostcenterID and a.SysColumnName like 'dcccnid%'
	and a.localreference is not null and a.localreference>0
	order by b.ColumnCostCenterID
	select @i=0,@cnt=count(id) from @tab
	while(@i<@cnt)
	BEGIN
		set @i=@i+1
		select  @colname=colname  from @tab where id=@i
		
		set @sql='select @NID='+@colname+' from Com_DOCCCData WITH(NOLOCK) WHERE '
		if(@IsInv=1)
			set @sql=@sql+' InvDocDetailsID='
		else
			set @sql=@sql+' AccDocDetailsID='
		
		set @sql=@sql+convert(nvarchar,@Docdetid)
		
		EXEC sp_executesql @sql,N'@NID bigint OUTPUT',@NID output
		
		
		select  @ccid=ccid,@colname=RefColName,@table=tabname,@refccid=refccid  from @tab where id=@i
		
		set @sql='select @NodeID =CCNID'+convert(nvarchar,(@refccid-50000))+' from COM_CCCCDATA WITH(NOLOCK) WHERE Costcenterid='
		+convert(nvarchar,@ccid)+' and NOdeID='+convert(nvarchar,@NID)
		EXEC sp_executesql @sql,N'@NodeID bigint OUTPUT',@NodeID output
		print @sql
		
		set @sql=' update Com_DOCCCData
		set '+@colname+' ='+convert(nvarchar,@NodeID)+' WHERE '
		if(@IsInv=1)
			set @sql=@sql+' InvDocDetailsID='
		else
			set @sql=@sql+' AccDocDetailsID='
		
		set @sql=@sql+convert(nvarchar,@Docdetid)
		
		exec(@sql)
		
	END


COMMIT TRANSACTION
SET NOCOUNT OFF;      
END TRY      
BEGIN CATCH   
	
 --Return exception info [Message,Number,ProcedureName,LineNumber]      
 IF ERROR_NUMBER()=50000    
 BEGIN  
	
	  SELECT ErrorMessage ,ERROR_MESSAGE(),ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
	  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
	
 END    
 ELSE IF ERROR_NUMBER()=547    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)    
  WHERE ErrorNumber=-110 AND LanguageID=@LangID    
 END  
  ELSE IF ERROR_NUMBER()=1205  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)  
  WHERE ErrorNumber=-350 AND LanguageID=@LangID  
 END   
 ELSE IF ERROR_NUMBER()=2627    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)    
  WHERE ErrorNumber=-116 AND LanguageID=@LangID    
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
