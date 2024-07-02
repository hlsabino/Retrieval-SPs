USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetDivisions]
	@LocationID [int],
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY     
SET NOCOUNT ON    
    
	  --Declaration Section    
	  DECLARE @HasAccess bit,@Ret int,@username nvarchar(100)
    
	  select @username=UserName From ADM_Users WHERE UserID=@UserID

	 --SP Required Parameters Check    
	  if(@UserID<0)    
	  BEGIN    
	   RAISERROR('-100',16,1)    
	  END    
	  
	 IF EXISTS(SELECT Value FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='EnableDivisionWise' AND Value='True')
	 and  EXISTS(SELECT Value FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='Login' AND Value='True')
	 BEGIN
		---- if login with Employee
		declare @isemp bit,@empseqno INT,@empdivseqno INT,@SQL NVARCHAR(MAX)
		

		if exists (select * from sys.tables with(nolock) where name='com_cc50051')
		SET @SQL='if exists(select nodeid from com_cc50051 with(nolock) where code='''+CONVERT(NVARCHAR,@username)+''')
		begin
			set @isemp=1
			select @empseqno = nodeid from com_cc50051 with(nolock) where code='''+CONVERT(NVARCHAR,@username)+'''
			
		end'
		EXEC sp_executesql @SQL,N' @isemp int OUTPUT,@empseqno int OUTPUT',@isemp OUTPUT,@empseqno OUTPUT
		

		if(@isemp=1)
		begin
		SET @SQL='select @empdivseqno= ISNULL(CCNID1,1) FROM COM_CCCCDATA WITH(NOLOCK) WHERE CostCenterID=50051 AND NodeID='+CONVERT(NVARCHAR,@empseqno)
		EXEC sp_executesql @SQL,N' @empdivseqno INT OUTPUT', @empdivseqno OUTPUT
			select DISTINCT d.NodeID,d.Code,d.Name,d.IsGroup,d.lft from COM_Division d  WITH(NOLOCK)
			where d.NodeID=@empdivseqno
		end
		--end if login with Employee
		else
		begin
			if(@LocationID=0)
			begin
				select DISTINCT l.NodeID,l.Code,l.Name,l.IsGroup,l.lft from COM_Division l  WITH(NOLOCK)
				join COM_Division g WITH(NOLOCK) on l.lft between g.lft and g.rgt 
				join COM_CostCenterCostCenterMap c WITH(NOLOCK) on g.NodeID=c.NodeID and CostCenterID=50001
				join ( select DISTINCT d.NodeID from COM_Location l  WITH(NOLOCK)
				join COM_Location g  WITH(NOLOCK) on l.lft between g.lft and g.rgt 
				join COM_CostCenterCostCenterMap c WITH(NOLOCK) on g.NodeID=c.NodeID and c.CostCenterID=50002
				join COM_CostCenterCostCenterMap d WITH(NOLOCK) on d.ParentNodeID=l.NodeID and d.ParentCostCenterID=50002 and d.CostCenterID=50001
				where (c.ParentCostCenterID=7 and c.ParentNodeID=@UserID) or (c.ParentCostCenterID=6 and c.ParentNodeID=@RoleID)) as t on l.NodeID=t.NodeID 
				where ((ParentCostCenterID=7 and ParentNodeID=@UserID) or (ParentCostCenterID=6 and ParentNodeID=@RoleID))
				order by l.lft
			
			end
			ELSE
				select DISTINCT l.NodeID,l.Code,l.Name,l.IsGroup,l.lft from COM_Division l  WITH(NOLOCK)
				join COM_Division g WITH(NOLOCK) on l.lft between g.lft and g.rgt 
				join COM_CostCenterCostCenterMap c WITH(NOLOCK) on g.NodeID=c.NodeID and CostCenterID=50001
				join ( select ll.NodeID from COM_Division ll  WITH(NOLOCK)  
				join COM_Division lg WITH(NOLOCK) on ll.lft between lg.lft and lg.rgt   
				join COM_CostCenterCostCenterMap c WITH(NOLOCK) on lg.NodeID=c.NodeID   
				where ParentCostCenterID=50002 and ParentNodeID=@LocationID and CostCenterID=50001) as t on l.NodeID=t.NodeID 
				where ((ParentCostCenterID=7 and ParentNodeID=@UserID) or (ParentCostCenterID=6 and ParentNodeID=@RoleID))
				order by l.lft
				end
	 END  



	 ---- if login with Employee
		if exists (select * from sys.tables with(nolock) where name='com_cc50051')
		SET @SQL='if exists(select nodeid from com_cc50051 with(nolock) where code='''+CONVERT(NVARCHAR,@username)+''')
		begin
			set @isemp=1
			select @empseqno = nodeid from com_cc50051 with(nolock) where code='''+CONVERT(NVARCHAR,@username)+'''
			
		end'
		EXEC sp_executesql @SQL,N' @isemp int OUTPUT,@empseqno int OUTPUT',@isemp OUTPUT,@empseqno OUTPUT
		

		if(@isemp=1)
		begin
			SET @SQL='select @empdivseqno= ISNULL(CCNID1,1) FROM COM_CCCCDATA WITH(NOLOCK) WHERE CostCenterID=50051 AND NodeID='+CONVERT(NVARCHAR,@empseqno)
			EXEC sp_executesql @SQL,N' @empdivseqno INT OUTPUT', @empdivseqno OUTPUT
			select DISTINCT d.NodeID,d.Code,d.Name,d.IsGroup,d.lft,'True' IsEmp from COM_Division d  WITH(NOLOCK)
			where d.NodeID=@empdivseqno
		end
		--end if login with Employee
		else
		begin
			  if exists(SELECT NodeID FROM COM_CostCenterCostCenterMap WITH(NOLOCK)
			  WHERE CostCenterID=50001 AND ParentCostCenterID=7 and ParentNodeID = @UserID and NodeID=1)  
			  begin  
				SELECT NodeID,Code,Name from COM_Division WITH(NOLOCK) 
				WHERE isgroup=0   
			  end  
			  else  
			  begin  
				SELECT DISTINCT CD2.NodeID,CD2.Code,CD2.Name from COM_Division CD1 WITH(NOLOCK)
				LEFT JOIN COM_Division CD2 WITH(NOLOCK) ON CD2.lft between CD1.lft and CD1.rgt 
				WHERE CD1.NodeID in(SELECT NodeID FROM COM_CostCenterCostCenterMap WITH(NOLOCK)
				WHERE CostCenterID=50001 AND ((ParentCostCenterID=7 and ParentNodeID=@UserID) or (ParentCostCenterID=6 and ParentNodeID=@RoleID)))
			  end  
		end
	  
	  SELECT DivisionID FROM ADM_Users WITH(NOLOCK) WHERE UserID=@UserID

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
