USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_Widgets]
	@Type [int],
	@WID [bigint],
	@Name [nvarchar](50),
	@WType [int],
	@SelectedNodeID [bigint],
	@IsGroup [bit] = 0,
	@OptionsXML [nvarchar](max) = null,
	@AccountsXML [nvarchar](max) = null,
	@UserName [nvarchar](50),
	@UserID [nvarchar](50),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  

declare @RetValue bigint
DECLARE @lft bigint,@rgt bigint,@Selectedlft bigint,@Selectedrgt bigint,@Depth int,@ParentID bigint,@SelectedIsGroup bit,@Width int

set @RetValue=1

	if(@Type=0)
	begin	
		if @WID=0
		begin
			if @SelectedNodeID=0
				set @SelectedNodeID=1
			--To Set Left,Right And Depth of Record  
			SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
			from [ADM_Widgets] with(NOLOCK) where ID=@SelectedNodeID  
		   
			--IF No Record Selected or Record Doesn't Exist  
			if(@SelectedIsGroup is null)   
			 select @SelectedNodeID=ID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
			 from [ADM_Widgets] with(NOLOCK) where ParentID =0  
		         
			if(@SelectedIsGroup = 1)--Adding Node Under the Group  
			 BEGIN  
			  UPDATE ADM_Widgets SET rgt = rgt + 2 WHERE rgt > @Selectedlft;  
			  UPDATE ADM_Widgets SET lft = lft + 2 WHERE lft > @Selectedlft;  
			  set @lft =  @Selectedlft + 1  
			  set @rgt = @Selectedlft + 2  
			  set @ParentID = @SelectedNodeID  
			  set @Depth = @Depth + 1  
			 END  
			else if(@SelectedIsGroup = 0)--Adding Node at Same level  
			 BEGIN  
			  UPDATE ADM_Widgets SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;  
			  UPDATE ADM_Widgets SET lft = lft + 2 WHERE lft > @Selectedrgt;  
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
			 
			 if exists (select ID from ADM_Widgets with(nolock) where Name=@Name)
				RAISERROR('-112',16,1)

			insert into ADM_Widgets(Name,OptionsXML,AccountsXML,CreatedBy,CreatedDate,WType,Depth,ParentID,lft,rgt,IsGroup)
			values(@Name,@OptionsXML,@AccountsXML,@UserName,convert(float,getdate()),@WType,@Depth,@ParentID,@lft,@rgt,@IsGroup)
			set @RetValue=SCOPE_IDENTITY()		
			select * from ADM_Widgets
		end
		else
		begin
			set @RetValue=@WID			
			update ADM_Widgets set Name=@Name,OptionsXML=@OptionsXML,AccountsXML=@AccountsXML where ID=@WID
		end
	end
	else if(@Type=1)
	begin
		select OptionsXML,AccountsXML,WType from ADM_Widgets with(nolock) where ID=@WID
		select @WType=WType from ADM_Widgets with(nolock) where ID=@WID
		if @WType=14 or @WType=15 or @WType=102
			select DefaultPreferences from adm_revenureports with(nolock) where ReportID=13		
	end
	else if(@Type=2)
	begin
		select * from ADM_Widgets with(nolock) where ID=@WID
	end
	else if(@Type=3)
		select ID,Name,WType from ADM_Widgets with(nolock) where IsGroup=0 order by Name
	else if(@Type=4)
	begin
		set @RetValue=0
		if @WID>1000
		begin
			if exists (select ID from ADM_Widgets with(nolock) where ID=@WID and IsGroup=1)
				and exists (select ID from ADM_Widgets with(nolock) where ParentID=@WID)
			begin
				RAISERROR('-225',16,1)
			end
			else if exists (select * from ADM_DashBoard with(nolock) where ReportID=@WID and TypeID=6)
				select DashboardName from ADM_DashBoard with(nolock) where ReportID=@WID and TypeID=6
			else
			begin
				SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft + 1 FROM ADM_Widgets WITH(NOLOCK) WHERE ID=@WID
		
				delete from ADM_Widgets where ID=@WID
				set @RetValue=@WID
				
				--Update left and right extent to set the tree
				UPDATE ADM_Widgets SET rgt = rgt - @Width WHERE rgt > @rgt;
				UPDATE ADM_Widgets SET lft = lft - @Width WHERE lft > @rgt;
			end
		end
	end
	else if(@Type=5)
	begin
		select OptionsXML,AccountsXML from ADM_Widgets with(nolock) where ID=@WID
	end
	else if(@Type=6)
	begin
		select @OptionsXML=Value from ADM_GlobalPreferences with(nolock) where Name='Dimension List'
		if @OptionsXML is not null and @OptionsXML!=''
		begin
			declare @Tbl as Table(ID int)
			insert into @Tbl
			exec SPSplitString @OptionsXML,','
			select FeatureID,Name from ADM_Features F with(nolock) join @Tbl T on T.ID=F.FeatureID
			where F.FeatureID>50000 and F.FeatureID<50100
		end
		else
			select 1 FeatureID where 1!=1
	end
	else if(@Type=7)
	begin
		select Name from ADM_Widgets with(nolock) where ID=@WID
	end

COMMIT TRANSACTION
--rollback TRANSACTION

SET NOCOUNT OFF;    
RETURN @RetValue
END TRY    
BEGIN CATCH    
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
