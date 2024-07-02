USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_CloneUserWithAllRight]
	@NewUserID [int],
	@NewUserName [nvarchar](50),
	@EditUserID [int],
	@EditUserName [nvarchar](50),
	@LangID [int] = 1,
	@LoginUserName [nvarchar](100),
	@LoginUserID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
SET NOCOUNT ON    
BEGIN TRY    
  
  --Favorites Copy
  INSERT INTO ADM_Assign(CostCenterID,NodeID,GroupID,RoleID,UserID,CreatedBy,CreatedDate)
  SELECT CostCenterID,nodeid,0,RoleID,@NewUserID,@LoginUserName,convert(float,Getdate()) 
  from ADM_Assign with(nolock) where userid=@EditUserID

  --Dasboard Copy
  INSERT INTO ADM_DashBoardUserRoleMap(DashBoardID,GroupID,RoleID,UserID,CompanyGUID,GUID,CreatedBy,CreatedDate,IsDefault)  
  SELECT DashBoardID,GroupID,RoleID,@NewUserID,CompanyGUID,newid(),GUID,convert(float,Getdate()),IsDefault  
  FROM ADM_DashBoardUserRoleMap   with(nolock)    where  userid=@EditUserID   
  
  --Report  Copy
  INSERT INTO ADM_ReportsUserMap(ReportID,GroupID,RoleID,UserID,CreatedBy,CreatedDate,ActionType)  
  SELECT ReportID,GroupID,RoleID,@NewUserID,@LoginUserName,convert(float,Getdate()) ,ActionType  
  FROM ADM_ReportsUserMap   with(nolock)     where userid=@EditUserID

  --VPT  print Layout Copy
   INSERT INTO ADM_DocPrintLayoutsMap(DocPrintLayoutID,GroupID,RoleID,UserID,CCNID2,BasedOn,CreatedBy,CreatedDate)  
  SELECT DocPrintLayoutID,GroupID,RoleID,@NewUserID,CCNID2,BasedOn,@LoginUserName,convert(float,Getdate()) 
  FROM ADM_DocPrintLayoutsMap with(nolock) where userid=@EditUserID
  
  --CostCentermap
  INSERT INTO  COM_CostCenterCostCenterMap (ParentCostCenterID,ParentNodeID,CostCenterID,NodeID,GUID,CreatedBy,CreatedDate)
  select ParentCostCenterID,ParentNodeID,CostCenterID,NodeID,GUID,@LoginUserName,convert(float,Getdate())
  from COM_CostCenterCostCenterMap where CostCenterID=7 and NodeID= @EditUserID

   --CostCentermap
	  INSERT INTO  COM_CostCenterCostCenterMap (ParentCostCenterID,ParentNodeID,CostCenterID,NodeID,GUID,CreatedBy,CreatedDate)
	  select ParentCostCenterID,ParentNodeID,CostCenterID,NodeID,GUID,@LoginUserName,convert(float,Getdate())
	  from COM_CostCenterCostCenterMap with(nolock) where ParentCostCenterID=7 and ParentNodeID= @EditUserID
  --property
	if exists(select name from sys.tables where name ='ADM_PropertyUserRoleMap')
	BEGIN
		if exists(select column_name from information_schema.columns where table_name='ADM_PropertyUserRoleMap' and column_name='LocationID')  
			BEGIN
			 declare @sql nvarchar(max)
			set @sql ='INSERT INTO [ADM_PropertyUserRoleMap]([PropertyID],UserID,RoleID,LocationID,[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])
				select [PropertyID],'+Convert(nvarchar,@NewUserID)+' ,RoleID,LocationID,[CompanyGUID],[GUID],'''+Convert(nvarchar, @LoginUserName)+''',Convert(float,Getdate())
				from [ADM_PropertyUserRoleMap] with(nolock)
				where userid='+Convert(nvarchar,@EditUserID)+' '
				print @sql
				exec (@sql)
			End
			if not exists(select column_name from information_schema.columns where table_name='ADM_PropertyUserRoleMap' and column_name='LocationID')  
			BEGIN
			INSERT INTO [ADM_PropertyUserRoleMap]([PropertyID],UserID,RoleID,[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])
				select [PropertyID],@NewUserID,RoleID,[CompanyGUID],[GUID],@LoginUserName,convert(float,Getdate()) from [ADM_PropertyUserRoleMap] with(nolock)
				where userid=@EditUserID
			End
	End

--DocViewUserRoleMap
	INSERT INTO [ADM_DocViewUserRoleMap]([DocumentViewID],[DocumentTypeID] ,[CostCenterID],UserID,RoleID,GroupID,[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])
	SELECT [DocumentViewID],[DocumentTypeID],[CostCenterID],@NewUserID,RoleID,GroupID,[CompanyGUID],[GUID],@LoginUserName,convert(float,Getdate()) from [ADM_DocViewUserRoleMap] 
	with(nolock)
	where userid=@EditUserID

--NotifTemplateUserMap
INSERT INTO [COM_NotifTemplateUserMap]([NotificationID],[GroupID],[RoleID],[UserID],[CreatedBy],[CreatedDate],[BasedOnDimension],[BasedOnField])
   select  [NotificationID] ,[GroupID]    ,[RoleID]   ,@NewUserID   ,@LoginUserName    ,convert(float,Getdate()) ,[BasedOnDimension],[BasedOnField] from [COM_NotifTemplateUserMap]
   with(nolock) 	where userid=@EditUserID
		
		
--NotificationDeviceID		
INSERT INTO  [Com_UserNotificationDeviceID]([UserID],[RoleID],[CCID],[NodeID],[DeviceID],[CreatedOn],[UpdatedOn])
Select @NewUserID      ,[RoleID]   ,[CCID] ,[NodeID] ,[DeviceID],convert(float,Getdate()) ,convert(float,Getdate())
from [Com_UserNotificationDeviceID]     with(nolock) 	where userid=@EditUserID
--view
INSERT INTO [ADM_GridView]([CostCenterID],[FeatureID],[ViewName],[ResourceID],[SearchFilter]
        ,[RoleID],[UserID],[IsViewRoleDefault],[IsViewUserDefault],[IsUserDefined],[CompanyGUID]    
        ,[GUID],[CreatedBy]
        ,[CreatedDate],FILTERXML,ChunkCount,DefaultSearchListviews, DefaultColID , DefaultFilterID,DefaultListViewID)   
Select  [CostCenterID] ,[FeatureID] ,[ViewName]  ,[ResourceID]  ,[SearchFilter] ,[RoleID]  ,@NewUserID    
        ,[IsViewRoleDefault] ,[IsViewUserDefault] ,[IsUserDefined] ,[CompanyGUID],[GUID],@LoginUserName    
        ,convert(float,Getdate()),FILTERXML,ChunkCount,DefaultSearchListviews, DefaultColID , DefaultFilterID,DefaultListViewID  
		from [ADM_GridView]	with(nolock) 	where userid=@EditUserID

---Quik view 

	INSERT INTO ADM_QuickViewDefnUserMap(QID,ShowCCID,GroupID,RoleID,UserID)
	SELECT QID,ShowCCID,GroupID,RoleID,@NewUserID from ADM_QuickViewDefnUserMap with(nolock) where userid=@EditUserID


		
--select * from ADM_DocReportUserroleMap

--select * from ADM_QuickViewDefnUserMap
 
  





 -- listview 
  --emp
--  assign
  -- 
 
 --dimension mapping and document right are based on role saving
  
COMMIT TRANSACTION    
SET NOCOUNT OFF;      
--RETURN 1    
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
ROLLBACK TRANSACTION    
SET NOCOUNT OFF      
RETURN -999       
END CATCH 
GO
