USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_CopyCostCenter]
	@NodeID [int],
	@CostCenterID [int],
	@Name [nvarchar](500),
	@LangID [int] = 1,
	@UserID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  
	declare @Sql nvarchar(max), @TableName nvarchar(100)
	
	create table #temp (ID int Identity(1,1), oldNodeid int, name nvarchar(500),newNodeID int,ParentID int,newParentID int)

	select @TableName=tablename from ADM_Features with(nolock) where featureid=@CostCenterID
	
	SET @Sql=''
	SELECT @Sql=@Sql+','+a.name
	FROM sys.columns a with(nolock)
	JOIN sys.columns b with(nolock) on a.name=b.name and b.object_id= a.object_id
	WHERE a.object_id= object_id(@TableName) and a.name not in ('NodeID','lft','rgt','GUID','CreatedDate')
	
	set @Sql='declare @lft bigint, @rgt bigint, @rootrgt bigint,@MaxNodeID bigint,@RootNodeID bigint
	select @lft=lft , @rgt=rgt from '+@TableName+' with(nolock) where NodeID='+CONVERT(nvarchar,@NodeID)+'

	insert into #temp(oldNodeid,name,ParentID)
	select Nodeid,Name,ParentID from '+@TableName+' with(nolock) where lft>=@lft and rgt<=@rgt 
	order by lft

	select @rootrgt=MAX(rgt) from '+@TableName+' with(nolock)

	select @RootNodeID=NodeID from '+@TableName+' with(nolock) where IsGroup=1 and ParentID=0
	select @MaxNodeID=MAX(NodeID) from '+@TableName+' with(nolock)

	insert into '+@TableName+'(lft,rgt,GUID,CreatedDate'+@Sql+')
	select D.lft+@rootrgt-@lft,D.rgt+@rootrgt-@lft,NEWID(),CONVERT(float,GETDATE())'+REPLACE(@Sql,',',',D.')+'
	 from '+@TableName+' D with(nolock)
	inner join #temp T with(nolock) on T.oldNodeid=D.NodeID

	update #temp
	set newNodeID=D.NodeID
	from '+@TableName+' D with(nolock) inner join #temp T with(nolock) on T.name=D.Name and D.NodeID>@MaxNodeID

	update '+@TableName+'
	set rgt=rgt+@rgt-@lft
	where NodeID=@RootNodeID
	 
	update #temp
	set newParentID=ND.NodeID
	--select ND.NodeID,D.Name,T.newNodeID from 
	from '+@TableName+' D with(nolock) inner join #temp T with(nolock) on T.ParentID=D.NodeID --and D.NodeID>@MaxNodeID
	inner join '+@TableName+' ND with(nolock) on ND.Name=D.Name and ND.NodeID>@MaxNodeID
	where T.ID>1

	update '+@TableName+'
	set ParentID=T.newParentID
	from '+@TableName+' D with(nolock) inner join #temp T with(nolock) on T.newNodeiD=D.NodeID
	where T.ID>1

	update '+@TableName+'
	set Code='''+@Name+''',Name='''+@Name+'''
	where NodeID=(select newNodeiD from #temp T with(nolock) where T.ID=1)

	--select * from '+@TableName+' with(nolock) order by lft
'
	print @Sql
	exec(@Sql)
	
	SET @Sql=''
	SELECT @Sql=@Sql+','+a.name
	FROM sys.columns a with(nolock)
	WHERE a.object_id= object_id('COM_CCCCData') and a.name LIKE 'CCNID%'
	
	SET @Sql='insert into [COM_CCCCData]([CostCenterID],[NodeID],[CompanyGUID],GUID,[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[AccountID],[ProductID]'+@Sql+')
	SELECT c.CostCenterID,t.NewNodeid,[CompanyGUID],newid(),[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[AccountID],[ProductID]'+@Sql+'
	FROM [COM_CCCCData]  c with(nolock)
	join #temp t with(nolock) on c.nodeid=t.oldnodeid and c.costcenterid='+CONVERT(NVARCHAR,@CostCenterID)
	
	EXEC (@Sql)
	
  	select * from #temp with(nolock)
  	
	drop table #temp
	 

  
commit TRANSACTION
--ROLLBACK TRANSACTION
SET NOCOUNT OFF;
 
RETURN @NodeID  
END TRY  
  
BEGIN CATCH    
  --Return exception info [Message,Number,ProcedureName,LineNumber]    
  IF ERROR_NUMBER()=50000  
  BEGIN  
   SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
  END  
  ELSE IF ERROR_NUMBER()=547  
  BEGIN  
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)  
   WHERE ErrorNumber=-110 AND LanguageID=@LangID  
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
