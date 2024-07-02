USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetCCValues]
	@CCXML [nvarchar](max),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY      
SET NOCOUNT ON      
      
		DECLARE @SQL NVARCHAR(MAX),@XML XML,@I INT,@CNT INT,@INVID INT
		DECLARE @CCID int,@syscolname nvarchar(200),@value nvarchar(200),@tablename nvarchar(200)
		 
		SET @XML=@CCXML      

		DECLARE @tblres AS TABLE(CostCenterID int,NODEID INT,Name nvarchar(500), Code nvarchar(200),VenderID INT,UnitID INT,UnitName nvarchar(200),AccountCode nvarchar(200),AccountName nvarchar(200),ECode  nvarchar(200),FieldName nvarchar(200),barcodeid INT)      
		
		DECLARE @tblCC AS TABLE(ID int identity(1,1),CostCenterID int,syscolname nvarchar(200),value nvarchar(200))      
		INSERT INTO @tblCC
		SELECT X.value('@CostcenterID','int'),X.value('@syscolname','nvarchar(200)'),X.value('@value','nvarchar(200)')--LTRIM(RTRIM(X.value('@value','nvarchar(200)') ))     
		FROM @XML.nodes('/XML/Row') as Data(X)    
		  
         select  @I=0,@CNT=COUNT(ID) from @tblCC
          
         while(@I<@CNT)
         begin
				set @I=@I+1
				select @CCID=CostCenterID,@syscolname=syscolname,@value=value from @tblCC where ID=@I
				select @tablename=TableName from ADM_Features with(nolock) where FeatureID=@CCID
				if(@CCID>50000)
					set @SQL='select '+CONVERT(nvarchar,@CCID)+',NODEID,NAME,CODE,0,0,'''','''','''','''','''',0 from '+@tablename+' with(nolock) where '+@syscolname+'='''+@value+''''
				else if(@CCID=3)
				begin
					set @SQL='if exists(select BarcodeID from INV_ProductBarcode with(nolock) where Barcode='''+@value+''')  
						select '+CONVERT(nvarchar,@CCID)+',a.ProductID NODEID,ProductName NAME,ProductCode CODE,VenderID,b.UnitID,u.UnitName,AccountCode,
						AccountName,'''+@value+''' ECode,'''',Barcode_Key
						from INV_Product a with(nolock)
						join INV_ProductBarcode b with(nolock) on a.ProductID=b.ProductID
						left join COM_UOM u with(nolock) on b.UnitID=u.UOMID and u.ProductID=b.ProductID
						left join Acc_accounts ac with(nolock) on ac.AccountID=b.VenderID
						where Barcode='''+@value+'''  
					  else select '+CONVERT(nvarchar,@CCID)+',a.ProductID NODEID,a.ProductName NAME,a.ProductCode CODE,0,0,'''','''','''','''','''',0  from '+@tablename+' a with(nolock) 
						join INV_ProductExtended c with(nolock) on a.ProductID=c.ProductID
						where ('+@syscolname+'='''+@value+''' OR BARCODEID='''+@value+''')'
				end 
				else if(@CCID=400)
				begin
					set @SQL='select 3,a.ProductID NODEID,ProductName NAME,ProductCode CODE,0,0,'''','''','''','''','''',0
					 from Inv_docDetails a with(nolock) 
					 join INV_Product b with(nolock)  on a.ProductID=b.ProductID
					 where documenttype <>5 and vouchertype=1 and isqtyignored=0 and invdocdetailsid='+@value
					 if(isnumeric(@value)=1)
						set @INVID=@value
				END
				print @SQL
				insert into @tblres
				exec(@SQL)
         end
         
         select * from @tblres
         
        if(@INVID is not null and @INVID>0)
        BEGIN 
			declare @date float,@vno nvarchar(200),@productID INT,@boe int
			select @date=DocDate,@vno=VoucherNo,@productID=a.ProductID,@boe=isbillofentry from INV_DocDetails a WITH(NOLOCK)
			join INV_Product b with(nolock)  on a.ProductID=b.ProductID
			where InvDocDetailsID=@INVID
			if(@boe=2)
			BEGIN
				select a.InvDocDetailsID,a.Quantity+isnull(sum(b.Quantity*c.VoucherType),0) Qty from INV_DocDetails a WITH(NOLOCK)
				left join INV_DocExtraDetails b  WITH(NOLOCK) on a.InvDocDetailsID=b.RefID and b.Type=1 
				left join INV_DocDetails c WITH(NOLOCK) on c.InvDocDetailsID=b.InvDocDetailsID and c.IsQtyIgnored=0
				where a.IsQtyIgnored=0 and a.VoucherType=1 and a.ProductID=@productID and (a.DocDate<@date or (a.DocDate=@date and a.VoucherNo<@vno)) 
				group by a.InvDocDetailsID,a.Quantity,a.DocDate,a.VoucherNo
				having (a.Quantity+isnull(sum(b.Quantity*c.VoucherType),0))>0
				order by a.DocDate,a.VoucherNo
		   END   
		END
		
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

SET NOCOUNT OFF        
RETURN -999         
END CATCH
GO
