USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_ConvertCCToAccount]
	@CCNodeID [int] = 0,
	@code [nvarchar](max),
	@Name [nvarchar](max),
	@iVendorMax [int],
	@ContactsXML [nvarchar](max),
	@AddressXML [nvarchar](max),
	@AttachmentsXML [nvarchar](max),
	@NotesXML [nvarchar](max),
	@URoleID [nvarchar](max),
	@CompanyIndex [int],
	@CompanyGUID [nvarchar](100),
	@UserName [nvarchar](100),
	@UserID [int],
	@roleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY 
SET NOCOUNT ON		

	DECLARE @Dt float,@XML xml,@SSQL NVARCHAR(MAX),@UID INT,@URID INT,@CMPYID INT,@UCMPYID INT,@Return INT
	DECLARE @lft INT,@rgt INT,@Selectedlft INT,@Selectedrgt INT,@Depth int,@ParentID INT
	DECLARE @SelectedIsGroup bit ,@SelectedNodeID INT,@IsGroup BIT,@PContactID int
	DECLARE @CompanyName nvarchar(500),@AccountID INT,@ret int,@ind int
	DECLARE @COUNT INT,@I INT,@pwd NVARCHAR(MAX),@UserEmail NVARCHAR(MAX),@SQL NVARCHAR(MAX),@companyDB nvarchar(20)
	SET @Return = 1;
	SET @companyDB='PACT2C.dbo.'  

	SET @Dt=CONVERT(float,getdate())
				
				--IF EXISTS(Select column_name from information_schema.columns where table_name='COM_CC50170' and column_name='Category')
				--BEGIN
				--	IF ((SELECT count(*) from COM_CC50170 WITH(nolock) where  isnull(Category,'')<>'' AND NodeID=@CCNodeID)>0)
				--		SELECT @SelectedNodeID=Category FROM COM_CC50170 WITH(nolock) where NodeID=@CCNodeID
				--	ELSE
				--		SELECT @SelectedNodeID=isnull(VALUE,1) FROM ADM_GlobalPreferences WITH(nolock) WHERE NAME='VPAccountGroup' 
				--END
				--ELSE
				--	SELECT @SelectedNodeID=isnull(VALUE,1) FROM ADM_GlobalPreferences WITH(nolock) WHERE NAME='VPAccountGroup' 
					
				IF ((SELECT count(*) from COM_CC50170 WITH(nolock) where  isnull(Category,'')<>'' AND NodeID=@CCNodeID)>0)
					SELECT @SelectedNodeID=Category FROM COM_CC50170 WITH(nolock) where NodeID=@CCNodeID
				ELSE
					SELECT @SelectedNodeID=isnull(VALUE,1) FROM ADM_GlobalPreferences WITH(nolock) WHERE NAME='VPAccountGroup' 
				
				--To Set Left,Right And Depth of Record
				SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=isnull(ParentID,1),@Depth=isnull(Depth,1)
				from ACC_ACCOUNTS with(NOLOCK) where ACCOUNTID=@SelectedNodeID
				
				--IF No Record Selected or Record Doesn't Exist
				if(@SelectedIsGroup is null) 
					select @SelectedNodeID=ACCOUNTID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth
					from ACC_ACCOUNTS with(NOLOCK) where ParentID =0

				if(@SelectedIsGroup = 1)--Adding Node Under the Group
				BEGIN
					UPDATE ACC_ACCOUNTS SET rgt = rgt + 2 WHERE rgt > @Selectedlft;
					UPDATE ACC_ACCOUNTS SET lft = lft + 2 WHERE lft > @Selectedlft;
					set @lft =  @Selectedlft + 1
					set @rgt = @Selectedlft + 2
					set @ParentID = @SelectedNodeID
					set @Depth = @Depth + 1
				END
				else if(@SelectedIsGroup = 0)--Adding Node at Same level
				BEGIN
					UPDATE ACC_ACCOUNTS SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;
					UPDATE ACC_ACCOUNTS SET lft = lft + 2 WHERE lft > @Selectedrgt;
					set @lft =  @Selectedrgt + 1
					set @rgt = @Selectedrgt + 2 
				END
				else  --Adding Root
				BEGIN
					set @lft =  1
					set @rgt = 2 
					set @Depth = 0
					set @ParentID =0
					set @IsGroup=1
				END
				
				SET @IsGroup=0

				INSERT INTO ACC_ACCOUNTS (AccountCode,AccountName,AccountTypeID,StatusID,[IsBillwise],[CreditDays],[CreditLimit],  [DebitDays],  [DebitLimit], [Depth], [ParentID],  [lft],  [rgt],  [IsGroup],[CompanyGUID],  [GUID],  [CreatedBy],  [CreatedDate])
				values(@code,@Name,6,33,1,0,0,0,0,@Depth,@ParentID,@lft,@rgt,0,@CompanyGUID,newid(),@UserName,@Dt) 
				
				set @AccountID=@@identity
			 
				IF(@AccountID IS NOT NULL)
				BEGIN					
					insert into COM_DocBridge(AccDocID,InvDocID,CostCenterID,NodeID,[CompanyGUID],  [GUID],  [CreatedBy],  [CreatedDate],RefDimensionID,RefDimensionNodeID)
					values(0,0,50170,@CCNodeID,@CompanyGUID,newid(),@UserName,@Dt,2,@AccountID)
					--Handling of Extended Table  
					INSERT INTO [ACC_AccountsExtended]([AccountID],[CreatedBy],[CreatedDate])  
					VALUES(@AccountID, @UserName, @Dt)  					
					
					INSERT INTO COM_CCCCData(CostCenterID,NodeID,GUID,CreatedBy,CreatedDate)
					values(2,@AccountID,newid(),@UserName, @Dt)
					
					Exec @ret=[spDOC_SetLinkDimension]
							@InvDocDetailsID=@CCNodeID, 
							@Costcenterid=50170,         
							@DimCCID=2,
							@DimNodeID=@AccountID,
							@UserID=@UserID,    
							@LangID=@LangID  
						
						set @SQL='select @UserEmail=UserNameAlpha,@pwd=PasswordAlpha From COM_CC50170 WITH(NOLOCK) WHERE NodeID='+convert(nvarchar(max),@CCNodeID)
						exec sp_executesql @SQL,N'@UserEmail nvarchar(max) OUTPUT,@pwd nvarchar(max) OUTPUT',@UserEmail OUTPUT,@pwd OUTPUT
						
					
						INSERT  [COM_Contacts]([AddressTypeID],[FeatureID],[FeaturePK],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate],Email1,FirstName,RoleLookUpID)  
								VALUES(1,2,@AccountID,NEWID(),NEWID(),@UserName,@Dt,@UserEmail,@pwd,Convert(Int,@URoleID))  
								
								SET @PContactID=SCOPE_IDENTITY()
								INSERT INTO COM_ContactsExtended(ContactID,[CreatedBy],[CreatedDate])
 								VALUES(@PContactID, @UserName, @Dt)
 						
 						 --
 						 --Insert Multiple Contacts  
						  IF (@ContactsXML IS NOT NULL AND @ContactsXML <> '')  
						  BEGIN  
								--CHANGES MADE IN PRIMARY CONTACT QUERY BY HAFEEZ ON DEC 20 2013,BECOZ CONTACT QUICK ADD SCREEN IS CUSTOMIZABLE  
								 declare @rValue int
								EXEC @rValue =  spCOM_SetFeatureWiseContacts 2,@AccountID,2,@ContactsXML,@UserName,@Dt,@LangID  
								 IF @rValue=-1000  
								  BEGIN  
									RAISERROR('-500',16,1)  
								  END   
						  END  
						  	
						  --Insert Multiple Addresses  
						  EXEC spCOM_SetAddress 2,@AccountID,@AddressXML,@UserName  
						  
						  --Insert Multiple Notes  
						  IF (@NotesXML IS NOT NULL AND @NotesXML <> '')  
						  BEGIN  
						   SET @XML=@NotesXML  
						  
						   --If Action is NEW then insert new Notes  
						   INSERT INTO COM_Notes(FeatureID,CostCenterID,FeaturePK,Note,     
						   GUID,CreatedBy,CreatedDate)  
						   SELECT 2,2,@AccountID,Replace(X.value('@Note','NVARCHAR(MAX)'),'@~',''),  
						   newid(),@UserName,@Dt  
						   FROM @XML.nodes('/NotesXML/Row') as Data(X)  
						   WHERE X.value('@Action','NVARCHAR(10)')='NEW'  
						  
						   --If Action is MODIFY then update Notes  
						   UPDATE COM_Notes  
						   SET Note=Replace(X.value('@Note','NVARCHAR(MAX)'),'@~',''),     
							GUID=newid(),  
							ModifiedBy=@UserName,  
							ModifiedDate=@Dt  
						   FROM COM_Notes C   
						   INNER JOIN @XML.nodes('/NotesXML/Row') as Data(X)    
						   ON convert(INT,X.value('@NoteID','INT'))=C.NoteID  
						   WHERE X.value('@Action','NVARCHAR(10)')='MODIFY'  
						  
						   --If Action is DELETE then delete Notes  
						   DELETE FROM COM_Notes  
						   WHERE NoteID IN(SELECT X.value('@NoteID','INT')  
							FROM @XML.nodes('/NotesXML/Row') as Data(X)  
							WHERE X.value('@Action','NVARCHAR(10)')='DELETE')  
						  
						  END  
						  
						  --Insert Attachments 
						   IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')  
							exec [spCOM_SetAttachments] @AccountID,2,@AttachmentsXML,@UserName,@Dt
 						  --
						
						select @ParentID=StatusID from COM_Status WITH(NOLOCK) where Status='Converted'
						set @SQL='update COM_CC50170 set StatusID='+convert(nvarchar(max),@ParentID)+' where NodeID='+convert(nvarchar(max),@CCNodeID)
						exec(@SQL)
						PRINT'P'
						PRINT @PContactID
					if (select count(*) from (
							select U.UserID from adm_Proles R with(nolock)
							join ADM_UserRoleMap UR WITH(NOLOCK) on UR.RoleID=R.RoleID
							join ADM_Users U with(nolock) on U.UserID=UR.UserID
							where R.StatusID=434 and R.RoleType=2 and U.StatusID!=2
							group by U.UserID) AS T)>@iVendorMax-1
							begin
							Select 'Max Vendors License('+convert(nvarchar,@iVendorMax)+') Exceeds.'
								SET @Return = 2
							end
							else 
							begin
								select @ind=replace(DB_NAME(),'PACT2C','')
								exec 	@ret=spADM_SetUserFromContact 
													 @PContactID
													 ,@iVendorMax
													 ,0
													 ,@CompanyGUID
													 ,'guid'
													 ,@UserName
													 ,@roleID
													 ,@UserID 
													 ,@LangID
													 select @ret
								if(@ret=-999)
									return @ret			 
						 
								EXEC spCOM_SetNotifEvent -1001,50170,@CCNodeID,@CompanyGUID,@UserName,@UserID,@RoleID,@ind
								SELECT @UID=USERID FROM ADM_USERS WITH(NOLOCK)  WHERE USERNAME=@UserEmail
								IF(@UID>1)
								BEGIN
									SET @sSQL='EXEC '+@companyDB+'[spADM_AssignUsersToCompany] 2,'+convert(varchar,@CompanyIndex)+',''True'','''+convert(varchar,@UID)+''' ,'+convert(varchar,@roleID) +',1'
									--print (@sSQL)
									EXEC(@sSQL)
									Declare @tabCompanyMap table(ID INT IDENTITY(1,1),UserCompanyMapID INT,CompanyID int)
									Declare @r int,@rc int
									set @r=1
									SET @UID=0
						  			SELECT @UID=USERID FROM PACT2C.dbo.ADM_USERS WITH(NOLOCK)  WHERE USERNAME=@UserEmail
									IF(@UID<>1)
									BEGIN
										SELECT @CMPYID=COMPANYID FROM PACT2C.dbo.ADM_COMPANY WITH(NOLOCK) WHERE DBINDEX =@CompanyIndex
										IF(@CMPYID>0)
										BEGIN
											INSERT INTO @tabCompanyMap SELECT UserCompanyMapID,CompanyID FROM PACT2C.dbo.ADM_UserCompanyMap WITH(NOLOCK) WHERE USERID=@UID
											Delete from @tabCompanyMap where CompanyID=@CMPYID
											select @rc=count(*) from @tabCompanyMap
											while(@r<@rc)
											begin
												SELECT  @UCMPYID=UserCompanyMapID from @tabCompanyMap where id=@r
												DELETE FROM PACT2C.dbo.ADM_UserCompanyMap WHERE UserCompanyMapID=@UCMPYID  AND USERID=@UID
											--SELECT @UCMPYID=UserCompanyMapID FROM PACT2C.dbo.ADM_UserCompanyMap WITH(NOLOCK) WHERE companyID=1 AND USERID=@UID
											--DELETE FROM PACT2C.dbo.ADM_UserCompanyMap WHERE UserCompanyMapID=@UCMPYID
											set @r=@r+1
											end
										END
									END
								END
						END	
				END
COMMIT TRANSACTION  
SET NOCOUNT OFF;   
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=103 AND LanguageID=@LangID 
RETURN @Return
END TRY  
BEGIN CATCH  
	if(@ret=-999)
		return @ret		
 IF ERROR_NUMBER()=50000
 BEGIN
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
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
