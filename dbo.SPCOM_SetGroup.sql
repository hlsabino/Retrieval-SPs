USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SPCOM_SetGroup]
	@GroupId [bigint],
	@GroupName [nvarchar](500),
	@StatusID [int],
	@RoleXml [nvarchar](max),
	@CompanyGUID [nvarchar](50),
	@CreatedBy [nvarchar](50),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
 BEGIN TRY    
SET NOCOUNT ON;  
 
	Declare @CostCenterID int,@XML XML,@Count int,@SelectedNodeID INT,@IsGroup BIT
 DECLARE @lft bigint,@rgt bigint,@Selectedlft bigint,@Selectedrgt bigint,@Depth int,@ParentID bigint  
  DECLARE @SelectedIsGroup bit  
  --SP Required Parameters Check  
 SET @XML=@RoleXml
 --SET @SelectedNodeID=(SELECT ISNULL(MAX(NODEID),1) FROM COM_Groups)

  --CREATE ACCOUNT--  
	 
	if (@GroupId=0 and exists (select groupname from COM_Groups where GroupName=@GroupName))
	begin
		   RAISERROR('-112',16,1)  
	end
	else if(@GroupId>0 and exists (select groupname from COM_Groups where GroupName=@GroupName and GID<>@GroupId))
	begin
		   RAISERROR('-112',16,1)  
	end
	
	delete from [COM_GROUPS] where GID=@GroupId

if(@GroupId =0 )
 set @GroupId=(select isnull(max(GID),0)+1 from [COM_GROUPS]) 
 
   --To Set Left,Right And Depth of Record  
				SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
				from [COM_GROUPS] with(NOLOCK) where NodeID=1  
			   
				--IF No Record Selected or Record Doesn't Exist  
				if(@SelectedIsGroup is null)   
				 select @SelectedNodeID=NodeID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
				 from [COM_GROUPS] with(NOLOCK) where ParentID =0  
			         
				if(@SelectedIsGroup = 1)--Adding Node Under the Group  
				 BEGIN  
				  UPDATE [COM_GROUPS] SET rgt = rgt + 2 WHERE rgt > @Selectedlft;  
				  UPDATE [COM_GROUPS] SET lft = lft + 2 WHERE lft > @Selectedlft;  
				  set @lft =  @Selectedlft + 1  
				  set @rgt = @Selectedlft + 2  
				  set @ParentID = @SelectedNodeID  
				  set @Depth = @Depth + 1  
				 END  
				else if(@SelectedIsGroup = 0)--Adding Node at Same level  
				 BEGIN  
				  UPDATE [COM_GROUPS] SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;  
				  UPDATE [COM_GROUPS] SET lft = lft + 2 WHERE lft > @Selectedrgt;  
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
				  
 
 Insert into [COM_GROUPS]( GID,GroupName,StatusID, [CompanyGUID]
				  ,[GUID]    
				  ,[CreatedBy]
				  ,[CreatedDate],ParentId,IsGroup,lft,rgt,RoleId,UserId,Depth)
 Values (@GroupId,@GroupName,@StatusID,@CompanyGUID,NEWID(),@CreatedBy,CONVERT(float,getdate()), 1,1,@lft,@rgt,0,0,1)
 set @SelectedNodeID=SCOPE_IDENTITY()

CREATE TABLE #TBLTEMP(ID INT IDENTITY(1,1), GID BIGINT, GroupName nvarchar(500)
      ,UserID int,RoleID int	  
      ,[CompanyGUID] nvarchar(50)
      ,[GUID]    nvarchar(50)
      ,[CreatedBy] nvarchar(50)
      ,[CreatedDate] float)

	  INSERT INTO #TBLTEMP 
	  SELECT @GroupId,@GroupName,X.value('@UserID','BIGINT'), X.value('@RoleID','BIGINT')
	   ,@CompanyGUID, NewId(),@CreatedBy,convert(float,getdate())
   from @XML.nodes('XML/Row') as Data(X)
 
  DECLARE @I INT,@TEMPCOUNT INT,@J INT 
  SET @I=1
  SET @J=1
  SELECT @TEMPCOUNT=COUNT(*) FROM #TBLTEMP
 
	set @lft =0  
	set @rgt = 0   
	set @Depth = 0  
	set @ParentID =0  
  WHILE(@I<=@TEMPCOUNT)
  BEGIN
    --To Set Left,Right And Depth of Record  
				SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
				from [COM_GROUPS] with(NOLOCK) where NodeID=@SelectedNodeID  
			   
				--IF No Record Selected or Record Doesn't Exist  
				if(@SelectedIsGroup is null)   
				 select @SelectedNodeID=NodeID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
				 from [COM_GROUPS] with(NOLOCK) where ParentID =0  
			         
				if(@SelectedIsGroup = 1)--Adding Node Under the Group  
				 BEGIN  
				  UPDATE [COM_GROUPS] SET rgt = rgt + 2 WHERE rgt > @Selectedlft;  
				  UPDATE [COM_GROUPS] SET lft = lft + 2 WHERE lft > @Selectedlft;  
				  set @lft =  @Selectedlft + 1  
				  set @rgt = @Selectedlft + 2  
				  set @ParentID = @SelectedNodeID  
				  set @Depth = @Depth + 1  
				 END  
				else if(@SelectedIsGroup = 0)--Adding Node at Same level  
				 BEGIN  
				  UPDATE [COM_GROUPS] SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;  
				  UPDATE [COM_GROUPS] SET lft = lft + 2 WHERE lft > @Selectedrgt;  
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
			 
			  INSERT INTO [COM_GROUPS] (
				  GID
				  ,UserID,RoleID	  
				  ,[CompanyGUID]
				  ,[GUID]    
				  ,[CreatedBy]
				  ,[CreatedDate]
				  , [Depth],  
				   [ParentID],  
				   [lft],  
				   [rgt],  
				   [IsGroup]   ) 
				  SELECT GID,USERID,RoleID,[CompanyGUID],[GUID],[CreatedBy],[CreatedDate],
					2,  
				   @SelectedNodeID,  
				   @lft,  
				   @rgt,  
				   0 FROM #TBLTEMP   
				  WHERE  ID=@I  
  
 SET @I=@I+1

  END 

DROP TABLE #TBLTEMP
COMMIT TRANSACTION 
   SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
	WHERE ErrorNumber=100 AND LanguageID=1  
RETURN @SelectedNodeID  

END TRY  
BEGIN CATCH    
  --Return exception info [Message,Number,ProcedureName,LineNumber]    
  IF ERROR_NUMBER()=50000  
  BEGIN  
   SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
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
