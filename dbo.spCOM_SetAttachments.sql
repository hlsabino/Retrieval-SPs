USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetAttachments]
	@NodeID [int],
	@CostCenterID [int],
	@AttachmentsXML [nvarchar](max),
	@UserName [nvarchar](50),
	@Dt [float]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN 
	declare @mess nvarchar(500)
	IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')  
	BEGIN  
		DECLARE @XML XML
		SET @XML=@AttachmentsXML

		INSERT INTO COM_Files(FilePath,ActualFileName,RelativeFileName,FileExtension,FileDescription,IsProductImage,FeatureID,CostCenterID,FeaturePK,[GUID],CreatedBy,CreatedDate , IsDefaultImage,LocationID ,DivisionID,ColName,ValidTill,HasThumb
		,IssueDate,Type,RefNum,Remarks,DocNo,status,AllowInPrint,IsSign)
		SELECT X.value('@FilePath','NVARCHAR(500)'),X.value('@ActualFileName','NVARCHAR(50)'),X.value('@RelativeFileName','NVARCHAR(500)'),
		X.value('@FileExtension','NVARCHAR(50)'),X.value('@FileDescription','NVARCHAR(500)'),X.value('@IsProductImage','bit'),@CostCenterID,@CostCenterID,@NodeID, 
		X.value('@GUID','NVARCHAR(50)'),@UserName,@Dt,X.value('@IsDefaultImage','smallint'),X.value('@LocationID','INT') ,X.value('@DivisionID','INT'),X.value('@ColName','nvarchar(50)') 		
		,convert(float,X.value('@Validtill','Datetime')),isnull(X.value('@HasThumb','bit'),0)
		,convert(float,X.value('@IssueDate','Datetime')),X.value('@Type','INT')
		,X.value('@RefNo','NVARCHAR(max)'),X.value('@Remarks','NVARCHAR(max)')
		,X.value('@DocNo','NVARCHAR(max)'),X.value('@stat','int'),isnull(X.value('@AllowInPrint','bit'),0),isnull(X.value('@IsSign','bit'),0)
		FROM @XML.nodes('/AttachmentsXML/Row') as Data(X) 	
		WHERE X.value('@Action','NVARCHAR(10)')='NEW'

		--If Action is MODIFY then update Attachments
		UPDATE COM_Files
		SET FilePath=X.value('@FilePath','NVARCHAR(500)'),
			ActualFileName=X.value('@ActualFileName','NVARCHAR(50)'),
			RelativeFileName=X.value('@RelativeFileName','NVARCHAR(500)'),
			FileExtension=X.value('@FileExtension','NVARCHAR(50)'),
			FileDescription=X.value('@FileDescription','NVARCHAR(500)'),
			IsProductImage=X.value('@IsProductImage','bit'),
			IsDefaultImage=X.value('@IsDefaultImage','smallint'),
			[GUID]=X.value('@GUID','NVARCHAR(50)'),
			LocationID=X.value('@LocationID','INT') ,
			DivisionID=X.value('@DivisionID','INT') ,
			ModifiedBy=@UserName,
			ModifiedDate=@Dt
			
			,ValidTill=convert(float,X.value('@Validtill','Datetime'))
			,HasThumb=isnull(X.value('@HasThumb','bit'),0)
			,IssueDate=convert(float,X.value('@IssueDate','Datetime')),Type=X.value('@Type','INT')
			,RefNum=X.value('@RefNo','NVARCHAR(max)'),Remarks=X.value('@Remarks','NVARCHAR(max)')
			,DocNo=X.value('@DocNo','NVARCHAR(max)')
			,status=X.value('@stat','int')
			,AllowInPrint=isnull(X.value('@AllowInPrint','bit'),0)
			,IsSign=ISNULL(X.value('@IsSign','bit'),0)
		FROM COM_Files C with(nolock)
		INNER JOIN @XML.nodes('/AttachmentsXML/Row') as Data(X) 	
		ON convert(INT,X.value('@AttachmentID','INT'))=C.FileID
		WHERE X.value('@Action','NVARCHAR(500)')='MODIFY'
		
		UPDATE COM_Files
		SET LocationID=X.value('@LocationID','INT') ,
			DivisionID=X.value('@DivisionID','INT') 
			--ModifiedBy=@UserName,
			--ModifiedDate=@Dt
			,ValidTill=convert(float,X.value('@Validtill','Datetime'))			
			,IssueDate=convert(float,X.value('@IssueDate','Datetime')),Type=X.value('@Type','INT')
			,RefNum=X.value('@RefNo','NVARCHAR(max)'),Remarks=X.value('@Remarks','NVARCHAR(max)')
			,DocNo=X.value('@DocNo','NVARCHAR(max)')
			,status=X.value('@stat','int')
			,AllowInPrint=isnull(X.value('@AllowInPrint','bit'),0)
			,IsSign=isnull(X.value('@IsSign','bit'),0)
		FROM COM_Files C with(nolock)
		INNER JOIN @XML.nodes('/AttachmentsXML/Row') as Data(X) 	
		ON convert(INT,X.value('@AttachmentID','INT'))=C.FileID
		WHERE X.value('@Action','NVARCHAR(500)')='MODIFYText'
		

		--If Action is DELETE then delete Attachments
		DELETE FROM COM_Files
		WHERE FileID IN(SELECT X.value('@AttachmentID','INT')
		FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)
		WHERE X.value('@Action','NVARCHAR(10)')='DELETE')	
		
		if exists(select X.value('@DocNo','bit') from @XML.nodes('/AttachmentsXML/Detxml')as Data(X)
		where X.value('@DocNo','bit')=1)
		BEGIN
			if exists(select * from COM_Files WITH(NOLOCK)
			where FeatureID=@CostCenterID and DocNo is not null
			group by  DocNo
			having count(*)>1)
			BEGIN
				set @mess=''
				select @mess=X.value('@DocNoText','NVARCHAR(500)')
				from @XML.nodes('/AttachmentsXML/Detxml')as Data(X)				
				if(@mess is null or @mess='')
					set @mess='Docno' 
				set @mess=@mess+' is duplicate'
				RAISERROR(@mess,16,1)
			END	
			 
		END
		if exists(select X.value('@RefNo','bit') from @XML.nodes('/AttachmentsXML/Detxml')as Data(X)
		where X.value('@RefNo','bit')=1)
		BEGIN
			if exists(select * from COM_Files WITH(NOLOCK)
			where FeatureID=@CostCenterID and RefNum is not null
			group by  RefNum
			having count(*)>1)
			BEGIN
				set @mess=''
				select @mess=X.value('@RefNoText','NVARCHAR(500)')
				from @XML.nodes('/AttachmentsXML/Detxml')as Data(X)				
				if(@mess is null or @mess='')
					set @mess='RefNo' 
				set @mess=@mess+' is duplicate'
				RAISERROR(@mess,16,1)
			END	
			 
		END
		
	END
END
GO
