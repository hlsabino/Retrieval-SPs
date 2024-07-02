USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_DeleteContract]
	@CostCenterID [int],
	@ContractID [int] = 0,
	@SysInfo [nvarchar](500) = '',
	@AP [nvarchar](10) = '',
	@LockDims [nvarchar](max) = '',
	@UserName [nvarchar](50),
	@UserID [int] = 1,
	@RoleID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY    
SET NOCOUNT ON;    
  
	DECLARE @TBLCNT INT,@INCCNT INT,@DELETEDOCID INT,@DELETECCID INT,@DELETEISACC BIT    
	DECLARE @return_value int,@HasAccess BIT ,@tempCID INT,@sql nvarchar(max),@ScheduleID INT  
	DECLARE @AUDITSTATUS NVARCHAR(50)
 
	--User acces check
	SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,4)

	IF @HasAccess=0
	BEGIN
		RAISERROR('-105',16,1)
	END
	
	if(@LockDims is not null and @LockDims<>'')
	BEGIN
		set @sql=' if exists(select a.ContractID from REN_Contract a WITH(NOLOCK)
		join COM_CCCCData b WITH(NOLOCK) on a.ContractID=b.NodeID and a.CostCenterID=b.CostCenterID
		join ADM_DimensionWiseLockData c WITH(NOLOCK) on a.ContractDate between c.fromdate and c.todate and c.isEnable=1 
		where  a.CostCenterID='+convert(nvarchar,@CostCenterID)+' and a.ContractID='+convert(nvarchar,@ContractID)+' '+@LockDims
		+') RAISERROR(''-125'',16,1) '
		
		EXEC sp_executesql @sql
	END
	
	if exists(select * from REN_Contract WITH(NOLOCK) where  parentContractID=@ContractID)
		RAISERROR('Delete child contracts',16,1)
		
		
	--ondelete External function
	IF (@ContractID>0)
	BEGIN
		DECLARE @tablename NVARCHAR(200)
		set @tablename=''
		select @tablename=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=@CostCenterID and Mode=8
		if(@tablename<>'')
			exec @tablename @CostCenterID,@ContractID,'',@UserID,@LangID	
	END	

	SET @DELETECCID = 0 

	DECLARE @lft INT,@rgt INT ,@Width INT

	SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft + 1
	FROM REN_CONTRACT WITH(NOLOCK) WHERE ContractID=@ContractID
	
	Declare @temp table(id int identity(1,1), NodeID INT)  
	insert into @temp  
	select ContractID from REN_CONTRACT WITH(NOLOCK) WHERE lft >= @lft AND rgt <= @rgt  and costcenterid=@CostCenterID
    
	declare @i int, @cnt int
	DECLARE @NodeID INT, @Dimesion INT 
	
				
	SET @AUDITSTATUS= 'DELETE'

	DECLARE  @tblListDEL TABLE(ID int identity(1,1),ContractID INT , DocID INT, COSTCENTERID INT ,IsAccDoc BIT  )      

	INSERT INTO @tblListDEL    
	SELECT distinct ACC.REFNODEID , ACC.DocID , ACC.CostCenterID ,1
	FROM ACC_DOCDETAILS ACC WITH(NOLOCK)  	
	WHERE ACC.REFNODEID = @ContractID and acc.RefCCID=@CostCenterID
	and ACC.InvDocDetailsID is null
	INSERT INTO @tblListDEL    
	SELECT distinct ACC.REFNODEID , ACC.DocID , ACC.CostCenterID ,0
	FROM Inv_DOCDETAILS ACC WITH(NOLOCK)  	
	WHERE ACC.REFNODEID = @ContractID and acc.RefCCID=@CostCenterID
	
	SELECT @INCCNT = 1,@TBLCNT = COUNT(*) FROM @tblListDEL  

	WHILE(@INCCNT <= @TBLCNT)  
	BEGIN  
		SELECT @DELETEDOCID=DocID,@DELETECCID=CostCenterID,@DELETEISACC =IsAccDoc 
		FROM @tblListDEL WHERE ID = @INCCNT  

		IF(@DELETEISACC = 1)  
		BEGIN   
			IF (@DELETECCID > 0 )
				EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]  
				 @CostCenterID = @DELETECCID,  
				 @DocPrefix =  '',  
				 @DocNumber = '',  
				 @DocID=@DELETEDOCID ,
				 @SysInfo =@SysInfo, 
				 @AP =@AP, 
				 @UserID = 1,  
				 @UserName = @UserName,  
				 @LangID = 1,
				 @RoleID=1
		END   
		ELSE  
		BEGIN      
			IF (@DELETECCID > 0 ) 
			BEGIN 
				EXEC @return_value = [spDOC_DeleteInvDocument]  
				 @CostCenterID = @DELETECCID,  
				 @DocPrefix = '',  
				 @DocNumber = '',  
				 @DocID=@DELETEDOCID ,
				 @SysInfo =@SysInfo, 
				 @AP =@AP, 
				 @UserID = 1,  
				 @UserName = @UserName,  
				 @LangID = 1,
				 @RoleID=1
				 
				 set @ScheduleID=0
				select @ScheduleID=ScheduleID from COM_CCSchedules WITH(NOLOCK)
				where CostCenterID=@DELETECCID and NodeID=@DELETEDOCID
			
				if(@ScheduleID>0)
				BEGIN
					delete from COM_CCSchedules
					where ScheduleID=@ScheduleID
					
					delete from COM_UserSchedules
					where ScheduleID=@ScheduleID
					
					delete from COM_SchEvents
					where ScheduleID=@ScheduleID
					
					delete from COM_Schedules
					where ScheduleID=@ScheduleID
				END
			END	 
		END  
		SET @INCCNT = @INCCNT + 1   
	END   
	
	
	select @i=1,@cnt=count(*) from @temp  
	while @i<=@cnt
	begin
		set @NodeID=0
		set @Dimesion=0
		select @tempCID=NodeID from @temp where id=@i  
		select  @NodeID = CCNodeID, @Dimesion=CCID from REN_CONTRACT WITH(NOLOCK) where ContractID=@tempCID  
 
		if (@Dimesion > 0 and @NodeID is not null and @NodeID>1)  
		begin  

			Update REN_CONTRACT set CCID=0, CCNodeID=0 where ContractID =@tempCID  

			set @sql='update com_docccdata  
			set dcccnid'+convert(nvarchar,(@Dimesion-50000))+'=1  
			from ACC_DocDetails a WITH(NOLOCK) 
			where com_docccdata.accdocdetailsid=a.accdocdetailsid  
			and a.refccid='+Convert(NVARCHAR,@CostCenterID)+' and a.refnodeid='+convert(nvarchar,@tempCID)     
			exec sp_executesql @sql

			set @sql='update com_docccdata  
			set dcccnid'+convert(nvarchar,(@Dimesion-50000))+'=1  
			from INV_DocDetails a WITH(NOLOCK) 
			where com_docccdata.invdocdetailsid=a.invdocdetailsid  
			and a.refccid='+Convert(NVARCHAR,@CostCenterID)+' and a.refnodeid='+convert(nvarchar,@tempCID)  
			exec sp_executesql @sql

			set @sql='update com_ccccdata  
			set ccnid'+convert(nvarchar,(@Dimesion-50000))+'=1  
			from REN_CONTRACT a WITH(NOLOCK) 
			where com_ccccdata.Nodeid=a.ContractID   and com_ccccdata.costcenterid='+Convert(NVARCHAR,@CostCenterID)+'
			and  com_ccccdata.ccnid'+convert(nvarchar,(@Dimesion-50000))+'='+convert(nvarchar,@NodeID)  
			exec sp_executesql @sql

			SET @return_value = 0
			IF(@NodeID>1)
			BEGIN 
				EXEC @return_value = [dbo].[spCOM_DeleteCostCenter]
				@CostCenterID = @Dimesion,
				@NodeID = @NodeID,
				@RoleID=1,
				@UserID = @UserID,
				@LangID = @LangID,
				@CheckLink = 0
				--Deleting from Mapping Table
				Delete from com_docbridge WHERE CostCenterID = @CostCenterID AND RefDimensionNodeID = @NodeID AND RefDimensionID = @Dimesion	
			END			
		end
		set @i=@i+1
	end

	DECLARE @AuditTrial BIT        
	SET @AuditTrial=0        
	SELECT @AuditTrial= CONVERT(BIT,VALUE)  FROM [COM_COSTCENTERPreferences] with(nolock)     
	WHERE CostCenterID=95  AND NAME='AllowAudit'   
	IF (@AuditTrial=1)      
	BEGIN 	
		--INSERT INTO HISTROY   
		EXEC [spCOM_SaveHistory]  
			@CostCenterID =@CostCenterID,    
			@NodeID =@ContractID,
			@HistoryStatus =@AUDITSTATUS,
			@UserName=@UserName 
	END
	
	DELETE FROM COM_Files WHERE FEATUREID=@CostCenterID and  FeaturePK=@ContractID 
		
	DELETE FROM CRM_ACTIVITIES WHERE CostCenterID=@CostCenterID AND NodeID=@ContractID 
		    
	DELETE FROM REN_ContractDocMapping WHERE CONTRACTID = @CONTRACTID  
	DELETE FROM  [REN_ContractExtended] WHERE  [NodeID]  = @ContractID
	
	Delete from REN_ContractParticularsDetail where ContractID=@ContractID and Costcenterid=@CostCenterID
	
	delete from REN_ContractParticulars where ContractID=@ContractID    
	delete from REN_ContractPayTerms where ContractID=@ContractID  
	
	if exists(select * from REN_Contract WITH(NOLOCK) where  RefContractID=@ContractID)
	BEGIN
		delete from REN_Contract where  RefContractID=@ContractID  
		select @tempCID=unitid from REN_Contract WITH(NOLOCK) where  ContractID=@ContractID
		
		update REN_Contract 
		set unitid=1
		where  ContractID=@ContractID
		
		exec dbo.spREN_DeleteUnit @tempCID,1,1,1
	END
	
	IF exists(select * from REN_Contract WITH(NOLOCK) where ContractID=@ContractID AND parentContractID IS NOT NULL AND parentContractID>0)
	BEGIN
		select @tempCID=parentContractID from REN_Contract WITH(NOLOCK)
		where ContractID=@ContractID AND parentContractID IS NOT NULL AND parentContractID>0
		UPDATE [REN_Contract] SET NoOfContratcs=(NoOfContratcs-1)
		WHERE ContractID=@tempCID
	END
	
	UPDATE REN_Quotation SET StatusID=(CASE WHEN CostCenterID=103 THEN 426 ELSE 467 END) 
	WHERE QuotationID IN (SELECT QuotationID FROM REN_Contract WITH(NOLOCK) WHERE QuotationID IS NOT NULL AND QuotationID>0 AND ContractID=@ContractID)
	
	delete from REN_Contract where  ContractID=@ContractID  
	
	DELETE FROM com_approvals 
	WHERE CCID=@CostCenterID AND CCNODEID=@ContractID
	
COMMIT TRANSACTION  
SET NOCOUNT OFF;    
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=102 AND LanguageID=@LangID  
  
RETURN 1  
END TRY  
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]
 
 if(@return_value=-999)
     return @return_value
 IF ERROR_NUMBER()=50000  
 BEGIN  
	IF ISNUMERIC(ERROR_MESSAGE())=1	
		SELECT ErrorMessage,ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
	else
		SELECT ERROR_MESSAGE() ErrorMessage	
 END  
 ELSE IF ERROR_NUMBER()=547  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)  
  WHERE ErrorNumber=-110 AND LanguageID=@LangID  
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
