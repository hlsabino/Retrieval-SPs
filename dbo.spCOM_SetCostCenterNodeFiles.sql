USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetCostCenterNodeFiles]
	@FileID [int],
	@FilePath [nvarchar](500) = '',
	@ActualFileName [nvarchar](100) = '',
	@RelativeFileName [nvarchar](max) = '',
	@FileExtension [nvarchar](50) = '',
	@IsProductImage [bit],
	@AllowInPrint [bit],
	@ValidTill [datetime],
	@FeatureID [int],
	@FeaturePK [int],
	@IsDefaultImage [bit] = 0,
	@FileDescription [nvarchar](100) = '',
	@IssueDate [datetime],
	@Type [int],
	@RefNum [nvarchar](max),
	@Remarks [nvarchar](max),
	@DocNo [nvarchar](max),
	@IsSign [bit],
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON; 
		
		if(@ValidTill='1/Jan/1900') 
			set @ValidTill=null
		if(@IssueDate='1/Jan/1900') 
			set @IssueDate=null
				
		--Declaration Section
		DECLARE @HasAccess BIT,@TempGuid NVARCHAR(50),@FeatureActionTypeID INT
		
		--SP Required Parameters Check
		IF @FeatureID=0 OR @FeaturePK=0 OR @FilePath='' OR @ActualFileName='' OR @RelativeFileName='' OR @CompanyGUID IS NULL OR @CompanyGUID=''
		BEGIN
			RAISERROR('-100',16,1)
		END
		
		SET @FeatureActionTypeID=9
		
		IF (@FeatureID NOT BETWEEN 40001 AND 49999)
			SET @FeatureActionTypeID=12
	
		--User access check
		IF @FileID=0
		BEGIN
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@FeatureID,@FeatureActionTypeID)
		END
		ELSE
		BEGIN
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@FeatureID,@FeatureActionTypeID)
		END

		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END

		IF @FileID=0--TO INSERT RECORD    
		BEGIN    
			if(@IsDefaultImage=1)
				update com_files set IsDefaultImage=0 where FeatureID=@FeatureID and FeaturePK=@FeaturePK
				
			if(@GUID='')
				set @GUID=NEWID()
			INSERT INTO COM_Files
					(FilePath
					,ActualFileName
					,RelativeFileName
					,FileExtension
					,IsProductImage
					,AllowInPrint
					,FeatureID
					,FeaturePK
					,CompanyGUID
					,GUID
					,CreatedBy
					,CreatedDate,CostCenterID, IsDefaultImage,FileDescription,ValidTill
					,IssueDate,Type,RefNum,Remarks,DocNo,IsSign)    
			VALUES
					(@FilePath
					,@ActualFileName
					,@RelativeFileName
					,@FileExtension
					,@IsProductImage
					,@AllowInPrint
					,@FeatureID
					,@FeaturePK
					,@CompanyGUID
					,@GUID
					,@UserName
					,CONVERT(FLOAT,GETDATE()),@FeatureID,@IsDefaultImage,@FileDescription,convert(float,@ValidTill)
					,CONVERT(FLOAT,@IssueDate),@Type,@RefNum,@Remarks,@DocNo,@IsSign)  
  
			--To get inserted record primary key
			SET @FileID=SCOPE_IDENTITY()    
		END    
		ELSE--TO UPDATE RECORD    
		BEGIN  
			SELECT @TempGuid=[GUID] FROM COM_Files WITH(NOLOCK)     
			WHERE FileID=@FileID    
			IF(@Guid='')      
				SET @Guid= @TempGuid  
			if(@TempGuid!=@Guid)--IF RECORD ALREADY UPDATED BY SOME OTHER USER i.e DIRTY READ    
			BEGIN    
				RAISERROR('-101',16,1)
			END    
			ELSE    
			BEGIN    
				if(@FeatureID=2 or @FeatureID=3 or @FeatureID>50000)
				BEGIN
					if(@IsDefaultImage=1)
						UPDATE com_files set isdefaultimage=0 where FeatureID=@FeatureID and FeaturePK=@FeaturePK
					UPDATE COM_Files    
					SET  ActualFileName=@ActualFileName 
						,IsProductImage=@IsProductImage
						,IsDefaultImage=@IsDefaultImage 
						,ModifiedBy=@UserName
						,ModifiedDate=CONVERT(FLOAT,GETDATE())    
						,FileDescription=@FileDescription
						,IssueDate=CONVERT(FLOAT,@IssueDate),Type=@Type,RefNum=@RefNum,Remarks=@Remarks,DocNo=@DocNo,IsSign = @IsSign
						WHERE FileID=@FileID  
				END
				ELSE 
				BEGIN
					UPDATE COM_Files    
					SET  FilePath=@FilePath
						,ActualFileName=@ActualFileName
						,RelativeFileName=@RelativeFileName
						,FileExtension=@FileExtension
						,IsProductImage=@IsProductImage
						,AllowInPrint=@AllowInPrint
						,IsDefaultImage=@IsDefaultImage 
						,ModifiedBy=@UserName
						,ModifiedDate=CONVERT(FLOAT,GETDATE())    
						,FileDescription=@FileDescription
						,ValidTill=convert(float,@ValidTill)
						,IssueDate=CONVERT(FLOAT,@IssueDate),Type=@Type,RefNum=@RefNum,Remarks=@Remarks,DocNo=@DocNo,IsSign = @IsSign
						
					WHERE FileID=@FileID    
				END
			END    
		END    

   
COMMIT TRANSACTION 
SELECT FileID,FilePath,ActualFileName,RelativeFileName,FileExtension,IsProductImage,GUID FROM COM_Files WITH(NOLOCK) WHERE FileID=@FileID   
SET NOCOUNT OFF;  
RETURN @FileID    
END TRY
BEGIN CATCH  
		--Return exception info [Message,Number,ProcedureName,LineNumber]  
		IF ERROR_NUMBER()=50000
		BEGIN
			SELECT FileID,FilePath,ActualFileName,RelativeFileName,FileExtension,IsProductImage,GUID FROM COM_Files WITH(NOLOCK) WHERE FileID=@FileID   
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
