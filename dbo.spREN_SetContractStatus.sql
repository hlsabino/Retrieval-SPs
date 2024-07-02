USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_SetContractStatus]
	@ContractID [int],
	@TerminationDate [datetime],
	@StatusID [int] = 0,
	@Reason [int],
	@TermRemarks [nvarchar](max) = NULL,
	@RoleID [int],
	@WID [int],
	@SysInfo [nvarchar](500) = '',
	@AP [nvarchar](10) = '',
	@LockDims [nvarchar](max) = '',
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
DECLARE @QUERYTEST NVARCHAR(100)  , @IROWNO NVARCHAR(100) , @TYPE NVARCHAR(100)  
BEGIN TRY      
SET NOCOUNT ON;   
  
  
	DECLARE @Dt float,@level int,@maxLevel int,@wfAction int,@DDXML  nvarchar(max)
 

	SET @Dt=convert(float,getdate())--Setting Current Date  

	if(@LockDims is not null and @LockDims<>'')
	BEGIN
		set @DDXML=' if exists(select a.ContractID from REN_Contract a WITH(NOLOCK)
		join COM_CCCCData b WITH(NOLOCK) on a.ContractID=b.NodeID and a.CostCenterID=b.CostCenterID
		join ADM_DimensionWiseLockData c WITH(NOLOCK) on '+convert(nvarchar(max),convert(float,@TerminationDate))+' between c.fromdate and c.todate and c.isEnable=1 
		where  a.CostCenterID=95 and a.ContractID='+convert(nvarchar,@ContractID)+' '+@LockDims
		+') RAISERROR(''-125'',16,1) '
		print @DDXML
		EXEC(@DDXML)
	END

	
	if exists(select * from REN_Contract where  parentContractID=@ContractID and statusid not in (428,450,478,480,481,465,477))
		RAISERROR('Terminate child contracts',16,1)
	
	if exists(select * from REN_Contract where  parentContractID=@ContractID and statusid=450
	and RefundDate>CONVERT(FLOAT , @TerminationDate))
		RAISERROR('Termination date is less than child contracts RefundDate',16,1)
	
	if exists(select * from REN_Contract where  parentContractID=@ContractID and statusid=428
	and TerminationDate>CONVERT(FLOAT , @TerminationDate))
		RAISERROR('Termination date is less than child contracts termination',16,1)
		
	if(@WID>0)
	begin
		set @level=(SELECT  top 1  LevelID FROM [COM_WorkFlow]   WITH(NOLOCK) 
		where WorkFlowID=@WID and  UserID =@UserID)

		if(@level is null )
			set @level=(SELECT top 1 LevelID FROM [COM_WorkFlow]  WITH(NOLOCK)  
			where WorkFlowID=@WID and  RoleID =@RoleID)

		if(@level is null ) 
			set @level=(SELECT top 1  LevelID FROM [COM_WorkFlow]   WITH(NOLOCK) 
			where WorkFlowID=@WID and  GroupID in (select GroupID from COM_Groups WITH(NOLOCK) where UserID=@UserID))

		if(@level is null )
			set @level=( SELECT top 1  LevelID FROM [COM_WorkFlow] WITH(NOLOCK) 
			where WorkFlowID=@WID and  GroupID in (select GroupID from COM_Groups WITH(NOLOCK) 
			where RoleID =@RoleID))

		select @maxLevel=max(LevelID) from COM_WorkFlow WITH(NOLOCK)  where WorkFlowID=@WID  
		
		if(@level is not null and  @maxLevel is not null and @maxLevel>@level)
		begin	
			if(@StatusID=477)
			BEGIN
				set @StatusID=478
				set @wfAction=4
			END	
			ELSE	
			BEGIN
				set @StatusID=465
				set @wfAction=1
			END	
		END
	END
	 
	UPDATE REN_CONTRACT
	SET STATUSID = @StatusID, WorkFlowID=@WID ,wfAction=@wfAction,WorkFlowLevel=case when @WID>0 then @level else WorkFlowLevel end
	,TerminationDate =case when @StatusID in(477,478) then null else CONVERT(FLOAT , @TerminationDate) end	
	,RefundDate=case when @StatusID not in(477,478) then null else CONVERT(FLOAT , @TerminationDate) end,Reason = @Reason
	,TermRemarks=@TermRemarks,modifieddate=@Dt,modifiedby=@UserName,PendFinalSettl=1
	WHERE ContractID = @ContractID or RefContractID=@ContractID
	
	if(@WID>0 and @wfAction is not null)
	BEGIN
		INSERT INTO COM_Approvals(CCID,CCNODEID,StatusID,Date,Remarks,UserID   
		  ,CompanyGUID,GUID,CreatedBy,CreatedDate,WorkFlowLevel,DocDetID)      
		VALUES(95,@ContractID,@StatusID,@DT,'',@UserID
		  ,@CompanyGUID,newid(),@UserName,@DT,isnull(@level,0),0) 
	END	
	
COMMIT TRANSACTION     
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;   
RETURN @ContractID      
END TRY      
BEGIN CATCH 
	      
	IF ERROR_NUMBER()=50000  
	BEGIN  
		if(isnumeric(ERROR_MESSAGE())=1)
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
			WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
		else
			SELECT ERROR_MESSAGE() ErrorMessage
	END  
	ELSE IF ERROR_NUMBER()=547  
	BEGIN  
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine 
		FROM COM_ErrorMessages WITH(nolock)  
		WHERE ErrorNumber=-110 AND LanguageID=@LangID  
	END  
	ELSE IF ERROR_NUMBER()=2627  
	BEGIN  
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine 
		FROM COM_ErrorMessages WITH(nolock)  
		WHERE ErrorNumber=-116 AND LanguageID=@LangID  
	END  
	ELSE  
	BEGIN  
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
		FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=-999 AND LanguageID=@LangID  
	END   
	ROLLBACK TRANSACTION    
	 
	SET NOCOUNT OFF      
	RETURN -999       
END CATCH 

GO
