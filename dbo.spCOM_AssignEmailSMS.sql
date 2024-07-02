USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_AssignEmailSMS]
	@Type [int],
	@NotifID [bigint],
	@Groups [nvarchar](max),
	@Roles [nvarchar](max),
	@Users [nvarchar](max),
	@BasedOnDimension [nvarchar](max),
	@BasedOnField [nvarchar](max) = NULL,
	@LocationWhere [nvarchar](max) = null,
	@DivisionWhere [nvarchar](max) = null,
	@UserName [nvarchar](50),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
	DECLARE @Dt FLOAT,@TemplateType int
	DECLARE @TblApp AS TABLE(G BIGINT NOT NULL DEFAULT(0),R BIGINT NOT NULL DEFAULT(0),U BIGINT NOT NULL DEFAULT(0),D INT NOT NULL DEFAULT(0),F NVARCHAR(100) NULL)
	SET @Dt=CONVERT(FLOAT,GETDATE())
	
	IF @Type=1--TO GET MAP INFORMATION
	BEGIN
		--Groups,Roles,Users
		EXEC spADM_AssignInfo @LocationWhere,@DivisionWhere,@UserID
		
		SELECT UserID,RoleID,GroupID,BasedOnDimension,BasedOnField FROM COM_NotifTemplateUserMap WITH(NOLOCK) WHERE NotificationID=@NotifID
		
		SELECT @TemplateType=TemplateType FROM COM_NotifTemplate WITH(NOLOCK) WHERE TemplateID=@NotifID
		
		declare @FID int
		select @FID=CostCenterID from COM_NotifTemplate with(nolock) WHERE TemplateID=@NotifID
		
		DECLARE @EmailBasedOnDimension NVARCHAR(MAX)
		if(@FID>40000 and @FID<50000)
			SELECT @EmailBasedOnDimension=PrefValue FROM COM_DocumentPreferences with(nolock) 
			WHERE CostCenterID=@FID AND ((@TemplateType=1 and PrefName='EmailBasedOnDimension') or (@TemplateType=2 and PrefName='SMSBasedOnDimension'))
		else
			SELECT @EmailBasedOnDimension=Value FROM COM_CostCenterPreferences with(nolock) WHERE CostCenterID=@FID AND Name='EmailBasedOn'
			
		IF @EmailBasedOnDimension IS NOT NULL AND @EmailBasedOnDimension!=''
		BEGIN
			if @EmailBasedOnDimension like 'CCNID%'
				set @EmailBasedOnDimension=50000+convert(int,substring(@EmailBasedOnDimension,6,5))
			if isnumeric(@EmailBasedOnDimension)=1 and convert(int,@EmailBasedOnDimension)>50000
			begin
				SELECT @EmailBasedOnDimension='select NodeID,Name from '+TableName+'  with(nolock) where IsGroup=0 order by Name' FROM ADM_Features with(nolock) WHERE FeatureID=@EmailBasedOnDimension
				EXEC(@EmailBasedOnDimension)
			end
			else if @EmailBasedOnDimension='AccountTypeID'
			begin
				select AccountTypeID NodeID,AccountType Name from ACC_AccountTypes with(nolock)
				EXEC(@EmailBasedOnDimension)
			end
			else if @EmailBasedOnDimension='ProductTypeID'
			begin
				select ProductTypeID NodeID,ProductType Name from INV_ProductTypes with(nolock)
				EXEC(@EmailBasedOnDimension)
			end
			else
				SELECT @EmailBasedOnDimension 'EmailSMSBasedOnField'
		END
		ELSE
			SELECT 1 'EmailBasedOn' WHERE 1<>1
	END
	ELSE IF @Type=2--TO SET MAP INFORMATION
	BEGIN
		DELETE FROM COM_NotifTemplateUserMap 
		WHERE NotificationID=@NotifID
	
		INSERT INTO @TblApp(G)
		EXEC [SPSplitString] @Groups,','

		INSERT INTO @TblApp(R)
		EXEC [SPSplitString] @Roles,','

		INSERT INTO @TblApp(U)
		EXEC [SPSplitString] @Users,','
		
		INSERT INTO @TblApp(D)
		EXEC [SPSplitString] @BasedOnDimension,','
		
		INSERT INTO @TblApp(F)
		EXEC [SPSplitString] @BasedOnField,';'

		SELECT *,@UserName,@Dt FROM @TblApp

		INSERT INTO COM_NotifTemplateUserMap(NotificationID,GroupID,RoleID,UserID,BasedOnDimension,BasedOnField,CreatedBy,CreatedDate)
		SELECT @NotifID,G,R,U,D,F,@UserName,@Dt
		FROM @TblApp
		ORDER BY U,R,G
		
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=100 AND LanguageID=@LangID
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
