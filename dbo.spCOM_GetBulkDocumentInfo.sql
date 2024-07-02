USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetBulkDocumentInfo]
	@ID [bigint],
	@LOCATION [bigint],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY 
SET NOCOUNT ON
	
		 	
  
		--SP Required Parameters Check
		IF @UserID<1
		BEGIN
			RAISERROR('-100',16,1)
		END
		
		IF @LOCATION=0
		BEGIN
			 SELECT DISTINCT BULKID,NAME,MappingType FROM COM_DocumentBulkMapping WITH(NOLOCK)
			 
 			 SELECT M.*,C.ResourceData as UserColumnName FROM COM_DocumentBulkMapping M WITH(NOLOCK)
 			 LEFT JOIN ADM_CostCenterDef A ON A.COSTCENTERCOLID=M.COSTCENTERCOLID
			  LEFT join Com_LanguageResources C on C.ResourceID=A.ResourceID
			  WHERE C.LANGUAGEID=@LangID
			 
			   
			 SELECT     CostCenterID, DocumentName, IsInventory, DocumentType FROM ADM_DocumentTypes WITH(NOLOCK)
			 
 			 --Getting Details of All Documents from Adm_CostCenterDef
			 select distinct A.CostCenterID,A.CostCenterColID,A.CostCenterName,C.ResourceData as UserColumnName, A.SysColumnName
			 from ADM_CostCenterDef A 
			 join Com_LanguageResources C on C.ResourceID=A.ResourceID AND C.LANGUAGEID=@LangID
			 where  (IsColumnUserDefined=0  or IsColumnInUse=1) and
			  SysColumnName NOT LIKE '%dcCurrID%' and SysColumnName NOT LIKE '%dcExchRT%' 
			  and  SysColumnName NOT LIKE '%dcCalcNum%' and SysColumnName NOT LIKE '%dcCalcNum%' 
			  and SysColumnName NOT LIKE '%dcCalcNum%' and SysColumnName <> 'UOMConversion'   AND SysColumnName <> 'UOMConvertedQty' 
			  and CostCenterID between 40000 and 50000 
			 order by CostCenterID
 		END
 		ELSE
 		BEGIN
 				 SELECT M.*,A.IsColumnUserDefined,C.ResourceData as UserColumnName,A.SysColumnName,A.UserColumnType,A.ColumnDataType
 				 ,DD.ShowTotal, DD.DebitAccount,DD.CreditAccount,DD.Formula,DD.PostingType,
 				 A.UserDefaultValue,A.UserProbableValues,A.IsMandatory,A.Decimal,
 				 A.IsColumnUserDefined,A.ColumnCostCenterID,A.ColumnCCListViewTypeID ,l.Resourcedata As DocumentName
 				    
 				  FROM COM_DocumentBulkMapping M WITH(NOLOCK)
 				 LEFT JOIN ADM_CostCenterDef A ON A.COSTCENTERCOLID=M.COSTCENTERCOLID
				 LEFT join Com_LanguageResources C on C.ResourceID=A.ResourceID and C.LanguageID=@LangID
				   LEFT JOIN ADM_DocumentDef DD ON DD.CostCenterColID=M.CostCenterColID
				left join ADM_RibbonView r on r.FeatureID=M.Document
				left join COM_LanguageResources l on l.ResourceID=r.ScreenResourceID and l.LanguageID=@LangID
		     
				 WHERE BULKID=@ID  AND C.LANGUAGEID=@LangID order by type,[Order]
				 
				--Get source documents
				CREATE TABLE #TABLEDOCUMENTS (ID INT IDENTITY(1,1),LINKID BIGINT,COSTCENTERIDLINKED BIGINT)
			
				 DECLARE @CNT INT,@I INT,@J INT,@RCNT INT,@type int,@LinkId int,@DocDate Datetime  ,    
				 @DueDate Datetime    ,@UserColumn nvarchar(300),@Column nvarchar(300),@SELECTCOLUMNS NVARCHAR(MAX),@SOURCECOLUMNS NVARCHAR(MAX),@DESTINATIONCOLUMNS NVARCHAR(MAX),
				 @SOURCECCID BIGINT,@DESTINATIONCCID BIGINT,@Alter NVARCHAR(MAX), @FQuery nvarchar(max),@InvDocDetID bigint
				 
				 SET @SOURCECCID=(SELECT  TOP 1 DOCUMENT FROM COM_DocumentBulkMapping WHERE 
				 BULKID=@ID  AND Type=1)
				 
				 SET @DESTINATIONCCID=(SELECT  TOP 1 DOCUMENT FROM COM_DocumentBulkMapping WHERE 
				 BULKID=@ID  AND Type=2)
				  
				 
				 INSERT INTO #TABLEDOCUMENTS
				 SELECT Type,COSTCENTERCOLID FROM COM_DocumentBulkMapping WHERE 
				 BULKID=@ID  and Type=1
				 ORDER BY Type,[Order] ASC
					set @SOURCECOLUMNS=''
				    SET @SELECTCOLUMNS=''
					set @DESTINATIONCOLUMNS=''
					 CREATE TABLE #TBL(ID INT IDENTITY(1,1),InvDocDetailsID bigint,DocNo nvarchar(100)) 
					SET @Alter=' ALTER TABLE #TBL ADD '
					 SELECT @CNT=COUNT(*),@I=1 FROM #TABLEDOCUMENTS
				 	WHILE @I<=@CNT
					BEGIN
						 select @type=LINKID from #TABLEDOCUMENTS WHERE ID=@I
						 
						 SELECT  @Column=SYSCOLUMNNAME,@UserColumn=usercolumnname FROM ADM_COSTCENTERDEF WHERE COSTCENTERCOLID IN (
							SELECT COSTCENTERIDLINKED FROM #TABLEDOCUMENTS WHERE ID=@I )
						
					 
						
						 IF @type=1
						 BEGIN  
						 if( @SOURCECOLUMNS like '%'+@Column+'%,')
						 begin
							set @I=@I+1
							continue
						  end
						 IF(@Column='DocDate')
						 begin 
								SET @Alter= @Alter + @Column + ' datetime' + ', ' 
						 end
						 else
						 begin
							 
								SET @Alter= @Alter + @Column + ' NVARCHAR(300)' + ', ' 
						 end	
						   
							 SET @SOURCECOLUMNS=@SOURCECOLUMNS + @Column 
							 
							SET @SOURCECOLUMNS=@SOURCECOLUMNS+ ',' 
							 
							SET @SELECTCOLUMNS=@SELECTCOLUMNS + @Column 
							SET @SELECTCOLUMNS=@SELECTCOLUMNS+ ',' 
						 END
						 ELSE
						 BEGIN 
						  IF(@Column='DocDate')
						  begin
								 
								SET @Alter= @Alter + @Column + ' datetime ' + ', ' 
						 end
						else
						begin
							  	
								SET @Alter= @Alter + @Column + ' NVARCHAR(300)' + ', ' 
						end		
									  
						SET @DESTINATIONCOLUMNS=@DESTINATIONCOLUMNS +  @Column  
						SET @DESTINATIONCOLUMNS=@DESTINATIONCOLUMNS+ ','
						 
						 END
						 SET @I=@I+1
					END
				 
				 
				 SET @Alter=SUBSTRING(@Alter,1,LEN(@Alter)-1)	
				 SET @SOURCECOLUMNS	 =SUBSTRING(@SOURCECOLUMNS,1,LEN(@SOURCECOLUMNS)-1)	
				  SET @SELECTCOLUMNS	 =SUBSTRING(@SELECTCOLUMNS,1,LEN(@SELECTCOLUMNS)-1)	
				  if(len(@DESTINATIONCOLUMNS)>1)
				 SET @DESTINATIONCOLUMNS =SUBSTRING(@DESTINATIONCOLUMNS,1,LEN(@DESTINATIONCOLUMNS)-1)	
				 EXEC (@Alter) 
					SET @CNT=1
					SET @I=1
					
				TRUNCATE TABLE #TABLEDOCUMENTS
				  
								 CREATE TABLE #TABLEVOUCHERS(ID int identity(1,1),Voucherno NVARCHAR(300),
								 CostCenterid NVARCHAR(300),DocDate DATETIME,DocID NVARCHAR(300))
								 SELECT @CNT=COUNT(*),@I=1 FROM #TABLEDOCUMENTS
								 set @DocDate=GETDATE()
												
												 
				  --Declaration Section    
				  DECLARE @HasAccess bit,@CostCenterID int,@ColumnName nvarchar(50),@lINKColumnName nvarchar(50)    
				  DECLARE @Query nvarchar(max),@LinkCostCenterID int,@ColID bigint,@lINKColID bigint,@PrefValue nvarchar(50)    
				  
				  
				  SET @CostCenterID=@DESTINATIONCCID      
					--SET @ColID=[CostCenterColIDBase]    
					 SET @LinkCostCenterID=@SOURCECCID 
					-- SET @lINKColID=[CostCenterColIDLinked]    
					 
					 
					    
				    
				  SELECT @ColumnName=SysColumnName from ADM_CostCenterDef    
				  where CostCenterColID=@ColID    
				    
				  SELECT @lINKColumnName=SysColumnName from ADM_CostCenterDef    
				  where CostCenterColID=@lINKColID    
				    
				    set @ColumnName='Quantity'
				    set @lINKColumnName='Quantity'
				  --Create temporary table     
				  CREATE TABLE #tblList(ID int identity(1,1),DocDetailsID bigint,Val float)      
				       
				    
				  set @Query='SELECT a.InvDocDetailsID, a.'+@ColumnName+'-isnull(sum(b.LinkedFieldValue),0) from '    
				  IF(@ColumnName LIKE 'dcNum' )    
				  SET @Query=@Query+'COM_DocNumData a ' +    
				  'join INV_DocDetails d on a.InvDocDetailsID =d.InvDocDetailsID     
				   join COM_DocCCData DC on d.InvDocDetailsID =DC.InvDocDetailsID'    
				  ELSE    
				  SET @Query=@Query+'INV_DocDetails a  join COM_DocCCData DC on a.InvDocDetailsID =DC.InvDocDetailsID'    
				      
				     
				      
					SET @Query=@Query+' left join INV_DocDetails B on a.InvDocDetailsID =b.LinkedInvDocDetailsID and b.DocID<>'+convert(nvarchar(5),0)        
				      
					select @PrefValue=PrefValue from COM_DocumentPreferences      
					where CostCenterID=@LinkCostCenterID and PrefName='AllowMultipleLinking'        
				          
					if(@PrefValue is not null and @PrefValue='True'    ) --FOr Linking Multiple      
					BEGIN      
					 SET @Query=@Query+' and b.CostCenterid='+convert(nvarchar(5),@CostCenterID)        
					END      
				      
				      
				      
				  IF(@ColumnName LIKE 'dcNum' )    
				   SET @Query=@Query+' where d.CostCenterid='+convert(nvarchar(5),@LinkCostCenterID)    
				  ELSE    
				   SET @Query=@Query+' where a.CostCenterid='+convert(nvarchar(5),@LinkCostCenterID)    
				      
				  select @PrefValue=PrefValue from COM_DocumentPreferences    
				  where CostCenterID=@LinkCostCenterID and PrefName='Allowlinkingonce'      
				      
				  if(@PrefValue is not null and @PrefValue='True')--FOr Linking only once    
				  begin    
				   SET @Query=@Query+' and a.InvDocDetailsID not in ( select LinkedInvDocDetailsID from INV_DocDetails with(nolock) where LinkedInvDocDetailsID is not null)'    
				  end    
				      
				  IF(@LOCATION > 0)    
				   SET @Query=@Query+' and DC.dcCCNID2='+convert(nvarchar(5),@LOCATION)    
				  --IF(@DivisionID > 0)    
				  --BEGIN    
				  -- select @PrefValue=PrefValue from COM_DocumentPreferences                    --Need to check    
				  -- where CostCenterID=@CostCenterID and PrefName='OverrideDivisionwise'      
				        
				  -- if(@PrefValue is null or @PrefValue<>'True')--FOr Override Division wise    
				  -- SET @Query=@Query+' and DC.dcCCNID1='+convert(nvarchar(5),@DivisionID)    
				  --END    
				      
				      
				  select @PrefValue=PrefValue from COM_DocumentPreferences    --Need to check    
				  where CostCenterID=@CostCenterID and PrefName='MonthWise'      
				    
				  if(@PrefValue is NOT null AND  @PrefValue='True' and @DocDate is not null and @DocDate <> '')--FOr DocDate filter    
				  BEGIN    
				   SET @Query=@Query+' and month(convert(datetime, a.DocDate)) = '''+convert(nvarchar(20),month(@DocDate))+''''     
					 END    
				          
				       
				  select @PrefValue=PrefValue from COM_DocumentPreferences    --Need to check    
				  where CostCenterID=@CostCenterID and PrefName='Ondocumentdate'      
				      
				  if(@PrefValue is NOT null AND  @PrefValue='True' and @DocDate is not null and @DocDate <> '')--FOr DocDate filter    
				  BEGIN    
				   SET @Query=@Query+' and convert(datetime, a.DocDate) = '''+convert(nvarchar(20),@DocDate)+''''     
					 END    
				         
					 select @PrefValue=PrefValue from COM_DocumentPreferences    --Need to check    
				  where CostCenterID=@CostCenterID and PrefName='Duedatewise'      
				      
				  if(@PrefValue is NOT null AND  @PrefValue='True' and @DueDate is not null and @DueDate <> '' and @DueDate not like  '1-1-1900%') --FOr DueDate filter    
				  BEGIN    
				   SET @Query=@Query+' and convert(datetime, a.DueDate) = '''+convert(nvarchar(20),@DueDate)+''''    
					 END    
				          
				          
				          
				  SET @Query=@Query+' group by a.InvDocDetailsID,a.'+@ColumnName    
				      
				  select @PrefValue=PrefValue from COM_DocumentPreferences    
				  where CostCenterID=@CostCenterID and PrefName='LinkZeroQty'      
				      
				  if(@PrefValue is null or @PrefValue<>'True')--FOr Link Zero Qty no validation    
				  begin    
				   SET @Query=@Query+' having a.'+@ColumnName+'-isnull(sum(b.LinkedFieldValue),0) <>0  '    
				  end    
				      
				   --Read XML data into temporary table only to delete records    
				    
				  print @Query    
				  INSERT INTO #tblList    
				  Exec(@Query)    
				     
				      
							
						    SELECT @RCNT=COUNT(*),@J=1 FROM #tblList
							WHILE @J<=@RCNT
							BEGIN
								SELECT @InvDocDetID=DocDetailsID from #tblList where ID=@J
								 
									SET @FQuery=' INSERT INTO #TBL(InvDocDetailsID,docno,'+@SOURCECOLUMNS+') 
									SELECT I.InvDocDetailsID,I.VoucherNo,'+@SELECTCOLUMNS+' FROM [INV_DocDetails] I
									LEFT JOIN [COM_DocCCData] CC ON CC.InvDocDetailsID=I.InvDocDetailsID
									LEFT JOIN [COM_DocNumData] NU ON NU.InvDocDetailsID=I.InvDocDetailsID
									LEFT JOIN [COM_DocTextData] TT ON TT.InvDocDetailsID=I.InvDocDetailsID WHERE  
									  CostCenterID='+CONVERT(VARCHAR,@SOURCECCID)+'   AND I.InvDocDetailsID='''+convert(nvarchar,@InvDocDetID)+'''  ' 
									 
									  EXEC(@FQuery)
									  
								SET @J=@J+1
							END 
							 
							 SET @J=1
							 SET @RCNT=1
							 
							set @FQuery='SELECT InvDocDetailsID,Docno,'+@SOURCECOLUMNS+' FROM #TBL  '
							exec (@FQuery)
				  
							select @SOURCECOLUMNS
				 
						if @DESTINATIONCCID>0
						begin
						   --Getting Linking Fields  
						   SELECT DISTINCT L.CostCenterColID,  L.SysColumnName BASECOL,B.SysColumnName LINKCOL ,B.CostCenterColID lINKCOLID, A.[VIEW]   FROM COM_DocumentLinkDetails A  
						   JOIN ADM_CostCenterDef B ON B.CostCenterColID=A.CostCenterColIDBase  
						   JOIN ADM_CostCenterDef L ON L.CostCenterColID=A.CostCenterColIDLinked  
						   WHERE A.DocumentLinkDeFID IN 
						   (SELECT top 1 DocumentLinkDeFID FROM [COM_DocumentLinkDef] WHERE [CostCenterIDBase]=@DESTINATIONCCID
						   AND [CostCenterIDLinked]=@SOURCECCID )
						end  
						else
						begin
							 select distinct A.CostCenterColID,A.SysColumnName BASECOL,A.SysColumnName LINKCOL
							  ,A.CostCenterColID lINKCOLID, 0 '0'
							 from ADM_CostCenterDef A 
							 join Com_LanguageResources C on C.ResourceID=A.ResourceID AND C.LANGUAGEID=@LangID
							 where  (IsColumnUserDefined=0  or IsColumnInUse=1) and
							  SysColumnName NOT LIKE '%dcCurrID%' and SysColumnName NOT LIKE '%dcExchRT%' 
							  and  SysColumnName NOT LIKE '%dcCalcNum%' and SysColumnName NOT LIKE '%dcCalcNum%' 
							  and SysColumnName NOT LIKE '%dcCalcNum%' and SysColumnName <> 'UOMConversion'   AND SysColumnName <> 'UOMConvertedQty' 
							  and CostCenterID =@SOURCECCID
							 order by CostCenterColID
						end   
						 
						     SELECT   a.*,cc.*,
							    NUM.*   ,TEX.*
							  from [INV_DocDetails] a WITH(NOLOCK)    
							  join #tblList c on a.InvDocDetailsID=c.DocDetailsID    
							  join COM_DocCCData CC  WITH(NOLOCK) on a.InvDocDetailsID=CC.InvDocDetailsID    
							   join [COM_DocNumData] NUM  WITH(NOLOCK) on a.InvDocDetailsID=NUM.InvDocDetailsID    
							      join [COM_DocTextData] TEX  WITH(NOLOCK) on a.InvDocDetailsID=TEX.InvDocDetailsID    
							  where a.statusid=369   
							  order by     Convert(datetime, a.DocDate) DESC ,  a.voucherno   
													   
					 select DocumentLinkDefID from dbo.COM_DocumentLinkDef
					 where CostCenterIDBase=@DESTINATIONCCID and CostCenterIDLinked=@SOURCECCID
						   --@DocumentLinkDefID  
						
				
 		END
 		
 		 select CostCenterColID,SysColumnName,CostCenterID,UserProbableValues from adm_costcenterdef
		 where (CostCenterID=@DESTINATIONCCID or CostCenterID=@SOURCECCID)
		 and (SysColumnName='DebitAccount' or SysColumnName='CreditAccount')
					
 		
 		 
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
