USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetUserInfo]
	@UserName [nvarchar](100) = null
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
	DECLARE @SQL nvarchar(max),@Where nvarchar(max),@ColNames nvarchar(max),@colwidth nvarchar(10)
	set @ColNames=''
	set @Where=''
	set @SQL=''
	IF(EXISTS(SELECT PREFIXCONTENT FROM COM_CostCenterCodeDef WITH(NOLOCK) WHERE COSTCENTERID=7 AND ISGROUPCODE=3 AND ISNULL(PREFIXCONTENT,'')<>''))
	BEGIN
		DECLARE @TblDef AS TABLE(ID INT IDENTITY(1,1),RowNo NVARCHAR(300),Name nvarchar(300),Delimiter NVARCHAR(10),colwidth NVARCHAR(10))
		DECLARE @PrefXml NVARCHAR(MAX),@xml XML,@COUNT INT,@I INT,@ColName nvarchar(300),@Delimeter nvarchar(10)
		SELECT @PrefXml=PrefixContent FROM [COM_CostCenterCodeDef] WITH(NOLOCK)	WHERE COSTCENTERID=7 AND ISGROUPCODE=3
		SET @xml=@PrefXml
		INSERT INTO @TblDef
		SELECT X.value('@RowNo','NVARCHAR(300)'),X.value('@Name','NVARCHAR(300)'),X.value('@Delimiter','NVARCHAR(10)'),X.value('@Length','NVARCHAR(10)')
		FROM @xml.nodes('XML/Row') as DATA(X)
		SELECT @COUNT=COUNT(*) FROM @TblDef  
		set @Delimeter=''  
		SET @I=1
		
			WHILE @I<=@COUNT
			BEGIN 
				set @ColName=''
				SELECT @ColName=Name,@colwidth=colwidth,@Delimeter=Delimiter FROM @TblDef  WHERE ID=@I 
				if(@ColName!='')
				BEGIN
					set @Delimeter=''' '+ @Delimeter+' '''
					if(@ColName='RoleID')
						set @ColName='P.Name'
					else 
						set @ColName='isnull(U.'+@ColName+','''')'
					if(isnull(@ColNames,'')='')
					begin
						if(isnull(@colwidth,'')<>'' and isnull(@colwidth,'')<>'-1')
							set @ColNames='substring('+@ColName+',0,'+@colwidth+')+'+@Delimeter
						else 
							set @ColNames=@ColName+'+'+@Delimeter
					end
					else
					begin
						if(isnull(@colwidth,'')<>'' and isnull(@colwidth,'')<>'-1')
							set @ColNames=@ColNames+'+'+'substring('+@ColName+',0,'+@colwidth+')+'+@Delimeter
						else 
							set @ColNames=@ColNames+'+'+@ColName+'+'+@Delimeter
					end
				END
		  SET @I=@I+1
		  END
			--print @ColNames
			
		SET @SQL=@SQL+' SELECT distinct U.UserID,U.UserName,'+ @ColNames +' as UserInfo FROM ADM_Users U WITH(NOLOCK)
						inner join ADM_UserRoleMap R WITH(NOLOCK) ON U.UserID=R.UserId
						inner join ADM_PRoles P WITH(NOLOCK) ON P.RoleID=R.RoleID
						WHERE U.StatusID=1	'
		IF(ISNULL(@UserName,'')<>'')
			SET @SQL=@SQL+' AND U.UserName='''+ @UserName +''''
			
		SET @SQL=@SQL+' ORDER BY U.UserName'
		--print @SQL
		EXEC sp_executesql @SQL
	END
		
END
GO
