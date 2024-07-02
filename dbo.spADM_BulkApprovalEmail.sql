USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_BulkApprovalEmail]
	@GUID [nvarchar](50),
	@ApprovalStatus [int],
	@Remarks [nvarchar](max),
	@WorkFlowID [int] = 0,
	@IsFrmDoc [int] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  
	declare @SchEventID INT,@CostCenterID int,@DocID INT,@IsInventory bit,@StatusID smallint,@SQL nvarchar(max),@DocNo nvarchar(100),@DocGUID nvarchar(50)
		,@DocDetailsID INT,@WID int,@WLevel smallint,@To nvarchar(max),@TblName nvarchar(50),@PK nvarchar(50),@DocType INT,@RemarksMandatory int
		,@UserName nvarchar(100),@UserID int,@RoleID int,@Dt float,@RETVALUE int,@LineXML nvarchar(max)
	declare @TblTo as table(ID int identity(1,1), Email nvarchar(max))
	--,@ApproveCommentsMandatory nvarchar(10),@RejectCommentsMandatory nvarchar(10)
	set @RemarksMandatory=0
	set @Dt=convert(float,getdate())
	
	select @StatusID=StatusID,@CostCenterID=CostCenterID,@DocID=DocID,@WID=WID
	--,@DocDetailsID=max(DocDetailsID),@WLevel=max(WLevel)
	from COM_EmailApproval A with(nolock) where GUID=@GUID

	if @CostCenterID is null
	begin
		select 'Invalid Request.' ErrorMessage
		rollback transaction
		return -1
	end
	else if @StatusID=2
	begin
		select 'Link Already Requested.' ErrorMessage
		rollback transaction
		return -1
	end
	else if @StatusID=3
	begin
		select 'Request Link Rejected.' ErrorMessage
		rollback transaction
		return -1
	end


	 select @SchEventID=SchEventID from COM_SchEvents with(nolock) where GUID=@GUID
 
	 select @To=[To] from COM_Notif_History with(nolock) where SchEventID=@SchEventID order by ID desc  
	 if @To is not null and @To like '%,%'  
	  set @To=replace(@To,',',';')  
	 insert into @TblTo(Email)  
	 exec SPSplitString @To,';'  
	 
	 select @UserID=UserID,@UserName=UserName from @TblTo  a
	 join adm_users u with(nolock) on  u.Email1=a.Email or u.Email2=a.Email
	 where Email IS NOT NULL AND Email<>''  
	 
	
	if @UserID is null
	begin
		select 'User not found.' ErrorMessage
		update COM_EmailApproval set StatusID=3 where GUID=@GUID
		rollback transaction
		return -1
	end
	
	select @RoleID=RoleID from ADM_UserRoleMap WITH(NOLOCK)  where UserID =@UserID and IsDefault=1
	
	select @RoleID=RoleID from (
	select top 1 R.RoleID,IsDefault
	from ADM_UserRoleMap M WITH(NOLOCK)
	inner join ADM_PRoles R with(nolock) on R.RoleID=M.RoleID
	where UserID=@UserID and M.Status=1 and IsDefault=0 and R.RoleID!=@RoleID
	and ((FromDate is null and ToDate is null) or (FromDate is not null and FromDate<=@Dt and ToDate is null) or (ToDate is not null and @Dt between FromDate and ToDate))
	union all
	select RoleID,1 from ADM_PRoles WITH(NOLOCK) where RoleID=@RoleID
	) AS T
	order by IsDefault desc
	
	select @DocType=DocumentType,@IsInventory=IsInventory from adm_documentTypes with(nolock) where CostCenterID=@CostCenterID 
	if @IsInventory=1
	begin
		set @TblName='INV_DocDetails'
		set @PK='InvDocDetailsID'
	end
	else
	begin
		set @TblName='ACC_DocDetails'
		set @PK='AccDocDetailsID'
	end
	
	if @ApprovalStatus=1
	begin
		set @ApprovalStatus=369
		if exists(select PrefName from COM_DocumentPreferences Where PrefName ='CommentsMandatoryforApprove' and isnull(PrefValue,'False')='True' and CostCenterID=@CostCenterID)
			set @RemarksMandatory=1
	end
	else
	begin
		set @ApprovalStatus=372
		if exists(select PrefName from COM_DocumentPreferences Where PrefName ='CommentsMandatoryforReject' and isnull(PrefValue,'False')='True' and CostCenterID=@CostCenterID)
			set @RemarksMandatory=2
	end
	--Remarks Mandatory
	if(@RemarksMandatory>0 and isnull(@Remarks,'')='')
	begin
		if(@RemarksMandatory=1)
			select 'Remarks Mandatory For Approval' ErrorMessage
		else if(@RemarksMandatory=2)
			select 'Remarks Mandatory For Reject' ErrorMessage
		update COM_EmailApproval set StatusID=3 where GUID=@GUID
		rollback transaction
		return -1
	end	
	
	set @LineXML=''
	--LineWise	
	if exists (select top 1 IsLineWise from COM_WorkFlowDef with(nolock) where @WID=WorkFlowID and IsLineWise=1)
	begin
		set @SQL='set @LineXML=''''
SELECT @DocNo=D.VoucherNo,@LineXML=@LineXML+''<Row ID="''+convert(nvarchar,D.'+@PK+')+''" Remarks="'+@Remarks+'" WID="''+convert(nvarchar,D.WorkflowID)+''" />''
FROM '+@TblName+' D with(nolock) 
WHERE D.CostCenterID='+convert(nvarchar,@CostCenterID)+' and D.DocID='+convert(nvarchar,@DocID)+'
AND (D.WorkFlowID>0 AND '
		if exists(select value from ADM_GlobalPreferences with(nolock) where Name='CanApproveFunction' and Value='True')
			set @SQL=@SQL+'dbo.fnExt_CanApprove(D.'+@PK+','
		else
			set @SQL=@SQL+'dbo.fnRPT_CanApprove('
		set @SQL=@SQL+'D.CostCenterID,D.WorkflowID,D.WorkFlowLevel,D.StatusID,D.CreatedDate,'+convert(nvarchar,@UserID)+','+convert(nvarchar,@RoleID)+')=1)
ORDER BY D.DocSeqNo'
		print (@SQL)
		EXEC sp_executesql @SQL,N'@DocNo nvarchar(100) output,@LineXML nvarchar(max) output',@DocNo output,@LineXML output
		
	
			if @LineXML=''
			begin	
				select '"'+@UserName+'" not authorized to approve/reject document.' ErrorMessage
				update COM_EmailApproval set StatusID=3 where GUID=@GUID
				rollback transaction
				return -1
			end
		
		set @LineXML='<XML No="'+@DocNo+'">'+@LineXML+'</XML>'
	end
	else
	begin
		set @SQL='SELECT @DocNo=D.VoucherNo FROM '+@TblName+' D with(nolock) 
				  WHERE D.CostCenterID='+convert(nvarchar,@CostCenterID)+' and D.DocID='+convert(nvarchar,@DocID)+'
				  AND (D.WorkFlowID>0 AND '
		IF EXISTS(select value from ADM_GlobalPreferences with(nolock) where Name='CanApproveFunction' and Value='True')  
			SET @SQL=@SQL+'dbo.fnExt_CanApprove(D.'+@PK+','  
		ELSE IF (@DocType >= 51 AND @DocType <= 199 AND @DocType != 64) --IS PAYROLL DOCUMENT
		BEGIN
			--Check Whether the User Level is Payroll Employee Report Manager Level or Not
			SET @SQL=@SQL+'dbo.fnPay_CanApprove('  
			SET @SQL=@SQL+'D.InvDocDetailsID,D.DocumentType,'''+convert(nvarchar,@UserName)+''',' 
		END
		ELSE  
			SET @SQL=@SQL+'dbo.fnRPT_CanApprove(' 
			
		SET @SQL=@SQL+'D.CostCenterID,D.WorkflowID,D.WorkFlowLevel,D.StatusID,D.CreatedDate,'+convert(nvarchar,@UserID)+','+convert(nvarchar,@RoleID)+')=1)'
		print (@SQL)
		EXEC sp_executesql @SQL,N'@DocNo nvarchar(100) output',@DocNo output
		
		if (@DocNo is null)
		begin			 
			select '"'+@UserName+'" not authorized to approve/reject document.' ErrorMessage
			update COM_EmailApproval set StatusID=3 where GUID=@GUID
			rollback transaction
			return -1
		end			
	end
	
	 
	select @DocGUID=GUID from com_docid with(nolock) where id=@DocID
	EXEC @RETVALUE=[spDOC_SetStatus] @STATUSID=@ApprovalStatus,@REMARKS=@Remarks,@DATE=@Dt,@ISINVENTORY=@IsInventory,@DOCID=@DocID,
		@COSTCENTERID=@CostCenterID,@WId=@WorkFlowID,@isFromDOc=@IsFrmDoc,@InvDocidS=@LineXML,@CompanyGUID='CompanyGUID',@UserName=@UserName,@DocGUID=@DocGUID,
		@UserID=@UserID,@ROLEID=@RoleID,@LangID=1 

	if @RETVALUE=1
		update COM_EmailApproval set StatusID=2,ModifiedDate=@Dt where GUID=@GUID
	 

COMMIT TRANSACTION
--ROLLBACK TRANSACTION
SET NOCOUNT OFF;  

if @ApprovalStatus=372
	select 'Rejected Successfully' ErrorMessage
else
	select 'Approved Successfully' ErrorMessage

RETURN 1
END TRY
BEGIN CATCH 

	SELECT ERROR_MESSAGE() ErrorMessage,-1 ErrorNumber

	ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
