USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_SetTeam]
	@Name [nvarchar](200),
	@Data [nvarchar](max) = null,
	@StatusID [int],
	@TeamID [int],
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@RoleID [int] = 0,
	@LangId [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON 
BEGIN TRANSACTION
BEGIN TRY
	DECLARE @Dt FLOAT, @lft INT,@rgt INT,@Selectedlft INT,@Selectedrgt INT,@HasAccess bit,
	@Depth int,@ParentID INT,@SelectedIsGroup int ,@IsGroup int ,@SelectedNodeID INT, @XML XML

	--User access check 
	SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,91,1)
	IF @HasAccess=0
	BEGIN
		RAISERROR('-105',16,1)
	END
		
    delete from CRM_Teams where TEAMID=@TeamID
	IF (@TeamID>0)
		SET @TeamID=0
	SET @Dt=convert(float,getdate())--Setting Current Date  
	 
	IF @TeamID= 0--------START INSERT RECORD-----------  
	BEGIN--CREATE Case  
  		--To Set Left,Right And Depth of Record  
		SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
		from CRM_Teams with(NOLOCK) where NodeID=1  
	   
		--IF No Record Selected or Record Doesn't Exist  
		if(@SelectedIsGroup is null)   
		 select @SelectedNodeID=NodeID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
		 from CRM_Teams with(NOLOCK) where ParentID =0  
	         
		if(@SelectedIsGroup = 1)--Adding Node Under the Group  
		 BEGIN  
		  UPDATE CRM_Teams SET rgt = rgt + 2 WHERE rgt > @Selectedlft;  
		  UPDATE CRM_Teams SET lft = lft + 2 WHERE lft > @Selectedlft;  
		  set @lft =  @Selectedlft + 1  
		  set @rgt = @Selectedlft + 2  
		  set @ParentID = @SelectedNodeID  
		  set @Depth = @Depth + 1  
		 END  
		else if(@SelectedIsGroup = 0)--Adding Node at Same level  
		 BEGIN  
		  UPDATE CRM_Teams SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;  
		  UPDATE CRM_Teams SET lft = lft + 2 WHERE lft > @Selectedrgt;  
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
 
		SELECT @TeamID=MAX(TEAMID)+1 FROM [CRM_Teams] with(NOLOCK)
		INSERT INTO [CRM_Teams]([TeamID],[TeamName],[StatusID],[UserID],[IsOwner],[Depth],[ParentID],[lft],[rgt],[IsGroup],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate],IsParent)
		VALUES(@TeamID,@Name,@StatusID,0,0,@Depth,1,@lft,@rgt,1,@CompanyGUID,NEWID(),@UserName,convert(float,@Dt),1)
		
		set @SelectedNodeID=SCOPE_IDENTITY()
 
	END --------END INSERT RECORD-----------  
		
	SET @XML=@Data
	CREATE TABLE #TBLTEMP(ID INT IDENTITY(1,1),UserID INT,isOwner int,[CompanyGUID] nvarchar(50),[GUID] nvarchar(50),[CreatedBy] nvarchar(50),[CreatedDate] float)

	INSERT INTO #TBLTEMP 
	SELECT X.value('@UserId','INT'), X.value('@IsOwner','INT'),@CompanyGUID, NewId(),@UserName,convert(float,getdate())
	from @XML.nodes('XML/Row') as Data(X)
 
	DECLARE @I INT,@TEMPCOUNT INT
	SELECT @I=1,@TEMPCOUNT=COUNT(*) FROM #TBLTEMP with(NOLOCK)
 
	set @lft =0  
	set @rgt = 0   
	set @Depth = 0  
	set @ParentID =0  
	
	WHILE(@I<=@TEMPCOUNT)
	BEGIN
		--To Set Left,Right And Depth of Record  
		SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
		from [CRM_Teams] with(NOLOCK) where NodeID=@SelectedNodeID  
	   
		--IF No Record Selected or Record Doesn't Exist  
		if(@SelectedIsGroup is null)   
		 select @SelectedNodeID=NodeID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
		 from [CRM_Teams] with(NOLOCK) where ParentID =0  
	         
		if(@SelectedIsGroup = 1)--Adding Node Under the Group  
		 BEGIN  
		  UPDATE [CRM_Teams] SET rgt = rgt + 2 WHERE rgt > @Selectedlft;  
		  UPDATE [CRM_Teams] SET lft = lft + 2 WHERE lft > @Selectedlft;  
		  set @lft =  @Selectedlft + 1  
		  set @rgt = @Selectedlft + 2  
		  set @ParentID = @SelectedNodeID  
		  set @Depth = @Depth + 1  
		 END  
		else if(@SelectedIsGroup = 0)--Adding Node at Same level  
		 BEGIN  
		  UPDATE [CRM_Teams] SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;  
		  UPDATE [CRM_Teams] SET lft = lft + 2 WHERE lft > @Selectedrgt;  
		  set @lft =  @Selectedrgt + 1  
		  set @rgt = @Selectedrgt + 2   
		 END  
		else  --Adding Root  
		 BEGIN  
		  set @lft =  1  
		  set @rgt = 2   
		  set @Depth = 0  
		  set @ParentID =0  
		  set @IsGroup = 1  
		 END   
			 
		INSERT INTO [CRM_Teams] (TeamID,TeamName,UserID,StatusID,IsOwner 				    
			  ,[CompanyGUID]
			  ,[GUID]    
			  ,[CreatedBy]
			  ,[CreatedDate]
			  , [Depth],  
			   [ParentID],  
			   [lft],  
			   [rgt],  
			   [IsGroup]   ) 
		SELECT @TeamID,@Name,USERID,@StatusID,isOwner,[CompanyGUID],[GUID],[CreatedBy],[CreatedDate],2,@SelectedNodeID,@lft,@rgt,0 
		FROM #TBLTEMP WITH(nolock)   
		WHERE  ID=@I  
  
		SET @I=@I+1

	END
	
	drop table #TBLTEMP	   
	COMMIT TRANSACTION
	SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;    
RETURN 1
END TRY    
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
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
--spCRM_SetTeam  
-- 'Team'
-- ,'<XML><Row  IsOwner=''1'' UserId=''3''/><Row  IsOwner=''0'' UserId=''5''/></XML>'
-- ,101
-- ,0
-- ,'830b4366-ab3c-4150-aefe-f5acaddc7089'
-- ,'d52d30bd-19bd-46f7-81fb-ea87de052f9f'
-- ,'admin'
-- ,1
-- ,1
GO
