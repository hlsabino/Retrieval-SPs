USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_GetServicesData]
	@ServiceTypeID [int],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY	
SET NOCOUNT ON
	
	BEGIN
		DECLARE @CCID int,@CCName nvarchar(50) , @SQL nvarchar(MAX)
	    IF (@ServiceTypeID=0)
		BEGIN
			SELECT Name, NodeID from COM_Location where IsGroup=0

			SELECT S.StatusID,R.ResourceData AS Status,Status as ActualStatus      
			FROM COM_Status S WITH(NOLOCK)      
			LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON S.ResourceID=R.ResourceID AND R.LanguageID=@LangID      
			WHERE CostCenterID = 82 
		
			SELECT ServiceName, ServiceTypeID, Description, StatusID, Locations, Technicians  FROM CRM_ServiceTypes

			SELECT * FROM CRM_ServiceReasons 

			set @CCID = (select Value from com_CostCenterPreferences where costcenterid=82 and name='ServiceTypeLinkDimension')
			set @CCName=(select TableName from Adm_Features where FeatureID=@CCID)

			set @SQL ='select Name, Nodeid from '+@CCName+ ' where isgroup=0'

			exec (@SQL)

			
		END
		ELSE IF (@ServiceTypeID >0)
		BEGIN
			 
			
			SELECT ServiceName, ServiceTypeID, Description, StatusID, Locations, Technicians  FROM CRM_ServiceTypes WHERE SERVICETYPEID=@ServiceTypeID
			--Getting Reasons
			SELECT * FROM CRM_ServiceReasons WHERE SERVICETYPEID=@ServiceTypeID
			
			--Getting Files
			SELECT * FROM  COM_Files WITH(NOLOCK) WHERE FeatureID=82 and  FeaturePK=@ServiceTypeID
		 
	END
		

	END

COMMIT TRANSACTION
SET NOCOUNT OFF;
RETURN 1
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
