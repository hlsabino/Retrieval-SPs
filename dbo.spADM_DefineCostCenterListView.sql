USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_DefineCostCenterListView]
	@ListViewTypeID [int] = 0,
	@CostCenterID [int],
	@ListViewName [nvarchar](300),
	@ListViewColumnsXML [nvarchar](max),
	@Filter [nvarchar](max),
	@FILTERXML [nvarchar](max),
	@GroupSearchFilter [nvarchar](300),
	@GroupFilterXML [nvarchar](max),
	@SearchOption [int],
	@ListViewPageSize [int],
	@ListViewDelaytime [int],
	@SearchOldValue [bit],
	@IgnoreSpecial [int],
	@IgnoreUserWise [bit],
	@FilterQOH [bit],
	@GUID [varchar](50),
	@CompanyGUID [varchar](50),
	@UserName [nvarchar](50),
	@RoleID [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
	--Declaration Section
	DECLARE @TempGuid nvarchar(50),@HasAccess bit,@ListViewID INT
	DECLARE @Dt float,@XML xml

	--SP Required Parameters Check
	if(@CostCenterID=0)
	BEGIN			 
		RAISERROR('-100',16,1)				 
	END

	--User acces check
	IF @ListViewTypeID=0
	BEGIN
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,27,1)
	END
	ELSE
	BEGIN
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,27,3)
	END
	IF @HasAccess=0
	BEGIN
		RAISERROR('-105',16,1)
	END

	SET @Dt=convert(float,getdate())--Getting Current Date
	 
	IF @ListViewTypeID=0--CREATE CostCenterListView--
	BEGIN
		SELECT @ListViewTypeID=ISNULL(MAX(ListViewTypeID),0)+1 FROM [ADM_ListView] WITH(NOLOCK) WHERE [CostCenterID]=@CostCenterID
		INSERT INTO [ADM_ListView]
				   ([CostCenterID]
				   ,[FeatureID]
				   ,[RoleID]
				   ,[UserID]
				   ,[CompanyGUID]
				   ,[GUID] 
				   ,[CreatedBy]
				   ,[CreatedDate]
				   ,FilterXML
				   ,SearchFilter
				   ,ListViewTypeID
				   ,ListViewName
				   ,IsUserDefined
				   ,SearchOption
				   	,ListViewPageSize
					,ListViewDelaytime
				   ,SearchOldValue,IgnoreUserWise,FilterQOH,IgnoreSpecial
				   ,GroupSearchFilter
				   ,GroupFilterXML)
			 VALUES
				   (@CostCenterID
				   ,@CostCenterID
				   ,@RoleID 
				   ,@UserID  
				   ,@CompanyGUID  
				   ,newid()   
				   ,@UserName  
				   ,@Dt 
				   ,@FILTERXML
				   ,@Filter
				   ,@ListViewTypeID
				   ,@ListViewName
				   ,1
				   ,@SearchOption
				   ,@ListViewPageSize
				   ,@ListViewDelaytime
				   ,@SearchOldValue,@IgnoreUserWise,@FilterQOH,@IgnoreSpecial
				   ,@GroupSearchFilter
				   ,@GroupFilterXML)

		SET @ListViewID=SCOPE_IDENTITY()--Get ListViewID
	END
	Else--TO UPDATE RECORD
	BEGIN 
		
		select @TempGuid=[GUID],@ListViewID=ListViewID from [ADM_ListView]  WITH(NOLOCK) 
		WHERE ListViewTypeID=@ListViewTypeID AND COSTCENTERID=@CostCenterID
		 
		if(@TempGuid!=@Guid)
		BEGIN
			RAISERROR('-101',16,1)
		END

		UPDATE [ADM_ListView]
		SET [CostCenterID] = @CostCenterID  
		,[FeatureID] = @CostCenterID
	    ,[RoleID] = @RoleID  
		,[UserID] = @UserID          
		,[CompanyGUID] = @CompanyGUID          
		,[GUID] = newid() 
		,[ModifiedBy] = @UserName 
		,[ModifiedDate] = @Dt
		,FilterXML=@FILTERXML
		,SearchFilter=@Filter
		,ListViewName=@ListViewName
		,SearchOption=@SearchOption
		,SearchOldValue=@SearchOldValue
		,IgnoreUserWise=@IgnoreUserWise
		,FilterQOH=@FilterQOH
		,ListViewPageSize=@ListViewPageSize
		,ListViewDelaytime=@ListViewDelaytime
		,IgnoreSpecial=@IgnoreSpecial
		,GroupSearchFilter=@GroupSearchFilter
		,GroupFilterXML=@GroupFilterXML
		WHERE ListViewTypeID=@ListViewTypeID and COSTCENTERID=@CostCenterID

	END
	
	SET @XML=@ListViewColumnsXML	--Set @ListViewColumnsXML in XMl variable
	
	DELETE FROM [ADM_ListViewColumns]    
	WHERE [ListViewID]=@ListViewID  

	--Insert into ListView Columns From XML
	INSERT INTO [ADM_ListViewColumns]
		   ([ListViewID]
		   ,[CostCenterColID]
		   ,[ColumnOrder]
		   ,[ColumnWidth]
		   ,[DocumentsList]
		   ,[Description]  
		   ,[CreatedBy]
		   ,[CreatedDate]
		   ,ColumnType
		   ,IsParent,IsCode,SearchColID,SearchColName)         
	SELECT @ListViewID,X.value('@CostCenterColID','INT')
		   ,X.value('@ColumnOrder','int')
		   ,X.value('@ColumnWidth','int')
		   ,X.value('@DocumentsList','nvarchar(max)')
		   ,X.value('@Description','nvarchar(500)')
		   ,@UserName,convert(float,getdate())
		   ,X.value('@ColumnType','int')
		   ,X.value('@IsParent','BIT') ,X.value('@IsCode','BIT')
		   ,X.value('@SearchColID','INT')
		   ,X.value('@SearchColName','nvarchar(max)')
	from @XML.nodes('/XML/Row') as Data(X)

COMMIT TRANSACTION  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;  
RETURN @ListViewID  
END TRY  
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN 
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
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
