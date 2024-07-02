USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_GetHistoryList]
	@CCID [bigint] = 0,
	@CCNODEID [bigint] = 0,
	@UserID [bigint] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
--BEGIN TRANSACTION  
BEGIN TRY   
SET NOCOUNT ON  
  DECLARE @UNM NVARCHAR(100),@AUNM NVARCHAR(100),@NM NVARCHAR(MAX),@I INT ,@COUNT INT,@DOCDATE FLOAT,@VNO NVARCHAR(50)
  DECLARE @CNT int,@k int
  DECLARE @TBLPRODUCTS TABLE(ID INT IDENTITY(1,1) PRIMARY KEY,PRODUCTID INT,PRODUCTNAME NVARCHAR(800),VOUCHERNO NVARCHAR(50),DOCDATE FLOAT)
  
  DECLARE @TBLACTIVITIES TABLE(ID INT IDENTITY(1,1) PRIMARY KEY,ACTIVITYID INT,SUBJECT NVARCHAR(800),STATUS NVARCHAR(30),STARTDATE FLOAT,STARTTIME NVARCHAR(30),ENDDATE FLOAT,ENDTIME NVARCHAR(30)
							  ,ASSIGNEDUSER NVARCHAR(100),CREATEDBY NVARCHAR(100),CREATEDDATE FLOAT)
  DECLARE @TBLCRMHISTORY TABLE(ID INT IDENTITY(1,1) PRIMARY KEY,TEAM INT,IsGroup INT,IsRole INT,TEAMNODEID INT,USERID INT,[DATE] FLOAT,CreatedBy nvarchar(300)
				   			  ,AssignedTo nvarchar(300),Description nvarchar(max),IsFrom nvarchar(100),DisplayOrder INT)  
    
  DECLARE  @TBLDOCUMENTLINK TABLE(ID INT IDENTITY(1,1) PRIMARY KEY, CostCenterID INT,VoucherNo nvarchar(50),ParentVoucherNo nvarchar(50),VAbbr nvarchar(20),VPrefix nvarchar(40),VNumber int,DetailsID bigint,LinkedDetailsID bigint,DocDate float,DocumentName nvarchar(100))
  
  
  --Approve
    INSERT INTO @TBLCRMHISTORY 
		 SELECT IsTeam,IsGroup,IsRole,TeamNodeID,USERID,convert(float,CREATEDDATE) CREATEDDATE,CreatedBy,AssignedUserName,isnull(Description,'') Description,isnull(IsFrom,'') IsFrom,1
			  FROM CRM_History    
			  WHERE CCID=@CCID AND CCNODEID=@CCNODEID AND isnull(IsFrom,'')='Approve'  
			  ORDER BY CREATEDDATE  desc
  --Approve
  --Convert
    INSERT INTO @TBLCRMHISTORY 
		 SELECT IsTeam,IsGroup,IsRole,TeamNodeID,USERID,convert(float,CREATEDDATE) CREATEDDATE,CreatedBy,AssignedUserName,isnull(Description,'') Description,isnull(IsFrom,'') IsFrom,2
			  FROM CRM_History    
			  WHERE CCID=@CCID AND CCNODEID=@CCNODEID AND isnull(IsFrom,'')='Convert'  
			  ORDER BY CREATEDDATE  desc
  --Convert
  --Assign Users
  INSERT INTO @TBLCRMHISTORY  
			  SELECT IsTeam,IsGroup,IsRole,TeamNodeID,USERID,convert(float,CREATEDDATE) CREATEDDATE,CreatedBy,AssignedUserName,isnull(Description,'') Description,isnull(IsFrom,'') IsFrom,3
			  FROM CRM_History    
			  WHERE CCID=@CCID AND CCNODEID=@CCNODEID AND isnull(IsFrom,'')='Assign'  AND (ISFROMACTIVITY=0 OR ISFROMACTIVITY IS NULL)
			  ORDER BY CREATEDDATE  desc
  --Assign Users
  
  ----Activity
  INSERT INTO @TBLCRMHISTORY 
			  SELECT distinct IsTeam,IsGroup,IsRole,TeamNodeID,USERID,convert(float,CREATEDDATE) CREATEDDATE,CreatedBy,AssignedUserName,isnull(Description,'') Description,isnull(IsFrom,'') IsFrom,4
			  FROM CRM_History    
			  WHERE CCID=@CCID AND CCNODEID=@CCNODEID AND isnull(IsFrom,'')='Activity'  AND (ISFROMACTIVITY>0 OR ISFROMACTIVITY IS NOT NULL)
			  AND ISNULL(DESCRIPTION,'')<>'' 
			  ORDER BY CREATEDDATE desc
  ----Activity
    
  --DOCUMENT
  SET @UNM=(SELECT USERNAME FROM ADM_USERS WHERE USERID=@UserID) 
  
  INSERT INTO @TBLPRODUCTS 
				SELECT D.PRODUCTID,P.PRODUCTNAME,D.VOUCHERNO,D.DOCDATE 
				FROM INV_PRODUCT P,INV_DOCDETAILS D WHERE P.PRODUCTID=D.PRODUCTID AND D.REFCCID=@CCID AND D.REFNODEID=@CCNODEID
  
  SELECT @I=1,@COUNT=COUNT(*) FROM @TBLPRODUCTS
  WHILE @I<=@COUNT
  BEGIN
	 SELECT @VNO=VOUCHERNO FROM @TBLPRODUCTS WHERE ID=@I
		  INSERT INTO @TBLDOCUMENTLINK(CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,DetailsID,LinkedDetailsID,DocDate)  
			  SELECT DISTINCT D.CostCenterID,D.VoucherNo,P.VoucherNo,D.DocAbbr,D.DocPrefix,D.DocNumber,D.InvDocDetailsID,D.LinkedInvDocDetailsID,D.DocDate  
			  FROM INV_DocDetails D    
			  LEFT JOIN INV_DocDetails P  ON P.InvDocDetailsID=D.LinkedInvDocDetailsID  
			  WHERE D.VoucherNo=@VNO and D.DynamicInvDocDetailsID is null  
			  union  
			  select distinct D.CostCenterID,D.VoucherNo,P.VoucherNo,D.DocAbbr,D.DocPrefix,D.DocNumber,D.InvDocDetailsID,D.LinkedInvDocDetailsID,D.DocDate  
			  FROM INV_DocDetails D    
			  LEFT JOIN INV_DocDetails P  ON P.InvDocDetailsID=D.LinkedInvDocDetailsID  
			  WHERE (D.DocAbbr+'-'+D.DocPrefix+D.DocNumber)=@VNO and D.DynamicInvDocDetailsID is null  
		  
		  
  SET @I=@I+1
  END
		   SET @k=0  
		   WHILE(1=1)  
		   BEGIN    
			SET @CNT=(SELECT Count(*) FROM @TBLDOCUMENTLINK )  
			if @CNT>10000  
			 break  
				INSERT INTO @TBLDOCUMENTLINK(CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,DetailsID,LinkedDetailsID,DocDate)  
					select D.CostCenterID,D.VoucherNo,P.VoucherNo,D.DocAbbr,D.DocPrefix,D.DocNumber,D.InvDocDetailsID,D.LinkedInvDocDetailsID,D.DocDate  
					FROM INV_DocDetails D    
					INNER JOIN @TBLDOCUMENTLINK T  on T.LinkedDetailsID=D.InvDocDetailsID AND T.ID>@k  
					LEFT JOIN INV_DocDetails P  ON P.InvDocDetailsID=D.LinkedInvDocDetailsID  
					LEFT JOIN @TBLDOCUMENTLINK TD  on TD.VoucherNo=D.VoucherNo AND TD.ParentVoucherNo=P.VoucherNo-- AND TD.ID>@I  
					WHERE T.ParentVoucherNo!='-1' and TD.VoucherNo IS NULL and D.CostCenterID>0 and D.DynamicInvDocDetailsID is null  
			IF @CNT=(SELECT Count(*) FROM @TBLDOCUMENTLINK )  
			 BREAK  
			SET @k=@CNT  
		   END  
		     
		   SET @k=0  
		   WHILE(1=1)  
		   BEGIN    
			SET @CNT=(SELECT Count(*) FROM @TBLDOCUMENTLINK )  
			if @CNT>10000  
			 break  
			IF @k=0  
			begin
			 INSERT INTO @TBLDOCUMENTLINK(CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,DetailsID,LinkedDetailsID,DocDate)  
				 SELECT distinct INV.CostCenterID,INV.VoucherNo,TINV.VoucherNo,INV.DocAbbr,INV.DocPrefix,INV.DocNumber,INV.InvDocDetailsID,INV.LinkedInvDocDetailsID,INV.DocDate  
				 FROM INV_DocDetails INV    
				 INNER JOIN INV_DocDetails TINV  on TINV.InvDocDetailsID=INV.LinkedInvDocDetailsID  
				 INNER JOIN @TBLDOCUMENTLINK T  ON TINV.VoucherNo=T.VoucherNo AND ID>@k and ID=1  
				 LEFT JOIN @TBLDOCUMENTLINK TD  on TD.DetailsID=INV.LinkedInvDocDetailsID AND TD.ParentVoucherNo=TINV.VoucherNo-- AND TD.ID>@I  
				 where TD.VoucherNo IS NULL and INV.CostCenterID>0 and INV.DynamicInvDocDetailsID is null  
		  end
			ELSE  
			 INSERT INTO @TBLDOCUMENTLINK(CostCenterID,VoucherNo,ParentVoucherNo,VAbbr,VPrefix,VNumber,DetailsID,LinkedDetailsID,DocDate)  
				 SELECT distinct INV.CostCenterID,INV.VoucherNo,TINV.VoucherNo,INV.DocAbbr,INV.DocPrefix,INV.DocNumber,INV.InvDocDetailsID,INV.LinkedInvDocDetailsID,INV.DocDate  
				 FROM INV_DocDetails INV    
				 INNER JOIN INV_DocDetails TINV  on TINV.InvDocDetailsID=INV.LinkedInvDocDetailsID  
				 INNER JOIN @TBLDOCUMENTLINK T  ON TINV.VoucherNo=T.VoucherNo AND ID>@k and ID<=@CNT  
				 LEFT JOIN @TBLDOCUMENTLINK TD  on TD.DetailsID=INV.LinkedInvDocDetailsID AND TD.ParentVoucherNo=TINV.VoucherNo-- AND TD.ID>@I  
				 where TD.VoucherNo IS NULL and INV.CostCenterID>0 and INV.DynamicInvDocDetailsID is null  
			IF @CNT=(SELECT Count(*) FROM @TBLDOCUMENTLINK )  
			 BREAK     
			SET @k=@CNT  
		   END
		   UPDATE TBLDOCUMENTLINK SET TBLDOCUMENTLINK.DocumentName=DT.DocumentName FROM @TBLDOCUMENTLINK TBLDOCUMENTLINK 
		   	      JOIN ADM_DocumentTypes DT  on DT.CostCenterID=TBLDOCUMENTLINK.CostCenterID
  set @I=1
  set @COUNT=(select distinct COUNT(*) FROM @TBLDOCUMENTLINK)
  WHILE @I<=@COUNT
  BEGIN
      SELECT @NM='Document: '+DocumentName+' / VoucherNo: '+ voucherno+' / ParentVoucherNo : '+parentvoucherNo,@DOCDATE=DOCDATE FROM @TBLDOCUMENTLINK WHERE ID=@I
		
	  INSERT INTO @TBLCRMHISTORY 
	  	 SELECT 0,0,0,0,@UserID,convert(float,@DOCDATE),@UNM,'',@NM ,'Document' IsFrom,5
  SET @I=@I+1
  END
  --DOCUMENT
  
    ---ACTIVITIES
    INSERT INTO  @TBLACTIVITIES SELECT distinct D.ActivityID,ISNULL(D.SUBJECT,''),P.STATUS,CONVERT(FLOAT,D.STARTDATE),D.STARTTIME,
    CONVERT(FLOAT,ENDDATE),ENDTIME,U.USERNAME,D.CREATEDBY,CONVERT(FLOAT,D.CREATEDDATE)
	FROM COM_STATUS P,CRM_Activities D,ADM_USERS U,CRM_History H WHERE 
	D.STATUSID=P.STATUSID AND D.AssignUserID=U.USERID AND H.IsFromActivity=D.ActivityID AND D.COSTCENTERID=@CCID AND D.NODEID=@CCNODEID
  
 --  INSERT INTO  @TBLACTIVITIES SELECT D.ActivityID,ISNULL(D.SUBJECT,''),P.STATUS,CONVERT(FLOAT,D.STARTDATE),D.STARTTIME,
 --   CONVERT(FLOAT,ENDDATE),ENDTIME,U.USERNAME,D.CREATEDBY,CONVERT(FLOAT,D.CREATEDDATE)
	--FROM COM_STATUS P,CRM_Activities D,ADM_USERS U WHERE 
	--D.STATUSID=P.STATUSID AND D.AssignUserID=U.USERID AND D.COSTCENTERID=@CCID AND D.NODEID=@CCNODEID
  
  
  SELECT @I=1,@COUNT=COUNT(*) FROM @TBLACTIVITIES

	WHILE @I<=@COUNT
	BEGIN
		SELECT @NM='Subject: '+ SUBJECT+' / Status: '+STATUS+' / StartDateTime: '+
		CONVERT(NVARCHAR,CONVERT(DATETIME,[STARTDATE]),102)  +' '+ CONVERT(NVARCHAR,CONVERT(TIME,STARTTIME),108)+
		+' - EndDateTime: '+CONVERT(NVARCHAR,CONVERT(DATETIME,ENDDATE),102) +' '+ CONVERT(NVARCHAR,CONVERT(TIME,ENDTIME),108)
		,@UNM=CREATEDBY,@AUNM=ASSIGNEDUSER,@DOCDATE=CREATEDDATE FROM @TBLACTIVITIES WHERE ID=@I
		INSERT INTO @TBLCRMHISTORY 
		SELECT 0,0,0,0,@UserID,convert(float,@DOCDATE),@UNM,@AUNM,@NM ,'Activity' IsFrom,4
	SET @I=@I+1
    END
    ---ACTIVITIES
    --FOLLOWUP
    INSERT INTO @TBLCRMHISTORY 
		SELECT 0,0,0,0,@UserID,CONVERT(FLOAT,DATE),CREATEDBY,'',FEEDBACK ,'Followup',6 FROM CRM_FEEDBACK WHERE CCID=@CCID AND CCNODEID=@CCNODEID
    --FOLLOWUP
    --NOTES
    INSERT INTO @TBLCRMHISTORY 
			  SELECT distinct IsTeam,IsGroup,IsRole,TeamNodeID,USERID,convert(float,CREATEDDATE) CREATEDDATE,CreatedBy,AssignedUserName,isnull(Description,'') Description,isnull(IsFrom,'') IsFrom,7
			  FROM CRM_History    
			  WHERE CCID=@CCID AND CCNODEID=@CCNODEID AND isnull(IsFrom,'')='Notes'
			  AND ISNULL(DESCRIPTION,'')<>'' 
			  ORDER BY CREATEDDATE desc
    --NOTES
    
		  SELECT DISTINCT TEAM,IsGroup,IsRole,TeamNodeID,USERID,CONVERT(NVARCHAR,CONVERT(DATETIME,[DATE]),102) [DATE],CreatedBy ASSIGNEDFROM,
			AssignedTo ASSIGNEDTO,isnull(Description,'') Description,isnull(IsFrom,'') IsFrom,DisplayOrder FROM @TBLCRMHISTORY  order by DisplayOrder
    
--COMMIT TRANSACTION  
SET NOCOUNT OFF;  
RETURN 1  
END TRY  
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
 IF ERROR_NUMBER()=50000  
 BEGIN  
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
 END  
 ELSE  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
  FROM COM_ErrorMessages  WHERE ErrorNumber=-999 AND LanguageID=@LangID  
 END  
--ROLLBACK TRANSACTION  
SET NOCOUNT OFF    RETURN -999     
END CATCH  
GO
