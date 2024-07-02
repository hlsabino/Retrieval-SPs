USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetCCCCMap]
	@PARENTFEATUREID [int],
	@PNodeID [int],
	@DATA [xml],
	@UserName [nvarchar](50),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
--BEGIN TRANSACTION  
--BEGIN TRY  
--SET NOCOUNT ON;
		
	--Declaration Section 
	DECLARE @Dt FLOAT,@DefCCID INT,@Action NVARCHAR(30)
	DECLARE @TempGuid NVARCHAR(50) 
	DECLARE @HasAccess BIT
	SET @Dt=CONVERT(FLOAT,GETDATE())--Setting Current Date   
	
	--User acces check 
	IF @PARENTFEATUREID=0
	BEGIN
		 RAISERROR('-100',16,1)  
	END
	
	--unique check
	IF @PARENTFEATUREID=3
	BEGIN
		DECLARE @AssignUniqueDimension NVARCHAR(MAX),@AssignUniqueXML XML,@I INT, @COUNT INT,@FeatureID INT,
		@Unique INT,@Level INT,@SQL NVARCHAR(MAX),@VAR NVARCHAR(MAX),@RESULT INT ,@NodeFilter NVARCHAR(MAX)
		
		SELECT @AssignUniqueDimension=Value FROM COM_CostCenterPreferences WITH(NOLOCK) 
		WHERE CostCenterID=@PARENTFEATUREID AND Name='AssignUniqueDimension'
		
		SET @AssignUniqueXML=@AssignUniqueDimension
		
		DECLARE @TAB TABLE([ID] INT IDENTITY(1,1),[FeatureID] INT,[Unique] INT, [Level] INT)
		INSERT INTO @TAB
		SELECT A.value('@FeatureID','INT'),A.value('@Unique','INT'),A.value('@Level','INT')
		from @AssignUniqueXML.nodes('/XML/Row') as DATA(A)  
		
		DECLARE @TABASSIGN TABLE([ID] INT IDENTITY(1,1),CostCenterId INT,NodeID INT)
		INSERT INTO @TABASSIGN
		SELECT A.value('@CCID','INT'),A.value('@ID','INT')
		from @DATA.nodes('/ASSIGNMAPXML/ASSIGN/R') as DATA(A)  
		INSERT INTO @TABASSIGN
		SELECT A.value('@CCID','INT'),A.value('@ID','INT')
		from @DATA.nodes('/ASSIGNMAPXML/MAP/R') as DATA(A)
		INSERT INTO @TABASSIGN  
		SELECT A.value('@CostCenterId','INT'),A.value('@NodeID','INT')
		from @DATA.nodes('/XML/Row') as DATA(A)
		
		SELECT @I=1,@COUNT=COUNT(*) FROM @TAB
		IF(@COUNT>0)
		BEGIN
			WHILE(@I<=@COUNT)
			BEGIN
				SELECT @FeatureID=[FeatureID],@Unique=[Unique],@Level=[Level] FROM @TAB WHERE [ID]=@I
				
				select @NodeFilter=STUFF((SELECT ','+CONVERT(NVARCHAR,NodeID) FROM  @TABASSIGN WHERE CostCenterId=@FeatureID FOR XML PATH('') ),1,1,'')
				
				IF @NodeFilter IS NOT NULL
				BEGIN
					SET @VAR='@RESULT INT OUTPUT'
					SET @SQL='SET @RESULT = (SELECT COUNT(CCM.NodeID) FROM COM_CostCenterCostCenterMap CCM WITH(NOLOCK) 
					LEFT JOIN INV_Product P WITH(NOLOCK) ON P.ProductID=CCM.ParentNodeID
					WHERE CCM.ParentCostCenterID='+CONVERT(NVARCHAR,@PARENTFEATUREID)+' 
					AND CCM.CostCenterID='+CONVERT(NVARCHAR,@FeatureID)+' 
					AND CCM.ParentNodeID<>'+CONVERT(NVARCHAR,@PNodeID)+'
					AND CCM.NodeID IN ('+ @NodeFilter +')'
					IF @Unique=1
						SET @SQL=@SQL+' AND CCM.ParentNodeID IN (SELECT DISTINCT PN.ProductID FROM INV_Product PN WITH(NOLOCK) 
						LEFT JOIN INV_Product PG WITH(NOLOCK) ON PN.LFT BETWEEN PG.LFT AND PG.RGT
						LEFT JOIN INV_Product PA WITH(NOLOCK) ON PG.ProductID=PA.ParentID AND PN.ProductID<>PA.ParentID
						WHERE PA.ProductID='+CONVERT(NVARCHAR,@PNodeID)+' )'
					IF @Level<>2
						SET @SQL=@SQL+' AND P.IsGroup='+CONVERT(NVARCHAR,@Level)
					SET @SQL=@SQL+')'
					EXEC sp_executesql @SQL,@VAR,@RESULT OUTPUT 	
					IF(@RESULT>0)
						RAISERROR('-149',16,1)
				END	  
				SET @I=@I+1
			END
		END
	END

	IF exists (select @DATA from @DATA.nodes('/ASSIGNMAPXML') as DATA(A) )
	BEGIN
		select @DefCCID=A.value('@Dimension','INT'),@Action=A.value('@Action','NVARCHAR(30)') from @DATA.nodes('/ASSIGNMAPXML') as DATA(A)

		if @DefCCID IS NULL OR @DefCCID=0
		begin
			IF @Action='ASSIGN' OR @Action='ASSIGN/MAP'
				DELETE FROM COM_CostCenterCostCenterMap WHERE ParentCostCenterID=@PARENTFEATUREID AND ParentNodeID=@PNodeID
			IF @Action='MAP' OR @Action='ASSIGN/MAP'
				DELETE FROM COM_CostCenterCostCenterMap WHERE CostCenterID=@PARENTFEATUREID AND NodeID=@PNodeID
		end
		else
		begin
			IF @Action='ASSIGN' OR @Action='ASSIGN/MAP'
				DELETE FROM COM_CostCenterCostCenterMap WHERE ParentCostCenterID=@PARENTFEATUREID AND ParentNodeID=@PNodeID AND CostCenterID=@DefCCID
			IF @Action='MAP' OR @Action='ASSIGN/MAP'
				DELETE FROM COM_CostCenterCostCenterMap WHERE CostCenterID=@PARENTFEATUREID AND NodeID=@PNodeID AND ParentCostCenterID=@DefCCID
		end
		
		INSERT INTO  COM_CostCenterCostCenterMap (ParentCostCenterID,ParentNodeID,CostCenterID,NodeID,GUID,CreatedBy,CreatedDate)
		SELECT @PARENTFEATUREID,@PNodeID,A.value('@CCID','INT'),A.value('@ID','INT'),NEWID(),@UserName,
		 @Dt from @DATA.nodes('/ASSIGNMAPXML/ASSIGN/R') as DATA(A)  
		 
		INSERT INTO  COM_CostCenterCostCenterMap (CostCenterID,NodeID,ParentCostCenterID,ParentNodeID,GUID,CreatedBy,CreatedDate)
		SELECT @PARENTFEATUREID,@PNodeID,A.value('@CCID','INT'),A.value('@ID','INT'),NEWID(),@UserName,
		 @Dt from @DATA.nodes('/ASSIGNMAPXML/MAP/R') as DATA(A)   
	END
	ELSE
	BEGIN
		declare @IsImport int
		select @IsImport=X.value('@IsImport','int')	from @DATA.nodes('/XML')  as Data(X)
		--select X.value('@IsImport','int')	from @DATA.nodes('/XML')  as Data(X)
		if @IsImport is not null and @IsImport=1
		begin
			DELETE FROM COM_CostCenterCostCenterMap WHERE ParentCostCenterID=@PARENTFEATUREID AND ParentNodeID=@PNodeID 
			and CostCenterID IN (SELECT distinct A.value('@CostCenterId','INT') from @DATA.nodes('/XML/Row')  as DATA(A) )
		end
		else
		begin
			DELETE FROM COM_CostCenterCostCenterMap WHERE ParentCostCenterID=@PARENTFEATUREID AND ParentNodeID=@PNodeID 
		end
		
		INSERT INTO  COM_CostCenterCostCenterMap (ParentCostCenterID,ParentNodeID,CostCenterID,
		NodeID,GUID,CreatedBy,CreatedDate)
		SELECT @PARENTFEATUREID,@PNodeID,A.value('@CostCenterId','INT'),A.value('@NodeID','INT'),NEWID(),@UserName,
		 @Dt from @DATA.nodes('/XML/Row') as DATA(A)  
	END
		
	IF @PARENTFEATUREID=2
	BEGIN
		
		
		if exists (select Value from adm_Globalpreferences with(nolock) where name='EnableLocationWise' and Value='True')
		and exists (select Value from adm_Globalpreferences with(nolock) where name='LW Accounts' and Value='True')
		begin
			declare @Vno nvarchar(max)
			set @Vno=''
			select distinct @Vno=@Vno+','+l.Name from ACC_DocDetails d with(nolock) 
			join com_docccdata cc with(nolock) on d.AccDocDetailsID=cc.AccDocDetailsID
			join com_location l with(nolock) on l.NodeID=cc.dcCCNID2
			where (debitaccount =@PNodeID or CreditAccount=@PNodeID) 
			and cc.dcCCNID2 not in (select l.NodeID from COM_CostCenterCostCenterMap M with(nolock) 
				join COM_Location g with(nolock) on g.NodeID=M.NodeID
				join COM_Location l with(nolock) on l.lft between g.lft and g.rgt
				where M.ParentCostCenterID=2 and M.ParentNodeID=@PNodeID and M.CostCenterID=50002)
			and d.CostCenterID not in (select CostCenterID from com_documentpreferences with(nolock) 
					where prefname='Donotuselocation' and prefvalue='true')
			
			if len(@Vno)=0
			begin
				select distinct @Vno=@Vno+','+l.Name from INV_DocDetails d with(nolock) 
				join com_docccdata cc with(nolock) on d.InvDocDetailsID=cc.InvDocDetailsID
				join com_location l with(nolock) on l.NodeID=cc.dcCCNID2
				where (debitaccount =@PNodeID or CreditAccount=@PNodeID) 
				and cc.dcCCNID2 not in (select l.NodeID from COM_CostCenterCostCenterMap M with(nolock) 
					join COM_Location g with(nolock) on g.NodeID=M.NodeID
					join COM_Location l with(nolock) on l.lft between g.lft and g.rgt
					where M.ParentCostCenterID=2 and M.ParentNodeID=@PNodeID and M.CostCenterID=50002)
				and d.CostCenterID not in (select CostCenterID from com_documentpreferences with(nolock) 
						where prefname='Donotuselocation' and prefvalue='true')
			end

			if(len(@Vno)>1)
			begin
				set @Vno=substring(@Vno,2,len(@Vno)-1)
				set @Vno='Assign Location : '+@Vno
				RAISERROR(@Vno,16,1)
			end
		end
	END
return 1

GO
