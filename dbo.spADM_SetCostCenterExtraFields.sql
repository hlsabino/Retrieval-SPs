USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetCostCenterExtraFields]
	@XML [nvarchar](max),
	@ExtraTabXML [nvarchar](max),
	@StaticXML [nvarchar](max) = null,
	@FollowXML [nvarchar](max) = null,
	@QuickXML [nvarchar](max),
	@GridsXML [nvarchar](max),
	@PreferenceXml [nvarchar](max),
	@ExtrnFuncXML [nvarchar](max),
	@COSTCENTERID [int],
	@ParentCCID [int],
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
SET NOCOUNT ON      
BEGIN TRY      
	--Declaration Section      
	DECLARE @TempGuid NVARCHAR(50),@TextFormat int,@COLSPAN INT,@HasAccess BIT,@DATA XML,@COUNT INT,@I INT,@FIELDNAME NVARCHAR(300),  @TYPE NVARCHAR(300),      
	@TabName NVARCHAR(300), @DEFAULTVALUE NVARCHAR(300), @ResourceID INT,@COSTCENTERCOLID INT,@MAPACTION NVARCHAR(300),@SQL nvarchar(max),  
	@Filter NVARCHAR(10),   @Display NVARCHAR(10), @PROBABLEVALUES NVARCHAR(MAX), @MANDATORY smallint, @COLUMNCOSTCENTERID INT, @CNTTAB INT,      
	@IsCostCenterUserDefined NVARCHAR(10), @ColumnDataType NVARCHAR(10), @RowCount int, @SectionName NVARCHAR(50),@SectionSeqNumber INT,  @ExtraTabData XML 
	DECLARE @COLUMNCCLISTVIEWTYPEID INT, @StaticXMLData XML,@langResourceID int,@Formula nvarchar(max),@localRef INT,@lnkData INT,@ResID INT,@IsCalculate bit,@EvalAfter nvarchar(200)
	DECLARE @GridData XML,@dependancy INT,@dependanton INT,@Isvisible bit,@IsUnique int,@IsnoTab bit,@Decimals int,@XMLDATA XML,@IgnoreChars INT,@WaterMark nvarchar(500),@MinChar int,@MaxChar int,@FieldExpression NVARCHAR(MAX),@LabelColor NVARCHAR(500),@ExtFuntDATA XML
	
	SET @GridData=@GridsXML
	SET @DATA=@XML      
	SET @ExtraTabData = @ExtraTabXML  


	--SP Required Parameters Check      
	IF @CompanyGUID IS NULL OR @CompanyGUID=''      
	BEGIN      
		RAISERROR('-100',16,1)      
	END      

	--User acces check       
	if(@COSTCENTERID <> 114 AND @COSTCENTERID<>110 AND @COSTCENTERID<>115 AND @COSTCENTERID<>154 
	AND @COSTCENTERID<>155 AND @COSTCENTERID<>146 AND @COSTCENTERID<>144 AND @COSTCENTERID<>156
	AND @COSTCENTERID<>123 AND @COSTCENTERID<>124 AND @COSTCENTERID<>127 AND @COSTCENTERID<>119 AND @COSTCENTERID<>118
	AND @COSTCENTERID<>120 AND @COSTCENTERID<>121 AND @COSTCENTERID<>251 AND @COSTCENTERID<>252 AND @COSTCENTERID<>253 AND @COSTCENTERID<>254 AND @COSTCENTERID<>255)
	BEGIN      
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@COSTCENTERID,31)      
	END       
	
	IF @HasAccess=0      
	BEGIN      
		RAISERROR('-105',16,1)      
	END  
	    
	--@XML = N'<XML><Row    RowNo="1" FieldName="department" Type="50004" CCTabName="105" DefaultValue="" ProbableValues="" Display="True"  MAPACTION=''NEW''  CostCenterColID="" Mandatory="False" IsCostCenterUserDefined =''True''  ColumnCostCenterID='''' ColumnDataType=''INT''/></XML>',
	CREATE TABLE #TBLTEMP(ID INT IDENTITY(1,1),FIELDNAME NVARCHAR(300),DEFAULTVALUE NVARCHAR(300),Formula NVARCHAR(max),localRef INT,lnkData INT,
	DTYPE NVARCHAR(50),COSTCENTERCOLID INT,MAPACTION VARCHAR(300),COLSPAN INT,DISPLAY VARCHAR(10),
	PROBABLEVALUES VARCHAR(MAX), MANDATORY smallint, COLUMNCOSTCENTERID INT, IsCostCenterUserDefined NVARCHAR(10), 
	ColumnDataType NVARCHAR(10), SectionID INT,SectionSeqNumber INT,ListViewTypeID int,TextFormat int, Filter NVARCHAR(10)
	,dependancy INT,dependanton INT,Isvisible bit,IsUnique int,IsnoTab bit,Decimals int,IgnoreChars INT,WaterMark nvarchar(500),MinChar INT,MaxChar INT
	,FieldExpression nvarchar(max),LabelColor nvarchar(500),Calc bit,EvalAfter nvarchar(200))  
	
	INSERT INTO #TBLTEMP      
	SELECT  X.value('@FieldName','NVARCHAR(300)'),      
	X.value('@DefaultValue','NVARCHAR(300)'),  
	X.value('@Formula','NVARCHAR(max)'),       
	X.value('@LocalRef','INT'),       
	X.value('@linkdata','INT'),       
	X.value('@Type','NVARCHAR(300)'),      
	X.value('@CostCenterColID','INT'),      
	X.value('@MAPACTION','NVARCHAR(300)'),   
	X.value('@ColumnSpan','INT'),     
	X.value('@Display','NVARCHAR(10)'),      
	X.value('@ProbableValues','NVARCHAR(MAX)'),      
	X.value('@Mandatory','smallint'),      
	X.value('@ColumnCostCenterID','INT'),      
	X.value('@IsCostCenterUserDefined','NVARCHAR(10)'),      
	X.value('@ColumnDataType','NVARCHAR(10)') ,    
	case when X.value('@CCTabName','INT')=0 THEN NULL ELSE X.value('@CCTabName','INT') end,    
	X.value('@SectionSeqNumber','INT'),
	X.value('@ListViewID','INT'),X.value('@TextFormat','INT'), X.value('@Filter','NVARCHAR(10)'),
	X.value('@dependancy','INT'),       
	X.value('@dependanton','INT'),       
	isnull(X.value('@Isvisible','bit'),1),
	X.value('@IsUnique','int')
	,isnull(X.value('@IsnoTab','bit'),0)
	,X.value('@Decimals','int')
	,X.value('@IgnoreChars','INT')
	,X.value('@WaterMark','NVARCHAR(500)')
	,X.value('@MinChar','int')
	,X.value('@MaxChar','int')
	,X.value('@FieldExpression','NVARCHAR(MAX)')
	,X.value('@LabelColor','NVARCHAR(500)')
	,X.value('@IsCalculate','BIT'),X.value('@EvalAfter','NVARCHAR(500)')
	from @DATA.nodes('XML/Row') as DATA(X) 


	update #TBLTEMP
	set COSTCENTERCOLID=0,MAPACTION='NEW'
	from #TBLTEMP T with(nolock) 
	inner join adm_costcenterdef C with(nolock) on C.CostCenterColID=T.CostCenterColID
	where SysTableName='COM_CCCCData' and T.COLUMNCOSTCENTERID=0

	
	IF @ParentCCID<>-1
	BEGIN
		--IF EXTRA FIELDS FOR ACTIVITIES ARE NOT PRESENT THEN INSERT DEFAULT EXTRA FIELDS
		IF(NOT EXISTS(SELECT * FROM ADM_COSTCENTERDEF with(nolock) WHERE LOCALREFERENCE=@ParentCCID AND CostCenterID=144))
		BEGIN
			EXEC spCom_SetActivitiesCustomizeFields @ParentCCID,@UserID,@LangID
		END														 
		
		IF (@ParentCCID=73 OR @ParentCCID=86 OR @ParentCCID=1000 OR @ParentCCID=88 OR @ParentCCID=89 OR @ParentCCID=83 OR @ParentCCID=65 or @ParentCCID>40000)
		 	UPDATE ADM_CostCenterDef SET ISCOLUMNINUSE=0
			WHERE COSTCENTERID=@COSTCENTERID AND LOCALREFERENCE=@ParentCCID AND (SYSCOLUMNNAME like '%CCNID%' OR SYSCOLUMNNAME like '%alpha%') AND
			CostCenterColID NOT IN (SELECT CostCenterColID	FROM #TBLTEMP with(nolock) WHERE CostCenterColID is not null and CostCenterColID>0)
	END
	ELSE
		UPDATE ADM_CostCenterDef SET ISCOLUMNINUSE=0
		WHERE COSTCENTERID=@COSTCENTERID AND (SYSCOLUMNNAME like '%CCNID%' OR SYSCOLUMNNAME like '%alpha%') AND
		CostCenterColID NOT IN (SELECT CostCenterColID	FROM #TBLTEMP with(nolock) WHERE CostCenterColID is not null and CostCenterColID>0)
		AND IsColumnUserDefined=1

	SELECT @I=1,@COUNT=COUNT(*) FROM #TBLTEMP with(nolock)

	WHILE @I<=@COUNT      
	BEGIN      
    
		SELECT @COLSPAN=COLSPAN, @FIELDNAME=FIELDNAME,@TextFormat=TextFormat,@Formula=Formula,@localRef=localRef,@lnkData=lnkData,
		@MAPACTION=MAPACTION,@DefaultValue=DefaultValue, @Type=DTYPE,      @Filter=Filter,
		@COSTCENTERCOLID=COSTCENTERCOLID, @Display=Display,@ColumnDataType=COLUMNDATATYPE ,      
		@ProbableValues=ProbableValues,@COLUMNCOSTCENTERID=COLUMNCOSTCENTERID, @Mandatory=Mandatory ,
		@SectionName =  SectionID,@SectionSeqNumber=SectionSeqNumber,@COLUMNCCLISTVIEWTYPEID=ListViewTypeID
		,@dependancy =dependancy,@dependanton =dependanton ,@Isvisible =Isvisible,@IsUnique=IsUnique,@IsnoTab=IsnoTab,@Decimals=Decimals
		,@IgnoreChars=IgnoreChars,@WaterMark=WaterMark,@MinChar=MinChar,@MaxChar=MaxChar,@FieldExpression=FieldExpression,@LabelColor=LabelColor
		,@IsCalculate=Calc,@EvalAfter=EvalAfter
		FROM #TBLTEMP with(nolock) WHERE ID=@I   

		if(@localRef is not null and (@localRef=2 or @localRef>50000) and @localRef<>26642 and @localRef<>26658)
		begin
			if(@localRef>50000)
			begin
				select  @localRef= CostCenterColID from ADM_CostCenterDef with(nolock)
				where CostCenterID=@CostCenterID and                
				SYSCOLUMNNAME='CCNID'+CONVERT(NVARCHAR,(@localRef-50000)) 
			end  
			else if (@localRef=2)
			begin
				select  @localRef= CostCenterColID from ADM_CostCenterDef with(nolock)
				where CostCenterID=@CostCenterID and COLUMNCOSTCENTERID=@localRef and iscolumninuse=1 and 
				(SYSCOLUMNNAME like '%alpha%' or SYSCOLUMNNAME='AccountID')  
			end
		end

		IF ((@MAPACTION='NEW'  or @MAPACTION='EDIT'  ) and @COLUMNCOSTCENTERID is not null and 
		(@COLUMNCOSTCENTERID>50000  OR @COLUMNCOSTCENTERID = 2 OR @COLUMNCOSTCENTERID = 3 OR @COLUMNCOSTCENTERID=44) )
		BEGIN 
   
			IF(@COLUMNCOSTCENTERID = 2)
			BEGIN		
				IF(@COLUMNCCLISTVIEWTYPEID is null or @COLUMNCCLISTVIEWTYPEID=0)
					SET @COLUMNCCLISTVIEWTYPEID = 2 -- Temporarily added
			END
			ELSE IF (@COLUMNCOSTCENTERID = 3)
			BEGIN
				if(@COSTCENTERID not in(115,154,155,156))		
					SELECT @COSTCENTERCOLID=COSTCENTERCOLID        
					FROM ADM_CostCenterDef with(nolock) 
					WHERE COSTCENTERID=@COSTCENTERID and SYSCOLUMNNAME='PRODUCTID' 	
				ELSE IF @MAPACTION='NEW'	
					SELECT @COSTCENTERCOLID=COSTCENTERCOLID        
					FROM ADM_CostCenterDef with(nolock) 
					WHERE COSTCENTERID=@COSTCENTERID  AND ISCOLUMNINUSE=0 AND SYSCOLUMNNAME LIKE '%Alpha%' and IsColumnDeleted=0

				if(@COLUMNCCLISTVIEWTYPEID is null or @COLUMNCCLISTVIEWTYPEID=0)
					SET @COLUMNCCLISTVIEWTYPEID = 10 -- Temporarily added
			END
			ELSE IF (@COSTCENTERID = 144)
			BEGIN 
				SELECT @COSTCENTERCOLID=COSTCENTERCOLID        
				FROM ADM_CostCenterDef with(nolock) WHERE COSTCENTERID=@COSTCENTERID  and   LOCALREFERENCE=@ParentCCID AND   
				SYSCOLUMNNAME='CCNID'+CONVERT(NVARCHAR,(@COLUMNCOSTCENTERID-50000))   
				
				if(@COLUMNCCLISTVIEWTYPEID is null or @COLUMNCCLISTVIEWTYPEID=0)
					SET @COLUMNCCLISTVIEWTYPEID = 1 -- Temporarily added  
			END
			ELSE
			BEGIN
				if(@COSTCENTERID in(95,104,103,129))
				BEGIN
					declare @tablename nvarchar(50)
					if(@COSTCENTERID in(95,104) and @SectionName=2)
						set @tablename='REN_ContractParticulars'
					else if(@COSTCENTERID in(95,104) and @SectionName=3)
						set @tablename='REN_ContractPayTerms'
					else if(@COSTCENTERID in(103,129) and @SectionName=2)
						set @tablename='REN_QuotationParticulars'
					else  if(@COSTCENTERID in(103,129) and @SectionName=3)
						set @tablename='REN_QuotationPayTerms'
					else
						set @tablename='COM_CCCCData'  
						
					SELECT @COSTCENTERCOLID=COSTCENTERCOLID        
					FROM ADM_CostCenterDef with(nolock) WHERE COSTCENTERID=@COSTCENTERID  and      
					SYSCOLUMNNAME='CCNID'+CONVERT(NVARCHAR,(@COLUMNCOSTCENTERID-50000)) 
					and SysTableName=@tablename  
			
					IF(@CostCenterColID is null or @CostCenterColID=0)
					BEGIN		
						exec [SpADM_AddColumn] @COSTCENTERID,@COLUMNCOSTCENTERID,'',@COSTCENTERCOLID OUTPUT
						
						update ADM_CostCenterDef
						set SysTableName=@tablename,sectionid=@SectionName
						where COSTCENTERCOLID=@COSTCENTERCOLID
						
						if not exists(select * from sys.columns where Object_id	=Object_id(@tablename) and name='CCNID'+CONVERT(NVARCHAR,(@COLUMNCOSTCENTERID-50000)) )
						AND @COLUMNCOSTCENTERID>50000
						BEGIN
							set @SQL='alter table '+@tablename+' add CCNID'+CONVERT(NVARCHAR,(@COLUMNCOSTCENTERID-50000)) +' INT'
							if(@tablename='REN_ContractParticulars')
								set @SQL=@SQL+' alter table REN_Particulars add CCNID'+CONVERT(NVARCHAR,(@COLUMNCOSTCENTERID-50000)) +' INT'
								
							print @SQL
							exec(@SQL)
						END
					END
				END
				ELSE IF(@COSTCENTERID = 50051 AND @COLUMNCOSTCENTERID<>44)
				BEGIN
					if not exists(select * from sys.columns where Object_id	=Object_id('COM_DOCCCDATA') and name='dcCCNID'+CONVERT(NVARCHAR,(@COLUMNCOSTCENTERID-50000)) )
					BEGIN
						set @SQL='alter table COM_DocCCData add dcCCNID'+convert(nvarchar,@COLUMNCOSTCENTERID-50000)+' BIGINT default(1) not null
						ALTER TABLE [COM_DocCCData] WITH CHECK ADD  CONSTRAINT [FK_COM_DocCCData_COM_CC'+convert(nvarchar,@COLUMNCOSTCENTERID)+'] FOREIGN KEY([dcCCNID'+convert						(nvarchar,@COLUMNCOSTCENTERID-50000)+']) REFERENCES [COM_CC'+convert(nvarchar,@COLUMNCOSTCENTERID)+'] ([NodeID])
						ALTER TABLE [COM_DocCCData] CHECK CONSTRAINT [FK_COM_DocCCData_COM_CC'+convert(nvarchar,@COLUMNCOSTCENTERID)+']'
					
					Exec sp_executesql @SQL
						
					set @SQL='alter table COM_DocCCData_History add dcCCNID'+convert(nvarchar,@COLUMNCOSTCENTERID-50000)+' INT  default(1) not null'
					print @SQL
					Exec sp_executesql @SQL
					END

					SELECT @COSTCENTERCOLID=COSTCENTERCOLID        
					FROM ADM_CostCenterDef with(nolock) WHERE COSTCENTERID=@COSTCENTERID  and      
					SYSCOLUMNNAME='CCNID'+CONVERT(NVARCHAR,(@COLUMNCOSTCENTERID-50000)) 

				END
				ELSE
				BEGIN
					SELECT @COSTCENTERCOLID=COSTCENTERCOLID        
					FROM ADM_CostCenterDef with(nolock) WHERE COSTCENTERID=@COSTCENTERID  and      
					SYSCOLUMNNAME='CCNID'+CONVERT(NVARCHAR,(@COLUMNCOSTCENTERID-50000))   
				END	
				
				if(@COLUMNCCLISTVIEWTYPEID is null or @COLUMNCCLISTVIEWTYPEID=0)
					SET @COLUMNCCLISTVIEWTYPEID = 1 -- Temporarily added  
			END 
  
			IF @MAPACTION='NEW' and (@COLUMNCOSTCENTERID = 2 or @COLUMNCOSTCENTERID=44)
			BEGIN	   
				IF @COSTCENTERID=144 --IF CUSTOMIZATION IS DONE AT ACTIVITIES THEN COSTCENTERCOLID IS BASED ON LOCALREFERENCE
				BEGIN
					SELECT TOP 1  @COSTCENTERCOLID=COSTCENTERCOLID  FROM ADM_CostCenterDef with(nolock) WHERE 
					COSTCENTERID=@COSTCENTERID AND ISCOLUMNINUSE=0   and   LOCALREFERENCE=@ParentCCID    
					AND SYSCOLUMNNAME LIKE '%Alpha%'  
				end	 
				else 
				BEGIN
					SELECT TOP 1  @COSTCENTERCOLID=COSTCENTERCOLID  FROM ADM_CostCenterDef with(nolock) WHERE COSTCENTERID=@COSTCENTERID AND ISCOLUMNINUSE=0      
					AND SYSCOLUMNNAME LIKE '%Alpha%'  
				end	      
			END 
			
			IF((@CostCenterColID is null or @CostCenterColID=0) and @CostCenterID>50000)
			BEGIN			
				exec [SpADM_AddColumn] @COSTCENTERID,@COLUMNCOSTCENTERID,'',@COSTCENTERCOLID OUTPUT
			END
			
			IF((@CostCenterColID is null or @CostCenterColID=0) and @COLUMNCOSTCENTERID>50000)
			BEGIN			
				exec [SpADM_AddColumn] @COSTCENTERID,@COLUMNCOSTCENTERID,'',@COSTCENTERCOLID OUTPUT
			END
			
			IF @COSTCENTERCOLID is not null       
			BEGIN     
		  
				UPDATE ADM_CostCenterDef SET ISCOLUMNINUSE=1,TextFormat=@TextFormat, ISCOSTCENTERUSERDEFINED=1, ISCOLUMNUSERDEFINED=1,
				ISEDITABLE=@Display,COLUMNSPAN=@COLSPAN, ISVISIBLE=@Isvisible,IsUnique=@IsUnique, USERCOLUMNNAME=@FIELDNAME,ISCOLUMNDELETED=0, Filter=@Filter,
				USERCOLUMNTYPE='LISTBOX', COLUMNCOSTCENTERID=@COLUMNCOSTCENTERID, USERDEFAULTVALUE=@DefaultValue,Cformula=@Formula,LocalReference=@localRef,LinkData=@LnkData,
				USERPROBABLEVALUES=@ProbableValues, ISMANDATORY=@MANDATORY, COLUMNCCLISTVIEWTYPEID=@COLUMNCCLISTVIEWTYPEID, SectionID = @SectionName,SectionSeqNumber=@SectionSeqNumber
				,dependancy=@dependancy ,dependanton=@dependanton,IsnoTab=@IsnoTab,Decimal=@Decimals,Calculate=@IsCalculate,EvalAfter=@EvalAfter
				WHERE COSTCENTERID=@COSTCENTERID AND COSTCENTERCOLID=@COSTCENTERCOLID
					
				UPDATE COM_LANGUAGERESOURCES SET RESOURCENAME=@FieldName, RESOURCEDATA=@FieldName
				WHERE RESOURCEID=(SELECT RESOURCEID FROM ADM_COSTCENTERDEF with(nolock) WHERE COSTCENTERCOLID=@COSTCENTERCOLID AND COSTCENTERID=@COSTCENTERID)
				AND LANGUAGEID=@LangID      
				
				UPDATE #TBLTEMP SET COSTCENTERCOLID=@COSTCENTERCOLID WHERE ID=@I
				
			END   
		END   
		else IF @MAPACTION='EDIT'      
		BEGIN    
			UPDATE ADM_CostCenterDef 
			SET ISCOLUMNINUSE=1,COLUMNSPAN=@COLSPAN, USERCOLUMNNAME=@FIELDNAME,TextFormat=@TextFormat, ISEDITABLE=@Display, USERDEFAULTVALUE=@DefaultValue,Cformula=@Formula,LocalReference=@localRef,LinkData=@LnkData,
				USERCOLUMNTYPE=@Type,USERPROBABLEVALUES=@ProbableValues, ISMANDATORY=@MANDATORY, COLUMNDATATYPE=@ColumnDataType ,
				SectionID = @SectionName,SectionSeqNumber=@SectionSeqNumber, filter=@Filter,IgnoreChar=@IgnoreChars,WaterMark=@WaterMark
				,dependancy=@dependancy ,dependanton=@dependanton, ISVISIBLE=@Isvisible,IsUnique=@IsUnique,IsnoTab=@IsnoTab,Decimal=@Decimals, COLUMNCOSTCENTERID=@COLUMNCOSTCENTERID,MinChar=@MinChar,MaxChar=@MaxChar,FieldExpression=@FieldExpression,LabelColor=@LabelColor
				,Calculate=@IsCalculate,EvalAfter=@EvalAfter
			WHERE COSTCENTERID=@COSTCENTERID AND COSTCENTERCOLID=@COSTCENTERCOLID       
			  
			UPDATE COM_LANGUAGERESOURCES SET RESOURCENAME=@FieldName, RESOURCEDATA=@FieldName
			WHERE RESOURCEID=(SELECT RESOURCEID FROM ADM_COSTCENTERDEF with(nolock) WHERE COSTCENTERCOLID=@COSTCENTERCOLID AND COSTCENTERID=@COSTCENTERID)
			AND LANGUAGEID=@LangID      
		END       
		ELSE IF @MAPACTION='NEW'    
		BEGIN  
			IF @COSTCENTERID=144 --IF CUSTOMIZATION IS DONE AT ACTIVITIES THEN COSTCENTERCOLID IS BASED ON LOCALREFERENCE
			BEGIN
				SELECT TOP 1  @COSTCENTERCOLID=COSTCENTERCOLID  FROM ADM_CostCenterDef with(nolock) WHERE COSTCENTERID=@COSTCENTERID 
				AND [LocalReference]=@ParentCCID AND ISCOLUMNINUSE=0 AND SYSCOLUMNNAME LIKE '%Alpha%' and IsColumnDeleted=0
			END 
			ELSE
			BEGIN
				SELECT TOP 1  @COSTCENTERCOLID=COSTCENTERCOLID  FROM ADM_CostCenterDef with(nolock) WHERE COSTCENTERID=@COSTCENTERID AND ISCOLUMNINUSE=0 
				 AND SYSCOLUMNNAME LIKE '%Alpha%' and IsColumnDeleted=0 AND COSTCENTERCOLID>224
				 
				IF((@COSTCENTERID IN(2,3,92,93,94,95,103,104,129,83,86,88,89,65) or @COSTCENTERID>50000) and (@CostCenterColID IS NULL or @CostCenterColID=0))
				BEGIN
					 exec [SpADM_AddColumn] @COSTCENTERID,0,'',@COSTCENTERCOLID OUTPUT
				END
			END	 
			--select @COSTCENTERCOLID,@Display
			UPDATE ADM_CostCenterDef SET ISCOLUMNINUSE=1,COLUMNSPAN=@COLSPAN, TextFormat=@TextFormat,Filter=@Filter,
			ISCOLUMNUSERDEFINED=1, ISVISIBLE=@Isvisible,IsUnique=@IsUnique, ISEDITABLE=@Display, USERCOLUMNNAME=@FIELDNAME, 
			USERCOLUMNTYPE=@TYPE, USERDEFAULTVALUE=@DefaultValue,Cformula=@Formula,LocalReference=@localRef,LinkData=@LnkData, USERPROBABLEVALUES=@ProbableValues, ISMANDATORY=@MANDATORY, COLUMNDATATYPE=@ColumnDataType  , SectionID = @SectionName,SectionSeqNumber=@SectionSeqNumber
			,dependancy=@dependancy ,dependanton=@dependanton,IsnoTab=@IsnoTab,Decimal=@Decimals,IgnoreChar=@IgnoreChars,WaterMark=@WaterMark,MinChar=@MinChar,MaxChar=@MaxChar,FieldExpression=@FieldExpression,LabelColor=@LabelColor
			,Calculate=@IsCalculate,EvalAfter=@EvalAfter
			WHERE COSTCENTERID=@COSTCENTERID AND COSTCENTERCOLID=@COSTCENTERCOLID   

			UPDATE COM_LANGUAGERESOURCES SET RESOURCENAME=@FieldName, RESOURCEDATA=@FieldName      
			WHERE RESOURCEID=(SELECT RESOURCEID FROM ADM_COSTCENTERDEF with(nolock) WHERE COSTCENTERCOLID=@COSTCENTERCOLID AND COSTCENTERID=@COSTCENTERID)      
			AND LANGUAGEID=@LangID   

			UPDATE #TBLTEMP SET COSTCENTERCOLID=@COSTCENTERCOLID WHERE ID=@I
		END      
		ELSE IF @MAPACTION='DELETE'       
		BEGIN      
			UPDATE ADM_CostCenterDef SET ISCOLUMNDELETED=1      
			WHERE COSTCENTERID=@COSTCENTERID AND COSTCENTERCOLID=@COSTCENTERCOLID           
		END      
		SET @I=@I+1      
	END    
  
     
	SET @StaticXMLData = @StaticXML
	 
	IF(@StaticXMLData IS NOT NULL)
	BEGIN
	 	UPDATE ADM_COSTCENTERDEF 
		SET  SectionSeqNumber = X.value('@Order','INT'),  
			IsVisible = X.value('@Visible','BIT'),
			IsEditable = X.value('@Editable','BIT'),
			IsMandatory = X.value('@Mandatory','smallint'), 
			Columnspan= X.value('@ColumnSpan','INT'),
			TextFormat= X.value('@TextFormat','INT')  ,
			Filter= X.value('@Filter','BIT')  
			,IsUnique= X.value('@IsUnique','int')
			,IsnoTab=isnull(X.value('@IsnoTab','bit'),0)
			,sectionID=case when X.value('@SectionID','int') is not null and X.value('@SectionID','int')>0 THEN X.value('@SectionID','int')
			 when X.value('@SectionID','int') is not null and X.value('@SectionID','int')=0 THEN NULL ELSE SectionID END
			,UserProbableValues=X.value('@ProbableValues','Nvarchar(max)')
			,[Decimal]=X.value('@Decimals','int')
			,UserColumnName = X.value('@Rename','NVARCHAR(500)')
			,IgnoreChar=X.value('@IgnoreChars','INT')
			,WaterMark=X.value('@WaterMark','NVARCHAR(500)')
			,MinChar=X.value('@MinChar','INT')
			,MaxChar=X.value('@MaxChar','INT')
			,FieldExpression=X.value('@FieldExpression','NVARCHAR(MAX)')
			,LabelColor=X.value('@LabelColor','NVARCHAR(500)')
			,Cformula=X.value('@Formula','NVARCHAR(Max)')
			,Calculate=X.value('@IsCalculate','BIT')
			,EvalAfter=X.value('@EvalAfter','NVARCHAR(500)')
		from ADM_COSTCENTERDEF with(nolock)
		left join @StaticXMLData.nodes('XML/Row') as Data(X)
		 on ADM_COSTCENTERDEF.CostCenterColID=X.value('@CostCenterColID','INT')  
		where COSTCENTERID = @COSTCENTERID AND CostCenterColID = X.value('@CostCenterColID','INT') 



		if(@COSTCENTERID=73 OR @COSTCENTERID=2 OR @COSTCENTERID=76  OR @COSTCENTERID=3 OR @COSTCENTERID=92 OR @COSTCENTERID=93 OR @COSTCENTERID=50051
		or @COSTCENTERID >50000 or @COSTCENTERID in(86, 83, 88, 89, 65, 73, 92, 93, 94, 95, 103, 104, 129))		 
			UPDATE ADM_COSTCENTERDEF 
			SET ColumnCCListViewTypeID=isnull(X.value('@ListViewTypeID','INT'),0)
			from ADM_COSTCENTERDEF  with(nolock)
			left join @StaticXMLData.nodes('XML/Row') as Data(X)
			 on ADM_COSTCENTERDEF.CostCenterColID=X.value('@CostCenterColID','INT')  
			where COSTCENTERID = @COSTCENTERID AND CostCenterColID = X.value('@CostCenterColID','INT') 
			
		if(@COSTCENTERID=16 or @COSTCENTERID=3 or @COSTCENTERID=95 or @COSTCENTERID=89
		or @COSTCENTERID >50000 or @COSTCENTERID in(86, 83, 88, 89, 65, 73, 92, 93, 94, 95, 103, 104, 129))
			UPDATE ADM_COSTCENTERDEF 
			set UserDefaultValue=X.value('@DefaultValue','nvarchar(500)')  
			from ADM_COSTCENTERDEF  with(nolock)
			left join @StaticXMLData.nodes('XML/Row') as Data(X)
			 on ADM_COSTCENTERDEF.CostCenterColID=X.value('@CostCenterColID','INT')  
			where COSTCENTERID = @COSTCENTERID AND CostCenterColID = X.value('@CostCenterColID','INT') and X.value('@DefaultValue','nvarchar(500)') is not null
			
			--select  X.value('@CostCenterColID','INT')  ,X.value('@DefaultValue','nvarchar(500)')   
			-- from ADM_COSTCENTERDEF  with(nolock)
			--left join @StaticXMLData.nodes('XML/Row') as Data(X)
			-- on ADM_COSTCENTERDEF.CostCenterColID=X.value('@CostCenterColID','INT')  
			--where COSTCENTERID = @COSTCENTERID AND CostCenterColID = X.value('@CostCenterColID','INT') and X.value('@DefaultValue','nvarchar(500)') is not null
			 
			
	 	Update COM_LANGUAGERESOURCES
	 	 SET RESOURCEDATA = X.value('@Rename','NVARCHAR(500)')
		from @StaticXMLData.nodes('XML/Row') as Data(X) 
		join ADM_COSTCENTERDEF c with(nolock) on  c.CostCenterColID = X.value('@CostCenterColID','INT') 
		 WHERE COM_LANGUAGERESOURCES.ResourceID=c.ResourceID and LANGUAGEID=@LangID AND C.COSTCENTERID=@COSTCENTERID

		CREATE TABLE #TBL(ID INT identity(1,1), ColID int, SeqNum int,visible BIT,ColSpan int)
		
		INSERT INTO #TBL      		
		SELECT COSTCENTERCOLID,SectionSeqNumber,isvisible,ColumnSpan
		from adm_costcenterdef	with(nolock)		
		WHERE  SECTIONID is null and  sectionseqnumber is not null
		AND COSTCENTERID=@COSTCENTERID AND ISCOLUMNINUSE=1 and isvisible=1
		order by SectionSeqNumber asc 
		
		declare @r int, @c int, @cnt int, @icnt int,   @Colid int,@ImgRow int,@ImgCol int,@showimg int
		set @ImgRow=0
		set @ImgCol=0
		
		if(@PreferenceXml<>'')
		BEGIN
		
			SET @DATA=@PreferenceXml
			SELECT @XMLDATA=X.value('@Value','nvarchar(max)')
			FROM @DATA.nodes('/PrefXML/Row') as DATA(X)
			where X.value('@Name','nvarchar(300)')='ImageDimensions'

			SELECT @ImgRow=X.value('@RowSpan','int'),@ImgCol=X.value('@ColumnSpan','int'), @showimg=X.value('@ShowImage','int')
			from @XMLDATA.nodes('XML') as DATA(X)
			if(@showimg=0)
			BEGIN
				set @ImgRow=0
				set @ImgCol=0
			END
			else if(@ImgCol=1)
				set @ImgCol=3
			else if(@ImgCol=3)
				set @ImgCol=1			
		END
				
		set @r=0
		set @c=0
		set @icnt=0
		set @cnt=(select count(*) from #TBL WITH(NOLOCK) )
		while @icnt<@cnt
		begin
			set @icnt=@icnt+1 
			
			Select @Colid=Colid,@ColSpan=ColSpan from #TBL WITH(NOLOCK) where ID=@icnt
			
			if(@ColSpan is null)
				set @ColSpan=1
			
			if((@COSTCENTERID in(92,93,94) or @COSTCENTERID > 50000)  and @r<@ImgRow)
			begin
				if(@c+@ColSpan>@ImgCol)
				begin
					set @r=@r+1
					set @c=0
				end
			end	
			ELSE if((@COSTCENTERID=2 or @COSTCENTERID=3 or @COSTCENTERID=65 or @COSTCENTERID=83) and @r<3)
			begin
				if(@c+@ColSpan>3)
				begin
					set @r=@r+1
					set @c=0
				end
			end
			else
			begin
				if(@c+@ColSpan>4)
				begin
					set @r=@r+1
					set @c=0
				end
			end
			
			
			
			 
		--SELECT @r,@c,@ColSpan,SysColumnName,costcentercolid FROM adm_costcenterdef where costcentercolid=@Colid
			update adm_costcenterdef set RowNo=@r, ColumnNo=@c 
			where costcentercolid=@Colid AND COSTCENTERID=@COSTCENTERID
			
			 if(@COSTCENTERID=3)
			 begin
				 if exists(select SysColumnName from ADM_CostCenterDef with(nolock) where costcentercolid=@Colid and SysColumnName='Description' AND COSTCENTERID=@COSTCENTERID)
				 begin
					set @r=@r+1
				 end
			 end
			 
			 set @c=@c+@ColSpan
			 set @ColSpan=0
			
			
		end

	END
	
		--ADDED CODE ON JULY 20 2012 BY HAFEEZ 
		--PURPOSE TO SET ROW AND COLUMN FOR DYNAMIC FIELDS
		DECLARE @TABS TABLE (ID INT IDENTITY(1,1),SECTIONID INT) 
	    INSERT INTO @TABS
		SELECT SECTIONID FROM adm_costcenterdef with(nolock)
		WHERE  CostCenterID=@COSTCENTERID AND SECTIONID IS NOT NULL 		 
		GROUP BY SECTIONID 
		  
	 	SELECT @I=1,@COUNT=COUNT(*) FROM @TABS
		WHILE @I<=@COUNT
		BEGIN	
		
			TRUNCATE TABLE #TBL      	 
			INSERT INTO #TBL (ColID , SeqNum ,ColSpan)
			SELECT COSTCENTERCOLID,SectionSeqNumber,ColumnSpan
			from adm_costcenterdef	with(nolock)		
			WHERE  SECTIONID =(SELECT SECTIONID FROM @TABS WHERE ID=@I ) 
			AND COSTCENTERID=@COSTCENTERID AND ISCOLUMNINUSE=1 and isvisible=1
			order by SectionSeqNumber asc 
				
			--declare @r int, @c int, @cnt int, @icnt int, @ColSpan int, @Colid int		
			IF (@COSTCENTERID=3 AND ((SELECT SECTIONID FROM @TABS WHERE ID=@I)=550)) 
			BEGIN
				set @r=6
				set @c=0
			END
			ELSE
			BEGIN
				set @r=0
				set @c=0
			END
			
			set @icnt=0
			set @cnt=(select count(*) from #TBL WITH(NOLOCK) )
			while @icnt<@cnt
			begin
				set @icnt=@icnt+1  
				set @ColSpan=null
				--set @ColSpan=(Select ColSpan from #TBL where ID=@icnt)
				Select @Colid=Colid,@ColSpan=COLSPAN from #TBL WITH(NOLOCK) where ID=@icnt
				
				if exists(select COLSPAN from #TBLTEMP WITH(NOLOCK) where COSTCENTERCOLID=@Colid)
					select @ColSpan=COLSPAN from #TBLTEMP WITH(NOLOCK) where COSTCENTERCOLID=@Colid
				
				
				if(@ColSpan is null or @ColSpan=0)
					set @ColSpan=1 
					
				if((@COSTCENTERID=3) and @r<3)
				begin
					if(@c+@ColSpan>3)
					begin
						set @r=@r+1
						set @c=0
					end
				end
				else
				begin
					if(@c+@ColSpan>4)
					begin
						set @r=@r+1
						set @c=0
					end
				end 
						  
				update adm_costcenterdef set COLUMNSPAN=@ColSpan,RowNo=@r, ColumnNo=@c 
				where costcentercolid=@Colid AND COSTCENTERID=@COSTCENTERID
				
				set @c=@c+@ColSpan
				set @ColSpan=0 
			end
				
			TRUNCATE TABLE #TBL
		SET @I=@I+1
		END

	--SELECT ColumnSpan FROM 	ADM_COSTCENTERDEF	with(nolock) WHERE COSTCENTERID=50051 AND SysColumnName='PANNo'

UPDATE ADM_COSTCENTERTAB  
SET  TabOrder = X.value('@TabOrder','INT'),  
    IsVisible = X.value('@Visibility','TINYINT'),
    GroupOrder = X.value('@GroupOrder','INT'),  
    GroupVisible = X.value('@GroupVisibility','TINYINT')
from @ExtraTabData.nodes('XML/Row') as ExtraTabData(X)   
where COSTCENTERID = @COSTCENTERID AND CCTabID =  X.value('@CCTabID','int') 
 AND X.value('@Action','nvarchar(300)')<>'DELETE' 

--ADDED CODE ON DEC 30 BY HAFEEZ TO DELETE TABS
--If Action is DELETE then delete tabs
DELETE FROM ADM_COSTCENTERTAB
WHERE CCTabID IN(SELECT X.value('@CCTabID','INT')
from @ExtraTabData.nodes('XML/Row') as ExtraTabData(X) 
where COSTCENTERID = @COSTCENTERID  
and X.value('@Action','nvarchar(300)')='DELETE')
 
  
  if(@FollowXML IS NOT NULL)
   BEGIN
			DECLARE @TEMPXML XML,@Dt FLOAT
				SET @Dt=convert(float,getdate())
				SET @TEMPXML=@FollowXML
		if exists(select name from sys.tables where name='CRM_FollowUpCustomization')
		begin
			SET @SQL='DELETE FROM CRM_FollowUpCustomization WHERE CCID='+CONVERT(NVARCHAR,@COSTCENTERID)+'
			INSERT INTO CRM_FollowUpCustomization(CCID,CCCOLID,NAME,ISVISIBLE,SYSCOLUMNNAME,COMPANYGUID,CREATEDBY,CREATEDDATE)
			SELECT  '+CONVERT(NVARCHAR,@COSTCENTERID)+',
					x.value(''@CCCOLID'',''INT''),
					x.value(''@Name'',''NVARCHAR(200)''),
					x.value(''@IsVisible'',''BIT''),
					x.value(''@Syscolumnname'',''NVARCHAR(200)''),
					'''+@CompanyGUID+''',
					'''+@UserName+''',
					'+CONVERT(NVARCHAR,convert(float,@Dt))+'
					from @TEMPXML.nodes(''XML/Row'') as data(x)
					where  x.value(''@CCCOLID'',''INT'')is not null and   x.value(''@CCCOLID'',''INT'') <> '''''
			EXEC sp_executesql @SQL,N'@TEMPXML XML',@TEMPXML
		END
  END
  
	--Quick Add Screen XML
	DECLARE @QXML XML--, @TblQuick AS TABLE(ColID INT,iOrder INT)
	SET @QXML=@QuickXML
	
	IF NOT (@ParentCCID>0 AND  @COSTCENTERID=144)
	BEGIN
		UPDATE adm_costcenterdef
		set ShowInQuickAdd=0
		where COSTCENTERID=@COSTCENTERID
	END
	
	IF (@ParentCCID>0 AND  @COSTCENTERID=144)
	BEGIN
		UPDATE adm_costcenterdef
		set ShowInQuickAdd=0
		where COSTCENTERID=@COSTCENTERID and LocalReference=@ParentCCID
	END
		
	UPDATE adm_costcenterdef
	SET  ShowInQuickAdd=1,QuickAddOrder=x.value('@Order','INT')
	from adm_costcenterdef C with(nolock) 
	INNER JOIN @QXML.nodes('QuickXML/Row') as data(x) ON x.value('@ColID','INT')=C.CostCenterColID
	WHERE C.COSTCENTERID=@COSTCENTERID 

   --update grids properties
     UPDATE adm_costcenterdef  
     SET   IsVisible = X.value('@Visibility','BIT'), 
		   SectionSeqNumber = X.value('@TabOrder','INT'), 
			UIWidth=X.value('@Width','NVARCHAR(50)')  
   FROM adm_costcenterdef C with(nolock)
   INNER JOIN @GridData.nodes('/XML/Row') as Data(X) ON X.value('@CostCenterColID','INT')=C.CostCenterColID  
   WHERE C.COSTCENTERID=@COSTCENTERID 
   
    
  --ADDED ON APR 20 2013 BY HAFEEZ
	IF(@ParentCCID<>-1 AND @COSTCENTERID=144)
	BEGIN
        IF (@ParentCCID=73 OR @ParentCCID=86 OR @ParentCCID=1000 OR @ParentCCID=2 OR @ParentCCID=88 OR @ParentCCID=89 OR @ParentCCID=83 OR @ParentCCID=65 OR @ParentCCID=95 or @ParentCCID=94 or @ParentCCID=92 or @ParentCCID=93 or @ParentCCID>40000) 
		
		UPDATE adm_costcenterdef  
		SET  LOCALREFERENCE = @ParentCCID WHERE COSTCENTERID=@COSTCENTERID
		AND COSTCENTERCOLID IN (SELECT COSTCENTERCOLID FROM #TBLTEMP) 
		
		DECLARE @QuickAddOrder INT
		select @QuickAddOrder=QuickAddOrder from  adm_costcenterdef with(nolock)
		where COSTCENTERID=@COSTCENTERID and LocalReference=@ParentCCID and ShowInQuickAdd=1 and SysColumnName='Remarks'

		IF(@QuickAddOrder IS NOT NULL AND @QuickAddOrder >0 )
		BEGIN
			UPDATE adm_costcenterdef SET QuickAddOrder=QuickAddOrder+4
			where COSTCENTERID=@COSTCENTERID and LocalReference=@ParentCCID and ShowInQuickAdd=1 AND QuickAddOrder>@QuickAddOrder
		END
	END
  
	--To Update Preferences
	IF @PreferenceXml!=''
	BEGIN
		DECLARE @TEMP TABLE (ID INT IDENTITY(1,1),[KEY] NVARCHAR(500),[VALUE] NVARCHAR(MAX))
		DECLARE @KEY NVARCHAR(500),@VALUE NVARCHAR(MAX)
		SET @DATA=@PreferenceXml
		INSERT INTO @TEMP ([KEY],[VALUE])
		SELECT X.value('@Name','nvarchar(300)'),X.value('@Value','nvarchar(max)')
		FROM @DATA.nodes('/PrefXML/Row') as DATA(X)
		 
		SELECT @I=1,@COUNT=COUNT(*) FROM @TEMP
 
		WHILE @I<=@COUNT
		BEGIN
			SELECT @KEY=[KEY],@VALUE=[VALUE] FROM @TEMP WHERE ID=@I		
			if(@KEY='ActivityFields' and @COSTCENTERID=144 and @ParentCCID between 40000 and 50000)			
			BEGIN
				UPDATE [com_documentpreferences] 
				SET [PrefValue]=@VALUE,
					[ModifiedBy]=@UserName,
					[ModifiedDate]=convert(float,getdate())
				WHERE [PrefName]=@KEY AND CostCenterID=@ParentCCID
			END

			ELSE IF (@KEY='ActivityFields' and @COSTCENTERID=144 and  @ParentCCID in (92,93,94,95))
			BEGIN
				UPDATE [COM_CostCenterPreferences] 
				SET [Value]=@VALUE,
					[ModifiedBy]=@UserName,
					[ModifiedDate]=convert(float,getdate())
				WHERE [Name]=@KEY AND CostCenterID=@ParentCCID
			END
			ELSE
			BEGIN
				UPDATE COM_CostCenterPreferences 
				SET [Value]=@VALUE,
					[ModifiedBy]=@UserName,
					[ModifiedDate]=convert(float,getdate())
				WHERE [Name]=@KEY AND CostCenterID=@CostCenterID
			END
			SET @I=@I+1
		END 
	END
	
	--External Function XML
	delete from ADM_DocFunctions where CostCenterID=@COSTCENTERID
	if(@ExtrnFuncXML<>'')
	BEGIN
		  SET @ExtFuntDATA=@ExtrnFuncXML        
    
		insert into ADM_DocFunctions(CostCenterID,CostCenterColID,Mode,Shortcut,SpName,IpParams,OpParams,Expression)
		SELECT  @CostCenterID,X.value('@CostCenterColID','int'),X.value('@Mode','INT') ,X.value('@Shortcut','NVARCHAR(MAX)')
            ,X.value('@SpName','NVARCHAR(MAX)'),X.value('@IpParams','NVARCHAR(MAX)'),X.value('@OpParams','NVARCHAR(MAX)'),X.value('@Expression','NVARCHAR(MAX)')
        FROM @ExtFuntDATA.nodes('/XML/Row') as DATA(X)
   
	END 
	
	Create  TABLE #TEMPCOLIDS (ID INT IDENTITY(1,1),COLID INT,ROWNO INT,COLUMNNO INT,ColumnSpan INT)
	Create TABLE #PRDIMENSIONS  (ROWSPAN INT,COLSPAN INT)
	
	--TO UPDATE PRODUCT IMAGE HEIGHT/WIDTH
	IF @CostCenterID=3
	BEGIN
			
			
			SELECT @XMLDATA=isnull(VALUE,'') FROM COM_CostCenterPreferences with(nolock) WHERE CostCenterID=3 AND Name='ProductImageDimensions'
			INSERT INTO #PRDIMENSIONS
			SELECT X.value('@RowSpan','int'),X.value('@ColumnSpan','int') from @XMLDATA.nodes('XML') as DATA(X)
			IF((select COUNT(*) from #PRDIMENSIONS with(nolock))>0)
			BEGIN
				  
			INSERT INTO #TEMPCOLIDS
			SELECT CostCenterColID,RowNo,ColumnNo,ColumnSpan FROM ADM_CostCenterDef with(nolock) WHERE CostCenterID=3 AND 
			(SectionID IS NULL OR SectionID='') AND IsColumnInUse=1 AND IsVisible=1
			 AND CostCenterColID IN (261,262,263,264,264,266,265,281,282)
			 ORDER BY RowNo,ColumnNo
	  
			select @imgrow=ROWSPAN,@imgcol=COLSPAN from #PRDIMENSIONS with(nolock) 
			SELECT @I=1 , @COUNT=COUNT(*) FROM #TEMPCOLIDS with(nolock)
			set @r=0
			set @c=0 
			WHILE @I<=@COUNT
			BEGIN
			Select @Colid=COLID,@ColSpan=ColumnSpan from #TEMPCOLIDS with(nolock) where ID=@I
			 
			if(@ColSpan is null or @ColSpan=0)
				 set @ColSpan=1  
			IF @r<@imgrow
			BEGIN 
				IF((@c + @ColSpan + @imgcol)>4)			
				BEGIN
					set @r=@r+1
					set @c=0
				END
			IF ((@ColSpan + @imgcol)>4)
				SET @ColSpan=4-@imgcol 
			END
			ELSE
			BEGIN  
				if(@c+@ColSpan>3)
				begin
					set @r=@r+1
					set @c=0
				end
			END   
				 	update adm_costcenterdef set COLUMNSPAN=@ColSpan,RowNo=@r, ColumnNo=@c 
					where costcentercolid=@Colid AND COSTCENTERID=@COSTCENTERID 
			 set @c=@c+@ColSpan 
			 set @ColSpan=0 
			SET @I=@I+1
			END
			
			END  
	END
	
	
	
	--To update extra fields having dimensioins like account,product,...
	if exists(select * from ADM_CostCenterDef with(nolock) where CostCenterID=@CostCenterID and SysColumnName like '%Alpha%' and IsColumnInUse=1 and IsCostCenterUserDefined=1 and ColumnCostCenterID!=44)
	begin
		update ADM_CostCenterDef
		set IsForeignKey=T.IsForeignKey,ParentCostcenterID=T.ParentCostcenterID,ParentCostCenterColID=T.ParentCostCenterColID
		,ParentCostCenterSysName=T.ParentCostCenterSysName,ParentCostCenterColSysName=T.ParentCostCenterColSysName,ParentCCDefaultColID=T.ParentCCDefaultColID 
		from ADM_CostCenterDef C with(nolock)
		inner join (
		select ColumnCostCenterID, IsForeignKey,ParentCostcenterID,ParentCostCenterColID
		,ParentCostCenterSysName,ParentCostCenterColSysName,ParentCCDefaultColID 
		from ADM_CostCenterDef D with(nolock)
		where D.CostCenterID=40001 and D.ColumnCostCenterID>0 and D.IsForeignKey=1 and ColumnCostCenterID!=12) AS T on C.ColumnCostCenterID=T.ColumnCostCenterID
		where C.CostCenterID=@CostCenterID and C.SysColumnName like '%Alpha%' and C.IsColumnInUse=1 and C.IsCostCenterUserDefined=1
	end	
	
	
  
COMMIT TRANSACTION        
 SELECT * FROM ADM_CostCenterTab WITH(NOLOCK) WHERE COSTCENTERID=@COSTCENTERID       
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)       
WHERE ErrorNumber=100 AND LanguageID=@LangID          
SET NOCOUNT OFF;        
RETURN @COSTCENTERID        
END TRY        
BEGIN CATCH        
 --Return exception info [Message,Number,ProcedureName,LineNumber]        
 IF ERROR_NUMBER()=50000      
 BEGIN      
  SELECT * FROM ADM_CostCenterTab WITH(NOLOCK) WHERE COSTCENTERID=@COSTCENTERID       
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID      
 END      
 ELSE IF ERROR_NUMBER()=547      
 BEGIN      
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)      
  WHERE ErrorNumber=-110 AND LanguageID=@LangID      
 END      
 ELSE      
 BEGIN      
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine      
  FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID      
 END      
 ROLLBACK TRANSACTION      
 SET NOCOUNT OFF        
 RETURN -999         
END CATCH

GO
