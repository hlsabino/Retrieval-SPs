USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_DefineCostCenterGridView]
	@GridViewID [int],
	@CostCenterID [int] = 0,
	@FeatureID [int] = 0,
	@ViewName [nvarchar](200),
	@ChunkCount [bigint],
	@ResourceID [int],
	@SearchFilter [nchar](300),
	@RoleID [int],
	@SetUserID [bigint],
	@IsViewRoleDefault [bit],
	@IsViewUserDefault [bit],
	@DefaultColID [bigint],
	@DefaultFilterID [int],
	@CompanyGUID [nvarchar](50),
	@Guid [nvarchar](50),
	@UserName [nvarchar](50),
	@GridViewColumnsXML [nvarchar](max),
	@FILTERXML [nvarchar](max),
	@RolesXML [nvarchar](max) = NULL,
	@COLUMNLISTVIEWXML [nvarchar](max),
	@DefaultListViewID [varchar](50) = 0,
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;    
    
  --Declaration Section    
  DECLARE @TempGuid nvarchar(50),@HasAccess bit
  DECLARE @Dt float,@XML xml,@I int,@Cnt int,@CostCenterColID BIGINT    
    
  --Create temporary table to read xml data into table    
  CREATE TABLE #tblList(ID int identity(1,1),CostCenterColID BIGINT)      

  --SP Required Parameters Check    
  if(@CostCenterID=0 or @FeatureID=0)    
  BEGIN        
   RAISERROR('-100',16,1)         
  END    
      
  --User acces check    
  IF @GridViewID=0    
  BEGIN    
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,26,1)    
  END    
  ELSE    
  BEGIN    
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,26,3)    
  END    
  IF @HasAccess=0    
  BEGIN    
   RAISERROR('-105',16,1)    
  END    

    
  SET @Dt=convert(float,getdate())--Getting Current Date    
  SET @XML=@GridViewColumnsXML --Set GridViewColumnsXML in XMl variable    
      
  --IF USER DEFAULT THEN CLEAR PREVIOUS Default    
  IF(@CostCenterID<>16 and @IsViewUserDefault=1)    
  BEGIN    
   update ADM_GridView    
   set IsViewUserDefault=0    
   where UserID=@SetUserID  and CostCenterID=@CostCenterID   
  END    
      
--ADDED CODE ON JUN 30 2011 BY HAFEEZ FOR BILLWISE VIEW    
IF @CostCenterID=99    
BEGIN 
   
 DELETE FROM [ADM_GridViewColumns] WHERE [GridViewID] IN(    
 SELECT [GridViewID] FROM [ADM_GridView] with(nolock) WHERE [CostCenterID]=99)    
 DELETE FROM [ADM_GridView] WHERE [CostCenterID]=99    
     
END    
IF @CostCenterID=23    
BEGIN    
 DELETE FROM [ADM_GridViewColumns] WHERE [GridViewID] IN(    
 SELECT [GridViewID] FROM [ADM_GridView] with(nolock) WHERE [CostCenterID]=23)    
-- DELETE FROM [ADM_GridView] WHERE [CostCenterID]=23    
END    

IF @CostCenterID=159    
BEGIN    
 DELETE FROM [ADM_GridViewColumns] WHERE [GridViewID] IN(    
 SELECT [GridViewID] FROM [ADM_GridView] with(nolock) WHERE [CostCenterID]=159)    
 DELETE FROM [ADM_GridView] WHERE [CostCenterID]=159    
     
END    
IF @CostCenterID=161    
BEGIN    
 DELETE FROM [ADM_GridViewColumns] WHERE [GridViewID] IN(    
 SELECT [GridViewID] FROM [ADM_GridView] with(nolock) WHERE [CostCenterID]=161)    
 DELETE FROM [ADM_GridView] WHERE [CostCenterID]=161    
     
END    
IF (@CostCenterID=102 )    
BEGIN    
 DELETE FROM [ADM_GridViewColumns] WHERE [GridViewID] IN(    
 SELECT [GridViewID] FROM [ADM_GridView] with(nolock) WHERE [FeatureID]=@CostCenterID) 
END    
    
IF @CostCenterID=112    
BEGIN     
 DELETE FROM [ADM_GridViewColumns] WHERE [GridViewID] IN(    
 SELECT [GridViewID] FROM [ADM_GridView] with(nolock) WHERE [CostCenterID]=112)    
 DELETE FROM [ADM_GridView] WHERE [CostCenterID]=112    
    
END    
    
 if(@CostCenterID=102 or @CostCenterID=23  )    
 begin    
  select top 1 @GridViewID=[GridViewID] FROM [ADM_GridView] with(nolock) WHERE [CostCenterID]=@CostCenterID      
 end    
 else    
 begin    
  IF @GridViewID=0--CREATE CostCenterGridView--    
   BEGIN    
       
	select @ResourceID=MAX([ResourceID])+1 FROM [Com_LanguageResources] WITH(NOLOCK)

	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
	VALUES(@ResourceID,@ViewName,1,'English',@ViewName,@ViewName) 

	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
	VALUES(@ResourceID,@ViewName,2,'Arabic',@ViewName,@ViewName) 
	
   INSERT INTO [ADM_GridView]    
        ([CostCenterID]    
        ,[FeatureID]    
        ,[ViewName]    
        ,[ResourceID]    
        ,[SearchFilter]    
        ,[RoleID]    
        ,[UserID]    
        ,[IsViewRoleDefault]    
        ,[IsViewUserDefault]    
        ,[IsUserDefined]    
        ,[CompanyGUID]    
        ,[GUID]     
        ,[CreatedBy]    
        ,[CreatedDate],FILTERXML,ChunkCount,DefaultSearchListviews, DefaultColID , DefaultFilterID,DefaultListViewID)    
     VALUES    
        (@CostCenterID    
        ,@FeatureID    
        ,@ViewName    
        ,@ResourceID    
        ,@SearchFilter    
        ,@RoleID    
        ,@SetUserID    
        ,@IsViewRoleDefault    
        ,@IsViewUserDefault    
        ,1    
        ,@CompanyGUID    
        ,newid()     
        ,@UserName    
        ,@Dt,@FILTERXML,@ChunkCount ,@COLUMNLISTVIEWXML,@DefaultColID, @DefaultFilterID,@DefaultListViewID)    
       
   set @GridViewID=SCOPE_IDENTITY()--Getting GridViewID    
    
   END    
   ELSE--UPDATE CostCenterGridView--    
   BEGIN    
    
    select @TempGuid=[GUID] from [ADM_GridView]  WITH(NOLOCK)     
     WHERE GridViewID=@GridViewID    
    
 
    if(@TempGuid!=@Guid)    
    BEGIN    
     RAISERROR('-101',16,1)    
    END    
      
    UPDATE [ADM_GridView]    
       SET [CostCenterID] = @CostCenterID    
       ,[FeatureID] = @FeatureID    
       ,[ViewName] = @ViewName      
       ,[SearchFilter] = @SearchFilter    
       ,[RoleID] = @RoleID    
       ,[UserID] = @SetUserID    
       ,[IsViewRoleDefault] = @IsViewRoleDefault    
       ,[IsViewUserDefault] = @IsViewUserDefault    
       ,[CompanyGUID] = @CompanyGUID    
       ,[GUID] =newid(),FILTERXML=@FILTERXML    ,DefaultSearchListviews=@COLUMNLISTVIEWXML
       ,[ModifiedBy] = @UserName    
       ,[ModifiedDate] = @Dt    
       ,ChunkCount=@ChunkCount    
       ,DefaultColID = @DefaultColID    
       ,DefaultFilterID =  @DefaultFilterID    ,DefaultListViewID=@DefaultListViewID
     WHERE  GridViewID=@GridViewID     
   END    
    
 end    

IF @CostCenterID=98    
BEGIN
	 DELETE FROM [ADM_GridViewColumns]    
	 WHERE [GridViewID]=@GridViewID and ColumnType =1    
END

 DELETE FROM [ADM_GridViewColumns]    
 WHERE [GridViewID]=@GridViewID and ColumnType =2 
   
    
    --Insert into GridView Columns From XML    
    INSERT INTO [ADM_GridViewColumns]    
    ([GridViewID]    
    ,CostCenterColID    
    ,[ColumnResourceID]    
    ,[ColumnFilter]    
    ,[ColumnOrder]    
    ,[ColumnWidth]    
    ,[Description] 
    ,[IsCode]   
    ,[CreatedBy]    
    ,[CreatedDate],ColumnType)    
    SELECT @GridViewID    
    ,X.value('@CostCenterColID','INT')    
    ,X.value('@ColumnResourceID','INT'),       
    X.value('@ColumnFilter','nvarchar(500)'),X.value('@ColumnOrder','int'),X.value('@ColumnWidth','int')  ,    
    X.value('@Description','nvarchar(500)'),
    X.value('@IsCode','INT'),
    @UserName,convert(float,getdate())    
    ,X.value('@ColumnType','INT')    
    from @XML.nodes('/XML/Row') as Data(X)    
    WHERE X.value('@MapAction','nvarchar(10)') ='NEW'    
    
      UPDATE [ADM_GridViewColumns] SET CostCenterColID=A.value('@CostCenterColID','INT'),[ColumnOrder]=A.value('@ColumnOrder','int'),    
      [ColumnWidth]=A.value('@ColumnWidth','int'),[ModifiedBy]=@UserName,[ModifiedDate]=convert(float,getdate())    
      ,ColumnType=A.value('@ColumnType','INT'),[Description]=A.value('@Description','nvarchar(500)'),
      [IsCode]=A.value('@IsCode','INT')
       FROM [ADM_GridViewColumns] U    
      INNER JOIN @XML.nodes('/XML/Row') AS DATA(A)    
       ON CONVERT(BIGINT,A.value('@CostCenterColID','BIGINT'))=U.CostCenterColID    
    WHERE A.value('@MapAction','NVARCHAR(500)')='OLD' AND [GridViewID]=@GridViewID AND U.ColumnType=A.value('@ColumnType','INT')
    
    --DELETE RECORDS FROM MAPPING    
    --If MapAction is DELETE then delete        
    DELETE FROM [ADM_GridViewColumns]    
    WHERE CostCenterColID IN(SELECT A.value('@CostCenterColID','BIGINT')    
    FROM @XML.nodes('/XML/Row') as Data(A)    
    WHERE A.value('@MapAction','NVARCHAR(10)')='DELETE') AND [GridViewID]=@GridViewID    
    
   IF @RolesXML IS NOT NULL AND @RolesXML<>''    
   BEGIN    
    EXEC [spCOM_SetCCCCMap] 26,@GridViewID,@RolesXML,'ADMIN',@LangID    
   END    
      
  select * from adm_gridviewColumns with(nolock) where GridViewID=@GridViewID    
    
COMMIT TRANSACTION      
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=100 AND LanguageID=@LangID     
SET NOCOUNT OFF;      
RETURN @GridViewID      
END TRY      
BEGIN CATCH      
 --Return exception info [Message,Number,ProcedureName,LineNumber]      
 IF ERROR_NUMBER()=50000    
 BEGIN  
	 IF ISNUMERIC(ERROR_MESSAGE())<>1
	 BEGIN
		SELECT ERROR_MESSAGE() ErrorMessage
	 END
	 ELSE
	 BEGIN     
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
	 END 
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
