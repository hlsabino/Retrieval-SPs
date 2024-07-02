USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetFeaturesWebData]
	@FEATURE [int],
	@WHERE [nvarchar](200),
	@FilterText [nvarchar](500),
	@TypeID [int],
	@UserID [bigint],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
SET NOCOUNT ON
BEGIN TRY
		DECLARE @SQL NVARCHAR(MAX) 
		Declare @SearchFilter nvarchar(max)
		
		select @SearchFilter=SearchFilter FROM ADM_ListView WITH(NOLOCK)      
		WHERE CostCenterID=@FEATURE and ListViewTypeID=@TypeID
		
	 	--SP Required Parameters Check
		IF @FEATURE=0
		BEGIN
			RAISERROR('-100',16,1)
		END 
		  
		 IF @FEATURE = 3
		 BEGIN
			declare @tblname nvarchar(100), @Val int 
			select @Val=value from adm_globalpreferences where name='POSItemCodeDimension'
			select @tblname=tablename from adm_features where featureid=@Val 
			IF(@WHERE IS NULL OR @WHERE='')
				SET @SQL=' TOP 10 ' 
			ELSE
				SET @SQL='' 
			set @SQL= ' select '+@SQL+' a.ProductID,ProductCode CODE ,ProductName NAME,a.Code STOCKCODE  from '+@tblname+'  a  with(nolock)
			join INV_Product b  with(nolock) on a.ProductID=b.ProductID '
			if(@SearchFilter<>'')
				set @SQL =@SQL+' where '+@SearchFilter
			set @SQL =@SQL+' UNION
			select b.productid,ProductCode,ProductName,max(a.code)  from INV_Product b with(nolock)
			join  '+@tblname+' a on b.productid=a.productid  '
			if(@SearchFilter<>'')
				set @SQL =@SQL+' where '+@SearchFilter
			set @SQL =@SQL+' group by b.productid,ProductCode,ProductName '
			if(@WHERE<>'')
			BEGIN
				set @SQL= 'select TOP 10 ProductID ID, STOCKCODE, CODE , NAME from ('+@SQL+') as DATA WHERE '+@WHERE 
			END  
			print @SQL	
			EXEC(@SQL)
		 END
		 ELSE IF @FEATURE = 2
		 BEGIN  
			IF(@WHERE IS NULL OR @WHERE='')
				SET @SQL=' TOP 10 ' 
			ELSE
				SET @SQL='' 
				
			SET @SQL='SELECT '+	@SQL+' ACCOUNTID ID,ACCOUNTCODE CODE, ACCOUNTNAME NAME, C.PHONE1, C.ADDRESS1, C.ADDRESS2,
			C.CITY, C.STATE, C.COUNTRY FROM ACC_ACCOUNTS A WITH(NOLOCK)
			LEFT JOIN COM_CONTACTS C ON A.ACCOUNTID= C.FEATUREPK AND C.FEATUREID=2 AND C.ADDRESSTYPEID=1 Where A.AccountID>0'
			
			if(@SearchFilter<>'')
				set @SQL =@SQL+' and ('+@SearchFilter +')'
			if(@FilterText<>'')
				set @SQL =@SQL+' and ('+@FilterText +')'
			IF(@WHERE<>'')
				SET @SQL='select top 10 * from ('+@SQL+') AS DATA WHERE   '+@WHERE
			print (@SQL)
			EXEC(@SQL)
		 END
		 else if @FEATURE=11
		 BEGIN
			select UOMID ID,  BaseName Code, UnitName Name from com_uom
		 END
		 else if @FEATURE=12
		 BEGIN 
			 IF(@WHERE<>'')
			 begin
				set @SQL='SELECT  CurrencyID,Notes,Change FROM Com_CurrencyDenominations where ' +@WHERE
				exec(@SQL)
			 end
			 else
				select CurrencyID ID,Symbol CODE, NAME   from com_currency				
		 END
		 ELSE IF (@FEATURE=300)
		 BEGIN
			SET @SQL ='SELECT DocumentName NAME,DocumentAbbr CODE, CostCenterID ID from adm_documenttypes'
			IF(@WHERE<>'')
				SET @SQL='select top 10 * from ('+@SQL+') AS DATA WHERE   '+@WHERE
			print (@SQL)
			EXEC(@SQL)
		 END
		 else if (@FEATURE=200)
		 BEGIN
		  SET @SQL='DECLARE @UserID BIGINT,@RoleID BIGINT              
			SET @UserID='+CONVERT(NVARCHAR,@UserID)+'              
			set @RoleID='+convert(nvarchar,@RoleID)+'
			SELECT row_number() over (order by R.lft) rowno, ReportName, ReportTypeName, StatusID, Depth, ParentID, lft, rgt, IsGroup,ReportID  NodeID,0 as TypeID    
			FROM ADM_RevenUReports AS R with(nolock)    
			WHERE ReportID>0 AND (IsGroup=1 OR @RoleID=1 OR ReportID IN 
			(
			SELECT R.ReportID FROM ADM_ReportsUserMap M with(nolock) inner join ADM_RevenUReports R with(nolock) on R.ReportID=M.ReportID and R.IsGroup=0 and M.ActionType=1
			WHERE UserID=@UserID OR RoleID = @RoleID OR GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)
			union
			SELECT SR.ReportID FROM ADM_ReportsUserMap M with(nolock) inner join ADM_RevenUReports R with(nolock) on R.ReportID=M.ReportID and R.IsGroup=1 and M.ActionType=1
			inner join ADM_RevenUReports SR with(nolock) on SR.lft between R.lft and R.rgt and SR.ReportID>0
			WHERE UserID=@UserID OR RoleID = @RoleID OR GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)
			)

			)'      
			EXEC(@SQL)
		 END
		 ELSE IF @FEATURE=117
		 BEGIN		  
			SET @SQL=	 'DECLARE @UserID BIGINT,@RoleID BIGINT              
			SET @UserID='+CONVERT(NVARCHAR,@UserID)+'              
			set @RoleID='+convert(nvarchar,@RoleID)+'

			SELECT  Distinct ROW_NUMBER() over (order by max(lft)), DashBoardName,DashBoardType, 1 StatusID, Depth, IsGroup,ParentID,  max(lft) lft,  max(rgt) rgt, 0 AS TypeID ,DashBoardID as NodeID    
			FROM  ADM_DashBoard with(nolock) where ParentID=0 or  (@RoleID=1 or createdby=@UserID  
			or (DashBoardID IN  
			(
			(SELECT DashBoardID FROM ADM_DashBoardUserRoleMap with(nolock) WHERE UserID=@UserID OR RoleID=@RoleID   
			or GroupID IN (SELECT G.GID FROM COM_Groups G with(nolock) WHERE G.UserID=@UserID or G.RoleID=@RoleID))
			union
			SELECT SR.DashBoardID FROM ADM_DashBoardUserRoleMap M with(nolock) 
			inner join ADM_DashBoard D with(nolock) on D.DashBoardID=M.DashBoardID and D.IsGroup=1
			inner join ADM_DashBoard SR with(nolock) on SR.lft between D.lft and D.rgt and SR.DashBoardID>0
			WHERE UserID=@UserID OR RoleID = @RoleID OR GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)
			)     ))
			group by DashBoardName, DashBoardType, depth,isgroup,parentid ,DashBoardID
			ORDER BY LFT '
    		EXEC(@SQL)
		 END
		 ELSE IF @FEATURE > 50000
		 BEGIN
			DECLARE @TABLENAME NVARCHAR(300)
			SELECT @TABLENAME=TABLENAME FROM ADM_FEATURES WHERE FEATUREID=@FEATURE		 
			IF(@WHERE IS NULL OR @WHERE='')
				SET @SQL=' TOP 10 ' 
			ELSE
				SET @SQL=''
			SET @SQL='SELECT  '+@SQL+'  CODE,NAME,NODEID ID FROM '+@TABLENAME + ' WHERE Isgroup <> 1 ' 
			IF(@WHERE<>'')
				SET @SQL='select top 10 * from ('+@SQL+') AS DATA WHERE '+@WHERE
			
		    EXEC(@SQL)
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
