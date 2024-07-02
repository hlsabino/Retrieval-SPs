USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_SetDocFlow]
	@CCID [int],
	@DocID [int],
	@ProfileID [int],
	@RefCCID [int],
	@RefNodeID [int],
	@RefStatusID [int],
	@UserName [nvarchar](max),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  
		declare @xml xml,@sql nvarchar(max),@tablename nvarchar(100),@PKKey nvarchar(100),@i int,@cnt int,@fid int,@Fccid int,@nid int,@ActNodeID int
		if not exists(select * from COM_DocFlow WITH(NOLOCK) where CCID=@CCID and DocID=@DocID and RefCCID=@RefCCID and RefNodeID=@RefNodeID)
		BEGIN
			insert into COM_DocFlow(ProfileID,CCID,DocID,RefCCID,RefNodeID,RefStatusID)
			Values(@ProfileID,@CCID,@DocID,@RefCCID,@RefNodeID,@RefStatusID)
		END
		
		select @xml=Dimxml from ADM_DocFlowDef WITH(NOLOCK)
		where ProfileID=@ProfileID and CCID=@CCID
		
		if(convert(nvarchar(max),@xml)<>'')
		BEGIN
			declare @tab table(id int identity(1,1),Feature int,CostCenterId int,NodeID int,tablename nvarchar(100),PKKey nvarchar(100))
			insert into @tab
			select X.value('@Feature', 'INT') ,X.value('@CostCenterId', 'INT') ,X.value('@NodeID', 'INT') ,f.TableName,f.PrimaryKey
			from @xml.nodes('/XML/Row') as Data(X)    
			join adm_features f WITH(NOLOCK) on X.value('@Feature', 'INT')=f.FeatureID
			
			set @i =0
			select @cnt=count(*) from @tab
			
			WHILE(@i<@cnt)
			BEGIN
				set @i=@i+1
				select @fid =Feature,@Fccid =CostCenterId,@nid=NodeID,@tablename=tablename,@PKKey=PKKey 
				from @tab where id=@i
				
				if(@RefCCID=@fid)
					set @ActNodeID=@RefNodeID
				ELSE if(@RefCCID=95)
				BEGIN				
					if(@fid=93)
						select @ActNodeID=UnitID from REN_Contract WITH(NOLOCK) where ContractID=@RefNodeID
					else if(@fid=92)
						select @ActNodeID=PropertyID from REN_Contract WITH(NOLOCK) where ContractID=@RefNodeID	
					else if(@fid=94)
						select @ActNodeID=TenantID from REN_Contract WITH(NOLOCK) where ContractID=@RefNodeID	
				END		
				set @sql='update COM_CCCCData set CCNID'+convert(nvarchar(max),(@Fccid-50000))+'='+convert(nvarchar(max),@nid)
				+' where CostCenterID='+convert(nvarchar(max),@fid)+' and NodeID='+convert(nvarchar(max),@ActNodeID)
				exec(@sql)
			END			
		END
	 
	
COMMIT TRANSACTION   
SET NOCOUNT OFF;
RETURN 1  
END TRY  
BEGIN CATCH       
  IF ERROR_NUMBER()=50000  
  BEGIN  
   SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
  END  
  ELSE  
  BEGIN  
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
   FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999  AND LanguageID=@LangID 
  END  
ROLLBACK TRANSACTION  
SET NOCOUNT OFF    
RETURN -999     
END CATCH

GO
