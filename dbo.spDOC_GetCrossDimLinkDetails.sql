USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetCrossDimLinkDetails]
	@From [int],
	@To [int],
	@FromCCID [int],
	@TOCCID [int],
	@DOCID [int],
	@LocXML [nvarchar](max),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY     
SET NOCOUNT ON    
declare @CDDOCID int,@ToCCColID nvarchar(max)
	Declare @XML XML ;
	IF @LocXML = ''
	BEGIN
		select @CDDOCID=b.DocID
		from INV_DocDetails a WITH(NOLOCK)
		join INV_DocDetails b WITH(NOLOCK) on A.InvDocDetailsId=b.refnodeid and b.refccid=300
		where b.costcenterid=@TOCCID and a.CostCenterID=@FromCCID AND a.DocID=@DocID

	   SELECT DrAccount,CrAccount,@CDDOCID docid ,DimIn ,DimFor from ADM_CrossDimension WITH(NOLOCK) 
        where DimIn = @From and DimFor = @To and Document=@FromCCID
    END
	ELSE
	BEGIN
	set @XML = @LocXML;
	IF EXISTS(SELECT 1 FROM @XML.nodes('/Locations/Loc') as T(c) where not exists 
	(SELECT 1 FROM ADM_CrossDimension L WHERE L.DimIn =  c.value('@From','INT')  and  L.DimFor = c.value('@To','INT') AND Document=@FromCCID))
	BEGIN 
	  Select DrAccount,CrAccount, null AS docid, DimIn,DimFor From ADM_CrossDimension where 1 != 1
		--RAISERROR('ERROR  At least one combination of from  and  to values does not existin',16,1);
	END
	ELSE
	BEGIN

	   IF @DOCID = 0
	   BEGIN
	          SELECT DrAccount,CrAccount, null AS docid, DimIn,DimFor from ADM_CrossDimension l WITH(NOLOCK)
			  JOin  @XML.nodes('/Locations/Loc') as T(c) On l.DimIn = c.value('@From','INT') And  l.DimFor = c.value('@To','INT') 
			  where Document=CONVERT(NVARCHAR,@FromCCID) group by DrAccount,CrAccount,DimIn,DimFor
	   END
	   ELSE
	   BEGIN
	        Declare @SqlQuery nvarchar(max) ,@Count Int;
			select  b.DocID, C.* into #t1
			from INV_DocDetails a WITH(NOLOCK)
			join INV_DocDetails b WITH(NOLOCK) on A.InvDocDetailsId=b.refnodeid and b.refccid=300
			join Com_DocTextData C WITH(NOLOCK) on C.InvDocDetailsId = A.InvDocDetailsId 
			where b.costcenterid = @TOCCID and a.CostCenterID=@FromCCID AND a.DocID=@DocID 
			
			--select * from #t1

		   Select @ToCCColID = D.SysColumnName From Com_DocumentPreferences P 
		   Left Join Adm_CostcenterDef D on D.CostCenterColID = p.PrefValue
		   where P.CostCenterID=@FromCCID and PrefName = 'CrossDimField'
		   
		   Set @SqlQuery = ' 
		       SELECT DrAccount,CrAccount,docid, DimIn,DimFor from ADM_CrossDimension l WITH(NOLOCK)
		      join #t1 tt on tt.'+@ToCCColID+'=DimFor where Document='+CONVERT(NVARCHAR,@FromCCID)+'  group by DrAccount,CrAccount,tt.DocID,DimIn,DimFor
			  Union 
		      SELECT DrAccount,CrAccount,null AS docid, DimIn,DimFor from ADM_CrossDimension l WITH(NOLOCK)
			  JOin  @XML.nodes(''/Locations/Loc'') as T(c) On l.DimIn = c.value(''@From'',''INT'') And  l.DimFor = c.value(''@To'',''INT'') 
			  where Document='+CONVERT(NVARCHAR,@FromCCID)+' and l.DimFor not in (Select '+@ToCCColID+' from #T1)'
		   print @SqlQuery
		   Exec sp_executesql @SqlQuery,N' @XML XML,@From INT,@To INT',@XML,@From,@To
	   END
	END
 END

   --Getting Linking Fields    
   SELECT case when A.CostCenterColIDBase <0 THEN 'TO'+B.SysColumnName else B.SysColumnName end BASECOL,L.SysColumnName LINKCOL ,A.[VIEW],A.CostCenterColIDLinked,A.CalcValue  
   FROM COM_DocumentLinkDetails A WITH(NOLOCK) 
   JOIN ADM_CostCenterDef B WITH(NOLOCK) ON (B.CostCenterColID=A.CostCenterColIDBase or B.CostCenterColID=A.CostCenterColIDBase*-1)
   JOIN ADM_CostCenterDef L WITH(NOLOCK)  ON (L.CostCenterColID=A.CostCenterColIDLinked or L.CostCenterColID=A.CostCenterColIDLinked *-1)   
   join COM_DocumentLinkDef D on d.DocumentLinkDeFID=a.DocumentLinkDeFID
   WHERE D.CostCenterIDBase=@TOCCID   and D.CostCenterIDLinked=@FromCCID and A.CostCenterColIDLinked<>0  
       
	
 SET NOCOUNT OFF;    
RETURN 1    
END TRY    
BEGIN CATCH      
	--Return exception info [Message,Number,ProcedureName,LineNumber]      
	IF ERROR_NUMBER()=50000    
	BEGIN    
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
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
