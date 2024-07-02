USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SaveImportDetails]
	@ProfileID [int],
	@ProfileName [nvarchar](100),
	@FileName [nvarchar](100),
	@XML [nvarchar](max),
	@SelectedNodeID [bigint],
	@IsGroup [bit],
	@IsGet [bit],
	@UserName [nvarchar](50),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
SET NOCOUNT ON      
BEGIN TRY      

	--Declaration Section      
	DECLARE  @DATA XML,@COUNT INT,@I INT, @Dt float,@HasAccess bit
	SET @DATA=@XML      
	declare @AccID INT
	set @Accid=0
	 
	SET @Dt=convert(float,getdate())--Setting Current Date
	 if(@IsGet=1)
	 BEGIN
		select * from ADM_ImportDef where ProfileID=@ProfileID
	 END
	 else
	 BEGIN 
		if(@ProfileID=0)
		BEGIN 
			DECLARE @lft bigint,@rgt bigint,@Selectedlft bigint,@Selectedrgt bigint,@Depth int,@ParentID bigint
			DECLARE @SelectedIsGroup bit

			if @SelectedNodeID=0
				set @SelectedNodeID=1
				
			--To Set Left,Right And Depth of Record
			SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth
			from ADM_ImportDef with(NOLOCK) where ProfileID=@SelectedNodeID

			--IF No Record Selected or Record Doesn't Exist
			IF(@SelectedIsGroup is null) 
				select @SelectedNodeID=ProfileID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth
				from ADM_ImportDef with(NOLOCK) where ParentID =0
						
			IF(@SelectedIsGroup = 1)--Adding Node Under the Group
			BEGIN
				UPDATE ADM_ImportDef SET rgt = rgt + 2 WHERE rgt > @Selectedlft;
				UPDATE ADM_ImportDef SET lft = lft + 2 WHERE lft > @Selectedlft;
				SET @lft =  @Selectedlft + 1
				SET @rgt =	@Selectedlft + 2
				SET @ParentID = @SelectedNodeID
				SET @Depth = @Depth + 1
			END
			ELSE IF(@SelectedIsGroup = 0)--Adding Node at Same level
			BEGIN
				UPDATE ADM_ImportDef SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;
				UPDATE ADM_ImportDef SET lft = lft + 2 WHERE lft > @Selectedrgt;
				SET @lft =  @Selectedrgt + 1
				SET @rgt =	@Selectedrgt + 2 
			END
			ELSE  --Adding Root
			BEGIN
					SET @lft =  1
					SET @rgt =	2 
					SET @Depth = 0
					SET @ParentID =0
					SET @IsGroup=1
			END
				
			INSERT INTO ADM_ImportDef ([ProfileName],[FileName],[Structure],[CreatedDate],[CreatedBy],[IsGroup],[Depth],[ParentID],[lft],[rgt],statusid)
			VALUES (@ProfileName,@FileName,@XML,@Dt,@UserName,@IsGroup,@Depth,@ParentID,@lft,@rgt,1) 
			set @ProfileID=scope_identity()
		END 
		ELSE
		BEGIN
			UPDATE ADM_ImportDef SET ProfileName=@ProfileName,
			FileName=@FileName, 
			Structure=@XML, 
			ModifiedBy=@UserName,
			ModifiedDate=@Dt 
			where ProfileID=@ProfileID     
		END
	END
COMMIT TRANSACTION        

SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)       
WHERE ErrorNumber=100 AND LanguageID=@LangID          
SET NOCOUNT OFF;        
RETURN @ProfileID        
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
 ELSE      
 BEGIN      
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine      
  FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID      
 END      
 ROLLBACK TRANSACTION      
 SET NOCOUNT OFF        
 RETURN -999         
END CATCH    
   
      
      

GO
