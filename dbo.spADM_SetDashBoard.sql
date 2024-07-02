USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetDashBoard]
	@ID [int] = 0,
	@XML [nvarchar](max),
	@SelectedNodeID [int],
	@IsGroup [bit] = 0,
	@CompanyGUID [nvarchar](max),
	@UserID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY
SET NOCOUNT ON

	declare @DXML XML,@DashBoardID INT,@DT Float,@RIBBONID INT,@return INT,@RID INT,@RName nvarchar(50),@ResID INT
	DECLARE @lft INT,@rgt INT,@Selectedlft INT,@Selectedrgt INT,@Depth int,@ParentID INT  
	DECLARE @SelectedIsGroup bit  
	select * from adm_dashboard with(nolock) where dashboardid=@ID

	set @DT=convert(Float,getdate())
	set @DXML=@XML
	
	if(@ID=0)
	BEGIN 
		SELECT @DashBoardID=ISNULL(MAX(DashBoardID),0) +1 FROM ADM_DashBoard with(nolock)
		IF(@XML is not null and @XML <> '')
		BEGIN
			if not exists (select Distinct(DashBoardName) from ADM_DashBoard with(nolock) where dashboardname in (select X.value('@Heading','nvarchar(50)') from  @DXML.nodes('/XML/Rows') as Data(x)) )
				BEGIN
					select @SelectedNodeID=nodeid from adm_dashboard with(nolock) where dashboardid=@SelectedNodeID
 
				-- Set lft & rgt
				  SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
					from ADM_DashBoard with(NOLOCK) where nodeid=@SelectedNodeID  
				   
					--IF No Record Selected or Record Doesn't Exist  
					if(@SelectedIsGroup is null)   
					 select @SelectedNodeID=NodeID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
					 from ADM_DashBoard with(NOLOCK) where ParentID =0  
				         
					if(@SelectedIsGroup = 1)--Adding Node Under the Group  
					 BEGIN  
					  UPDATE ADM_DashBoard SET rgt = rgt + 2 WHERE rgt > @Selectedlft;  
					  UPDATE ADM_DashBoard SET lft = lft + 2 WHERE lft > @Selectedlft;  
					  set @lft =  @Selectedlft + 1  
					  set @rgt = @Selectedlft + 2  
					  set @ParentID = @SelectedNodeID  
					  set @Depth = @Depth + 1  
					 END  
					else if(@SelectedIsGroup = 0)--Adding Node at Same level  
					 BEGIN  
					  UPDATE ADM_DashBoard SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;  
					  UPDATE ADM_DashBoard SET lft = lft + 2 WHERE lft > @Selectedrgt;  
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
	
					
					insert into ADM_DashBoard(DashBoardID,DashBoardName,DashBoardType,ReportName,ReportID,AutoRefresh,RefreshRate,
					Filter,CompanyGUID,GUID,CreatedBy,CreatedDate,[Type],[TypeID],GraphType,TextField,NumericField,
					ShowGrid,TopRecords,lft,rgt,depth,parentid,Isgroup,RowNo,ColNo,RowSpan,ColSpan,ShowPoint,NumSeriesColor,Options,
					WidgetXML,Mode)
							select @DashBoardID,X.value('@Heading','nvarchar(50)'),X.value('@DashBoardType','nvarchar(50)'),X.value('@ScreenName','nvarchar(50)')
							,X.value('@ReportID','INT'),X.value('@AutoRefresh','bit'),X.value('@RefreshRate','float'),X.value('@Filter','bit')
							,@CompanyGUID,newid(),@UserID,@DT,X.value('@Type','nvarchar(50)'),X.value('@TypeID','INT')
							,X.value('@GraphType','INT'),X.value('@TextFields','nvarchar(max)'),X.value('@NumericFields','nvarchar(max)'),X.value('@ShowGrid','bit'),X.value('@TopRecords','int')
							,@lft,@rgt,@Depth,@Parentid,@IsGroup
							,isnull(X.value('@row','int'),0),isnull(X.value('@col','int'),0),isnull(X.value('@rowspan','int'),1),isnull(X.value('@colspan','int'),1), X.value('@ShowPoint','int')
							,X.value('@SeriesColor','nvarchar(max)'),isnull(X.value('@Options','nvarchar(max)'),convert(nvarchar(max),X.query('Options[1]')))
							,convert(nvarchar(max),X.query('Widget[1]')),isnull(X.value('@Mode','int'),0)
							from  @DXML.nodes('/XML/Rows') as Data(x)						
					set @return=SCOPE_IDENTITY()
					
					select @RID=DashBoardID,@RName=DashBoardName from ADM_DashBoard with(nolock) where NodeID=@return
					SELECT @RIBBONID=ISNULL(MAX(RibbonViewID),0)+1 FROM [ADM_RibbonView] with(nolock)
					IF @RIBBONID<50000
						set @RIBBONID=50001
					
					--IF not exists(select * from com_languageresources where ResourceData=@RName and Feature='DASHBOARD')
					--begin
						select @ResID=ISNULL(MAX(ResourceID),0)+1 FROM com_languageresources with(nolock) --where ResourceID<500000
						
						INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
						VALUES(@ResID,@RName,1,'English',@RName,'DASHBOARD')
					--end
					--ELSE
					--BEGIN
					--	select @ResID=ResourceID from com_languageresources where ResourceData=@RName and Feature='DASHBOARD'
					--END
					
					INSERT INTO [ADM_RibbonView]
						(	
							 [RibbonViewID],[TabID],[GroupID],[TabName],[TabResourceID],[GroupName] ,[GroupResourceID],[TabOrder] ,[GroupOrder],[FeatureID]
							,[FeatureActionID],[FeatureActionResourceID] ,[FeatureActionName] ,[IsEnabled],[ScreenName],[ScreenResourceID],[ImageType]
							,[ImagePath],[ToolTipTitleResourceID],[ToolTipTitle],[ToolTipImg],[ToolTipDescResourceID],[ToolTipDesc],[RoleID],[UserID]
							,[UserName],[CompanyGUID] ,[GUID],[Description],[CreatedBy],[CreatedDate],DrpID  , ColumnOrder  , DrpName , DrpResourceID      
						)
					VALUES
						(
							 @RIBBONID,1,2 ,'Home',33,'DashBoard',39,1,1,499
							,@RID,@ResID,@RName,1,@RName,@ResID,1
							,'DB_pie_chart_new.png',@ResID,NULL,'DB_pie_chart_new.png',@ResID,NULL,NULL,1
							,'ADMIN',@CompanyGUID,NEWID(),NULL,@UserID  ,CONVERT(FLOAT,GETDATE()),NULL,0,@RName, 39 
						)	
				END
				else
				BEGIN  
					RAISERROR('-393',16,1)  
				END 
		END 
	END
	ELSE
	BEGIN
		IF(@XML is not null and @XML <> '')
		BEGIN 
			declare @DashName nvarchar(50),@OldDashName nvarchar(50)  
			select @DashName=X.value('@Heading','nvarchar(50)') from  @DXML.nodes('/XML/Rows') as Data(x)
			
			if not exists (select Distinct(DashBoardName) from ADM_DashBoard with(nolock) where dashboardname=@DashName and DashBoardID<>@ID)
			BEGIN 
				select @OldDashName=DashBoardName from ADM_DashBoard with(nolock) where DashBoardID=@ID
				if(@IsGroup=1)
					update ADM_DashBoard set DashBoardName=@DashName where DashBoardID=@ID
				else 	
				begin
					select @lft=lft,@rgt=rgt,@Parentid=ParentID,@Depth=Depth  
					from ADM_DashBoard with(NOLOCK) where DashBoardID=@ID
					 
					delete from ADM_DashBoard where NodeID IN (
					select D.NodeID from ADM_DashBoard D with(nolock)
					left join @DXML.nodes('/XML/Rows') as Data(x) on D.NodeID=X.value('@NodeID','INT')
					where D.DashBoardID=@ID and X.value('@NodeID','INT') is null)
				
					update ADM_DashBoard
					set DashBoardName=X.value('@Heading','nvarchar(50)'),
						DashBoardType=X.value('@DashBoardType','nvarchar(50)'),
						ReportName=X.value('@ScreenName','nvarchar(50)'),
						ReportID=X.value('@ReportID','INT'),
						AutoRefresh=X.value('@AutoRefresh','bit'),
						RefreshRate=X.value('@RefreshRate','nvarchar(50)'),
						Filter=X.value('@Filter','bit'),					
						CreatedBy=@UserID,
						CreatedDate=@DT,
						[Type]=X.value('@Type','nvarchar(50)'),
						[TypeID]=X.value('@TypeID','INT'),
						GraphType=X.value('@GraphType','INT'),
						TextField=X.value('@TextFields','nvarchar(max)'),
						NumericField=X.value('@NumericFields','nvarchar(max)'),
						ShowGrid=X.value('@ShowGrid','bit'),
						TopRecords=X.value('@TopRecords','int'),
						RowNo=X.value('@row','int'),
						ColNo=X.value('@col','int'),
						RowSpan=X.value('@rowspan','int'),
						ColSpan=X.value('@colspan','int'),
						ShowPoint=X.value('@ShowPoint','int'),
						NumSeriesColor=X.value('@SeriesColor','nvarchar(max)'),
						Options=convert(nvarchar(max),X.query('Options[1]')),
						WidgetXML=convert(nvarchar(max),X.query('Widget[1]')),
						Mode=isnull(X.value('@Mode','int'),0)
					from  @DXML.nodes('/XML/Rows') as Data(x)
					where DashBoardID=@ID and NodeID=X.value('@NodeID','INT')

					SET @DashBoardID=@ID
					
					insert into ADM_DashBoard(DashBoardID,DashBoardName,DashBoardType,ReportName,ReportID,AutoRefresh,RefreshRate,
					Filter,CompanyGUID,GUID,CreatedBy,CreatedDate,[Type],[TypeID],GraphType,TextField,NumericField,
					ShowGrid,TopRecords,lft,rgt,depth,parentid,Isgroup,RowNo,ColNo,RowSpan,ColSpan,ShowPoint,NumSeriesColor,Options,WidgetXML,Mode)
					select @DashBoardID,X.value('@Heading','nvarchar(50)'),X.value('@DashBoardType','nvarchar(50)'),X.value('@ScreenName','nvarchar(50)')
					,X.value('@ReportID','INT'),X.value('@AutoRefresh','bit'),X.value('@RefreshRate','float'),X.value('@Filter','bit')
					,@CompanyGUID,newid(),@UserID,@DT,X.value('@Type','nvarchar(50)'),X.value('@TypeID','INT')
					,X.value('@GraphType','INT'),X.value('@TextFields','nvarchar(max)'),X.value('@NumericFields','nvarchar(max)'),X.value('@ShowGrid','bit'),X.value('@TopRecords','int')
					,@lft,@rgt,@Depth,@Parentid,0
					,X.value('@row','int'),X.value('@col','int'),X.value('@rowspan','int'),X.value('@colspan','int'),X.value('@ShowPoint','int')
					,X.value('@SeriesColor','nvarchar(max)'),convert(nvarchar(max),X.query('Options[1]')),convert(nvarchar(max),X.query('Widget[1]')),isnull(X.value('@Mode','int'),0)
					from  @DXML.nodes('/XML/Rows') as Data(x)
					where X.value('@NodeID','INT') is null or X.value('@NodeID','INT')=0
					
					select @ResID=Resourceid from com_languageresources with(nolock)
					where ResourceName=@OldDashName
					and Feature='DASHBOARD'
											
					IF(@ResID is not null or @ResID<>0)
					BEGIN
						update com_languageresources 
						set ResourceName=@DashName, ResourceData=@DashName where Resourceid=@ResID
					END
					
					update ADM_RibbonView set FeatureActionName=@DashName,ScreenName=@DashName
					from  @DXML.nodes('/XML/Rows') as Data(x)
					where FeatureActionID=@ID AND FeatureID=499
				end
			END
			else
			BEGIN  
				RAISERROR('-393',16,1)  
			END 
		END		
	END
	
COMMIT TRANSACTION
--ROLLBACK TRANSACTION
SET NOCOUNT OFF;
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID 
RETURN @DashBoardID
END TRY
BEGIN CATCH  
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
