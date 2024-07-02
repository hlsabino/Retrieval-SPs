USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetAssignedUsers]
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY     
SET NOCOUNT ON  
	declare   @users nvarchar(max),@temp nvarchar(max),@sql nvarchar(max)
	
	set @users=''
	set @temp=''
	select @temp=@temp+convert(nvarchar,NodeID)+','  from COM_CostCenterCostCenterMap  WITH(NOLOCK)  
	where parentcostcenterid=7 and parentnodeid=@UserID and costcenterid=7
	
	if (@temp<>'')
	BEGIN
		set @users=@users+@temp
		
		set @temp=substring(@temp,0,len(@temp))
		set @users=substring(@users,0,len(@users))

		set @sql='select @temp=@temp+convert(nvarchar,NodeID)+'','' from COM_CostCenterCostCenterMap  WITH(NOLOCK)  
		where parentcostcenterid=7 and parentnodeid in('+@temp+') and costcenterid=7 
		and nodeid not in('+@users+')'
		set @temp=''
		exec sp_executesql 	@sql,N'@temp nvarchar(max) output ',@temp output
		while (@temp<>'')
		BEGIN			
			set @users=@users+','+@temp
		
			set @temp=substring(@temp,0,len(@temp))
			set @users=substring(@users,0,len(@users))
			
			set @sql='select @temp=@temp+convert(nvarchar,NodeID)+'','' from COM_CostCenterCostCenterMap  WITH(NOLOCK)  
				where parentcostcenterid=7 and parentnodeid in('+@temp+') and costcenterid=7  
				and nodeid not in('+@users+')'
			set @temp=''
			exec sp_executesql 	@sql,N'@temp nvarchar(max) output ',@temp output
		END
		
	END
	
	set @sql='select @users=@users+UserName+'','' from ADM_Users  WITH(NOLOCK)  
		where UserID in('+@users+')'
		set @users=''
		exec sp_executesql 	@sql,N'@users nvarchar(max) output ',@users output
	
    
	select @users AssignedUsers
	
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
SET NOCOUNT OFF      
RETURN -999       
END CATCH      
	
GO
