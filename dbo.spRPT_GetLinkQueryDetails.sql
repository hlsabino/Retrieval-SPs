USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_GetLinkQueryDetails]
	@Qry [nvarchar](max),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY    
SET NOCOUNT ON;    
  
 declare @tab table(ID INT IDENTITY (1,1),DOCdETID BIGINT )   
 DECLARE  @voucherNo nvarchar(100) ,@CC BIGINT, @DocID BIGINT ,@InvDocDetID BIGINT   
 DECLARE  @VCHRCNT INT ,@VCHRID INT   
 declare @DocDetailsID nvarchar(max) ,@sql nvarchar(max) ,@i int,@cnt int,@ID bigint ,@ParentID BIGINT   
 declare @tabDocs table(ID INT IDENTITY (1,1),DOCID BIGINT ,CCID BIGINT,VOUCHERNO NVARCHAR(100) )   

 DECLARE @IDOCID INT ,@ICNTDOCID INT 
 
 --exec(@Qry)  

	INSERT INTO @tabDocs  
	exec(@Qry)  

	declare @tabids table(Quantity fLOAT,InvDocDetailsID bigint ,ccid BIGINT, VOUCHERNO NVARCHAR(200), DocStatus NVARCHAR(50) ,DOCID BIGINT , ParentID BIGINT,ParVoucher  NVARCHAR(200) )   

	INSERT INTO @tabids
	SELECT A.Quantity - sum(isnull(B.LinkedFieldValue,0))     AS Quantity ,A.InvDocDetailsID , 
	a.CostCenterID ,a.VOUCHERNO,max(S.Status), a.DOCID  , C.DOCID PRDOCID,C.VoucherNo   ParVoucher
	FROM INV_DocDetails A WITH(NOLOCK) 
	LEFT JOIN COM_Status S WITH(NOLOCK) ON S.StatusID=A.StatusID
	LEFT JOIN INV_DocDetails B WITH(NOLOCK) ON A.InvDocDetailsID = B.LinkedInvDocDetailsID   
	LEFT JOIN INV_DocDetails C WITH(NOLOCK) ON A.LinkedInvDocDetailsID = C.InvDocDetailsID 
	JOIN @tabDocs d ON  d.DOCID=A.DOCID 
	GROUP BY   A.Quantity,A.InvDocDetailsID , 
	a.CostCenterID ,a.VOUCHERNO , a.DOCID  , C.DOCID ,C.VoucherNo

	INSERT INTO @tab    
	SELECT a.InvDocDetailsID FROM INV_DocDetails A WITH(NOLOCK) 
	joiN  @tabids B ON A.LinkedInvDocDetailsID=B.InvDocDetailsID
	
	WHILE(exists (select DOCdETID from @tab))
	BEGIN    

		INSERT INTO @tabids
		SELECT A.Quantity - sum(isnull(B.LinkedFieldValue,0))     AS Quantity ,A.InvDocDetailsID , 
		a.CostCenterID,a.VOUCHERNO,max(S.Status),a.DOCID,C.DOCID PRDOCID,C.VoucherNo   ParVoucher
		FROM INV_DocDetails A WITH(NOLOCK)
		LEFT JOIN COM_Status S WITH(NOLOCK) ON S.StatusID=A.StatusID
		LEFT JOIN INV_DocDetails B WITH(NOLOCK) ON A.InvDocDetailsID = B.LinkedInvDocDetailsID   
		LEFT JOIN INV_DocDetails C WITH(NOLOCK) ON A.LinkedInvDocDetailsID = C.InvDocDetailsID
		JOIN @tab d ON  d.DOCdETID=A.InvDocDetailsID 
		GROUP BY   A.Quantity,A.InvDocDetailsID , 
		a.CostCenterID ,a.VOUCHERNO , a.DOCID  , C.DOCID ,C.VoucherNo
		
		set @DocDetailsID=''
		select @i=min(ID),@cnt=max(ID) from @tab
		set @i=@i-1
		while(@i<@cnt)
		begin
			set @i=@i+1
			select @ID=DOCdETID from @tab where ID=@i
			set @DocDetailsID=@DocDetailsID+convert(nvarchar,@ID)
			if(@i<>@cnt)
				set @DocDetailsID=@DocDetailsID+','
		end
		delete from @tab
						
		set @sql='SELECT InvDocDetailsID FROM INV_DocDetails WITH(NOLOCK) WHERE  LinkedInvDocDetailsID in('+@DocDetailsID+')'
		--PRINT @sql
		insert into @tab
		exec(@sql)		
 		
	END  
    
  select * from @tabids  
  
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
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine  
  FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
 END  
SET NOCOUNT OFF    
RETURN -999     
END CATCH  

GO
