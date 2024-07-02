USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_PostVoucherSave]
	@CostCenterID [int],
	@DocID [bigint],
	@DocPrefix [nvarchar](50),
	@DocNumber [nvarchar](500),
	@DocDate [datetime],
	@InvDocXML [nvarchar](max),
	@ActivityXML [nvarchar](max),
	@PDCsXML [nvarchar](max),
	@LocationID [bigint],
	@DivisionID [bigint],
	@RoleID [int],
	@RefCCID [bigint],
	@RefNodeid [bigint],
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LangID [int] = 1,
	@IsOffline [bit] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY      
SET NOCOUNT ON;    

		
		declare @I int, @Cnt int,@PDCDocument int,@Stat int,@XML xml,@TEMPxml nvarchar(max),@DocIDValue int,@TempDocIDValue int,@return_value int,@DELETECCID int,@tempAmt float,@totalPrevPDRc int
		
		
		if(@CostCenterID>40000)
		BEGIN
					EXEC @return_value = [dbo].[spDOC_SetTempAccDocument]      
							@CostCenterID = @CostCenterID,      
							@DocID = @DocID,      
							@DocPrefix = @DocPrefix,      
							@DocNumber =@DocNumber,      
							@DocDate = @DocDate,      
							@DueDate = NULL,      
							@BillNo = NULL,      
							@InvDocXML = @InvDocXML,      
							@NotesXML = N'',      
							@AttachmentsXML = N'',      
							@ActivityXML  = @ActivityXML,     
							@IsImport = 0,      
							@LocationID = @LocationID,      
							@DivisionID = @DivisionID,      
							@WID = 0,      
							@RoleID = @RoleID,      
							@RefCCID = @RefCCID,    
							@RefNodeid = @RefNodeid ,    
							@CompanyGUID = @CompanyGUID,      
							@UserName = @UserName,      
							@UserID = @UserID,      
							@LangID = @LangID 
						set @DocID=@return_value
							
		END
		
		IF(@PDCsXML<>'')
		BEGIN
				set @XML=@PDCsXML
				
				SELECT @PDCDocument=X.value('@PDCDocument','INT')   
				from @XML.nodes('/PDCXML') as Data(X)    		         
		END		
		
		if(@PDCDocument>0 and @RefNodeid>0)
		BEGIN
			declare  @tblExistingPDCS TABLE (ID int identity(1,1),DOCID bigint,ccid int)           
			insert into @tblExistingPDCS     
			select DOCID,Costcenterid from  Acc_docDetails with(nolock)   
			where RefccID=300 and RefNodeid=@RefNodeid and DocID<>@DocID
			
			select @CNT=0,@totalPrevPDRc=COUNT(id) from @tblExistingPDCS     

			IF(@PDCsXML<>'')
			BEGIN
				set @XML=@PDCsXML
				
				SELECT @PDCDocument=X.value('@PDCDocument','INT')   
				from @XML.nodes('/PDCXML') as Data(X)    		         
				

				--Create temporary table to read xml data into table  
				declare @tblPDCS TABLE (ID int identity(1,1),TRANSXML NVARCHAR(MAX),DOcid bigint,statusid int)
				--Insert XML data into temporary table
				INSERT INTO @tblPDCS    
				SELECT CONVERT(NVARCHAR(MAX), X.query('DocumentXML')),X.value('@DOcid','BIGINT') ,X.value('@StatusID','int')   
				from @XML.nodes('/PDCXML/PDCRow') as Data(X)    		         
		
				--Set loop initialization varaibles    
				SELECT @I=0, @Cnt=count(*) FROM @tblPDCS 
				WHILE(@I<@Cnt)      
				BEGIN	
					SET @I=@I+1 	
					SET @TEMPxml=''
					set @DocIDValue=0
					SELECT @DocIDValue = DOCID,@DELETECCID=ccid   FROM @tblExistingPDCS WHERE  ID = @I     

					if(@DocIDValue >0 AND @DELETECCID <> 0 and @PDCDocument<>@DELETECCID)    
					begin   
						EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]      
						@CostCenterID = @DELETECCID,      
						@DocPrefix = '',      
						@DocNumber = '',  
						@DOCID = @DocIDValue,      
						@UserID = 1,      
						@UserName = N'ADMIN',      
						@LangID = 1,
						@RoleID=1

						set @DocIDValue=0       
					end    
					
					SELECT @TEMPxml=TRANSXML,@TempDocIDValue=isnull(DOcid,0) FROM @tblPDCS  WHERE ID=@I  
					
					if(@TempDocIDValue is not null and @TempDocIDValue<>'' and convert(bigint,@TempDocIDValue)>0 and @TempDocIDValue= @DocIDValue)
					BEGIN
						set @XML=@TEMPxml    
						select @tempAmt=X.value ('@Amount', 'FLOAT' )            
						from @XML.nodes('/DocumentXML/Row/Transactions') as Data(X)  
						if exists(select DOCID from Acc_docdetails with(nolock) where  DOCID=@DocIDValue and Amount=@tempAmt and StatusID in(369,429) and DocumentType=19)
							continue;
					END  
					
					
						EXEC @return_value = [dbo].[spDOC_SetTempAccDocument]      
								@CostCenterID = @PDCDocument,      
								@DocID = @DocIDValue,      
								@DocPrefix = '',      
								@DocNumber =1,      
								@DocDate = @DocDate,      
								@DueDate = NULL,      
								@BillNo = NULL,      
								@InvDocXML = @TEMPxml,      
								@NotesXML = N'',      
								@AttachmentsXML = N'',      
								@ActivityXML  = @ActivityXML,     
								@IsImport = 0,      
								@LocationID = @LocationID,      
								@DivisionID = @DivisionID,      
								@WID = 0,      
								@RoleID = @RoleID,      
								@RefCCID = @RefCCID,    
								@RefNodeid = @RefNodeid ,    
								@CompanyGUID = @CompanyGUID,      
								@UserName = @UserName,      
								@UserID = @UserID,      
								@LangID = @LangID 
					
				END
			END	
			
			WHILE(@CNT <  @totalPrevPDRc)    
			BEGIN    

				SET @CNT = @CNT+1    
				SELECT @DocIDValue = DOCID,@DELETECCID=ccid   FROM @tblExistingPDCS WHERE ID = @CNT    

				EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]      
					@CostCenterID = @DELETECCID,      
					@DocPrefix = '',      
					@DocNumber = '',  
					@DOCID = @DocIDValue,      
					@UserID = 1,      
					@UserName = N'ADMIN',      
					@LangID = 1,
					@RoleID=1

			END  
		END
COMMIT TRANSACTION

 
SELECT   ErrorMessage ,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=100 AND LanguageID=@LangID    
SET NOCOUNT OFF;      
RETURN @DocID
END TRY      
BEGIN CATCH   
  if(@return_value is not null and  @return_value=-999)         
	 return -999  
 --Return exception info [Message,Number,ProcedureName,LineNumber]      
 IF ERROR_NUMBER()=50000    
 BEGIN  		  
	  SELECT ErrorMessage ,ERROR_MESSAGE(),ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
	  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  	   
 END    
 ELSE IF ERROR_NUMBER()=547    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)    
  WHERE ErrorNumber=-110 AND LanguageID=@LangID    
 END  
  ELSE IF ERROR_NUMBER()=1205  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)  
  WHERE ErrorNumber=-350 AND LanguageID=@LangID  
 END   
 ELSE IF ERROR_NUMBER()=2627    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)    
  WHERE ErrorNumber=-116 AND LanguageID=@LangID    
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
