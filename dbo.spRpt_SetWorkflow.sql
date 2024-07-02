USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRpt_SetWorkflow]
	@CCID [int],
	@QtnCCID [int],
	@DocID [bigint],
	@AppDate [datetime],
	@Remarks [nvarchar](50),
	@Mode [int],
	@WorkFlowLevel [int],
	@WID [int],
	@QtnIDs [nvarchar](max),
	@CompanyGUID [nvarchar](max),
	@UserID [int] = 0,
	@RoleID [bigint] = 0,
	@UserName [nvarchar](50),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY   
SET NOCOUNT ON 
		
		declare @maxLevel int,@sql NVARCHAR(max),@i int,@QtnDocID BIGINT,@STATUSID int,@retVal int
		
		if(@Mode=1)
			set @STATUSID=369
		else if(@Mode=2)
			set @STATUSID=372
		else if(@Mode=3)
			set @STATUSID=369
		else if(@Mode=4)
			set @STATUSID=369
		else if(@Mode=5)
			set @STATUSID=376
		else if(@Mode=6)
			set @STATUSID=376
								
		
		declare @table table(id int identity(1,1),DocID BIGINT,CCID int)  
		
		if(@Mode in(1,2,3))
		BEGIN
			insert into @table(DocID)
			exec SPSplitString @QtnIDs,',' 
			set @i=0
			select @maxLevel=Count(id) from @table
			while(@I<@maxLevel)
			BEGIN
				set @I=@I+1
				select @QtnDocID=DocID from @table where id=@I
				
				if exists(select statusid from INV_DocDetails WITH(NOLOCK) where Docid=@QtnDocID and statusid<>376 
					and (statusid not in (441,372) or WorkFlowLevel<>@WorkFlowLevel))
				BEGIN	
					exec [spDOC_SetStatus]	@STATUSID=@StatusID,@REMARKS=@Remarks,@DATE=@AppDate,@ISINVENTORY=1,@DOCID=@QtnDocID,
						@COSTCENTERID=@QtnCCID,@WId=@WID,@isFromDOc=0,@InvDocidS='',@CompanyGUID=@CompanyGUID,@UserName=@UserName,@DocGUID='',
						@UserID=@UserID,@ROLEID=@RoleID,@LangID=@LangID 
				END		
			END	
		END
		
		if(@Mode in(3,4))
		BEGIN	
			select @maxLevel=max(LevelID) from COM_WorkFlow WITH(NOLOCK) where WorkFlowID=@WID
			if(@WorkFlowLevel=1)
			BEGIN
				set @sql='if exists(select statusid from INV_DocDetails WITH(NOLOCK) where Docid in('+@QtnIDs+') and statusid not in (376,372)
				and (statusid not in(441,371) or WorkFlowLevel<>'+convert(nvarchar,@WorkFlowLevel)+')) RAISERROR(''-575'',16,1) 
				if not exists(select statusid from INV_DocDetails WITH(NOLOCK) where Docid in('+@QtnIDs+') and statusid =371 and 
				WorkFlowLevel='+convert(nvarchar,@WorkFlowLevel)+') RAISERROR(''-575'',16,1) '
				
				exec(@sql)
				set @STATUSID=371
			END	
			else if(@maxLevel is not null and @maxLevel>@WorkFlowLevel)
			BEGIN
				set @sql='if exists(select statusid from INV_DocDetails WITH(NOLOCK) where Docid in('+@QtnIDs+') and statusid not in (376,372)
				and (statusid <>441 or WorkFlowLevel<>'+convert(nvarchar,@WorkFlowLevel)+')) RAISERROR(''-575'',16,1) 
				if not exists(select statusid from INV_DocDetails WITH(NOLOCK) where Docid in('+@QtnIDs+') and statusid =441 and 
				WorkFlowLevel='+convert(nvarchar,@WorkFlowLevel)+') RAISERROR(''-575'',16,1) '
				exec(@sql)
				set @STATUSID=441
			END
			else
			BEGIN
				set @STATUSID=369
				set @sql='if exists(select statusid from INV_DocDetails WITH(NOLOCK) where Docid in('+@QtnIDs+') and statusid not in (376,372)
				and (statusid <>441 or WorkFlowLevel<>'+convert(nvarchar,@WorkFlowLevel)+')) RAISERROR(''-575'',16,1)  
				if not exists(select statusid from INV_DocDetails WITH(NOLOCK) where Docid in('+@QtnIDs+') and statusid =441 and 
				WorkFlowLevel='+convert(nvarchar,@WorkFlowLevel)+') RAISERROR(''-575'',16,1) 
				
				update [INV_DocDetails]
				set statusid=369					
				where WorkFlowLevel='+convert(nvarchar,@WorkFlowLevel)+' and statusid=441 
				and Docid in('+@QtnIDs+')'
				exec(@sql)
			END
		END

		if(@Mode in(1,2,3,4))
		BEGIN		
			insert into com_approvals(CCID,CCNODEID,Date,Remarks,StatusID,UserID,GUID,CreatedBy,CreatedDate,WorkFlowLevel,RowType,DocDetID)
			Values(@CCID,@DocID,convert(float,@AppDate),@Remarks,@StatusID,@UserID,newid(),@UserName,convert(float,getdate()),@WorkFlowLevel,0,0)
		 END
		 ELSE
		 BEGIN
		 
			delete from com_approvals
			where CCID=@CCID and CCNODEID=@DocID
			
			insert into @table(DocID)
			exec SPSplitString @QtnIDs,',' 
			
			update @table
			set CCID=@QtnCCID
			
			if(@Mode=6)
			BEGIN
				DECLARE @TotI INT,@TotCNT INT
				DECLARE @Tbl AS TABLE(ID INT NOT NULL IDENTITY(1,1), DetailsID BIGINT,CostCenterID int,DOCID BIGINT)
		 
				INSERT INTO @Tbl(DetailsID,CostCenterID,DOCID)
				SELECT InvDocDetailsID,CostCenterID,inv.docid
				FROM INV_DocDetails INV with(nolock) 
				join @table t on inv.docid=t.DocID
				where inv.costcenterid=@QtnCCID
				
				set @TotI=0
				WHILE(1=1)
				BEGIN
					SET @TotCNT=(SELECT Count(*) FROM @Tbl)
					
					
					INSERT INTO @Tbl(DetailsID,CostCenterID,DOCID)
					SELECT Link.InvDocDetailsID,Link.CostCenterID,Link.DOCID
					FROM INV_DocDetails INV with(nolock) 
					join INV_DocDetails Link on INV.LINKEDInvDocDetailsID=Link.InvDocDetailsID
					INNER JOIN @Tbl T ON INV.InvDocDetailsID=T.DetailsID AND ID>@TotI
					where INV.LINKEDInvDocDetailsID is not null and INV.LINKEDInvDocDetailsID>0
					
					IF @TotCNT=(SELECT Count(*) FROM @Tbl)
						BREAK
					SET @TotI=@TotCNT
				END
				
				delete from @table
				
				set @i=0
				select @maxLevel=Count(id) from @Tbl
				while(@I<@maxLevel)
				BEGIN
					set @I=@I+1
					select @QtnDocID=DOCID,@QtnCCID=CostCenterID from @Tbl where id=@I
					if exists(select * from @table where DocID=@QtnDocID)
						continue;
						
					insert into @table(DocID)values(@QtnDocID)
					
					EXEC @retVal=spDOC_SuspendInvDocument        
					 @CostCenterID = @QtnCCID, 
					 @DocID=@QtnDocID,
					 @DocPrefix = '',  
					 @DocNumber = '', 
					 @Remarks=@Remarks, 
					 @UserID = @UserID,  
					 @UserName = @UserName, 
					 @RoleID=@RoleID, 
					 @LangID = @LangID  
					 
					 if(@retVal=-999)
					 BEGIN
						 ROLLBACK TRANSACTION    
						 SET NOCOUNT OFF      
						 RETURN -999 
					 END
				END				
				
			END
			ELSE
			BEGIN
				set @i=0
				select @maxLevel=Count(id) from @table
				while(@I<@maxLevel)
				BEGIN
					set @I=@I+1
					select @QtnDocID=DocID,@QtnCCID=CCID from @table where id=@I
					
					EXEC @retVal=spDOC_SuspendInvDocument        
					 @CostCenterID = @QtnCCID, 
					 @DocID=@QtnDocID,
					 @DocPrefix = '',  
					 @DocNumber = '', 
					 @Remarks=@Remarks, 
					 @UserID = @UserID,  
					 @UserName = @UserName, 
					 @RoleID=@RoleID, 
					 @LangID = @LangID  
					 
					 if(@retVal=-999)
					 BEGIN
						 ROLLBACK TRANSACTION    
						 SET NOCOUNT OFF      
						 RETURN -999 
					 END
				END
			END	
		 END
		
		
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID  
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
