USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_DefineCostCenter]
	@CostCenterId [int],
	@CostCenterName [nvarchar](50),
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON    
		--Declaration Section  
		DECLARE @SQL NVARCHAR(MAX),@HasAccess BIT,@Table NVARCHAR(50),@CreatedDt FLOAT,@RESOURCEMAX INT
		DECLARE @ActiveStatusId INT,@GridViewID INT,@CodeColID INT,@NameColID INT

		--SP Required Parameters Check  
		IF  @CompanyGUID IS NULL OR @CompanyGUID=''  
		BEGIN  
			RAISERROR('-100',16,1)  
		END  

		--User acces check    
		SET @HasAccess=0   
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,8,1)  

		IF @HasAccess=0  
		BEGIN  
			RAISERROR('-105',16,1)  
		END  

		SET @CreatedDt=CONVERT(FLOAT,GETDATE())    
 
		---Create New Cost center(Table creation and some inserts)  
		IF @CostCenterId=0    
		BEGIN
			SELECT @CostCenterId=ISNULL(MAX(CostCenterId)+1,50000) FROM ADM_CostCenterDef WITH(NOLOCK)  
																	WHERE  CostCenterId >=50000

			SET @Table='COM_CC'+CONVERT(NVARCHAR,@CostCenterId)
			
			SET @SQL='CREATE TABLE '+@Table+'(    
			[NodeID] [INT] IDENTITY(1,1) NOT NULL,
			Code NVARCHAR(500),
			Name NVARCHAR(500), 
			AliasName NVARCHAR(500),   
			[StatusID] [INT] NOT NULL,    
			[Depth] [INT] NOT NULL,    
			[ParentID] [INT] NOT NULL,    
			[lft] [INT] NOT NULL,    
			[rgt] [INT] NOT NULL,    
			[IsGroup] [BIT] NOT NULL,
			[CreditDays] [int] NOT NULL,
			[CreditLimit] [float] NOT NULL,
			[PurchaseAccount] [int] NOT NULL,
			[SalesAccount] [int] NOT NULL,   
			[CompanyGUID] [NVARCHAR](50) NOT NULL,  
			[GUID] [varchar](50) NOT NULL,    
			[Description] [NVARCHAR](500) NULL,    
			[CreatedBy] [NVARCHAR](50) NOT NULL,    
			[CreatedDate] [FLOAT] NOT NULL,    
			[ModifiedBy] [NVARCHAR](50) NULL,    
			[ModifiedDate] [FLOAT] NULL,    
			CONSTRAINT [PK_'+@Table+'] PRIMARY KEY CLUSTERED     
			(    
			[NodeID] ASC    
			)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]    
			) ON [PRIMARY]    
			'    
			EXEC(@SQL)    
			
			
			--Inserting feature to the costcenter--  
			INSERT INTO ADM_Features(FeatureID,Name,SysName,ParentFeatureID,FeatureTypeID,FeatureTypeName,IsUserDefined,ApplicationID,StatusID,CreatedDate,CreatedBy,TableName)    
			VALUES(@CostCenterId,@CostCenterName,@CostCenterName,1,1,@CostCenterName,1,1,1,@CreatedDt,@UserName,@Table)  --CREATE FEATURE  

			--Insert costcenter gridview definition  
			INSERT INTO ADM_GridView(FeatureID,CostCenterID,ViewName,UserID,RoleID,IsUserDefined,GUID,CreatedBy,CreatedDate)    
			VALUES(@CostCenterId,@CostCenterId,@CostCenterName,1,1,0,NEWID(),@UserName,@CreatedDt)    
			SET @GridViewID=SCOPE_IDENTITY()   

			--Inserting feature actions to the costcenter--  
			EXEC spCOM_SetCostCenterLanguageData 'Create',@CostCenterName,@UserName,@RESOURCEMAX output --IINSERT INTO RESOURCE TABLE
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy,GridShortCut)    
			VALUES('Create',@CostCenterId,@RESOURCEMAX,1,1,1,@CreatedDt,@UserName,'Ctrl + N')   
			--INSERT INTO CONTEXT MENU 			
			INSERT INTO [ADM_GridContextMenu]([GridViewID],[FeatureActionID],[RoleID],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])
		    VALUES(@GridViewID,SCOPE_IDENTITY(),1,@CompanyGUID,NEWID(),@UserName,CONVERT(FLOAT,GETDATE())) 

			EXEC spCOM_SetCostCenterLanguageData 'Read',@CostCenterName,@UserName,@RESOURCEMAX output
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('Read',@CostCenterId,@RESOURCEMAX,2,1,1,@CreatedDt,@UserName)  			
			--INSERT INTO CONTEXT MENU 			
			INSERT INTO [ADM_GridContextMenu]([GridViewID],[FeatureActionID],[RoleID],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])
		    VALUES(@GridViewID,SCOPE_IDENTITY(),1,@CompanyGUID,NEWID(),@UserName,CONVERT(FLOAT,GETDATE()))  


			EXEC spCOM_SetCostCenterLanguageData 'Edit',@CostCenterName,@UserName,@RESOURCEMAX output
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy,GridShortCut)    
			VALUES('Edit',@CostCenterId,@RESOURCEMAX,3,1,1,@CreatedDt,@UserName,'Ctrl + E')  
			--INSERT INTO CONTEXT MENU 			
			INSERT INTO [ADM_GridContextMenu]([GridViewID],[FeatureActionID],[RoleID],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])
		    VALUES(@GridViewID,SCOPE_IDENTITY(),1,@CompanyGUID,NEWID(),@UserName,CONVERT(FLOAT,GETDATE())) 

			EXEC spCOM_SetCostCenterLanguageData 'Delete',@CostCenterName,@UserName,@RESOURCEMAX output
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy,GridShortCut)    
			VALUES('Delete',@CostCenterId,@RESOURCEMAX,4,1,1,@CreatedDt,@UserName,'Ctrl + D') 
			--INSERT INTO CONTEXT MENU 			
			INSERT INTO [ADM_GridContextMenu]([GridViewID],[FeatureActionID],[RoleID],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])
		    VALUES(@GridViewID,SCOPE_IDENTITY(),1,@CompanyGUID,NEWID(),@UserName,CONVERT(FLOAT,GETDATE())) 
 
			EXEC spCOM_SetCostCenterLanguageData 'Move',@CostCenterName,@UserName,@RESOURCEMAX output
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy,GridShortCut)    
			VALUES('Move',@CostCenterId,@RESOURCEMAX,5,1,1,@CreatedDt,@UserName,'Ctrl + M')  
			--INSERT INTO CONTEXT MENU 			
			INSERT INTO [ADM_GridContextMenu]([GridViewID],[FeatureActionID],[RoleID],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])
		    VALUES(@GridViewID,SCOPE_IDENTITY(),1,@CompanyGUID,NEWID(),@UserName,CONVERT(FLOAT,GETDATE())) 
			
			EXEC spCOM_SetCostCenterLanguageData 'Transfer',@CostCenterName,@UserName,@RESOURCEMAX output
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('Transfer',@CostCenterId,@RESOURCEMAX,6,1,1,@CreatedDt,@UserName)  
			--INSERT INTO CONTEXT MENU 			
			INSERT INTO [ADM_GridContextMenu]([GridViewID],[FeatureActionID],[RoleID],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])
		    VALUES(@GridViewID,SCOPE_IDENTITY(),1,@CompanyGUID,NEWID(),@UserName,CONVERT(FLOAT,GETDATE())) 

			EXEC spCOM_SetCostCenterLanguageData 'Map',@CostCenterName,@UserName,@RESOURCEMAX output
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('Map',@CostCenterId,@RESOURCEMAX,7,1,1,@CreatedDt,@UserName)  
			--INSERT INTO CONTEXT MENU 			
			INSERT INTO [ADM_GridContextMenu]([GridViewID],[FeatureActionID],[RoleID],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])
		    VALUES(@GridViewID,SCOPE_IDENTITY(),1,@CompanyGUID,NEWID(),@UserName,CONVERT(FLOAT,GETDATE())) 

			EXEC spCOM_SetCostCenterLanguageData 'Create Group',@CostCenterName,@UserName,@RESOURCEMAX output
			INSERT INTO ADM_FeatureAction(Name,FeatureID,ResourceID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy,GridShortCut)    
			VALUES('Create Group',@CostCenterId,@RESOURCEMAX,21,1,1,@CreatedDt,@UserName,'Ctrl + G')  
			--INSERT INTO CONTEXT MENU 			
			INSERT INTO [ADM_GridContextMenu]([GridViewID],[FeatureActionID],[RoleID],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])
		    VALUES(@GridViewID,SCOPE_IDENTITY(),1,@CompanyGUID,NEWID(),@UserName,CONVERT(FLOAT,GETDATE())) 



			INSERT INTO ADM_FeatureAction(Name,FeatureID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('Note_Create',@CostCenterId,8,1,1,@CreatedDt,@UserName)   

			INSERT INTO ADM_FeatureAction(Name,FeatureID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('Note_Read',@CostCenterId,9,1,1,@CreatedDt,@UserName)   

			INSERT INTO ADM_FeatureAction(Name,FeatureID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('Note_Update',@CostCenterId,10,1,1,@CreatedDt,@UserName)   

			INSERT INTO ADM_FeatureAction(Name,FeatureID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('Note_Delete',@CostCenterId,11,1,1,@CreatedDt,@UserName)    

			INSERT INTO ADM_FeatureAction(Name,FeatureID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('File_Create',@CostCenterId,12,1,1,@CreatedDt,@UserName)    

			INSERT INTO ADM_FeatureAction(Name,FeatureID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('File_Read',@CostCenterId,13,1,1,@CreatedDt,@UserName)    

			INSERT INTO ADM_FeatureAction(Name,FeatureID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('File_Update',@CostCenterId,14,1,1,@CreatedDt,@UserName)  

			INSERT INTO ADM_FeatureAction(Name,FeatureID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('File_Delete',@CostCenterId,15,1,1,@CreatedDt,@UserName)    

			INSERT INTO ADM_FeatureAction(Name,FeatureID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('Contacts_Create',@CostCenterId,16,1,1,@CreatedDt,@UserName)    

			INSERT INTO ADM_FeatureAction(Name,FeatureID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('Contacts_Read',@CostCenterId,17,1,1,@CreatedDt,@UserName)    

			INSERT INTO ADM_FeatureAction(Name,FeatureID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('Contacts_Update',@CostCenterId,18,1,1,@CreatedDt,@UserName)   

			INSERT INTO ADM_FeatureAction(Name,FeatureID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('Contacts_Delete',@CostCenterId,19,1,1,@CreatedDt,@UserName) 
		
			INSERT INTO ADM_FeatureAction(Name,FeatureID,FeatureActionTypeID,ApplicationID,Status,CreatedDate,CreatedBy)    
			VALUES('Preferences',@CostCenterId,30,1,1,@CreatedDt,@UserName)  


			--Inserting feature actions to the ROLE--  
			INSERT INTO [ADM_FeatureActionRoleMap]([RoleID],[FeatureActionID],[Status],[CreatedBy],[CreatedDate])
			 SELECT 1,[FeatureActionID],1,@UserName,@CreatedDt FROM ADM_FeatureAction WITH(NOLOCK) WHERE FEATUREID=@CostCenterId
 
			--Insert Active status to Costcenter  
			EXEC [spCOM_SetInsertResourceData] 'Active','Active',@CostCenterName,@UserName,1,@RESOURCEMAX output
			INSERT INTO COM_Status(CostCenterID,FeatureID,RESOURCEID,Status,IsUserDefined,CompanyGUID,GUID,CreatedBy,CreatedDate)     
			VALUES(@CostCenterId,@CostCenterId,@RESOURCEMAX,'Active',0,@CompanyGUID,NEWID(),@UserName,@CreatedDt)  --INSERT ACTIVE STAUS FOR FEATURE  
			SET @ActiveStatusId=SCOPE_IDENTITY()    

			--Insert In Active status to Costcenter  
			EXEC [spCOM_SetInsertResourceData] 'In Active','In Active',@CostCenterName,@UserName,1,@RESOURCEMAX output
			INSERT INTO COM_Status(CostCenterID,FeatureID,RESOURCEID,Status,IsUserDefined,CompanyGUID,GUID,CreatedBy,CreatedDate)     
			VALUES(@CostCenterId,@CostCenterId,@RESOURCEMAX,'In Active',0,@CompanyGUID,NEWID(),@UserName,@CreatedDt)  --INSERT IN-ACTIVE STAUS FOR FEATURE  


			EXEC	[spCOM_SetInsertResourceData] 'Code','Code',@CostCenterName,@UserName,1,@RESOURCEMAX output
			--Insert Name Code definition TO ADM_CostCenterDef TABLE.  
			INSERT INTO ADM_CostCenterDef(CostCenterID,CostCenterName,SysTableName,UserColumnName,SysColumnName,UserColumnType,ResourceID,ColumnOrder,IsCostCenterUserDefined,IsColumnUserDefined,ColumnCostCenterID,IsMandatory,IsEditable,CompanyGUID,GUID,CreatedBy,CreatedDate)    
			VALUES(@CostCenterId,@CostCenterName,@Table,'Code','Code','TEXT',@RESOURCEMAX,0,0,0,0,0,0,@CompanyGUID,NEWID(),@UserName,@CreatedDt)    
			SET @CodeColID=SCOPE_IDENTITY()   

			EXEC	[spCOM_SetInsertResourceData] 'Name','Name',@CostCenterName,@UserName,1,@RESOURCEMAX output
			--Insert Name column definition TO ADM_CostCenterDef TABLE.  
			INSERT INTO ADM_CostCenterDef(CostCenterID,CostCenterName,SysTableName,UserColumnName,SysColumnName,UserColumnType,ResourceID,ColumnOrder,IsCostCenterUserDefined,IsColumnUserDefined,ColumnCostCenterID,IsMandatory,IsEditable,CompanyGUID,GUID,CreatedBy,CreatedDate)    
			VALUES(@CostCenterId,@CostCenterName,@Table,'Name','Name','TEXT',@RESOURCEMAX,0,0,0,0,0,0,@CompanyGUID,NEWID(),@UserName,@CreatedDt)    
			SET @NameColID=SCOPE_IDENTITY()   
	

			EXEC	[spCOM_SetInsertResourceData] 'AliasName','AliasName',@CostCenterName,@UserName,1,@RESOURCEMAX output
			--Insert Name column definition TO ADM_CostCenterDef TABLE.  
			INSERT INTO ADM_CostCenterDef(CostCenterID,CostCenterName,SysTableName,UserColumnName,SysColumnName,UserColumnType,ResourceID,ColumnOrder,IsCostCenterUserDefined,IsColumnUserDefined,ColumnCostCenterID,IsMandatory,IsEditable,CompanyGUID,GUID,CreatedBy,CreatedDate)    
			VALUES(@CostCenterId,@CostCenterName,@Table,'AliasName','AliasName','TEXT',@RESOURCEMAX,0,0,0,0,0,0,@CompanyGUID,NEWID(),@UserName,@CreatedDt)    
			--SET @NameColID=SCOPE_IDENTITY()   



			--CreditDays,CreditLimit,PurchaseAccount,SalesAccount 
			 EXEC	[spCOM_SetInsertResourceData] 'Status','Status',@CostCenterName,@UserName,1,@RESOURCEMAX output
			--Insert status column definition TO ADM_CostCenterDef TABLE.  
			INSERT INTO ADM_CostCenterDef(CostCenterID,CostCenterName,SysTableName,UserColumnName,SysColumnName,UserColumnType,ResourceID,ColumnOrder,IsCostCenterUserDefined,IsColumnUserDefined,ColumnCostCenterID,IsMandatory,IsEditable,CompanyGUID,GUID,CreatedBy,CreatedDate)    
			VALUES(@CostCenterId,@CostCenterName,@Table,'Status','StatusID','INT',@RESOURCEMAX,0,0,0,0,0,0,@CompanyGUID,NEWID(),@UserName,@CreatedDt)    

				
			EXEC	[spCOM_SetInsertResourceData] 'Group','Group',@CostCenterName,@UserName,1,@RESOURCEMAX output
			--Insert Name column definition TO ADM_CostCenterDef TABLE.  
			INSERT INTO ADM_CostCenterDef(CostCenterID,CostCenterName,SysTableName,UserColumnName,SysColumnName,UserColumnType,ResourceID,ColumnOrder,IsCostCenterUserDefined,IsColumnUserDefined,ColumnCostCenterID,IsMandatory,IsEditable,CompanyGUID,GUID,CreatedBy,CreatedDate)    
			VALUES(@CostCenterId,@CostCenterName,@Table,'Group','IsGroup','INT',@RESOURCEMAX,0,0,0,0,0,0,@CompanyGUID,NEWID(),@UserName,@CreatedDt)    

			EXEC	[spCOM_SetInsertResourceData] 'CreditDays','CreditDays',@CostCenterName,@UserName,1,@RESOURCEMAX output
			--Insert Name column definition TO ADM_CostCenterDef TABLE.  
			INSERT INTO ADM_CostCenterDef(CostCenterID,CostCenterName,SysTableName,UserColumnName,SysColumnName,UserColumnType,ResourceID,ColumnOrder,IsCostCenterUserDefined,IsColumnUserDefined,ColumnCostCenterID,IsMandatory,IsEditable,CompanyGUID,GUID,CreatedBy,CreatedDate)    
			VALUES(@CostCenterId,@CostCenterName,@Table,'CreditDays','CreditDays','INT',@RESOURCEMAX,0,0,0,0,0,0,@CompanyGUID,NEWID(),@UserName,@CreatedDt)    
		 
			EXEC	[spCOM_SetInsertResourceData] 'CreditLimit','CreditLimit',@CostCenterName,@UserName,1,@RESOURCEMAX output
			--Insert Name column definition TO ADM_CostCenterDef TABLE.  
			INSERT INTO ADM_CostCenterDef(CostCenterID,CostCenterName,SysTableName,UserColumnName,SysColumnName,UserColumnType,ResourceID,ColumnOrder,IsCostCenterUserDefined,IsColumnUserDefined,ColumnCostCenterID,IsMandatory,IsEditable,CompanyGUID,GUID,CreatedBy,CreatedDate)    
			VALUES(@CostCenterId,@CostCenterName,@Table,'CreditLimit','CreditLimit','FLOAT',@RESOURCEMAX,0,0,0,0,0,0,@CompanyGUID,NEWID(),@UserName,@CreatedDt)    
			

			EXEC	[spCOM_SetInsertResourceData] 'PurchaseAccount','PurchaseAccount',@CostCenterName,@UserName,1,@RESOURCEMAX output
			--Insert Name column definition TO ADM_CostCenterDef TABLE.  
			INSERT INTO ADM_CostCenterDef(CostCenterID,CostCenterName,SysTableName,UserColumnName,SysColumnName,UserColumnType,ResourceID,ColumnOrder,IsCostCenterUserDefined,IsColumnUserDefined,ColumnCostCenterID,IsMandatory,IsEditable,CompanyGUID,GUID,CreatedBy,CreatedDate)    
			VALUES(@CostCenterId,@CostCenterName,@Table,'PurchaseAccount','PurchaseAccount','INT',@RESOURCEMAX,0,0,0,0,0,0,@CompanyGUID,NEWID(),@UserName,@CreatedDt)    

			EXEC	[spCOM_SetInsertResourceData] 'SalesAccount','SalesAccount',@CostCenterName,@UserName,1,@RESOURCEMAX output
			--Insert Name column definition TO ADM_CostCenterDef TABLE.  
			INSERT INTO ADM_CostCenterDef(CostCenterID,CostCenterName,SysTableName,UserColumnName,SysColumnName,UserColumnType,ResourceID,ColumnOrder,IsCostCenterUserDefined,IsColumnUserDefined,ColumnCostCenterID,IsMandatory,IsEditable,CompanyGUID,GUID,CreatedBy,CreatedDate)    
			VALUES(@CostCenterId,@CostCenterName,@Table,'SalesAccount','SalesAccount','INT',@RESOURCEMAX,0,0,0,0,0,0,@CompanyGUID,NEWID(),@UserName,@CreatedDt)    

			--Inserting root node to costcenter  
			SET @SQL='INSERT INTO '+@Table+'(Code,Name,StatusID,Depth,ParentID,lft,rgt,[CreditDays],[CreditLimit],[PurchaseAccount],[SalesAccount],IsGroup,CompanyGUID,GUID,CreatedBy,CreatedDate)    
			VALUES('''+@CostCenterName+''','''+@CostCenterName+''','+CONVERT(NVARCHAR,@ActiveStatusId)+',0,0,1,2,0,0,0,0,1,'''+@CompanyGUID+''',NEWID(),'''+@UserName+''','+CONVERT(NVARCHAR,@CreatedDt)+')'    
			Exec(@SQL)    

			 
			--Insert costcenter gridview columns definition  
			INSERT INTO ADM_GridViewColumns(GridViewID,CostCenterColID,ColumnOrder,ColumnWidth,CreatedBy,CreatedDate)    
			VALUES(@GridViewID,@CodeColID,0,200,@UserName,@CreatedDt)  
			 
			INSERT INTO ADM_GridViewColumns(GridViewID,CostCenterColID,ColumnOrder,ColumnWidth,CreatedBy,CreatedDate)    
			VALUES(@GridViewID,@NameColID,1,200,@UserName,@CreatedDt)  
			
			 INSERT INTO [ADM_GridView]    
			([CostCenterID]    
			,[FeatureID]    
			,[ViewName] 
			,[RoleID]    
			,[UserID]    
			,[IsViewRoleDefault]    
			,[IsViewUserDefault]    
			,[IsUserDefined]    
			,[CompanyGUID]    
			,[GUID]     
			,[CreatedBy]    
			,[CreatedDate],ChunkCount, DefaultColID , DefaultFilterID)    
		 VALUES (98,@CostCenterId,'Default view',1,1,1,1,0,'admin'
			,newid(),'admin',22,1000 ,-1, 5)    
       
		set @GridViewID=SCOPE_IDENTITY()--Getting GridViewID 
			 
			 INSERT INTO [ADM_GridViewColumns]    
			([GridViewID],CostCenterColID,[ColumnFilter],[ColumnOrder]    
			,[ColumnWidth],[Description] ,[IsCode]   ,[CreatedBy]    ,[CreatedDate],ColumnType)  
			values(@GridViewID,@namecolid,'',0,200,'',0,'admin',22,1)
			INSERT INTO [ADM_GridViewColumns]    
			([GridViewID],CostCenterColID,[ColumnFilter],[ColumnOrder]    
			,[ColumnWidth],[Description] ,[IsCode]   ,[CreatedBy]    ,[CreatedDate],ColumnType)  
			values(@GridViewID,@codecolid,'',0,200,'',0,'admin',22,1)
		    
			INSERT INTO [ADM_GridViewColumns]    
			([GridViewID],CostCenterColID,[ColumnFilter],[ColumnOrder]    
			,[ColumnWidth],[Description] ,[IsCode]   ,[CreatedBy]    ,[CreatedDate],ColumnType)  
			values(@GridViewID,@namecolid,'',0,200,'',0,'admin',22,2)
			INSERT INTO [ADM_GridViewColumns]    
			([GridViewID],CostCenterColID,[ColumnFilter],[ColumnOrder]    
			,[ColumnWidth],[Description] ,[IsCode]   ,[CreatedBy]    ,[CreatedDate],ColumnType)  
			values(@GridViewID,@codecolid,'',0,200,'',0,'admin',22,2)


			--Insert costcenter listview definition  
			INSERT INTO ADM_ListView(FeatureID,CostCenterID,ListViewName,ListViewTypeID,UserID,RoleID,IsUserDefined,GUID,CreatedBy,CreatedDate)    
			VALUES(@CostCenterId,@CostCenterId,@CostCenterName,1,1,1,0,NEWID(),@UserName,@CreatedDt)   --REGISTER FEATURE WITH LISTVIEW  
			SET @GridViewID=SCOPE_IDENTITY()    

			--Insert costcenter listview columns definition  
			INSERT INTO ADM_ListViewColumns(ListViewID,CostCenterColID,ColumnOrder,ColumnWidth,CreatedBy,CreatedDate)    
			VALUES(@GridViewID,@CodeColID,0,200,@UserName,@CreatedDt)    

			INSERT INTO ADM_ListViewColumns(ListViewID,CostCenterColID,ColumnOrder,ColumnWidth,CreatedBy,CreatedDate)    
			VALUES(@GridViewID,@NameColID,1,200,@UserName,@CreatedDt) 
			
			----INSERT INTO QUICK VIEW 
			--INSERT INTO [ADM_QuickViewDef]([CostCenterID],[CostCenterColID],[FeatureID],[FeatureActionID],[ColumnOrder],[IsGroupView],[IsUserDefined],[UserID],[RoleID],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])
			--VALUES(@CostCenterId,@CodeColID,@CostCenterId ,1 ,0,0,0,@UserID,1,@CompanyGUID,NEWID() ,@UserName ,@CreatedDt)

			--INSERT INTO [ADM_QuickViewDef]([CostCenterID],[CostCenterColID],[FeatureID],[FeatureActionID],[ColumnOrder],[IsGroupView],[IsUserDefined],[UserID],[RoleID],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])
			--VALUES(@CostCenterId,@NameColID,@CostCenterId ,1 ,1,0,0,@UserID,1,@CompanyGUID,NEWID() ,@UserName ,@CreatedDt)

--			INSERT INTO [ADM_QuickViewDef]([CostCenterID],[CostCenterColID],[FeatureID],[FeatureActionID],[ColumnOrder],IsGroupView],[IsUserDefined],[UserID],[RoleID],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])
--			VALUES(@CostCenterId,@CodeColID,@CostCenterId ,1 ,0,0,0,@UserID,1,@CompanyGUID,NEWID() ,@UserName ,@CreatedDt)
			
				
				EXEC	[spCOM_SetInsertResourceData] 'Is Code Auto Generate','Is Code Auto Generate',@CostCenterName,@UserName,1,@RESOURCEMAX output
			INSERT INTO  [COM_CostCenterPreferences]
           ([CostCenterID],[FeatureID],[ResourceID],[Name],[Value],[DefaultValue],[GUID],[Description],[CreatedBy],[CreatedDate])          
		   VALUES
           (@CostCenterId,@CostCenterId,@RESOURCEMAX,'IsCodeAutoGen','False','False',newid(),'Preference for '+@CostCenterName, @UserName ,convert(float,getdate()))

				EXEC	[spCOM_SetInsertResourceData] 'Is Duplicate Name Allowed','Is Duplicate Name Allowed',@CostCenterName,@UserName,1,@RESOURCEMAX output
			INSERT INTO  [COM_CostCenterPreferences]
			   ([CostCenterID],[FeatureID],[ResourceID],[Name],[Value],[DefaultValue],[GUID],[Description],[CreatedBy],[CreatedDate])          
			VALUES
			   (@CostCenterId,@CostCenterId,@RESOURCEMAX,'IsDuplicateNameAllowed','False','False',newid(),'Preference for '+@CostCenterName, @UserName ,convert(float,getdate()))
           
           	--INSERT EXTRA FIELDS
			EXEC spCOM_SetCostCenterExtraFields @CostCenterId,50,@CompanyGUID,@GUID,@UserName,@UserID,@RoleID,@LangID    

			--CREATE COSCENTER IN MENU
			--EXEC spCOM_CreateCostCenterMenu @CostCenterId,@CostCenterName,@UserName ,@UserID,@CompanyGUID
			
		END
		---Create New Cost center(Table creation and some inserts)---  
		ELSE
		BEGIN
			
			UPDATE ADM_CostCenterDef
			SET CostCenterName=@CostCenterName
			WHERE CostCenterID=@CostCenterID

		END
       
COMMIT TRANSACTION 
SET NOCOUNT OFF;  
RETURN 1 
END TRY
BEGIN CATCH  
		--Return exception info [Message,Number,ProcedureName,LineNumber]  
		IF ERROR_NUMBER()=50000
		BEGIN
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
