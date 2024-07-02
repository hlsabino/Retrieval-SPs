USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_SetAccountQuick]
	@AccountID [int],
	@AccountCode [nvarchar](200),
	@AccountName [nvarchar](500),
	@AccountTypeID [int],
	@IsGroup [bit],
	@StatusID [int],
	@CodePrefix [nvarchar](200),
	@CodeNumber [int],
	@StaticFieldsQuery [nvarchar](max),
	@CustomFieldsQuery [nvarchar](max),
	@CustomCostCenterFieldsQuery [nvarchar](max),
	@AssignCCCCData [nvarchar](max) = null,
	@AddressXML [nvarchar](max) = null,
	@HistoryXML [nvarchar](max) = null,
	@StatusXML [nvarchar](max) = null,
	@CompanyGUID [varchar](50),
	@GUID [varchar](50),
	@Description [nvarchar](500),
	@UserName [nvarchar](50),
	@WID [int] = 0,
	@RoleID [int] = 0,
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  
  --Declaration Section  
  DECLARE @Dt float,@TempGuid nvarchar(50),@HasAccess bit,@XML XML
  DECLARE @IsDuplicateNameAllowed bit,@IsDuplicateCodeAllowed BIT,@IsIgnoreSpace bit  
    declare @isparentcode bit,@HistoryStatus NVARCHAR(300),@AccountTypeAllowDuplicate NVARCHAR(300),@AccountTypeChar NVARCHAR(5)
  
  set @AccountName=ltrim(@AccountName)
  if(@AccountID=0)
	set @HistoryStatus='Add'
  else
	set @HistoryStatus='Update'
		
  --User acces check FOR ACCOUNTS  
  IF @AccountID=0  
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,2,1)  
  END  
  ELSE  
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,2,3)  
  END  
  
  IF @HasAccess=0  
  BEGIN  
   RAISERROR('-105',16,1)  
  END  

  
  IF EXISTS(SELECT StatusID FROM dbo.COM_Status with(nolock) WHERE CostCenterID=2 AND Status='Active' AND StatusID=@StatusID) 
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,2,23)  
   IF @HasAccess=0  
   BEGIN  
    RAISERROR('-111',16,1)  
   END  
  END  
  
  IF EXISTS(SELECT StatusID FROM dbo.COM_Status with(nolock) WHERE CostCenterID=2 AND Status='In Active' AND StatusID=@StatusID)
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,2,24)  
   IF @HasAccess=0  
   BEGIN  
    RAISERROR('-113',16,1)  
   END  
  END  
  
  IF not exists(SELECT  FeatureTypeID FROM ADM_FeatureTypeValues with(nolock) where FeatureTypeID= @AccountTypeID 
  and FeatureID=2 and (userid =@UserID or roleid=@RoleID))
  BEGIN     
    RAISERROR('-357',16,1)  
  END
  
	--GETTING PREFERENCE  
	IF @IsGroup=0
    BEGIN
		SELECT @IsDuplicateCodeAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=2 and  Name='DuplicateCodeAllowed'  
		SELECT @IsDuplicateNameAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=2 and  Name='DuplicateNameAllowed'
	END
	ELSE
	BEGIN
		SELECT @IsDuplicateCodeAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=2 and  Name='DuplicateGroupCodeAllowed'  
		SELECT @IsDuplicateNameAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=2 and  Name='DuplicateGroupNameAllowed'
	END
	SELECT @IsIgnoreSpace=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=2 and  Name='IgnoreSpaces'  
	select @isparentcode=IsParentCodeInherited  from COM_CostCenterCodeDef with(nolock) where CostCenterID=2
	SELECT @AccountTypeAllowDuplicate=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=2 and  Name='AccountTypeAllowDuplicate'

	--If Duplicate code allowed then check for AccountType
	SET @AccountTypeChar='~'+CONVERT(nvarchar,@AccountTypeID)+'~'
  
   --DUPLICATE CODE CHECK  
	if(@isparentcode=0)
	BEGIN 
		IF @IsDuplicateCodeAllowed=0 OR charindex(@AccountTypeChar,@AccountTypeAllowDuplicate,1)=0
		BEGIN
			IF @AccountID=0  
			BEGIN  
				IF EXISTS (SELECT AccountID FROM ACC_Accounts WITH(nolock) WHERE IsGroup=@IsGroup and  [AccountCode]=@AccountCode)  
					RAISERROR('-116',16,1)  
			END  
			ELSE  
			BEGIN  
				IF EXISTS (SELECT AccountID FROM ACC_Accounts WITH(nolock) WHERE IsGroup=@IsGroup and [AccountCode]=@AccountCode AND AccountID <> @AccountID)  
					RAISERROR('-116',16,1)  
			END
		END		
	END
	ELSE
	BEGIN
  		IF @IsDuplicateCodeAllowed=0 OR charindex(@AccountTypeChar,@AccountTypeAllowDuplicate,1)=0
		BEGIN
			IF @AccountID=0  
			BEGIN  
				IF EXISTS (SELECT AccountID FROM ACC_Accounts WITH(nolock) WHERE IsGroup=@IsGroup AND AccountCode=@AccountCode)--  or (CodePrefix=@CodePrefix and CodeNumber=@CodeNumber)
					RAISERROR('-116',16,1)  
			END  
			ELSE  
			BEGIN  
				IF EXISTS (SELECT AccountID FROM ACC_Accounts WITH(nolock) WHERE IsGroup=@IsGroup AND AccountID <> @AccountID and ([AccountCode]=@AccountCode) )-- or (CodePrefix=@CodePrefix and CodeNumber=@CodeNumber)
					RAISERROR('-116',16,1)  
			END  
		END
	END

  
	--DUPLICATE CHECK  
	IF @IsDuplicateNameAllowed=0 OR charindex(@AccountTypeChar,@AccountTypeAllowDuplicate,1)=0
	BEGIN  
		IF @IsIgnoreSpace IS NOT NULL AND @IsIgnoreSpace=1  
		BEGIN  
			IF @AccountID=0  
			BEGIN  
				IF EXISTS (SELECT AccountID FROM ACC_Accounts WITH(nolock) WHERE IsGroup=@IsGroup AND replace(AccountName,' ','')=replace(@AccountName,' ',''))  
					RAISERROR('-108',16,1)  
			END  
			ELSE  
			BEGIN  
				IF EXISTS (SELECT AccountID FROM ACC_Accounts WITH(nolock) WHERE IsGroup=@IsGroup AND replace(AccountName,' ','')=replace(@AccountName,' ','') AND AccountID <> @AccountID)  
					RAISERROR('-108',16,1)       
			END  
		END  
	    ELSE  
	    BEGIN  
			IF @AccountID=0  
			BEGIN  
				IF EXISTS (SELECT AccountID FROM ACC_Accounts WITH(nolock) WHERE IsGroup=@IsGroup AND AccountName=@AccountName)  
					RAISERROR('-108',16,1)  
			END  
			ELSE  
			BEGIN  
				IF EXISTS (SELECT AccountID FROM ACC_Accounts WITH(nolock) WHERE IsGroup=@IsGroup AND AccountName=@AccountName AND AccountID <> @AccountID)  
					RAISERROR('-108',16,1)  
			END  
	   END
	END  
	
  
  
  SET @Dt=convert(float,getdate())--Setting Current Date  
  
	
   SELECT @TempGuid=[GUID] from [ACC_Accounts]  WITH(NOLOCK)   
   WHERE AccountID=@AccountID  
  
   IF(@TempGuid!=@Guid)--IF RECORD ALREADY UPDATED BY SOME OTHER USER i.e DIRTY READ    
   BEGIN    
       RAISERROR('-101',16,1)   
   END
   
	DECLARE @SQL NVARCHAR(MAX)
   	--Update Main Table
	IF(@StaticFieldsQuery IS NOT NULL AND @StaticFieldsQuery <> '')
	BEGIN
		set @SQL='update ACC_Accounts
		SET '+@StaticFieldsQuery+'[GUID]= NEWID(), [ModifiedBy] ='''+ @UserName
		  +''',[ModifiedDate] =' + convert(NVARCHAR,@Dt) +' WHERE AccountID='+convert(NVARCHAR,@AccountID)
		exec(@SQL)		
	END
	ELSE
	BEGIN
		set @SQL='update ACC_Accounts
		SET [GUID]= NEWID(), [ModifiedBy] ='''+ @UserName
		  +''',[ModifiedDate] =' + convert(NVARCHAR,@Dt) +' WHERE AccountID='+convert(NVARCHAR,@AccountID)
		exec(@SQL)
	END
	
	if exists(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]='IsControlAccounts' and [Value]='True')
		and exists (select AccountTypeID from ACC_Accounts with(nolock) where AccountID=@AccountID and AccountTypeID in (6,7) and IsBillwise=0)
		and exists (select AccountID from COM_BillWise with(nolock) where AccountID=@AccountID)
		and dbo.fnCOM_HasAccess(@RoleID,2,182)=0
	begin
		RAISERROR('-223',16,1)
	end
	
	--Update Extended
	IF(@CustomFieldsQuery IS NOT NULL AND @CustomFieldsQuery <> '')
	BEGIN
		set @SQL='update ACC_AccountsExtended
		SET '+@CustomFieldsQuery+' [ModifiedBy] ='''+ @UserName
		  +''',[ModifiedDate] =@ModDate WHERE AccountID='+convert(NVARCHAR,@AccountID)
		EXEC sp_executesql @SQL,N'@ModDate float',@Dt
	END
	
	if exists (select CostCenterColID from adm_costcenterdef with(nolock) where CostCenterID=2 and CostCenterColID=244)
	and ((select count(*) from sys.columns where object_id=object_id('ACC_AccountsExtended') and name in ('acAlpha51','acAlpha60'))=2)
	begin
		set @SQL='
		if exists (select acAlpha60 from ACC_AccountsExtended with(nolock) where AccountID=@AccountID and acAlpha60=0)
		begin
			update ACC_AccountsExtended set acAlpha60=@AccountID where AccountID=@AccountID 
		end'
		EXEC sp_executesql @SQL,N'@AccountID int',@AccountID
		set @SQL='
declare @TRN nvarchar(max),@GA INT
select @TRN=acAlpha51,@GA=acAlpha60 from ACC_AccountsExtended with(nolock) where AccountID=@AccountID
if @TRN is not null and @TRN!=''''
begin
	if len(@TRN)!=15
		RAISERROR(''Tax Registration Number - TRN/TIN length should be 15'',16,1)
	else
	begin
		begin try
			select convert(INT,@TRN)
		end try
		begin catch
			RAISERROR(''Invalid Tax Registration Number - TRN/TIN'',16,1)
		end catch
	end
	if exists (select acAlpha51 from ACC_AccountsExtended with(nolock) where acAlpha60!=@GA and acAlpha51=@TRN)
	begin
		set @TRN=''Duplicate Tax Registration Number - TRN/TIN - ''+@TRN
		RAISERROR(@TRN,16,1)
	end
	else if exists (select acAlpha51 from ACC_AccountsExtended with(nolock) where acAlpha60=@GA and acAlpha51!=@TRN)
	begin
		set @TRN=''Group Company Account has different Tax Registration Number - TRN/TIN - ''+@TRN
		RAISERROR(@TRN,16,1)
	end
end'
		EXEC sp_executesql @SQL,N'@AccountID int',@AccountID
	end


	--Update CostCenter Extra Fields
	set @SQL='update COM_CCCCDATA
	SET '+@CustomCostCenterFieldsQuery+' [ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE NodeID='+convert(nvarchar,@AccountID) + ' AND COSTCENTERID = 2 '
	exec(@SQL)
	
	--Address
	if @AddressXML is not null and @AddressXML!=''
		EXEC spCOM_SetAddress 2,@AccountID,@AddressXML,@UserName  
	
	--Duplicate Check
	exec [spCOM_CheckUniqueCostCenter] @CostCenterID=2,@NodeID =@AccountID,@LangID=@LangID
	
	--Series Check
	declare @retSeries INT
	EXEC @retSeries=spCOM_ValidateCodeSeries 2,@AccountID,@LangId
	if @retSeries>0
	begin
		ROLLBACK TRANSACTION
		SET NOCOUNT OFF  
		RETURN -999
	end
 
 
  --SETTING ACCOUNT CODE EQUALS AccountID IF EMPTY  
  IF(@AccountCode IS NULL OR @AccountCode='')  
  BEGIN  
   UPDATE  [ACC_Accounts]  
   SET [AccountCode] = @AccountID  
   WHERE AccountID=@AccountID        
  END  
  
	--CHECK WORKFLOW
	EXEC spCOM_CheckCostCentetWF 2,@AccountID,@WID,@RoleID,@UserID,@UserName,@StatusID output

	--Dimension History Data
	IF (@HistoryXML IS NOT NULL AND @HistoryXML <> '')    
		EXEC spCOM_SetHistory 2,@AccountID,@HistoryXML,@UserName  
	
	IF (@StatusXML IS NOT NULL AND @StatusXML <> '')
		exec spCOM_SetStatusMap 2,@AccountID,@StatusXML,@UserName,@Dt
			
   --Creating Dimension based on Preference 'AccountTypeLinkDimension'
     
      declare @CC nvarchar(max), @CCID nvarchar(10)
	  SELECT @CC=[Value] FROM com_costcenterpreferences with(nolock) WHERE [Name]='AccountTypeLinkDimension'
	  if (@CC is not null and @CC<>'')
	  begin
			DECLARE @TblCC AS TABLE(ID INT IDENTITY(1,1),CC nvarchar(100))
			DECLARE @TblCCVal AS TABLE(ID INT IDENTITY(1,1),CC2 nvarchar(100))
			--SELECT @CC   
			INSERT INTO @TblCC(CC)
			EXEC SPSplitString @CC,','
			declare @i int,@cnt int
			declare @value nvarchar(max)
			set @i=1
			select @cnt=count(*) from @TblCC
			while @i<=@cnt
			begin
				select @value=cc from @TblCC where id=@i
				--select @value
				insert into @TblCCVal (CC2)
				EXEC SPSplitString @value,'~'
				 --select cc2 from @TblCCVal
				if exists (select cc2 from @TblCCVal where cc2 =@AccountTypeID )
				begin
					select @CCID=cc2 from @TblCCVal where cc2>50000   
					--select @CCID
					if(@CCID>50000)
					begin
						declare @CCStatusID INT
						set @CCStatusID = (select top 1 statusid from com_status with(nolock) where costcenterid=@CCID)
			 			declare @NID INT, @CCIDAcc INT
						select @NID = CCNodeID, @CCIDAcc=CCID  from acc_Accounts with(nolock) where Accountid=@AccountID
						iF(@CCIDAcc<>@CCID)
						BEGIN
							if(@NID>0)
							begin 
							Update Acc_accounts set CCID=0, CCNodeID=0 where AccountID=@AccountID
							DECLARE @RET INT
								EXEC	@RET = [dbo].[spCOM_DeleteCostCenter]
									@CostCenterID = @CCIDAcc,
									@NodeID = @NID,
									@RoleID=1,
									@UserID = 1,
									@LangID = @LangID
							end	
							set @NID=0
							set @CCIDAcc=0 
						END
					 	declare @return_value int
						if(@NID is null or @NID =0)
						begin
							
							EXEC	@return_value = [dbo].[spCOM_SetCostCenter]
							@NodeID = 0,@SelectedNodeID = 1,@IsGroup = 0,
							@Code = @AccountCode,
							@Name = @AccountName,
							@AliasName=@AccountName,
							@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
							@CustomFieldsQuery=NULL,@AddressXML='',@AttachmentsXML=NULL,
							@CustomCostCenterFieldsQuery=NULL,@ContactsXML='',@NotesXML=NULL,
							@CostCenterID = @CCID,@CompanyGUID=@COMPANYGUID,@GUID='',@UserName='admin',@RoleID=1,@UserID=1 , @CheckLink = 0
							-- Link Dimension Mapping
							INSERT INTO COM_DocBridge (CostCenterID, NodeID,InvDocID, AccDocID, RefDimensionID  , RefDimensionNodeID ,  CompanyGUID, guid, Createdby, CreatedDate,Abbreviation)
							values(2, @AccountID,0,0,@CCID,@return_value,'',newid(),@UserName, @dt,'Account')
							DECLARE @CCMapSql nvarchar(max)
							set @CCMapSql='update COM_CCCCDATA  
							SET CCNID'+convert(nvarchar,(@CCID-50000))+'='+CONVERT(NVARCHAR,@return_value)+'  WHERE NodeID = '+convert(nvarchar,@AccountID) + ' AND CostCenterID = 2' 
							EXEC (@CCMapSql)	
						end
						else
						begin
							declare @Gid nvarchar(50) , @Table nvarchar(100), @CGid nvarchar(50)
							declare @NodeidXML nvarchar(max) 
							select @Table=Tablename from adm_features where featureid=@CCID
							declare @str nvarchar(max) 
							set @str='@Gid nvarchar(50) output' 
							set @NodeidXML='set @Gid= (select GUID from '+@Table+' with(nolock) where NodeID='+convert(nvarchar,@NID)+')'
								exec sp_executesql @NodeidXML, @str, @Gid OUTPUT 
								
							EXEC @return_value = [dbo].[spCOM_SetCostCenter]
								@NodeID = @NID,@SelectedNodeID = 1,@IsGroup = 0,
								@Code = @AccountCode,
								@Name = @AccountName,
								@AliasName=@AccountName,
								@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
								@CustomFieldsQuery=NULL,@AddressXML='',@AttachmentsXML=NULL,
								@CustomCostCenterFieldsQuery=NULL,@ContactsXML='',@NotesXML=NULL,
								@CostCenterID = @CCID,@CompanyGUID=@CompanyGUID,@GUID=@Gid,@UserName='admin',@RoleID=1,@UserID=1, @CheckLink = 0
						end 
						if(@return_value>0 or @return_value<-10000)
						BEGIN
							Exec [spDOC_SetLinkDimension]
								@InvDocDetailsID=@AccountID, 
								@Costcenterid=2,         
								@DimCCID=@CCID,
								@DimNodeID=@return_value,
								@BasedOnValue=@AccountTypeID,
								@UserID=@UserID,    
								@LangID=@LangID 
						END
						Update Acc_accounts set CCID=@CCID, CCNodeID=@return_value where AccountID=@AccountID
					
					end
				end
				delete from @TblCCVal
				set @i=@i+1
			end 
	end
 
	--CC CC MAP
	IF (@AssignCCCCData IS NOT NULL AND @AssignCCCCData <> '') 
	BEGIN
		DECLARE @Action NVARCHAR(100)
		DECLARE @CCCCCData xml
		SET @CCCCCData=@AssignCCCCData
	    declare @Val bit,   @NodeID INT,@DATA xml,@DefCCID INT
		set @DATA=@CCCCCData   

		EXEC [spCOM_SetCCCCMap] 2,@AccountID,@CCCCCData,@UserName,@LangID 

	    if(@IsGroup=1 and not exists(select Name from com_costcenterpreferences with(nolock) where CostCenterID=2 and Name='DontAssignGroupToNodes' and Value='True'))
		begin
			declare @count int, @a int
			create table #temp (id int identity(1,1), Accountid INT )
			insert into #temp
			select AccountID from acc_accounts with(nolock) where lft between (select lft from acc_accounts with(nolock) where accountid=@AccountID) 
			and (select rgt from acc_accounts with(nolock) where accountid=@AccountID) and accountid<>@AccountID order by lft
			select @count=count(*) from #temp with(nolock)
			set @a=1
			while @a<=@count
			begin
				declare @acc INT 
				select @acc=Accountid from #temp with(nolock) where id=@a 
				
				if(@Val =1)
				begin
					set @NodeID=@acc
					IF exists (select @DATA from @DATA.nodes('/ASSIGNMAPXML') as DATA(A) )
					BEGIN 
						select @DefCCID=A.value('@Dimension','INT'),@Action=A.value('@Action','NVARCHAR(30)') from @DATA.nodes('/ASSIGNMAPXML') as DATA(A)
						IF @Action='ASSIGN' OR @Action='ASSIGN/MAP'
							if exists ( select voucherno from Inv_DocDetails d with(nolock)
							join com_docccdata cc with(nolock) on d.InvDocDetailsID=cc.InvDocDetailsID
							where (debitaccount =@NodeID or CreditAccount=@NodeID) and cc.dcCCNID2 in  
							(Select cc.NodeID    from COM_CostCenterCostCenterMap cc with(nolock)
							left join @DATA.nodes('/ASSIGNMAPXML/ASSIGN/R') as DATA(A)  on  ParentCostCenterID=2 AND ParentNodeID=@NodeID 
							and costcenterid=A.value('@CCID','INT') and NodeID=A.value('@ID','INT')
							where cc.ParentCostCenterID=2 AND cc.ParentNodeID=@NodeID and cc.CostCenterID=50002 
							and A.value('@ID','INT') is null))
							or exists  (select voucherno from ACC_DocDetails d with(nolock)
							join com_docccdata cc with(nolock) on d.AccDocDetailsID=cc.AccDocDetailsID
							where (debitaccount =@NodeID or CreditAccount=@NodeID) and cc.dcCCNID2 in  
							(Select cc.NodeID    from COM_CostCenterCostCenterMap cc with(nolock)
							left join @DATA.nodes('/ASSIGNMAPXML/ASSIGN/R') as DATA(A)  on  ParentCostCenterID=2 AND ParentNodeID=@NodeID 
							and costcenterid=A.value('@CCID','INT') and NodeID=A.value('@ID','INT')
							where cc.ParentCostCenterID=2 AND cc.ParentNodeID=@NodeID and cc.CostCenterID=50002 and A.value('@ID','INT') is null))
								RAISERROR('-110',16,1)  
					END
					ELSE
					BEGIN
						--IF DATA EXISTS @ DOCUMENTS THE RAISE ERROR 
						if exists ( select voucherno from Inv_DocDetails d with(nolock)
						join com_docccdata cc with(nolock) on d.InvDocDetailsID=cc.InvDocDetailsID
						where (debitaccount =@NodeID or CreditAccount=@NodeID) and cc.dcCCNID2 in  
						(Select cc.NodeID    from COM_CostCenterCostCenterMap cc with(nolock)
						left join @DATA.nodes('/XML/Row') as DATA(A)  on  ParentCostCenterID=2 AND ParentNodeID=@NodeID 
						and costcenterid=A.value('@CostCenterId','INT') and NodeID=A.value('@NodeID','INT')
						where cc.ParentCostCenterID=2 AND cc.ParentNodeID=@NodeID and cc.CostCenterID=50002 
						and A.value('@NodeID','INT') is null))
						or exists  (select voucherno from ACC_DocDetails d with(nolock)
						join com_docccdata cc with(nolock) on d.AccDocDetailsID=cc.AccDocDetailsID
						where (debitaccount =@NodeID or CreditAccount=@NodeID) and cc.dcCCNID2 in  
						(Select cc.NodeID    from COM_CostCenterCostCenterMap cc with(nolock)
						left join @DATA.nodes('/XML/Row') as DATA(A)  on  ParentCostCenterID=2 AND ParentNodeID=@NodeID 
						and costcenterid=A.value('@CostCenterId','INT') and NodeID=A.value('@NodeID','INT')
						where cc.ParentCostCenterID=2 AND cc.ParentNodeID=@NodeID and cc.CostCenterID=50002 and A.value('@NodeID','INT') is null))
							RAISERROR('-110',16,1)
					END
				end	 
				
				EXEC [spCOM_SetCCCCMap] 2,@acc,@CCCCCData,@UserName,@LangID  
				set @a=@a+1
			end
			drop table #temp 
	   end
	END
	
	 --validate Data External function
	DECLARE @tempCode NVARCHAR(200)
	set @tempCode=''
	select @tempCode=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=2 and Mode=9
	if(@tempCode<>'')
	begin
		exec @tempCode 2,@AccountID,@UserID,@LangID
	end
	
	--Insert Notifications
	EXEC spCOM_SetNotifEvent 3,2,@AccountID,@CompanyGUID,@UserName,@UserID,-1
	
	--INSERT INTO HISTROY   
	EXEC [spCOM_SaveHistory]  
		@CostCenterID =2,    
		@NodeID =@AccountID,
		@HistoryStatus =@HistoryStatus,
		@UserName=@UserName,
		@DT=@DT
		
COMMIT TRANSACTION
--ROLLBACK TRANSACTION

SELECT * FROM [ACC_Accounts] WITH(nolock) WHERE AccountID=@AccountID  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;    
RETURN @AccountID    
END TRY    
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
 IF ERROR_NUMBER()=50000  
 BEGIN  
	IF ISNUMERIC(ERROR_MESSAGE())=1
	BEGIN
		SELECT * FROM [ACC_Accounts] WITH(nolock) WHERE AccountID=@AccountID    
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
	END
	ELSE
		SELECT ERROR_MESSAGE() ErrorMessage
 END  
 ELSE IF ERROR_NUMBER()=547  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)  
  WHERE ErrorNumber=-110 AND LanguageID=@LangID  
 END  
 ELSE IF ERROR_NUMBER()=2627  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)  
  WHERE ErrorNumber=-116 AND LanguageID=@LangID  
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
