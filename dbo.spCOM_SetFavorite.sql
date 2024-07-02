USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetFavorite]
	@Data [nvarchar](max) = null,
	@FavID [int] = 0,
	@FavName [nvarchar](100),
	@IsDefault [bit],
	@OptionsXML [nvarchar](max),
	@UserName [nvarchar](50),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY  
SET NOCOUNT ON;    
   
	--SP Required Parameters Check  
	IF @UserID IS NULL OR @UserID=''  
	BEGIN  
		RAISERROR('-100',16,1)  
	END
	declare @Dt float,@RID INT,@RName nvarchar(50),@ResID INT 
	select @ResID=ISNULL(MAX(ResourceID),0) FROM com_languageresources with(nolock) --where ResourceID<500000  
	set @Dt=CONVERT(FLOAT,GETDATE())
--    select @FavID
 IF(@Data<>'<XML></XML>')
 BEGIN
	if @FavID>0
	begin
		DELETE FROM LR FROM COM_Favourite F WITH(NOLOCK)
		JOIN COM_LanguageResources LR WITH(NOLOCK) ON F.ResourceID=LR.ResourceID
		WHERE F.FavID=@FavID and (F.TypeID=2 or F.TypeID=0)
		
		update COM_Favourite set FavName=@FavName,OptionsXML=@OptionsXML WHERE ID=@FavID
		DELETE FROM COM_Favourite WHERE FavID=@FavID and (TypeID=2 or TypeID=0)
	end
	else
	begin
		if exists (select top 1 FavName from COM_Favourite with(nolock) where FavName=@FavName)
		BEGIN  
			RAISERROR('-112',16,1)  
		END
				  
	    SET @ResID=@ResID+1
		
		insert into COM_Favourite(TypeID,FavID,FavName,FeatureID,FeatureactionID,IsReport,DisplayName,RowNo,ColumnNo,ShortCutKey,CreatedBy,CreatedDt,OptionsXML,ResourceID)
		values(1,0,@FavName,0,0,0,'',null,null,null,@UserName,@Dt,@OptionsXML,@ResID)
		set @FavID=SCOPE_IDENTITY()
	  
	    INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])  
	    VALUES(@ResID,@FavName,1,'English',@FavName,'Favorites')  
	    INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])  
  	    VALUES(@ResID,@FavName,2,'Arabic',@FavName+'-AR','Favorites')

		insert into ADM_Assign(CostCenterID,NodeID,UserID,RoleID,GroupID,CreatedBy,CreatedDate)
		select 69,@FavID,@UserID,0,0,@UserName,@Dt
	end	
	
	DECLARE @XML XML,@COUNT INT,@I INT ,@R INT,@C INT   
	SET @XML=@Data  
	
	SELECT @COUNT=COUNT(A.value('@FeatureActionID','INT')),@I=1	FROM @XML.nodes('/XML/Row') as Data(A) 
	WHILE(@I<=@COUNT)
	BEGIN
		SET @ResID=@ResID+1
		INSERT INTO COM_Favourite(TypeID,FavID,FeatureactionID,DisplayName,RowNo,ColumnNo,IsReport,ShortCutKey,FavName,
		CreatedBy,CreatedDt,FeatureID,Link,Category,ResourceID)  
		SELECT 2,@FavID,A.value('@FeatureActionID','INT'),  
		A.value('@DisplayName','nvarchar(300)'),  
		A.value('@R','int'),  
		A.value('@ColumnNo','int'),  
		A.value('@isReport','int'),  
		A.value('@ShortcutKey','nvarchar(300)'),  
		@FavName,--A.value('@FavoriteName','nvarchar(300)'),  
		@UserName,@Dt
		,A.value('@FeatureID','INT')
		,A.value('@Link','nvarchar(max)')
		,A.value('@Category','nvarchar(100)'),@ResID
		FROM @XML.nodes('/XML/Row') as Data(A) WHERE A.value('@RowNo','INT')=@I
		--order by A.value('@RowNo','INT') ,	A.value('@ColumnNo','INT')
		
		if(@IsDefault=1)
		begin
			declare @DefaultFavID INT
			select @DefaultFavID=FavID from COM_Favourite with(nolock) where TypeID=3 and FeatureactionID=@UserID
			if @DefaultFavID is null
				insert into COM_Favourite(TypeID,FavID,FavName,FeatureID,FeatureactionID,IsReport,DisplayName,RowNo,ColumnNo,ShortCutKey,CreatedBy,CreatedDt,ResourceID)
				values(3,@FavID,null,0,@UserID,0,'',null,null,null,@UserName,@Dt,@ResID)
			else
				update COM_Favourite set FavID=@FavID WHERE TypeID=3 and FeatureactionID=@UserID
		end
		--		  
		  INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])  
		  SELECT @ResID,A.value('@DisplayName','nvarchar(300)'),1,'English',A.value('@DisplayName','nvarchar(300)'),'Favorites'
		  FROM @XML.nodes('/XML/Row') as Data(A) WHERE A.value('@RowNo','INT')=@I
		  INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])  
		  SELECT @ResID,A.value('@DisplayName','nvarchar(300)'),2,'Arabic',A.value('@DisplayName','nvarchar(300)')+'-AR','Favorites'
		  FROM @XML.nodes('/XML/Row') as Data(A) WHERE A.value('@RowNo','INT')=@I
		SET @I=@I+1
	END
	
  
	--
	select * from COM_Favourite with(nolock) where FavID=@FavID
  END	

COMMIT TRANSACTION    
--ROLLBACK TRANSACTION  
 SET NOCOUNT OFF;    
 SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=100 AND LanguageID=@LangID      
RETURN @FavID
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
