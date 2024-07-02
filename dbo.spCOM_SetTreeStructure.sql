USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetTreeStructure]
	@CostcenterID [bigint],
	@CCNodeID [bigint] = 0,
	@ColumnName [nvarchar](200) = '',
	@CurDepth [int] = 0,
	@lft [bigint] = 0 OUTPUT
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  
  
  --Declaration Section  
  declare @i bigint,@cnt bigint,@diff bigint,@nodeid bigint,@isgrp bit,@Depth  int
  declare @tab table(id bigint identity(1,1),NodeID bigint,isgrp bit)  
  declare @PrimKey nvarchar(200),@TableName nvarchar(200),@sql nvarchar(max)  
  
	select @TableName=tablename,@PrimKey=PrimaryKey from adm_features where featureid=@CostcenterID  
	  
	set @sql='select '+@PrimKey+',isgroup from '+@TableName+' with(nolock) 
	where ParentID='+convert(nvarchar,@CCNodeID)+'  
	order by lft'
  
    set @Depth=@CurDepth+1
 
  insert into @tab  
  exec(@sql)  
      
  set @i=0  
  select @cnt=count(id) from @tab  
      
  while(@i<@cnt)  
  begin  
   set @i=@i+1  
   select @nodeid=nodeid,@isgrp=isgrp from @tab  
   where id=@i  
  
   set @lft=@lft+1  
  
   if(@isgrp=1)  
   begin  
	  set @sql='update '+@TableName+'  
	   set lft='+convert(nvarchar,@lft)+',Depth='+convert(nvarchar,@CurDepth)+'
	   where '+@PrimKey+'='+convert(nvarchar,@nodeid) 
	   exec(@sql)  
	      
	   
    
    exec [spCOM_SetTreeStructure] @CostcenterID,@nodeid,@ColumnName,@Depth,@lft OUTPUT 
    
      set @sql='update '+@TableName+'  
	   set rgt='+convert(nvarchar,@lft+1)+'  
	   where '+@PrimKey+'='+convert(nvarchar,@nodeid) 
   end 
   ELSE
	   set @sql='update '+@TableName+'  
	   set lft='+convert(nvarchar,@lft)+',rgt='+convert(nvarchar,@lft+1)+',Depth='+convert(nvarchar,@CurDepth)+'
	   where '+@PrimKey+'='+convert(nvarchar,@nodeid)  
    
   exec(@sql)  
     
   set @lft=@lft+1  
     
  end  
   
COMMIT TRANSACTION   
SET NOCOUNT OFF;     
RETURN 1  
END TRY  
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
 IF ERROR_NUMBER()=50000  
 BEGIN  
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=1  
 END  
 ELSE  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
 FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=1  
 END  
ROLLBACK TRANSACTION  
SET NOCOUNT OFF    
RETURN -999     
END CATCH    
GO
