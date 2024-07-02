USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spINV_UpdatePayTermsofProperty]
	@PropXml [nvarchar](max),
	@dt [int],
	@where [nvarchar](max),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION        
BEGIN TRY         
SET NOCOUNT ON  

		declare @Sql nvarchar(max),@xml xml,@CostCenterID INT,@I int,@Cnt int
		declare @Columnname nvarchar(100),@vno nvarchar(200),@docid INT,@days int
		set @xml=@PropXml
		
		declare @tblList table(ID int identity(1,1),docid INT,ccid INT,vno nvarchar(200))  
		
		insert into @tblList  
		SELECT X.value('@ID','INT')  , X.value('@CostCenterID','INT')  , X.value('@VNO','NVARCHAR(200)') 
		from @xml.nodes('/XML/Row') as Data(X)   
		
		SELECT @I=0, @Cnt=count(*) FROM @tblList       
       

		WHILE(@I<@Cnt)        
		BEGIN      
			SET @I=@I+1    
		    
			SELECT  @docid=docid,@CostCenterID=ccid,@vno=vno FROM @tblList  WHERE ID=@I        
			
			set @Sql=' update COM_DocPayTerms
			 set Period=1,DueDate=basedate+'+convert(nvarchar(max),@dt)+', days='+convert(nvarchar(max),@dt)+'
			 where VoucherNo='''+@vno+''' '+@where
			 exec(@Sql)
			 --update COM_DocPayTerms
			 --set DueDate=convert(float, DATEADD(MONTH,@days,convert(datetime,basedate)))
			 --where VoucherNo=@vno and Period=2
		END
	 
COMMIT TRANSACTION        
	
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  		
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
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS          
ErrorLine        
  FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID        
 END        
ROLLBACK TRANSACTION        
SET NOCOUNT OFF          
RETURN -999           
END CATCH
GO
