USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPRD_DeleteMO]
	@MFGOrderID [bigint],
	@UserID [bigint],
	@UserName [nvarchar](100),
	@LangID [int] = 1,
	@RoleID [int] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;    


	declare @tab table(id int identity(1,1),Accid bigint,invid bigint)
	declare @i int,@cnt int,@invDocid bigint,@accdocid bigint,@docno nvarchar(200),@prefix nvarchar(50),@CCID bigint,@return_value int

	DELETE FROM  PRD_MFGOrderExtd WHERE MFGOrderID=@MFGOrderID    

	DELETE FROM   COM_CCCCDATA WHERE [CostCenterID]=78 and  [NodeID]=@MFGOrderID    

	DELETE FROM [PRD_MOWODetails]
	where  MFGOrderWOID in (select MFGOrderWOID  FROM [PRD_MFGOrderWOs]
	where  MFGOrderBOMID in (select  MFGOrderBOMID FROM  [PRD_MFGOrderBOMs]   
	WHERE MFGOrderID=@MFGOrderID))
	
	DELETE FROM [PRD_MFGOrderWOs]
	where  MFGOrderBOMID in (select  MFGOrderBOMID FROM  [PRD_MFGOrderBOMs]   	
	WHERE MFGOrderID=@MFGOrderID)
	
	DELETE FROM  [PRD_MFGOrderBOMs]   
	WHERE MFGOrderID=@MFGOrderID 


	insert into @tab 
	select [AccDocID],[InvDocID] from [PRD_MFGDocRef] WITH(NOLOCK) 
	where [MFGOrderID]=@MFGOrderID

	select @i=0,@cnt=COUNT(id) from @tab
	while(@i<@cnt)
	begin
		set @i=@i+1

		select @invDocid=invid,@accdocid=accid from @tab where id=@i 
		
		if(@invDocid is not null and @invDocid<>0)
		begin
			set @CCID=0
			select Top 1 @CCID=costcenterid from inv_docdetails
			where docid=@invDocid
			if(@CCID>40000)
			BEGIN
				 EXEC @return_value = [spDOC_DeleteInvDocument]      
				@CostCenterID = @CCID,      
				@DocPrefix = '',      
				@DocNumber = '', 
				@DocID=@invDocid,     
				@UserID = @UserID,      
				@UserName = @UserName,      
				@LangID = @LangID ,
				@RoleID=@RoleID
			END
		end
		else if(@accdocid is not null and @accdocid<>0)
		begin
			set @CCID=0
			select Top 1 @CCID=costcenterid from acc_docdetails
			where docid=@accdocid
			if(@CCID>40000)
			BEGIN
				EXEC @return_value = spDOC_DeleteAccDocument      
				@CostCenterID = @CCID,      
				@DocPrefix = '',      
				@DocNumber = '', 
				@DocID=@accdocid,     
				@UserID = @UserID,      
				@UserName = @UserName,      
				@LangID = @LangID ,
				@RoleID=@RoleID
			END	
		end

	end

	DELETE from [PRD_MFGDocRef]  
	where [MFGOrderID]=@MFGOrderID

	DELETE FROM  COM_Notes
	WHERE FeatureID=78 and  FeaturePK=@MFGOrderID  

	DELETE FROM  COM_Files    
	WHERE FeatureID=78 and  FeaturePK=@MFGOrderID  

	DELETE FROM PRD_ProductionMethod
	where MOID=@MFGOrderID

	DELETE FROM PRD_MFGOrder  
	WHERE MFGOrderID=@MFGOrderID  
	
  
COMMIT TRANSACTION  
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=102 AND LanguageID=@LangID

RETURN @@rowcount
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
