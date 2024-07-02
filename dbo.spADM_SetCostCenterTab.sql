USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetCostCenterTab]
	@COSTCENTERID [int],
	@CCTabID [int] = 0,
	@TabName [nvarchar](50),
	@QuickViewCCID [int],
	@QuickViewID [int],
	@CCIDValues [nvarchar](max) = null,
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
SET NOCOUNT ON    
BEGIN TRY    
	
	IF EXISTS (SELECT * FROM ADM_CostCenterTab with(nolock) WHERE CostCenterID=@COSTCENTERID AND CCTabName=@TabName AND CCTabID<>@CCTabID)
			RAISERROR('-148',16,1)  
			
	IF @QuickViewCCID>0	
		IF EXISTS (SELECT * FROM ADM_CostCenterTab with(nolock) WHERE CostCenterID=@COSTCENTERID AND QuickViewCCID=@QuickViewCCID AND CCTabID<>@CCTabID)
			RAISERROR('-149',16,1)
		
	IF @CCTabID=0
	BEGIN	
		DECLARE @ResourceID INT, @TabOrder INT

		EXEC [spCOM_SetInsertResourceData] @TabName,@TabName,@TabName,1,1,@ResourceID OUTPUT    

		SELECT @TabOrder = ISNULL(MAX(TABORDER),0) +1 FROM ADM_CostCenterTab WITH(NOLOCK) WHERE COSTCENTERID = @COSTCENTERID
	 
		INSERT INTO ADM_CostCenterTab(CCTabName,CostCenterID,ResourceID,TabOrder,IsVisible,IsTabUserDefined, GroupOrder,GroupVisible,QuickViewCCID,QuickViewID,CCIDValues)
		VALUES (@TabName,@COSTCENTERID,@ResourceID, @TabOrder,1, 1, @TabOrder,1,@QuickViewCCID,@QuickViewID,@CCIDValues)
		
		SET @CCTabID=SCOPE_IDENTITY()
	END
	ELSE
	BEGIN
		DECLARE @IsUserDefined BIT
		SELECT @IsUserDefined=IsTabUserDefined FROM ADM_CostCenterTab with(nolock) WHERE CostCenterID=@COSTCENTERID AND CCTabID=@CCTabID
			
		IF(@COSTCENTERID=50051 AND @IsUserDefined=0) -- EMPLOYEE MASTER
		BEGIN
			UPDATE ADM_CostCenterTab SET QuickViewCCID=@QuickViewCCID,QuickViewID=@QuickViewID ,
			CCIDValues = @CCIDValues
			WHERE CostCenterID=@COSTCENTERID AND CCTabID=@CCTabID
			
			UPDATE LR SET LR.ResourceData=@TabName
			FROM COM_LanguageResources LR with(nolock) 
			LEFT JOIN ADM_CostCenterTab CT WITH(NOLOCK) ON CT.ResourceID=LR.ResourceID
			WHERE CT.CostCenterID=@COSTCENTERID AND CT.CCTabID=@CCTabID
		END
		ELSE
		BEGIN
			UPDATE ADM_CostCenterTab SET CCTabName=@TabName,QuickViewCCID=@QuickViewCCID,QuickViewID=@QuickViewID ,
			CCIDValues = @CCIDValues
			WHERE CostCenterID=@COSTCENTERID AND CCTabID=@CCTabID
			
			UPDATE LR SET LR.ResourceName=@TabName,LR.ResourceData=@TabName
			FROM COM_LanguageResources LR with(nolock) 
			LEFT JOIN ADM_CostCenterTab CT WITH(NOLOCK) ON CT.ResourceID=LR.ResourceID
			WHERE CT.CostCenterID=@COSTCENTERID AND CT.CCTabID=@CCTabID
		END
	END

SET NOCOUNT OFF;     
COMMIT TRANSACTION 
 
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=100 AND LanguageID=@LangID        
SET NOCOUNT OFF;      
RETURN @CCTabID       
END TRY      
BEGIN CATCH      
 --Return exception info [Message,Number,ProcedureName,LineNumber]      
 IF ERROR_NUMBER()=50000    
 BEGIN    
  SELECT * FROM ADM_CostCenterTab WITH(NOLOCK) WHERE COSTCENTERID=@COSTCENTERID     
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
