USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetRole]
	@RoleID [int] = 0,
	@RoleName [nvarchar](50),
	@Description [nvarchar](500) = null,
	@Status [smallint],
	@MapXml [nvarchar](max),
	@CompanyRoleXML [nvarchar](max),
	@RestrictXML [nvarchar](max),
	@ExtraXML [nvarchar](max),
	@RoleType [int] = 0,
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@LoginRoleID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;     
    
  --Declaration Section    
  DECLARE @HasAccess BIT,@Dt FLOAT,@TempGuid NVARCHAR(50),@XML XML  , @RXML XML ,@HistGUID nvarchar(50)
    
  --SP Required Parameters Check    
  IF @RoleID<0 OR @CompanyGUID IS NULL OR @CompanyGUID=''    
  BEGIN    
   RAISERROR('-100',16,1)    
  END    

  --User access check    
  IF @RoleID=0    
  BEGIN    
   SET @HasAccess=dbo.fnCOM_HasAccess(@LoginRoleID,6,1)    
  END    
  ELSE    
  BEGIN    
   SET @HasAccess=dbo.fnCOM_HasAccess(@LoginRoleID,6,3)    
  END    
    
  IF @HasAccess=0    
  BEGIN    
   RAISERROR('-105',16,1)    
  END    
    
  SET @Dt=CONVERT(FLOAT,GETDATE())      
  set @HistGUID=newid()
  
CREATE TABLE #tblList(FeatureActionID INT null,MapAction NVARCHAR(10) null,Descrip nvarchar(max))      

IF @Status=-100
BEGIN
	SET @XML=@MapXML

	declare @tblRoles as table(RoleID int)
	insert into @tblRoles
	exec SPSplitString @CompanyRoleXML,','
	
	--Read XML data into temporary table
	INSERT INTO #tblList(FeatureActionID,MapAction,Descrip)      
	SELECT X.value('@FAID','INT')   
	,X.value('@Map','NVARCHAR(10)') ,X.value('@Description','NVARCHAR(max)')      
	FROM @XML.nodes('/XML/Row') AS Data(X)
	
	--select * from #tblList
	
	--Delete all feature actions mapping for that roles
	delete ADM_FeatureActionRoleMap
	from ADM_FeatureActionRoleMap F
	join #tblList T on T.FeatureActionID=F.FeatureActionID
	WHERE RoleID in (select RoleID from @tblRoles)

	--Insert feature actions mapping for that role      
	INSERT INTO ADM_FeatureActionRoleMap    
	(RoleID    
	,FeatureActionID    
	,Status,Description
	,CreatedBy    
	,CreatedDate)      
	SELECT     
	R.RoleId    
	,FeatureActionID    
	,1,Descrip  
	,@UserName    
	,@Dt
	FROM #tblList T,@tblRoles R 
	WHERE MapAction='LINK'

	INSERT INTO ADM_FeatureActionRoleMapHistory(FeatureActionRoleMapID,RoleID,FeatureActionID,[Status],[GUID],CreatedBy,CreatedDate)
	select FeatureActionRoleMapID,RoleID,F.FeatureActionID,[Status],@HistGUID,CreatedBy,CreatedDate
	from ADM_FeatureActionRoleMap F with(nolock) 
	join #tblList T on T.FeatureActionID=F.FeatureActionID
	where T.MapAction='LINK' and RoleID in (select RoleID from @tblRoles)
	order by FeatureActionRoleMapID
	
	delete from ADM_GridContextMenu where GridContextMenuID in (
	select GridContextMenuID from ADM_GridContextMenu M	
	join @tblRoles R on R.RoleID=M.RoleID
	join #tblList T on T.FeatureActionID=M.FeatureActionID)
	
	insert into ADM_GridContextMenu  
	([GridViewID]  
	,[GridViewColumnID]  
	,[FeatureActionID]  
	,[MenuOrder]  
	,[RoleID]  
	,[CompanyGUID]  
	,[GUID]   
	,[CreatedBy]  
	,[CreatedDate])  
	SELECT [GridViewID]  
	,[GridViewColumnID]  
	,M.[FeatureActionID]  
	,[MenuOrder]  
	,R.RoleId    
	,@CompanyGUID  
	,@HistGUID
	,@UserName    
	,CONVERT(float,GETDATE())  
	FROM [ADM_GridContextMenu] M
	join #tblList T on T.FeatureActionID=M.FeatureActionID
	,@tblRoles R
	where M.RoleId = 1
END
ELSE
BEGIN
  IF @RoleID=0     
  BEGIN--------START INSERT RECORD-----------    
   INSERT INTO ADM_PRoles    
      (Name,Description,StatusID,ExtraXML,IsUserDefined    
      ,CompanyGUID,GUID,CreatedBy,CreatedDate,RoleType)
    VALUES    
      (@RoleName,@Description,@Status,@ExtraXML
      ,1,@CompanyGUID,@HistGUID,@UserName,@Dt,@RoleType)
    
    --To get inserted record primary key    
    SET @RoleID=SCOPE_IDENTITY()      
    
  END--------END INSERT RECORD-----------      
  ELSE-------START UPDATE RECORD-----------      
  BEGIN      
    
    SELECT @TempGuid=[GUID] FROM ADM_PRoles WITH(NOLOCK)         
    WHERE RoleID=@RoleID        
     
--    if(@TempGuid!=@Guid)--IF RECORD ALREADY UPDATED BY SOME OTHER USER i.e DIRTY READ        
--    BEGIN        
--     RAISERROR('-101',16,1)    
--    END        
    
    UPDATE ADM_PRoles      
    SET Name=@RoleName    
        ,Description=@Description    
        ,StatusID=@Status
        ,ExtraXML=@ExtraXML
        ,GUID=@HistGUID   
        ,ModifiedBy=@UserName    
        ,ModifiedDate=@Dt
        ,RoleType=@RoleType
    WHERE RoleID=@RoleID      
  END--------END UPDATE RECORD-----------      
  IF(@MapXML<>'')    
  BEGIN    
   SET @XML=@MapXML      

   --Read XML data into temporary table    
   INSERT INTO #tblList    
      (FeatureActionID
      ,MapAction,Descrip)      
    SELECT X.value('@FAID','INT')    
      ,X.value('@Map','NVARCHAR(10)') ,X.value('@Description','NVARCHAR(max)')      
    FROM @XML.nodes('/XML/Row') AS Data(X)     
    
    
   --Delete all feature actions mapping for that role      
   DELETE FROM ADM_FeatureActionRoleMap WHERE 
	 RoleID = @RoleId
	--FeatureActionID IN   (SELECT FeatureActionID FROM #tblList WHERE  UPPER(LTRIM(RTRIM(MapAction)))='LINK')      
    
   --Insert feature actions mapping for that role      
   INSERT INTO ADM_FeatureActionRoleMap    
      (RoleID    
      ,FeatureActionID    
      ,Status,Description
      ,CreatedBy    
      ,CreatedDate)      
    SELECT     
      @RoleId    
      ,FeatureActionID    
      ,1,Descrip  
      ,@UserName    
      ,@Dt
    FROM #tblList WHERE  UPPER(LTRIM(RTRIM(MapAction)))='LINK'    
    
    if @RoleId=1
    begin
		INSERT INTO ADM_FeatureActionRoleMap(RoleID,FeatureActionID,Status,CreatedBy,CreatedDate)  
		select 1,FA.FeatureActionID,1,@UserName,@Dt from adm_featureaction FA with(nolock) 
		left join ADM_FeatureActionRoleMap FAR with(nolock) on FAR.FeatureActionID=FA.FeatureActionID and FAR.RoleID=1
		where FA.FeatureID=6 and FAR.FeatureActionID is null
		
		UPDATE ADM_PRoles      
		SET Name='ADMIN',Description='ADMIN',StatusID=434
		WHERE RoleID=1
    end

    --Added to get global preferences (pranathi)
    if exists (select featureactionid from #tblList WHERE  UPPER(LTRIM(RTRIM(MapAction)))='LINK'   and FeatureActionID=1619)
		 INSERT INTO ADM_FeatureActionRoleMap (RoleID ,FeatureActionID,Status,CreatedBy,CreatedDate)      
		 values (@RoleId,3759,1,@UserName,@Dt)
		 
	INSERT INTO ADM_FeatureActionRoleMapHistory(FeatureActionRoleMapID,RoleID,FeatureActionID,[Status],[GUID],CreatedBy,CreatedDate)
	select FeatureActionRoleMapID,RoleID,FeatureActionID,[Status],@HistGUID,CreatedBy,CreatedDate
	from ADM_FeatureActionRoleMap with(nolock) where RoleID=@RoleId order by FeatureActionRoleMapID
    
    Drop table #tblList    
  
	if (@RoleId<>1)
	begin
		DELETE FROM ADM_GridContextMenu
		WHERE  RoleID =    @RoleId

		insert into dbo.ADM_GridContextMenu  
		([GridViewID]  
		,[GridViewColumnID]  
		,[FeatureActionID]  
		,[MenuOrder]  
		,[RoleID]  
		,[CompanyGUID]  
		,[GUID]   
		,[CreatedBy]  
		,[CreatedDate])  
		SELECT [GridViewID]  
		,[GridViewColumnID]  
		,[FeatureActionID]  
		,[MenuOrder]  
		,@RoleId    
		,@CompanyGUID  
		,@HistGUID
		,@UserName    
		,CONVERT(float,GETDATE())  

		FROM  [ADM_GridContextMenu]   

		where [FeatureActionID] in ( SELECT     
		X.value('@FAID','INT')       
		FROM @XML.nodes('/XML/Row') AS Data(X) ) AND RoleId = 1 
	end 
		  
     
  END    
      
   IF(@CompanyRoleXML <> '' AND @CompanyRoleXML IS NOT NULL)  
		BEGIN  
		  EXEC [spCOM_SetCCCCMap]6,@RoleId,@CompanyRoleXML,@UserName,@LangID
	 END 
	 
	 IF(@RestrictXML <>'' and  @RestrictXML is not null)
	 BEGIN 
	 SET @RXML=@RestrictXML
	 delete from adm_featuretypevalues where RoleID=@RoleId and userid is null
		INSERT INTO [ADM_FeatureTypeValues]
		   ([FeatureID]
		   ,[CostCenterID]
		   ,[FeatureTypeID]
		   ,[GUID] 
		   ,[CreatedBy]
		   ,[CreatedDate]
		   ,[RoleID])
		SELECT     
			X.value('@CostCenterId','INT')    
			,X.value('@CostCenterId','INT')    
			,X.value('@FeatureTypeID','INT') 
			,@HistGUID
			,@UserName    
			,CONVERT(float,GETDATE())  
			,@RoleId    
		FROM @RXML.nodes('/XML/Row') AS Data(X)    
	 END
END

COMMIT TRANSACTION
--ROLLBACK TRANSACTION

SELECT Name,Description,StatusID,IsUserDefined,CreatedBy,CreatedDate,RoleType
FROM ADM_PRoles WITH(nolock) WHERE RoleID=@RoleID     
SET NOCOUNT OFF;      
RETURN  @RoleID    
END TRY    
BEGIN CATCH      
 --Return exception info [Message,Number,ProcedureName,LineNumber]      
 IF ERROR_NUMBER()=50000    
 BEGIN    
  SELECT Name,Description,StatusID,IsUserDefined,CreatedBy,CreatedDate     
  FROM ADM_PRoles WITH(nolock) WHERE RoleID=@RoleID     
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
 END    
 ELSE    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine    
  FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID    
 END    
ROLLBACK TRANSACTION    
SET NOCOUNT OFF      
RETURN -999       
END CATCH    
GO
