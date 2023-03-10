USE [CDSBusiness]
GO
/****** Object:  StoredProcedure [dbo].[usp_DEService_UpdateConfirmedForJAR]    Script Date: 1/18/2023 7:02:15 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/****************************************************************
-- Procedure Name    : usp_DEService_UpdateConfirmedForJAR
-- Input Param(s)    : @JobID1,@CabID
-- Output            : NA
-- Author            : Prasuna
-- Created Date      : December 30'2015
-- Description       : Updating JobStatusID as Booking Confirmed on receiving DR from device
-- Tables Used       :
-- Stored Procedures :
-- Views Used        : NA
*****************************************************************
-- HISTORY
--****************************************************************
-- Modified By    Modified Date    Remarks
   Rajareddy K    12-May'17        updating cab details for now booking also
   Suresh		  18th Nov 2019 Added condition to update the JobiD in CabEntryAtAirport table for EnterPrise Hub
   SURESH			22nd Jul 2022 ADDED STF Dispatch Changes
    pravin/Suresh			2022-10-20  Added DEV Code in Live Sp [20221020]
-C--R--U--D
X  X  X  -
******************************************************************/
ALTER PROCEDURE [dbo].[usp_DEService_UpdateConfirmedForJAR] ( 
		@JobID1 INT
	,   @JobID2 INT = 0
	,   @CabID INT 
	,	@STFStatus_DriveApp INT = 0						
)
AS
BEGIN

insert into logs (JobID,ID,PhoneNo,RecDatetime)
Values(@JobID1, 0, 'usp_DEService_UpdateConfirmedForJAR-0', Getdate())

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

	SET @WebBookingReferenceNo = ''

	SELECT @PreviousJobStatusID = JobStatusID
	,      @IsAutoDispatch = IsAutoDispatch
	FROM dbo.tblJobStatusDetail WITH (NOLOCK)
	WHERE JobID = @JobID1

	insert into logs (JobID,ID,PhoneNo,RecDatetime)
Values(@JobID1, @PreviousJobStatusID, 'usp_DEService_UpdateConfirmedForJAR-1', Getdate())

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
		WHERE JobID = @JobID1

		IF (@PreviousJobStatusID = 10)
		BEGIN
			IF (@STFStatus_DriveApp = 2 OR @STFStatus_DriveApp = 3)
				SELECT @JobStatusID = 9
		    ELSE
				SELECT @JobStatusID = 11
		END
		-- [+] added Code [20221020]
			ELSE IF (@PreviousJobStatusID = 5 AND (DATEDIFF(MINUTE,GETDATE(),@PickupTime) >= -60 AND datediff(MINUTE,GETDATE(),@PickupTime) <= 60))
		BEGIN
			SELECT @JobStatusID = 7
		END
		ELSE IF (@PreviousJobStatusID = 5)
		BEGIN
			SELECT @JobStatusID = 47
		END
		ELSE IF (@PreviousJobStatusID = 47)
		BEGIN
			SELECT @JobStatusID = 48
		END
		ELSE IF (@PreviousJobStatusID = 48 AND (DATEDIFF(MINUTE,GETDATE(),@PickupTime) >= -60 AND datediff(MINUTE,GETDATE(),@PickupTime) <= 60))
		--Deleting the record from tbl_Bookings_Blocked_Cabs table 
		BEGIN
			IF(SELECT COUNT(1) FROM tbl_Bookings_Blocked_Cabs WHERE JobId = @JobID1) > 0
				BEGIN
					DELETE FROM tbl_Bookings_Blocked_Cabs WHERE JobId = @JobID1
				END
			SELECT @JobStatusID = 7
		END
		ELSE IF (@PreviousJobStatusID = 48 AND (datediff(MINUTE,GETDATE(),@PickupTime) >= 60))
		BEGIN
			SELECT @JobStatusID = 48
			RETURN
		END
		-- [-] END Code

		ELSE IF (@PreviousJobStatusID = 33)
			BEGIN
				SELECT @JobStatusID = 34
			END
			ELSE IF (@PreviousJobStatusID IN (3	,37	) AND @IsAutoDispatch = 1
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
					ELSE IF (@CityID IN (1,3,4,5))
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
				ELSE  IF (@PreviousJobStatusID != 9) -- Added this conditon to control multiple DR's on 29/06
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
			FROM CDSBusiness.dbo.tblLoggedinSubscriberDetails WITH (NOLOCK)
			WHERE CabID = @CabID --CabRegistrationNo = @CabRegNo

			IF (
				@SubscriberID != ''
				OR @SubscriberID IS NOT NULL
				)
			BEGIN
				SELECT @CabSubscriberMappingID = CabSubscriberMappingID
				FROM dbo.tblCabSubscriberMappingDetail WITH (NOLOCK)
				WHERE SubscriberID = @SubscriberID
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
Values(@JobID1, @JobStatusID, 'usp_DEService_UpdateConfirmedForJAR-2', Getdate())

		BEGIN TRY
		BEGIN TRANSACTION

		UPDATE dbo.tblJobStatusDetail
		SET JobStatusID          = @JobStatusID
		,   StatusUpdateDateTime = GetDate()
		WHERE JobID = @JobID1

		IF (@IsGenie = 1)
		BEGIN
			INSERT INTO dbo.tblSubscriberAcceptanceForAutoJAM ( JobID   )
			VALUES                                            ( @JobID1 )
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
			WHERE JobID = @JobID1
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

			-- Comented Below Code  added Code [20221020]

			--Added code to get the DeviceID on 14/09/2022
		--Select @SiebelDeviceID = SiebelDeviceID
		--From   dbo.tblCabMaster CM 
		--Join dbo.tblCabDeviceMappingDetail CDM ON CM.CabID = CDM.CabID
		--Join dbo.tblDeviceMaster           DM  ON CDM.DeviceID = DM.DeviceID
		--Where CM.CabID = @CabID

		/*Updating Cabinfo in tblJobBooking*/
		UPDATE dbo.tblJobBooking
		SET MappingID                = @CabSubscriberMappingID
		,   CabAssignedTime          = GetDate()
		,   CabRegistrationNo        = @CabRegNo
		,   AssignedCabBrandTypeID   = @AssignedBrandTypeID
		,   AssignedCabProductTypeID = @AssignedProductTypeID
		,   CabTypeID                = 1
		,   JobSubscriberID          = @SubscriberID
		,	STFStaus				 = @STFStatus_DriveApp
		WHERE JobID = @JobID1

		--Insert JobID,JobStatusID into tblJobDispatchDetail For History purpose
		INSERT INTO dbo.tblJobDispatchDetail ( JobID,   JobStatusID,  PreviousJobStatusID,  AssignedCabNo, AssignedSubscriberID )
		VALUES                               ( @JobID1, @JobStatusID, @PreviousJobStatusID, @CabRegNo,     @SubscriberID        )

		--   /*Airport*/
		--   IF(@ChannelID = 6)
		--   BEGIN
		--    UPDATE dbo.tblCabEntryAtAirport SET Status = 3,ResponseTime = GETDATE() WHERE JobID = @JobID1
		--   END
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
		WHERE JobID = @JobID1

		/*Updating CabInfo in tblMeruWebSiteBookingReference*/
		UPDATE tblMeruWebSiteBookingReference
		SET RequestProcessStatusID  = 6
		,   RequestProcessTime      = GETDATE()
		,   ResponseProcessStatusID = 1
		,   ResponseProcessTime     = GETDATE()
		,   TaxiNo                  = @CabRegNo
		,   SubscriberName          = @SubscriberName
		,   SubscriberMobileNo      = @SubMobileNo
		--WHERE JobID = @JobID1 AND (JobIDResponse != 'OneClick done' OR JobType != 'Current')
		WHERE JobID <> 0
			AND JobID = @JobID1
			AND (
			SourceChannel NOT IN (
			'eCab'
			,'eCab+'
			)
			--OR JobIDResponse != 'OneClick done' /*Commented by Rajareddy K on 12,May'17*/
			--OR JobType != 'Current'
			)

		--   /*Added for Sending JobStatus to eCab*/
		--    IF(@SourceChannel IN ('eCab','eCab+'))
		-- BEGIN
		--
		-- Select @CabLatitude = CabLatitude, @CabLongitude = CabLongitude, @SiebelDeviceID = SiebelDeviceID
		-- From CDSBusiness.dbo.tblCabMaster CM
		-- Inner Join CDSBusiness.dbo.tblCabDeviceMappingDetail CDM ON CM.CabID = CDM.CabID
		-- Inner Join CDSBusiness.dbo.tblDeviceMaster DM ON CDM.DeviceID = DM.DeviceID
		-- Where CM.CabID = @CabID
		--
		--  INSERT INTO tblJobStatusTrackToPartners(PartnerRefID,JobID,PartnerJobStatusID,CabNo,SubscriberName,SubscriberMobileNo,ETA,
		--										  PickupDateTime,CabLatitude,CabLongitude,SiebelDeviceID)
		--  VALUES(@WebBookingReferenceNo,@JobID1,2,@CabRegNo,@SubscriberName,@SubMobileNo,@ETA,@PickupDateTime,@CabLatitude,@CabLongitude,@SiebelDeviceID)  -- 2- ASSIGNED
		-- END
		/*For MERU SMS/Email*/
		IF (( @WebBookingReferenceNo != '' OR @WebBookingReferenceNo IS NOT NULL ) AND @IsGenie = 0 AND @SourceChannel <> 'Airport' )
		BEGIN
			INSERT INTO tblEmailAndSMSSentdetails ( JobID,   WebRefNo,               CustomerMobileNo,  CustomerName,  Pickuptime,  BookingStatus,  EmailAddress,   ChannelID, PickupArea,  PickupSubArea,  DropArea,  DropSubArea,  CityName,  PickupAddress,  CabRegistrationNo, SubscriberName,  SubscriberMobileNo )
			VALUES                                ( @JobID1, @WebBookingReferenceNo, @CustomerMobileNo, @CustomerName, @PickupTime, 'Cab Assigned', @CustomerEmail, 5,         @PickupArea, @PickupSubArea, @DropArea, @DropSubArea, @CityName, @PickupAddress, @CabRegNo,         @SubscriberName, @SubMobileNo       )
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
				INSERT INTO tblEmailAndSMSSentdetails_Genie ( JobID,   WebRefNo,               CustomerMobileNo,  CustomerName,  Pickuptime,  BookingStatus,  EmailAddress,   ChannelID, PickupArea,  PickupSubArea,  DropArea,  DropSubArea,  CityName,  PickupAddress,  CabRegistrationNo, SubscriberName,  SubscriberMobileNo )
				VALUES                                      ( @JobID1, @WebBookingReferenceNo, @CustomerMobileNo, @CustomerName, @PickupTime, 'Cab Assigned', @CustomerEmail, 5,         @PickupArea, @PickupSubArea, @DropArea, @DropSubArea, @CityName, @PickupAddress, @CabRegNo,         @SubscriberName, @SubMobileNo       )
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

		/*To delete if non airport job assigned*/

		IF @ChannelID != 6 AND @CityID = 3
		UPDATE DBO.tblCabEntryAtAirport
		SET IsDeleted = 1,LatestRecord = 0
		WHERE CabRegistrationNo = @CabRegNo AND LatestRecord = 1 AND IsDeleted = 0
		
		/*To delete if non airport job assigned*/

		--Updating only when DR received from MDT for Airport Jobs
		IF (@ChannelID = 6) AND @CityID IN (1,3,4,55) --City Id 55 added by vaibhav on 12Feb210 . 

		BEGIN
			UPDATE CDSBusiness.DBO.tblCabEntryAtAirport
			SET JobId = @JobID1,IsDeleted = 1,OutTime = GETDATE()
			WHERE CabRegistrationNo = @CabRegNo AND LatestRecord = 1 AND IsDeleted = 0

			UPDATE tblJobBookingAdditionalinfo
			SET IsDeleted = 1
			WHERE JobId = @JobID1

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
				SET JobId = @JobID1
				WHERE RowNo = 1
				AND DATEDIFF(MINUTE,QRScannedTime,GETDATE())<=90
			END
		END

		--Updating only when DR received from MDT for Enterprise Hub Jobs
		-- below Added CityID 5 for to update the Phoenix mall Bangalore Meru SPOT by MAhesh on 06-Aug-2020
		IF @ChannelID = 5 AND  (@CityID = 1 OR @CityID = 4 Or @CityID =5) AND @SourceChannel = 'EnterpriseHub' --Added Suresh on 18/11/2019 --Added by Suresh on 21 jul 2020 (OR @CityID = 4)
		BEGIN
			UPDATE CDSBusiness.DBO.tblCabEntryAtAirport
			SET JobId = @JobID1, IsDeleted = 1, OutTime = GETDATE()
			WHERE CabRegistrationNo = @CabRegNo AND LatestRecord = 1 AND IsDeleted = 0
		END

		--For OutCall to the drivers
		DECLARE @CabLat REAL,@CabLong REAL
			
		SELECT @CabLat = CabLatitude, @CabLong = CabLongitude
		FROM tblCabMaster WITH(NOLOCK)
		WHERE CabId = @CabID

		UPDATE tblJobBookingAdditionalinfo
		SET CabAssignedLat = @CabLat,CabAssignedLong = @CabLong
		WHERE JobId = @JobID1
		--For OutCall to the drivers
		--For updating the status of second job
		IF (@JobID2 != 0)
		BEGIN
			/*Updating Cabinfo in tblJobBooking*/
			UPDATE dbo.tblJobBooking
			SET MappingID                = @CabSubscriberMappingID
			,   CabAssignedTime          = GetDate()
			,   CabRegistrationNo        = @CabRegNo
			,   AssignedCabBrandTypeID   = @AssignedBrandTypeID
			,   AssignedCabProductTypeID = @AssignedProductTypeID
			,   CabTypeID                = 1
			,   JobSubscriberID          = @SubscriberID
			WHERE JobID = @JobID2

			--Insert JobID,JobStatusID into tblJobDispatchDetail For History purpose
			INSERT INTO dbo.tblJobDispatchDetail ( JobID,   JobStatusID, PreviousJobStatusID, AssignedCabNo, AssignedSubscriberID )
			VALUES                               ( @JobID2, 7,           46,                  @CabRegNo,     @SubscriberID        )

			/*Updating CabInfo in tblMeruWebSiteBookingReference*/
			UPDATE tblMeruWebSiteBookingReference
			SET RequestProcessStatusID  = 6
			,   RequestProcessTime      = GETDATE()
			,   ResponseProcessStatusID = 1
			,   ResponseProcessTime     = GETDATE()
			,   TaxiNo                  = @CabRegNo
			,   SubscriberName          = @SubscriberName
			,   SubscriberMobileNo      = @SubMobileNo
			--WHERE JobID = @JobID1 AND (JobIDResponse != 'OneClick done' OR JobType != 'Current')
			WHERE JobID = @JobID2
				AND (
				SourceChannel NOT IN (
				'eCab'
				,'eCab+'
				)
				--OR JobIDResponse != 'OneClick done' /*Commented by RajaReddy K on 12,May'17*/
				--OR JobType != 'Current'
				)
		END

		COMMIT TRANSACTION
		END TRY

		BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRANSACTION

		DECLARE @ErrorMessage NVARCHAR(4000)

		SET @ErrorMessage = ERROR_MESSAGE()

		INSERT INTO tblErrorMsgForBusiness ( ErrorMsg,      StoredProcedureName,                   JobID   )
		VALUES                             ( @ErrorMessage, 'usp_DEService_UpdateConfirmedForJAR', @JobID1 )
		END CATCH
	END
END


