USE [CDSBusiness]
GO
/****** Object:  StoredProcedure [dbo].[usp_DEService_UpdateConfirmed]    Script Date: 1/18/2023 7:01:53 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****************************************************************
-- Procedure Name    : usp_DEService_UpdateConfirmed
-- Input Param(s)    : @JobID,@CabID
-- Output            : NA
-- Author            : Jyothi
-- Created Date      : October 08'2009
-- Description       : Updating JobStatusID as Booking Confirmed on receiving DR from device
-- Tables Used       : tblJobStatusDetail,tblJobStatusMaster
tblJobDispatchDetail
-- Stored Procedures : [usp_DEService_UpdateConfirmed]
-- Views Used        : NA
*****************************************************************
-- HISTORY
--****************************************************************
-- Modified By    Modified Date    Remarks


Jyothi.K       21st Jun 2013    Updating Auto Dispatch

Rajareddy K    24 Dec'13        For Advertising sms, stopped on 31 Jan'14

Ravi.J         30 Jun'14        Added Genie Email Condition

Rajareddy K    4 Aug'13         For kellog's Advertising sms, stopped on 31 Aug'14

Rajareddy K    5 Aug'13         Airport charge of Rs.70 for both pick from airport or Drop to Airport

Rajareddy K    25 Aug'13        For Medimix soap Advertising sms, stopped on 25 Sep'14

Jyothi.K       25th Sep 2014    Merger Changes

Jyothi.K       01st Dec 2014    Used OpenQuery

Jyothi.K		  04th Apr 2015    Fine tuned

Jyothi.K		  06th May 2015    Removed READPAST

Ravi.J         16th Mar 2016    Added Subscribermapping check while updating in JobbookingTable
Rajareddy K      11,Apr'2017    @dropadress added fpr sending mails
Pavan V          22nd  Aug 2017  dr lat n long added for driver outcall
Suresh		   18th Nov 2019 Added condition to update the JobiD in CabEntryAtAirport table for EnterPrise Hub
suresh			4th Jan 2021 added a condition to update the status 47 to 48
suresh			2nd Marth 2021 Added a condition for outstation project 
SURESH			5TH MARCH 2021 ADDED A CONDITION TO FIX MULTIPLE DR ISSUE FOR OUTSTATION PROJECT
SURESH			22nd Jul 2022 ADDED STF Dispatch Changes
SURESH/PRAVIN   Added JobStatus for On Call Ph-3 [20230111]
-C--R--U--D
X  X  X  -
******************************************************************/
ALTER PROCEDURE [dbo].[usp_DEService_UpdateConfirmed] 
(  
    @JobID INT,
    @CabID INT,
	@STFStatus_DriveApp INT = 0
)
AS
BEGIN 

insert into logs (JobID,ID,PhoneNo,RecDatetime)
Values(@JobID, 0, 'usp_DEService_UpdateConfirmed-0', Getdate())

--declare @JobID int
--declare @CabID int 
--set @JobID = 60574373
--set @CabID = 116188

	DECLARE @JobStatusID            TINYINT
	,       @PreviousJobStatusID    TINYINT
	,       @CabSubscriberMappingID INT
	,       @CabRegNo               VARCHAR(50)
	,       @MappingID              INT
	,       @SubscriberID           INT
	,       @IVRSChannelID          NVARCHAR(50)
	,       @CustomerMobileNo       VARCHAR(50)
	,       @SubscriberName         VARCHAR(50)
	,       @SubMobileNo            VARCHAR(30)
	,       @CityID                 SMALLINT
	,       @PickupTime             DATETIME
	,       @DropLocalityID         INT
	,       @JobTypeID              TINYINT
	,       @WebBookingReferenceNo  VARCHAR(70)
	,       @CustomerName           VARCHAR(50)
	,       @CustomerEmail          VARCHAR(50)
	,       @PickupAddress          VARCHAR(150)
	,       @PickupArea             VARCHAR(150)
	,       @PickupSubArea          VARCHAR(150)
	,       @DropArea               VARCHAR(150)
	,       @DropSubArea            VARCHAR(150)
	,       @CityName               VARCHAR(150)
	,       @IsGenie                TINYINT
	,       @PickupSubAreaID        INT
	,       @DropSubAreaID          INT
	,       @DestinationAddress     VARCHAR(250)
	,       @IsAutoDispatch         BIT
	,       @CabRegistrationNo      VARCHAR(150)
	,       @SubscriberMobileNo     VARCHAR(150)
	,       @ChannelID              TINYINT
	,       @SourceChannel          VARCHAR(20)
	,       @PickupDateTime         DATETIME
	,       @ETA                    INT
	,       @CabLatitude            REAL
	,       @CabLongitude           REAL
	,       @SiebelDeviceID         VARCHAR(30)
	,       @AssignedBrandTypeID    TINYINT
	,       @AssignedProductTypeID  TINYINT
	,       @CurrentDispatchType    TINYINT

	SET @WebBookingReferenceNo = ''
	SET @CurrentDispatchType = 0

	SELECT @PreviousJobStatusID = JobStatusID
	,      @IsAutoDispatch = IsAutoDispatch
	,      @CurrentDispatchType = CurrentDispatchType
	FROM dbo.tblJobStatusDetail WITH (NOLOCK)
	WHERE JobID = @JobID

	insert into logs (JobID,ID,PhoneNo,RecDatetime)
Values(@JobID, @PreviousJobStatusID, 'usp_DEService_UpdateConfirmed-1', Getdate())
	
	-- RESTRICING MULTIPLE DR'S FROM DRIVER APP FOR OUTSTATION BOOKINGS...
	DECLARE @IsInterCity bit
	DECLARE @dtPickupTime datetime
	SELECT @IsInterCity = IsIntercity,@dtPickupTime = PickupTIme FROM tblJobBooking WHERE JobID =  @JobID
	DECLARE @CommandSent VARCHAR(25)
	SELECT @CommandSent = CommandSentTime FROM tblSpecialDirectTripInfo WHERE JobID = @JobID
	
	IF((@CommandSent IS  NULL OR @CommandSent = '')  AND @IsInterCity = 1 AND (DATEDIFF(MINUTE,GETDATE(),@dtPickupTime) <= -120 AND datediff(MINUTE,GETDATE(),@dtPickupTime) >= 120))
		BEGIN
			SET @PreviousJobStatusID = 7
		END
		
insert into logs (JobID,ID,PhoneNo,RecDatetime)
Values(@JobID, @PreviousJobStatusID, 'usp_DEService_UpdateConfirmed-2', Getdate())
	
	IF ( @PreviousJobStatusID NOT IN ( 7 ,11 ) ) -- To ignore duplicate DR's coming from device - 8th Sep 2016 by Prasuna.S
	BEGIN
		SELECT @CityID = CityID
		,      @PickupTime = PickUpTime
		,      @CustomerMobileNo = CustomerMobileNo
		,      @DropLocalityID = DestLocalityId
		,      @IsGenie = IsGenie
		,      @PickupSubAreaID = PickUpAddressPointID
		,      @DropSubAreaID = DestAddressPointID
		,      @DestinationAddress = DestinationAddress
		,      @IVRSChannelID = IVRSChannelID
		,      @JobTypeID = JobTypeID
		,      @ChannelID = ChannelID
		FROM dbo.tblJobBooking WITH (NOLOCK)
		WHERE JobID = @JobID

		IF (@PreviousJobStatusID = 10)
		BEGIN
			IF (@STFStatus_DriveApp = 2 OR @STFStatus_DriveApp = 3)
				SELECT @JobStatusID = 9
		    ELSE
				SELECT @JobStatusID = 11
		END
		-- [+] Added for On Call Ph-3 [20230111]
		--ELSE IF (@PreviousJobStatusID = 5)
		--BEGIN
		--	SELECT @JobStatusID = 47
		--END
		--[-] Added By On Call Ph-3 [20230111]
		ELSE IF (@PreviousJobStatusID = 47)
		BEGIN
			SELECT @JobStatusID = 48
		END
		ELSE IF (@PreviousJobStatusID = 48 AND (DATEDIFF(MINUTE,GETDATE(),@PickupTime) >= -120 AND datediff(MINUTE,GETDATE(),@PickupTime) <= 120))
		BEGIN
			SELECT @JobStatusID = 7
		END
		ELSE IF (@PreviousJobStatusID = 48 AND (datediff(MINUTE,GETDATE(),@PickupTime) >= 120))
		BEGIN
			SELECT @JobStatusID = 48
			RETURN
		END
		-- [+] Added for On Call Ph-3 [20230111]
		ELSE IF (@PreviousJobStatusID = 50)
		BEGIN
			SELECT @JobStatusID = 7
		END
		-- [-] END Code [20230111]

		ELSE IF (@PreviousJobStatusID = 33)
			BEGIN
				SELECT @JobStatusID = 34
			END
			ELSE IF (
					@PreviousJobStatusID IN (
					3
					,37
					)
					AND @IsAutoDispatch = 1
					)
				BEGIN
					IF (
						@CityID NOT IN (
						1
						,3
						,4
						,5
						)
						)
					BEGIN
						SELECT @JobStatusID = 38
					END
					ELSE IF ( @CityID IN (1,3,4,5))
				    BEGIN
						IF (@STFStatus_DriveApp = 2 OR @STFStatus_DriveApp = 3)
						BEGIN
							SELECT @JobStatusID = 9
						END
					ELSE
						BEGIN
							SELECT @JobStatusID = 11
						END
				  END
				END
				ELSE IF (@PreviousJobStatusID != 9)
				BEGIN
					IF (@STFStatus_DriveApp = 2 OR @STFStatus_DriveApp = 3)
						BEGIN
							SELECT @JobStatusID = 9
						END
					ELSE
						BEGIN
							SELECT @JobStatusID = 7
						END
				END
			--print @JobStatusID
		/*To get SubscriberID*/
		IF EXISTS (
			SELECT CabID
			FROM tblCabSubscriberMappingDetail_ForAttachCab WITH (NOLOCK)
			WHERE CabID = @CabID
			)
		BEGIN
			SELECT @SubscriberID = SubscriberID
			,      @CabSubscriberMappingID = CabSubscriberMappingID
			,      @CabRegNo = CabRegistrationNo
			FROM dbo.tblCabSubscriberMappingDetail WITH (NOLOCK)
			WHERE CabID = @CabID

			SELECT @SubscriberID = SubscriberID
			FROM dbo.tblLoggedinSubscriberDetails WITH (NOLOCK)
			WHERE CabID = @CabID --CabRegistrationNo = @CabRegNo

			IF (
				@SubscriberID != ''
				OR @SubscriberID IS NOT NULL
				)
			BEGIN
				SELECT @CabSubscriberMappingID = CabSubscriberMappingID
				FROM dbo.tblCabSubscriberMappingDetail WITH (NOLOCK)
				WHERE SubscriberID = @SubscriberID
					AND CabID = @CabID
			END
			ELSE
			BEGIN
				SELECT @SubscriberID = SubscriberID
				,      @CabSubscriberMappingID = CabSubscriberMappingID
				,      @CabRegNo = CabRegistrationNo
				FROM dbo.tblCabSubscriberMappingDetail WITH (NOLOCK)
				WHERE CabID = @CabID
			END
		END
		ELSE
		BEGIN
			SELECT @SubscriberID = SubscriberID
			,      @CabSubscriberMappingID = CabSubscriberMappingID
			,      @CabRegNo = CabRegistrationNo
			FROM dbo.tblCabSubscriberMappingDetail WITH (NOLOCK)
			WHERE CabID = @CabID
		END

insert into logs (JobID,ID,PhoneNo,RecDatetime)
Values(@JobID, @JobStatusID, 'usp_DEService_UpdateConfirmed-3', Getdate())

		BEGIN TRY
		BEGIN TRANSACTION

		UPDATE dbo.tblJobStatusDetail
		SET JobStatusID          = @JobStatusID
		,   StatusUpdateDateTime = GetDate()
		WHERE JobID = @JobID

		IF (@IsGenie = 1)
		BEGIN
			INSERT INTO dbo.tblSubscriberAcceptanceForAutoJAM ( JobID  )
			VALUES                                            ( @JobID )
		END

		IF (
			@IsAutoDispatch = 1
			AND @CityID IN (
			1
			,3
			,4
			,5
			)
			)
		BEGIN
			UPDATE tblSubscriberAcceptanceForAutoJAM
			SET SubscriberResponseTime = Getdate()
			WHERE JobID = @JobID
		END

		/*Selecting SubscriberInfo by passing SubscriberID*/
		SELECT @SubscriberName = SubscriberFirstName + ' ' + SubscriberLastName
		,      @SubMobileNo = SubscriberMobileNo
		FROM dbo.tblSubscriberMaster WITH (NOLOCK)
		WHERE SubscriberID = @SubscriberID

		SELECT @AssignedBrandTypeID = CabBrandTypeID
		,      @AssignedProductTypeID = CabProductTypeID
		FROM dbo.tblCabSubscriberMappingDetail
		WHERE SubscriberID = @SubscriberID
			AND CabRegistrationNo = @CabRegNo

		/*Updating Cabinfo in tblJobBooking*/
		UPDATE dbo.tblJobBooking
		SET MappingID                = @CabSubscriberMappingID
		,   CabAssignedTime          = GetDate()
		,   CabRegistrationNo        = @CabRegNo
		,   CabTypeID                = 1
		,   AssignedCabBrandTypeID   = @AssignedBrandTypeID
		,   AssignedCabProductTypeID = @AssignedProductTypeID
		,   JobSubscriberID          = @SubscriberID
		,	STFStaus				 = @STFStatus_DriveApp		
		--,   STFDeviceID			 = @SiebelDeviceID   -- Added below 3 columns for On Call Ph-3 [20230111]
		--,	STFCabNo				 = @CabRegNo
		--,	STFCabSentTime			 = GetDate()
		WHERE JobID = @JobID

		--Insert JobID,JobStatusID into tblJobDispatchDetail For History purpose
		INSERT INTO dbo.tblJobDispatchDetail ( JobID,  JobStatusID,  PreviousJobStatusID,  AssignedCabNo, AssignedSubscriberID )
		VALUES                               ( @JobID, @JobStatusID, @PreviousJobStatusID, @CabRegNo,     @SubscriberID        )

		/*Airport*/
		IF (@ChannelID = 6) AND @CityID IN (5)
		BEGIN
			UPDATE dbo.tblCabEntryAtAirport
			SET STATUS       = 3
			,   ResponseTime = GETDATE()
			WHERE JobID = @JobID
		END

		/*To delete if non airport job assigned*/

		IF @ChannelID != 6 AND @CityID = 3
		UPDATE DBO.tblCabEntryAtAirport
		SET IsDeleted = 1,LatestRecord = 0
		WHERE CabRegistrationNo = @CabRegNo AND LatestRecord = 1 AND IsDeleted = 0
		
		/*To delete if non airport job assigned*/

		IF (@ChannelID = 6) AND @CityID IN (1,3,4,5,55) --City Id 55 added by vaibhav on 12Feb210 . 
		BEGIN
			UPDATE DBO.tblCabEntryAtAirport
			SET JobId     = @JobID,OutTime = GETDATE()
			,   IsDeleted = 1
			WHERE CabRegistrationNo = @CabRegNo AND LatestRecord = 1 AND IsDeleted = 0

			UPDATE tblJobBookingAdditionalinfo
			SET IsDeleted = 1
			WHERE JobId = @JobID

			IF @CityID IN (3,52)
			BEGIN
				; WITH UpdateRecord AS
				(
					SELECT ROW_NUMBER () OVER (Partition By CabRegistrationNo ORDER BY Id DESC) RowNo,JobId,QRScannedTime
					FROM tblAirportQRCodeDetails
					WHERE CabRegistrationNo = @CabRegNo
					AND JobId IS NULL AND ERPPickStatus NOT IN (99)
				)

				UPDATE UpdateRecord
				SET JobId = @JobID
				WHERE RowNo = 1
				AND DATEDIFF(MINUTE,QRScannedTime,GETDATE())<=90
			END
		END
      		
		--For OutCall to the drivers
		
		DECLARE @CabLat REAL,@CabLong REAL
			
		SELECT @CabLat = CabLatitude, @CabLong = CabLongitude
		FROM tblCabMaster WITH(NOLOCK)
		WHERE CabId = @CabID

		UPDATE tblJobBookingAdditionalinfo
		SET CabAssignedLat = @CabLat,CabAssignedLong = @CabLong
		WHERE JobId = @JobID
		--For OutCall to the drivers

		SELECT @WebBookingReferenceNo = WebBookingReferenceNo
		,      @PickupAddress = PickupAddress
		,      @PickupArea = PickupArea
		,      @PickupSubArea = PickupSubArea
		,      @DropArea = DropArea
		,      @DropSubArea = DropSubArea
		,      @CustomerEmail = CustomerEmail
		,      @CustomerName = CustomerName
		,      @CityName = City
		,      @SourceChannel = SourceChannel
		,      @PickupDateTime = PickupDateTime
		,      @ETA = ETA
		FROM tblMeruWebSiteBookingReference WITH (NOLOCK)
		WHERE JobID = @JobID

		/*Updating CabInfo in tblMeruWebSiteBookingReference*/
		UPDATE tblMeruWebSiteBookingReference
		SET RequestProcessStatusID  = 6
		,   RequestProcessTime      = GETDATE()
		,   ResponseProcessStatusID = 1
		,   ResponseProcessTime     = GETDATE()
		,   TaxiNo                  = @CabRegNo
		,   SubscriberName          = @SubscriberName
		,   SubscriberMobileNo      = @SubMobileNo
		WHERE JobID = @JobID
			--AND (
			--JobIDResponse != 'OneClick done' /*Commented by RajaReddy K on 11,May'17*/
			--OR JobType != 'Current'
			--OR @CurrentDispatchType IN (1,2)
			--   )

         --Updating only when DR received from MDT for Enterprise Hub Jobs --Added Suresh on 18/11/2019
		IF (@ChannelID = 5 AND @CityID = 1 AND @SourceChannel = 'EnterpriseHub') 
		BEGIN
         UPDATE dbo.tblCabEntryAtAirport
			SET JobId     = @JobID, 
			OutTime = GETDATE(),
			IsDeleted = 1
			WHERE CabRegistrationNo = @CabRegNo AND LatestRecord = 1 AND IsDeleted = 0
		END

		/*Added by RajaReddy K  on 6,Oct'15*/
		Select @CabLatitude = CabLatitude
		,      @CabLongitude = CabLongitude
		,      @SiebelDeviceID = SiebelDeviceID
		From       dbo.tblCabMaster              CM 
		Inner Join dbo.tblCabDeviceMappingDetail CDM ON CM.CabID = CDM.CabID
		Inner Join dbo.tblDeviceMaster           DM  ON CDM.DeviceID = DM.DeviceID
		Where CM.CabID = @CabID

		IF NOT EXISTS(SELECT JobID
			from tblJobAwardLatLongDetails WITH(NOLOCK)
			WHERE JOBID=@Jobid)
		BEGIN
			INSERT INTO tblJobAwardLatLongDetails ( JobID,  CabLatitude,  CabLongitude,  CabRegistrationNo )
			VALUES                                ( @JobID, @CabLatitude, @CabLongitude, @CabRegNo         )
		END
		ELSE
		BEGIN
			UPDATE tblJobAwardLatLongDetails
			SET JobID             = @JobID
			,   CabLatitude       = @CabLatitude
			,   CabLongitude      = @CabLongitude
			,   CabRegistrationNo = @CabRegNo
			WHERE JobID=@JobID
		END

		/*Added for Sending JobStatus to eCab*/
		IF (
			@SourceChannel IN (
			'eCab'
			,'eCab+'
			)
			)
		BEGIN
			SELECT @CabLatitude = CabLatitude
			,      @CabLongitude = CabLongitude
			,      @SiebelDeviceID = SiebelDeviceID
			FROM       dbo.tblCabMaster              CM 
			INNER JOIN dbo.tblCabDeviceMappingDetail CDM ON CM.CabID = CDM.CabID
			INNER JOIN dbo.tblDeviceMaster           DM  ON CDM.DeviceID = DM.DeviceID
			WHERE CM.CabID = @CabID

			INSERT INTO tblJobStatusTrackToPartners ( PartnerRefID,           JobID,  PartnerJobStatusID, CabNo,     SubscriberName,  SubscriberMobileNo, ETA,  PickupDateTime,  CabLatitude,  CabLongitude,  SiebelDeviceID  )
			VALUES                                  ( @WebBookingReferenceNo, @JobID, 2,                  @CabRegNo, @SubscriberName, @SubMobileNo,       @ETA, @PickupDateTime, @CabLatitude, @CabLongitude, @SiebelDeviceID ) -- 2- ASSIGNED
		END

		/*For MERU SMS/Email*/
		IF (( @WebBookingReferenceNo != '' OR @WebBookingReferenceNo IS NOT NULL ) AND @IsGenie = 0 AND @SourceChannel <> 'Airport' )
		BEGIN
			INSERT INTO tblEmailAndSMSSentdetails ( JobID,  WebRefNo,               CustomerMobileNo,  CustomerName,  Pickuptime,  BookingStatus,  EmailAddress,   ChannelID, PickupArea,  PickupSubArea,  DropArea,  DropSubArea,  CityName,  PickupAddress,  CabRegistrationNo, SubscriberName,  SubscriberMobileNo,DestinationAddress )
			VALUES                                ( @JobID, @WebBookingReferenceNo, @CustomerMobileNo, @CustomerName, @PickupTime, 'Cab Assigned', @CustomerEmail, 5,         @PickupArea, @PickupSubArea, @DropArea, @DropSubArea, @CityName, @PickupAddress, @CabRegNo






,         @SubscriberName, @SubMobileNo,@DestinationAddress      )
		END
		/*For MERU SMS/Email*/
		ELSE IF (
				(
				@WebBookingReferenceNo != ''
				OR @WebBookingReferenceNo IS NOT NULL
				)
				AND @IsGenie = 1
				)
			BEGIN
				INSERT INTO tblEmailAndSMSSentdetails_Genie ( JobID,  WebRefNo,               CustomerMobileNo,  CustomerName,  Pickuptime,  BookingStatus,  EmailAddress,   ChannelID, PickupArea,  PickupSubArea,  DropArea,  DropSubArea,  CityName,  PickupAddress,  CabRegistrationNo, SubscriberName,  SubscriberMobileNo )
				VALUES                                      ( @JobID, @WebBookingReferenceNo, @CustomerMobileNo, @CustomerName, @PickupTime, 'Cab Assigned', @CustomerEmail, 5,         @PickupArea, @PickupSubArea, @DropArea, @DropSubArea, @CityName, @PickupAddress, @CabRegNo,         @SubscriberName, @SubMobileNo       )
			END

		/*For IVRS Current Jobs*/
		IF (
			(
			@IVRSChannelID != ''
			OR @IVRSChannelID != NULL
			)
			AND @JobTypeID = 1
			)
		BEGIN
			INSERT INTO IVRSJOBCONFIRMATION ( STATUS,    ChannelId,      CallerId          )
			VALUES                          ( @CabRegNo, @IVRSChannelID, @CustomerMobileNo )
		END

		--   IF(@CityID=5 AND @DropLocalityID=782)
		--   BEGIN
		--		DECLARE @RFID BIT
		--		SELECT @RFID = RFID FROM OPENQUERY([SQLGPSCLUSTER],'SELECT RFID,CabID FROM dbo.tblCabMasterAdditionalDetails WITH(NOLOCK)')C
		--		WHERE C.CabID=@CabID
		--
		--		IF(@RFID=0)
		--		BEGIN
		--			INSERT INTO tblSMSAdvertisementInfo(JobID,MobileNo,CabRegistrationNo,SMSTypeID,SMSText,[Type])
		--			VALUES(@JobID,@CustomerMobileNo,@CabRegNo,1,'Dear Customer, an additional toll charge of Rs.75 will be applicable for Airport drop trips, as per NDTPL guidelines. Meru Cabs, Bengaluru.','TRANSACTIONAL')
		--		END
		--   END
		COMMIT TRANSACTION
		END TRY

		BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRANSACTION

		DECLARE @ErrorMessage NVARCHAR(4000)

		SET @ErrorMessage = ERROR_MESSAGE()

		INSERT INTO tblErrorMsgForBusiness ( ErrorMsg,      StoredProcedureName,             JobID  )
		VALUES                             ( @ErrorMessage, 'usp_DEService_UpdateConfirmed', @JobID )
		END CATCH
	END
END




