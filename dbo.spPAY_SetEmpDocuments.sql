USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_SetEmpDocuments]
	@NodeID [int],
	@DocumentXML [nvarchar](max),
	@UserName [nvarchar](50)
WITH ENCRYPTION, EXECUTE AS CALLER
AS
DECLARE @XML XML, @Dt FLOAT,@AttacthList nvarchar(max)=null,@AttachXml XML,@Audit NVARCHAR(100)

	SELECT @Audit=Value FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE CostCenterID=50051 and Name='AuditTrial'

	--Inserts Multiple Documents  
	IF (@DocumentXML IS NOT NULL AND @DocumentXML <> '')  
	BEGIN  
		SET @Dt=CONVERT(FLOAT,GETDATE())
		SET @XML=@DocumentXML  
		DECLARE @DocumentQueryXML XML,@ExtraFields nvarchar(max),@UpdateSql NVARCHAR(MAX), @CCFields nvarchar(max),@PrimaryDocumentID int 
		SET @DocumentQueryXML=@DocumentXML
		DECLARE @DocTable TABLE(ID INT IDENTITY(1,1),ActionName NVARCHAR(300),DocumentType INT,DocumentID INT,STATICIFLEDS NVARCHAR(MAX),ALPHAFIELDS NVARCHAR(MAX),
			CCFIELDS NVARCHAR(MAX),AttachmentXML nvarchar(max))	
			
		DECLARE @COUNT INT,@I INT,@ACTION NVARCHAR(300),@DocumentID INT,@DType INT,@IsPrimarAddressFound BIT
		INSERT INTO @DocTable
		SELECT X.value('@Action','NVARCHAR(30)') ,ISNULL(X.value('@DType','NVARCHAR(300)'),0),ISNULL(X.value('@NodeID','NVARCHAR(300)'),0) ,X.value('@StaticFields','NVARCHAR(max)') ,X.value('@ExtraTextFields','NVARCHAR(max)'),
		X.value('@CCFields','NVARCHAR(max)'),X.value('@AttachmentXML','NVARCHAR(max)')   from @DocumentQueryXML.nodes('/Data/Row') as Data(X)
		SELECT @COUNT=COUNT(*),@I=1,@IsPrimarAddressFound=0 FROM @DocTable
		--SELECT * FROM @DocTable
		WHILE @I<=@COUNT
		BEGIN
			SELECT  @AttacthList=AttachmentXML,@ACTION=ActionName,@DType=DocumentType,@DocumentID=DocumentID,@DocumentXML=STATICIFLEDS ,@ExtraFields=ALPHAFIELDS,
			@CCFields=CCFIELDS FROM @DocTable WHERE ID=@I
			
			--SELECT @ACTION,@DocumentID,@ContactQuery,@ExtraFields,@CCFields 
			IF @ACTION='NEW' AND (@DocumentID=0 OR @DocumentID IS NULL)
			BEGIN
				INSERT INTO PAY_EmpDetail(EmployeeID,DType,[CreatedBy],[CreatedDate])
				VALUES (@NodeID,@DType,@UserName,@Dt)
				SET @PrimaryDocumentID=SCOPE_IDENTITY()
				
			    IF (@DocumentXML IS NOT NULL AND @DocumentXML <> '')  
				BEGIN    
					set @UpdateSql='UPDATE [PAY_EmpDetail]  
					SET '+@DocumentXML+',[ModifiedBy] ='''+ @UserName  
					+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE NodeID='+convert(nvarchar,@PrimaryDocumentID)     
					--SELECT @UpdateSql 
					EXEC sp_executesql @UpdateSql 
					--PRINT @UpdateSql
				END
				
				IF (@ExtraFields IS NOT NULL AND @ExtraFields <> '')  
				BEGIN 
					set @UpdateSql='UPDATE PAY_EmpDetail
					SET '+@ExtraFields+' WHERE NodeID ='+convert(nvarchar,@PrimaryDocumentID)	
					EXEC sp_executesql @UpdateSql
					--PRINT @UpdateSql
				END
				
				IF (@CCFields IS NOT NULL AND @CCFields <> '')  
				BEGIN 
					set @UpdateSql='UPDATE PAY_EmpDetail
					SET '+@CCFields+' 
					WHERE NodeID='+convert(nvarchar,@PrimaryDocumentID)+''
					EXEC sp_executesql @UpdateSql
				END

					IF(@Audit IS NOT NULL AND @Audit='True')
					BEGIN
						INSERT INTO PAY_EmpDetail_History 
						SELECT 50051,'Add',* FROM PAY_EmpDetail with(nolock)
						WHERE NodeID=@PrimaryDocumentID
					END
			END
			ELSE IF @ACTION='MODIFY' AND @DocumentID>0
			BEGIN
				IF (@DocumentXML IS NOT NULL AND @DocumentXML <> '')  
				BEGIN 
					set @UpdateSql='UPDATE [PAY_EmpDetail]  
					SET '+@DocumentXML+',DType='+convert(nvarchar,@DType) +',[ModifiedBy] ='''+ @UserName  
					+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE NodeID='+convert(nvarchar,@DocumentID)     
					--SELECT @UpdateSql 
					EXEC sp_executesql @UpdateSql 
					--PRINT @UpdateSql
				END
				
				IF (@ExtraFields IS NOT NULL AND @ExtraFields <> '')  
				BEGIN 
					set @UpdateSql='UPDATE PAY_EmpDetail
					SET '+@ExtraFields+', [ModifiedBy] ='''+ @UserName
					+''',[ModifiedDate] =' + convert(nvarchar,convert(float,getdate())) +' WHERE NodeID ='+convert(nvarchar,@DocumentID)	
					EXEC sp_executesql @UpdateSql
					--PRINT @UpdateSql
				END
					
				IF (@CCFields IS NOT NULL AND @CCFields <> '')  
				BEGIN 
					set @UpdateSql='UPDATE PAY_EmpDetail
					SET '+@CCFields+' 
					WHERE NodeID='+convert(nvarchar,@DocumentID)+' '
					EXEC sp_executesql @UpdateSql
				END

					IF(@Audit IS NOT NULL AND @Audit='True')
					BEGIN
						INSERT INTO PAY_EmpDetail_History 
						SELECT 50051,'Update',* FROM PAY_EmpDetail with(nolock)
						WHERE NodeID=@DocumentID
					END
			END
			ELSE IF @ACTION='DELETE' AND @DocumentID>0
			BEGIN
					IF(@Audit IS NOT NULL AND @Audit='True')
					BEGIN
						INSERT INTO PAY_EmpDetail_History 
						SELECT 50051,'Delete',* FROM PAY_EmpDetail with(nolock)
						WHERE NodeID=@DocumentID
					END
				 
				DELETE FROM PAY_EmpDetail WHERE NodeID=@DocumentID 
			END	

			if(@DocumentID>0)
				SET @PrimaryDocumentID=@DocumentID

			--Inserts Multiple Attachments  
			IF (@AttacthList IS NOT NULL AND @AttacthList <> '')  
			BEGIN  
				set @AttachXml=@AttacthList 
			
				INSERT INTO COM_Files(FilePath,ActualFileName,RelativeFileName,
				FileExtension,FileDescription,IsProductImage,FeatureID,CostCenterID,FeaturePK,[GUID],CreatedBy,CreatedDate)  
				SELECT X.value('@FilePath','NVARCHAR(500)'),X.value('@ActualFileName','NVARCHAR(50)'),X.value('@RelativeFileName','NVARCHAR(50)'),  
				X.value('@FileExtension','NVARCHAR(50)'),X.value('@FileDescription','NVARCHAR(500)'),X.value('@IsProductImage','bit'),@DType,@DType,@PrimaryDocumentID,  
				X.value('@GUID','NVARCHAR(50)'),@UserName,@Dt  
				FROM @AttachXml.nodes('/AttachmentsXML/Row') as Data(X)    
				WHERE X.value('@Action','NVARCHAR(10)')='NEW'  

				--If Action is MODIFY then update Attachments  
				UPDATE COM_Files SET FilePath=X.value('@FilePath','NVARCHAR(500)'),  
				ActualFileName=X.value('@ActualFileName','NVARCHAR(50)'),  
				RelativeFileName=X.value('@RelativeFileName','NVARCHAR(50)'),  
				FileExtension=X.value('@FileExtension','NVARCHAR(50)'),  
				FileDescription=X.value('@FileDescription','NVARCHAR(500)'),  
				IsProductImage=X.value('@IsProductImage','bit'),        
				[GUID]=X.value('@GUID','NVARCHAR(50)'),  
				ModifiedBy=@UserName,  
				ModifiedDate=@Dt  
				FROM COM_Files C WITH(NOLOCK)  
				INNER JOIN @AttachXml.nodes('/AttachmentsXML/Row') as Data(X) ON convert(INT,X.value('@AttachmentID','INT'))=C.FileID  
				WHERE X.value('@Action','NVARCHAR(500)')='MODIFY'  

				--If Action is DELETE then delete Attachments  
				DELETE FROM COM_Files  
				WHERE FileID IN(SELECT X.value('@AttachmentID','INT')  
				FROM @AttachXml.nodes('/AttachmentsXML/Row') as Data(X)  
				WHERE X.value('@Action','NVARCHAR(10)')='DELETE')  
			END  

			SET @I=@I+1	
		END
	END
RETURN @DocumentID
GO
