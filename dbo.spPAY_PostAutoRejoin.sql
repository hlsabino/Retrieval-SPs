USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_PostAutoRejoin]
	@CostCenterID [bigint],
	@DocID [int] = null,
	@UserId [int] = 1,
	@LangId [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY
SET NOCOUNT ON;
begin transaction
DECLARE @strQuery varchar(max),@strResult VARCHAR(500),@PayrollProduct INT,@CrACC INT,@DbAcc INT,@DocPrefix NVARCHAR(200),@DocDate DATETIME,@ActXml nvarchar(max),@sysinfo nvarchar(max),@AP varchar(10),@InvDocDetailsID BIGINT,@AutoRejoin BIT,@GradewiseMonthlyPayrollPref Varchar(5),@PayrollDate DATETIME,@Grade Int,@ddID Int,@ActRejoin NVARCHAR(100)
DECLARE @dcAlpha1 NVARCHAR(100),@dcAlpha2 NVARCHAR(100),@dcAlpha3 NVARCHAR(100),@dcAlpha4 NVARCHAR(100),@dcAlpha6 NVARCHAR(500),@dcCCNID51 BIGINT,@dcCCNID52 BIGINT

IF((@CostCenterID=40062 OR @CostCenterID=40072) AND (SELECT COUNT(DocID) FROM INV_DOCDETAILS WITH(NOLOCK) WHERE DOCID=@DOCID AND STATUSID=369)>0)--POSTED
BEGIN

SET @AutoRejoin=0
IF(@CostCenterID=40062)
BEGIN
	SELECT @AutoRejoin=CONVERT(BIT,PrefValue) FROM COM_DocumentPreferences WITH(NOLOCK) WHERE PrefName='AutoRejoinLeave'

	SELECT @dcAlpha1=T.dcAlpha4,@dcAlpha2=T.dcAlpha5,@dcAlpha3=CONVERT(VARCHAR(20),DATEADD(D,1,CONVERT(DATETIME,T.dcAlpha5)),106),@dcAlpha4=0,@dcAlpha6='AutoRejoin' ,@dcCCNID51=CC.dcCCNID51,@dcCCNID52=CC.dcCCNID52,@DocPrefix=I.DocPrefix,@DocDate=I.DocDate,@InvDocDetailsID=I.InvDocDetailsID 
	FROM INV_DocDetails I WITH(NOLOCK)
	JOIN COM_DocTextData T WITH(NOLOCK) ON T.InvDocDetailsID=I.InvDocDetailsID
	JOIN COM_DocCCData CC WITH(NOLOCK) ON CC.InvDocDetailsID=I.InvDocDetailsID
	WHERE T.tCostCenterID=40062 AND I.DocID=@DocID

	SET @PayrollDate=DATEADD(MONTH,DATEDIFF(MONTH,0,CONVERT(DATETIME,@dcAlpha1)),0)

	SELECT @GradewiseMonthlyPayrollPref=ISNULL(VALUE,'False') FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE NAME='GradeWiseMonthlyPayroll'
	IF (@GradewiseMonthlyPayrollPref='True')
	BEGIN
		IF((SELECT COUNT(CostCenterID) FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=50051 and SysColumnName ='CCNID53' and IsColumnInUse=1 and UserProbableValues='H')>0)
			SELECT @Grade=ISNULL(HistoryNodeID,0) FROM COM_HistoryDetails WITH(NOLOCK) WHERE NodeID=@dcCCNID51 AND CostCenterID=50051 AND HistoryCCID=50053 AND (FromDate<=CONVERT(FLOAT,CONVERT(DATETIME,@PayrollDate))) AND (ToDate>=CONVERT(FLOAT,CONVERT(DATETIME,@PayrollDate)) OR ToDate IS NULL)
		ELSE
			SELECT @Grade=ISNULL(CCNID53,0) FROM COM_CCCCDATA WITH(NOLOCK) WHERE COSTCENTERID=50051 AND NODEID=@dcCCNID51
	END
	
	IF ISNULL(@GRADE,0)=0
		SET @GRADE=1

	IF NOT EXISTS((SELECT * 
	FROM COM_CC50054 a WITH(NOLOCK)
	JOIN COM_CC50052 b WITH(NOLOCK) on a.ComponentID=b.NodeID
	WHERE a.GradeID=@GRADE AND A.ComponentID=@dcCCNID52 AND PayrollDate=(Select MAX(PayrollDate) FROM COM_CC50054 WITH(NOLOCK) WHERE CONVERT(DATETIME,PayrollDate)<=@PayrollDate)
	AND LeaveOthFeatures LIKE '%#REJOIN#%'))
	BEGIN
		SET @AutoRejoin=0
	END 
	
END
ELSE
BEGIN

	SELECT @dcAlpha1=T.dcAlpha2,@dcAlpha2=T.dcAlpha3,@dcAlpha3=CONVERT(VARCHAR(20),DATEADD(D,1,CONVERT(DATETIME,T.dcAlpha3)),106),@dcAlpha4=0,@dcAlpha6='AutoRejoin' ,@dcCCNID51=CC.dcCCNID51,@dcCCNID52=CC.dcCCNID52,@DocPrefix=I.DocPrefix,@DocDate=I.DocDate,@InvDocDetailsID=I.InvDocDetailsID 
		FROM INV_DocDetails I WITH(NOLOCK)
		JOIN COM_DocTextData T WITH(NOLOCK) ON T.InvDocDetailsID=I.InvDocDetailsID
		JOIN COM_DocCCData CC WITH(NOLOCK) ON CC.InvDocDetailsID=I.InvDocDetailsID
		WHERE T.tCostCenterID=40072 AND I.DocID=@DocID

	SELECT @AutoRejoin=CONVERT(BIT,PrefValue) FROM COM_DocumentPreferences WITH(NOLOCK) WHERE PrefName='AutoRejoinVacation'
END

if(isnull(@AutoRejoin,0)=1)
BEGIN
	SELECT @PayrollProduct=ISNULL(VALUE,2) FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE NAME='payrollproduct'
	SELECT @CrACC=ISNULL(UserDefaultValue,2) FROM ADM_COSTCENTERDEF WITH(NOLOCK) WHERE COSTCENTERID=40065 AND SYSCOLUMNNAME='CreditAccount'
	SELECT @DbAcc=ISNULL(UserDefaultValue,2) FROM ADM_COSTCENTERDEF WITH(NOLOCK) WHERE COSTCENTERID=40065 AND SYSCOLUMNNAME='DebitAccount'

	set @ActXml=''
	set @ddID=0

	SELECT TOP 1 @sysinfo=D.SysInfo,@AP=I.AP
	FROM INV_DOCDETAILS i WITH(NOLOCK) 
	join COM_DocID d	WITH(NOLOCK) ON D.DocNo=I.VoucherNo
	WHERE DOCID=@DocID

	SELECT @ddID=a.DocID,@ActRejoin=d.dcAlpha3
    FROM INV_DocDetails a WITH(NOLOCK) 
    JOIN COM_DocCCData b WITH(NOLOCK) ON b.InvDocDetailsID=a.InvDocDetailsID
    JOIN COM_DocTextData d WITH(NOLOCK) ON d.InvDocDetailsID=a.InvDocDetailsID
    WHERE d.tCostCenterID=40065 and ISNULL(d.dcAlpha6,'')='AutoRejoin' And b.dcCCNID51=@dcCCNID51 And B.dcCCNID52=@dcCCNID52
    AND a.RefNodeid IN (Select InvDocDetailsID FROM INV_DocDetails aa WITH(NOLOCK) WHERE DocID=@DocID)

	IF(@ActRejoin IS NOT NULL AND ISNULL(@ActRejoin,'')<>'')
	BEGIN
		IF(CONVERT(DATETIME,@ActRejoin)!=CONVERT(DATETIME,@dcAlpha3))
			raiserror('Cannot Post this Document...Rejoin date is changed',16,1)
	END
	
	set @ActXml='<XML SysInfo="'+@sysinfo+'" AP="'+@AP+'" ></XML>'
			
	set @strQuery=''
	set @strQuery='<Row>'
	set @strQuery=@strQuery+'<AccountsXML></AccountsXML>'
	set @strQuery=@strQuery+'<Transactions DocSeqNo="1"  DocDetailsID="0" LinkedInvDocDetailsID="0" LinkedFieldName="" LineNarration="" '
	set	@strQuery=@strQuery+' ProductID="'+ CONVERT(VARCHAR,@PayrollProduct) +'" '
	set @strQuery=@strQuery+' IsScheme="" Quantity="1" Unit="1" UOMConversion="1" UOMConvertedQty="1" Rate="0" Gross="" RefNO=""  IsQtyIgnored="1" AverageRate="0" StockValue="0" StockValueFC="0" CurrencyID="1" ExchangeRate="1.0"  '
	set @strQuery=@strQuery+' DebitAccount="'+ CONVERT(VARCHAR,@DbAcc) +'" '
	set @strQuery=@strQuery+' CreditAccount="'+ CONVERT(VARCHAR,@CrACC) +'" '
	set @strQuery=@strQuery+' ></Transactions>'
			
	set @strQuery=@strQuery+'<Numeric Query="" ></Numeric>'
	set @strQuery=@strQuery+'<Alpha Query="dcAlpha1=N'''+ @dcAlpha1  +''','
	set @strQuery=@strQuery+' dcAlpha2=N'''+ @dcAlpha2  +''','
	set @strQuery=@strQuery+' dcAlpha3=N'''+ @dcAlpha3  +''','
	set @strQuery=@strQuery+' dcAlpha4=N'''+ CONVERT(VARCHAR,@dcAlpha4) +''','
	set @strQuery=@strQuery+' dcAlpha6=N'''+ @dcAlpha6  +''', "></Alpha>'
			
	set @strQuery=@strQuery+'<CostCenters Query="dcCCNID51='+ CONVERT(VARCHAR,@dcCCNID51) +','
	set @strQuery=@strQuery+' dcCCNID52='+ CONVERT(VARCHAR,@dcCCNID52)  +','
	set @strQuery=@strQuery+'" ></CostCenters>'									
	set @strQuery=@strQuery+'<EXTRAXML></EXTRAXML></Row>'									
	--SELECT @strQuery
	
	set @strResult=''
	EXEC @strResult=spDOC_SetTempInvDoc 40065,@ddID,@DocPrefix,'',@DocDate,'','',@strQuery ,'','','',@ActXml,'false',0,0,0,1,'',300,@InvDocDetailsID,'admin','admin',1,1,False

END
END
commit transaction
SET NOCOUNT OFF;  
--RETURN 1  
END TRY  
BEGIN CATCH    
  --Return exception info [Message,Number,ProcedureName,LineNumber]    
  IF ERROR_NUMBER()=50000  
  BEGIN  
   SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
  END  
  ELSE  
  BEGIN  
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
   FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
  END   
SET NOCOUNT OFF    
   
END CATCH


GO
