USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_BulkApprovals]
	@CostCenterID [int],
	@isInv [bit],
	@Remarks [nvarchar](500) = null,
	@DocInfo [nvarchar](max),
	@Status [int],
	@AppRejDate [datetime],
	@ApprisalXML [nvarchar](max) = null,
	@UserID [int],
	@RoleID [int],
	@UserName [nvarchar](50),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;    

	DECLARE @RETVALUE INT,@TblName NVARCHAR(50),@DocGUID nvarchar(100) --, @WID INT, @level int, @maxlevel int, @StatusID int
	SET @RETVALUE=1 
		
	declare @i int, @cnt int, @DocID INT,@STATUSID int, @oldStatus int, @CompanyGUID nvarchar(50), @level int
	
	declare @tbldoc table (id int identity(1,1),DocId INT,CostCenterID int,IsInv bit)
	
	if(@CostCenterID=2 or @CostCenterID=3 or @CostCenterID=92 or @CostCenterID=93 or @CostCenterID=94 or @CostCenterID>50000)
	begin
		insert into @tbldoc(DocId)
		exec  SPSplitString @DocInfo,','
		
		declare @sql nvarchar(max),@sqlparm nvarchar(max)
		set @sqlparm='@STATUSID int output,@DocID INT'
		select @sql='select @STATUSID='+case when @CostCenterID=93 then 'STATUS' else 'STATUSID' end+' from '+TableName+' with(nolock) where '+PrimaryKey+'=@DocID ' 
		from ADM_Features with(nolock) 
		where FeatureID=@CostCenterID
		
		SET @Status=~convert(bit,@Status)
		
		select @i=1,@cnt=count(*) from @tbldoc
		while @i<=@cnt
		begin
			select @DocID=DocId from @tbldoc where id=@i

			exec sp_executesql @sql,@sqlparm, @STATUSID OUTPUT,@DocID 

			exec [spCOM_ApproveCostCenterWF]
			@CostCenterID =@CostCenterID,  
			@NodeID =@DocID,
			@RoleID =@RoleID,
			@UserID =@UserID, 	
			@UserName =@UserName,
			@Remarks =@Remarks,
			@IsReject =@Status,
			@StatusID =@STATUSID,
			@LangID =@LangID
			
			set @i=@i+1
		end	
	end
	else if(@CostCenterID=95 or @CostCenterID=103 or @CostCenterID=104 or @CostCenterID=129)
	begin
		insert into @tbldoc(DocId)
		exec  SPSplitString @DocInfo,','
		
		select @i=1,@cnt=count(*) from @tbldoc
		while @i<=@cnt
		begin
			select @DocID=DocId from @tbldoc where id=@i
			
			exec [spREN_ApproveContractDocs]  
			 @COSTCENTERID =@CostCenterID,
			 @ContractID =@DocID,
			 @IsApprove =@Status,
			 @RejRemarks =@Remarks,
			 @CompanyGUID=N'' ,
			 @RoleID =@RoleID,
			 @UserID =@UserID, 
			 @UserName=@UserName,
			 @LangID =@LangID      
			 
			set @i=@i+1
		end	
	end
	else if(@CostCenterID between 40001 and 49999)
	begin
		declare @IsLineWise bit,@XML xml,@DocPrefix NVARCHAR(100),@DocNumber NVARCHAR(30)
		declare @temptable table(id int identity(1,1),Voucherno nvarchar(max))
		if @DocInfo like '<XML%'
		begin
			set @IsLineWise=1
			declare @bb nvarchar(max)
			set @bb=convert(varchar,CHAR(17))
			insert into @temptable
			exec SPSplitString @DocInfo,@bb
		end
		else
		begin
			set @IsLineWise=0
			insert into @temptable
			exec  SPSplitString @DocInfo,','
		end

		if @IsLineWise=0
		begin
			insert into @tbldoc(DocId,CostCenterID,IsInv)
			select distinct docid,CostCenterID,1 from inv_docdetails WITH(NOLOCK) where Voucherno in (select Voucherno from @temptable)
			
			insert into @tbldoc(DocId,CostCenterID,IsInv)
			select distinct docid,CostCenterID,0 from acc_docdetails WITH(NOLOCK) where InvDocDetailsID is null and Voucherno in (select Voucherno from @temptable)

			select @i=1,@cnt=count(*) from @tbldoc
			while @i<=@cnt
			begin
				select @DocID=DocId,@CostCenterID=CostCenterID,@isInv=IsInv from @tbldoc where id=@i
				if @Status=2
				begin
					if(@isInv=0)
					begin
						select @DocPrefix=DocPrefix,@DocNumber=DocNumber from acc_docdetails WITH(NOLOCK) where docid=@DocID
						exec spDOC_SuspendAccDocument @CostCenterID=@CostCenterID,@DOCID=@DocID,@DocPrefix=@DocPrefix,@DocNumber=@DocNumber
						,@Remarks='',@LockWhere='',@UserID=@UserID,@UserName=@UserName,@RoleID=@RoleID,@LangID=@LangID
					end
					else
					begin
						select @DocPrefix=DocPrefix,@DocNumber=DocNumber from inv_docdetails WITH(NOLOCK) where docid=@DocID
						exec spDOC_SuspendInvDocument @CostCenterID=@CostCenterID,@DOCID=@DocID,@DocPrefix=@DocPrefix,@DocNumber=@DocNumber
						,@Remarks='',@LockWhere='',@UserID=@UserID,@UserName=@UserName,@RoleID=@RoleID,@LangID=@LangID
					end
				end
				else
				begin
					if(@isInv=0)
						select @oldStatus=statusid from acc_docdetails WITH(NOLOCK) where docid=@DocID
					else
						select @oldStatus=statusid from inv_docdetails WITH(NOLOCK) where docid=@DocID
						
						select @CompanyGUID=CompanyGUID,@DocGUID=GUID from com_Docid WITH(NOLOCK) where id=@DocID
					if @Status=1
						set @STATUSID=369
					else
						set @STATUSID=372

					exec [spDOC_SetStatus]	@STATUSID=@STATUSID,@REMARKS=@Remarks,@DATE=@AppRejDate,@ISINVENTORY=@isInv,@DOCID=@DocID,
					@COSTCENTERID=@CostCenterID,@WId=0,@isFromDOc=0,@InvDocidS='',@CompanyGUID=@CompanyGUID,@UserName=@UserName,@DocGUID=@DocGUID,
					@UserID=@UserID,@ROLEID=@RoleID,@LangID=@LangID   

					if(@CostCenterID=40085)
					BEGIN
						DECLARE @XML1 XML,@VocNo NVARCHAR(500),@Q NVARCHAR(MAX),@UpdatedStatus int
						SET @Q=''
						DECLARE @TEMP TABLE(ID INT IDENTITY(1,1),EMPNODEID INT,VoucherNo NVARCHAR(500),QUERY NVARCHAR(MAX))
						select @UpdatedStatus=statusid,@VocNo=VoucherNo from inv_docdetails WITH(NOLOCK) where docid=@DocID

						if(@UpdatedStatus=369)
						BEGIN
							if(ISNULL(@ApprisalXML,'')<>'')
							BEGIN
								SET @XML1=@ApprisalXML
								INSERT INTO @TEMP
								SELECT x.value('@EmpNodeID','BIGINT'),x.value('@VoucherNo','NVARCHAR(500)'),x.value('@Query','NVARCHAR(MAX)') FROM @XML1.nodes('/Data/Row') as DATA(x)

								SELECT @Q=QUERY FROM @TEMP WHERE VoucherNo=@VocNo
								--SELECT @Q
								EXEC(@Q)
								DELETE FROM @TEMP
							END
						END


					END
				end
		 
				set @i=@i+1
			end
		end
		else
		begin
			select @i=1,@cnt=count(*) from @temptable
			while @i<=@cnt
			begin
				select @DocInfo=Voucherno from @temptable where id=@i
				set @XML=@DocInfo
				
				if(@isInv=0)
					select @DocID=DocID,@oldStatus=statusid,@CostCenterID=CostCenterID from acc_docdetails WITH(NOLOCK) where VoucherNo=@XML.value('(XML/@No)[1]','NVARCHAR(MAX)')
				else
					select @DocID=DocID,@oldStatus=statusid,@CostCenterID=CostCenterID from inv_docdetails WITH(NOLOCK) where VoucherNo=@XML.value('(XML/@No)[1]','NVARCHAR(MAX)')
					
					
					select @CompanyGUID=CompanyGUID,@DocGUID=GUID from com_Docid WITH(NOLOCK) where id=@DocID
											 
					
				if @Status=1
					set @STATUSID=369
				else
					set @STATUSID=372
				
				exec [spDOC_SetStatus]	@STATUSID=@STATUSID,@REMARKS=@Remarks,@DATE=@AppRejDate,@ISINVENTORY=@isInv,@DOCID=@DocID,
				@COSTCENTERID=@CostCenterID,@WId=0,@isFromDOc=0,@InvDocidS=@DocInfo,@CompanyGUID=@CompanyGUID,@UserName=@UserName,@DocGUID=@DocGUID,
				@UserID=@UserID,@ROLEID=@RoleID,@LangID=@LangID   
				
				--select * from inv_docdetails where DocID=@DocID

				set @i=@i+1
			end
			--select * from com_approvals
		end
	end	   
	
COMMIT TRANSACTION
--rollback TRANSACTION

SET NOCOUNT OFF;       
RETURN @RETVALUE
END TRY
BEGIN CATCH      
 --Return exception info [Message,Number,ProcedureName,LineNumber]      
BEGIN TRY
ROLLBACK TRANSACTION
 IF ERROR_NUMBER()=50000    
 BEGIN    
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
 END    
 ELSE    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine    
 FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID    
 END
END TRY    
BEGIN CATCH
END CATCH

SET NOCOUNT OFF      
RETURN -999       
END CATCH
GO
