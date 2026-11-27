CREATE Database BidNile
GO 

use BidNile
GO

-- ============================================================================
-- 1. Create Logical Schemas (4 Schemas — No tables in dbo)
-- ============================================================================


CREATE SCHEMA Core;
GO 

CREATE SCHEMA Catalogue;
GO 

CREATE SCHEMA Trading;
GO

CREATE SCHEMA Engagement;
GO


-- ============================================================================
-- 2. Schema: Core (City, Member, Wallet ,Warehouse, Employee)
-- ============================================================================

-- ===  City   ===
CREATE TABLE Core.City
(
    CityId INT IDENTITY(1,1) NOT NULL,

    Name NVARCHAR(60) NOT NULL,

    CountryCode CHAR(2) NOT NULL,

    CONSTRAINT PK_City
        PRIMARY KEY (CityId),

    CONSTRAINT UQ_City_Name_Countery_Code
	UNIQUE (Name, CountryCode),

	CONSTRAINT CK_CITY_Country_Code 
	CHECK (CountryCode IN('EG', 'SA', 'AE'))
);
GO

-- ===  Member   ===
CREATE TABLE Core.Member (
MemberId UNIQUEIDENTIFIER  NOT NULL CONSTRAINT DF_Member_MemberID DEFAULT NEWID() ,
FullName NVARCHAR(100) NOT NULL ,
Email VARCHAR(254) NOT NULL ,
Phone NVARCHAR(16) NOT NULL ,
NationalID NVARCHAR(20) NOT NULL ,
DateOfBirth date NOT NULL ,
IsVerified BIT NOT NULL  CONSTRAINT DF_Member_IsVerivied DEFAULT 0,
RegisteredAt DATETIME2(3) NOT NULL CONSTRAINT DF_Membe_RegisterdAT  DEFAULT SYSDATETIME() ,
CityId int NOT NULL ,
InvitedByMemberId UNIQUEIDENTIFIER NULL,

CONSTRAINT PK_Member PRIMARY KEY (MemberID),
CONSTRAINT UQ_Member_Email UNIQUE (Email),
CONSTRAINT UQ_Member_NationalID UNIQUE(NationalID),
CONSTRAINT CK_Member_DateOfBirth CHECK(  DateOfBirth <= DATEADD(YEAR ,-18 ,CAST( GETDATE() AS DATE)) ), -- 2005  <= 2026  -18  2008
CONSTRAINT CK_Member_InvitedByMember CHECK(InvitedByMemberId IS NULL OR InvitedByMemberId <> MemberID )

);

GO


-- ===  Wallet   ===

CREATE TABLE Core.Wallet (
    MemberId   UNIQUEIDENTIFIER NOT NULL,
    Balance    DECIMAL(12, 2)   NOT NULL CONSTRAINT DF_Wallet_Balance DEFAULT 0,
    HeldAmount DECIMAL(12, 2)   NOT NULL CONSTRAINT DF_Wallet_HeldAmount DEFAULT 0,
    Currency   CHAR(3)          NOT NULL CONSTRAINT DF_Wallet_Currency DEFAULT 'EGP',
    UpdatedAt  DATETIME2(3)     NOT NULL CONSTRAINT DF_Wallet_UpdatedAt DEFAULT SYSDATETIME(),

    CONSTRAINT PK_Wallet PRIMARY KEY (MemberId),
    CONSTRAINT CK_Wallet_Balance CHECK (Balance >= 0),
    CONSTRAINT CK_Wallet_HeldAmount CHECK (HeldAmount >= 0),
    CONSTRAINT CK_Wallet_HeldLessThanBalance CHECK (HeldAmount <= Balance)
);
GO

-- ===  Warehouse   ===
CREATE TABLE Core.Warehouse (
    WarehouseId       INT IDENTITY(1,1) NOT NULL,
    Name              NVARCHAR(80)      NOT NULL,
    Capacity          INT               NOT NULL,
    Latitude          FLOAT             NOT NULL,
    Longitude         FLOAT             NOT NULL,
    CityId            INT               NOT NULL,
    ManagerEmployeeId UNIQUEIDENTIFIER  NOT NULL,
    ManagedSince      DATE              NOT NULL,

    CONSTRAINT PK_Warehouse PRIMARY KEY (WarehouseId),
    CONSTRAINT UQ_Warehouse_Name UNIQUE (Name),
    CONSTRAINT UQ_Warehouse_ManagerEmployeeId UNIQUE (ManagerEmployeeId),
    CONSTRAINT CK_Warehouse_Capacity CHECK (Capacity > 0),
    CONSTRAINT CK_Warehouse_Latitude CHECK (Latitude BETWEEN -90 AND 90),
    CONSTRAINT CK_Warehouse_Longitude CHECK (Longitude BETWEEN -180 AND 180)
);
GO


CREATE TABLE Core.Employee (
    MemberId  UNIQUEIDENTIFIER NOT NULL,
    WarehouseId INT              NULL,

    CONSTRAINT PK_Employee PRIMARY KEY (MemberId)
);
GO

-- ============================================================================
-- 4. Schema: Catalogue (Category, Item, ItemPhoto)
-- ============================================================================

CREATE TABLE Catalogue.Category (
    CategoryCode       INT           NOT NULL,
    NameEn           VARCHAR(50)   NOT NULL,
    NameAr           NVARCHAR(50)  NULL,
    CommissionPct    DECIMAL(4, 2) NOT NULL,
    ParentCategoryCode INT           NULL,

    CONSTRAINT PK_Category PRIMARY KEY (CategoryCode),
    CONSTRAINT UQ_Category_NameEn UNIQUE (NameEn),
    CONSTRAINT CK_Category_CommissionPct CHECK (CommissionPct BETWEEN 0 AND 30),
    CONSTRAINT CK_Category_ParentCategoryId CHECK (ParentCategoryCode IS NULL OR ParentCategoryCode <> CategoryCode)
);
GO

CREATE TABLE Catalogue.Item (
    ItemId         INT IDENTITY(1,1) NOT NULL,
    Title          NVARCHAR(150)     NOT NULL,
    Description    NVARCHAR(MAX)     NULL,
    ConditionScore TINYINT           NOT NULL,
    Specifications NVARCHAR(MAX)     NOT NULL, -- Use native JSON type if on SQL Server 2025 / Azure SQL
    ListedAt       DATETIME2(3)      NOT NULL CONSTRAINT DF_Item_ListedAt DEFAULT SYSDATETIME(),
    SellerId       UNIQUEIDENTIFIER  NOT NULL,
    InspectorId    UNIQUEIDENTIFIER  NULL,
    CategoryCode      INT               NOT NULL,
    WarehouseId    INT               NULL,

    CONSTRAINT PK_Item PRIMARY KEY (ItemId),
    CONSTRAINT CK_Item_ConditionScore CHECK (ConditionScore BETWEEN 1 AND 10),
    CONSTRAINT CK_Item_Specifications CHECK (ISJSON(Specifications) = 1),
    CONSTRAINT CK_Item_InspectorId CHECK (InspectorId IS NULL OR InspectorId <> SellerId)
);
GO

CREATE TABLE Catalogue.ItemPhoto (
    ItemId   INT          NOT NULL,
    Position TINYINT      NOT NULL,
    Url      VARCHAR(500) NOT NULL,
    IsMain   BIT          NOT NULL CONSTRAINT DF_ItemPhoto_IsMain DEFAULT 0,

    CONSTRAINT PK_ItemPhoto PRIMARY KEY (ItemId, Position),
    CONSTRAINT CK_ItemPhoto_Position CHECK (Position BETWEEN 1 AND 20)
);
GO


-- ============================================================================
-- 5. Schema: Trading (Auction, Bid, AuctionFollow)
-- ============================================================================

CREATE TABLE Trading.Auction (
    AuctionId     INT IDENTITY(1,1) NOT NULL,
    StartingPrice DECIMAL(12, 2)    NOT NULL,
    ReservePrice  DECIMAL(12, 2)    NULL,
    BidIncrement  DECIMAL(12, 2)    NOT NULL CONSTRAINT DF_Auction_BidIncrement DEFAULT 50.00,
    StartTime     DATETIMEOFFSET    NOT NULL,
    EndTime       DATETIMEOFFSET    NOT NULL,
    Status        VARCHAR(20)       NOT NULL CONSTRAINT DF_Auction_Status DEFAULT 'Draft',
    ItemId        INT               NOT NULL,

    CONSTRAINT PK_Auction PRIMARY KEY (AuctionId),
    CONSTRAINT CK_Auction_StartingPrice CHECK (StartingPrice > 0),
    CONSTRAINT CK_Auction_ReservePrice CHECK (ReservePrice IS NULL OR ReservePrice >= StartingPrice),
    CONSTRAINT CK_Auction_BidIncrement CHECK (BidIncrement > 0),
    CONSTRAINT CK_Auction_EndTime CHECK (EndTime > StartTime),
    CONSTRAINT CK_Auction_Status CHECK (Status IN ('Draft', 'Live', 'Ended', 'Cancelled'))
);
GO

CREATE TABLE Trading.Bid (
    BidId     BIGINT IDENTITY(1,1) NOT NULL,
    Amount    DECIMAL(12, 2)       NOT NULL,
    PlacedAt  DATETIME2(3)         NOT NULL CONSTRAINT DF_Bid_PlacedAt DEFAULT SYSDATETIME(),
    IpAddress VARCHAR(45)          NOT NULL,
    AuctionId INT                  NOT NULL,
    MemberId  UNIQUEIDENTIFIER     NOT NULL,

    CONSTRAINT PK_Bid PRIMARY KEY (BidId),
    CONSTRAINT UQ_Bid_AuctionId_Amount UNIQUE (AuctionId, Amount),
    CONSTRAINT CK_Bid_Amount CHECK (Amount > 0)
);
GO

-- ============================================================================
-- 6. Schema: Engagement ( AuctionFollow)
-- ============================================================================


CREATE TABLE Engagement.AuctionFollow (
    MemberId   UNIQUEIDENTIFIER NOT NULL,
    AuctionId  INT              NOT NULL,
    FollowedAt DATETIME2(3)     NOT NULL CONSTRAINT DF_AuctionFollow_FollowedAt DEFAULT SYSDATETIME(),

    CONSTRAINT PK_AuctionFollow PRIMARY KEY (MemberId, AuctionId)
);
GO


-- ============================================================================
-- TASK 3: ALTER — BUSINESS CHANGES
-- ============================================================================
--3.1  ADD FOREIGN KEY FOR ALL TABLE 

ALTER TABLE Core.MEMBER 
ADD CONSTRAINT FK_Member_City 
    FOREIGN KEY (CityId) REFERENCES CORE.CITY(CityId) ON DELETE NO ACTION,
CONSTRAINT FK_Member_InvitedByMember 
	FOREIGN KEY (InvitedByMemberId) REFERENCES Core.Member(MemberId) ON DELETE NO ACTION ;
GO

ALTER TABLE Core.Wallet
ADD CONSTRAINT FK_Wallet_Member 
	FOREIGN KEY (MemberId) REFERENCES Core.Member(MemberId) ON DELETE NO ACTION 
GO 

ALTER TABLE Core.Employee 
ADD CONSTRAINT FK_EMPLOYEE_MEMBER 
	FOREIGN KEY(MemberId) REFERENCES Core.Member(MemberId) ON DELETE NO ACTION ,
CONSTRAINT FK_EMPLOYEE_WAREHOUSE 
	FOREIGN KEY(WarehouseId) REFERENCES Core.Warehouse(WarehouseId) ON DELETE NO ACTION ;
GO

ALTER TABLE Core.Warehouse
    ADD CONSTRAINT FK_Warehouse_City
        FOREIGN KEY (CityId) REFERENCES Core.City(CityId) ON DELETE NO ACTION,
    CONSTRAINT FK_Warehouse_ManagerEmployee
        FOREIGN KEY (ManagerEmployeeId) REFERENCES Core.Employee(MemberId) ON DELETE NO ACTION;
GO

ALTER TABLE Catalogue.Category
    ADD CONSTRAINT FK_Category_ParentCategory
        FOREIGN KEY (ParentCategoryCode) REFERENCES Catalogue.Category(CategoryCode) ON DELETE NO ACTION;
GO

ALTER TABLE Catalogue.Item
    ADD CONSTRAINT FK_Item_Seller
        FOREIGN KEY (SellerId) REFERENCES Core.Member(MemberId) ON DELETE NO ACTION,
    CONSTRAINT FK_Item_Inspector
        FOREIGN KEY (InspectorId) REFERENCES Core.Employee(MemberId) ON DELETE NO ACTION,
    CONSTRAINT FK_Item_Category
        FOREIGN KEY (CategoryCode) REFERENCES Catalogue.Category(CategoryCode) ON DELETE NO ACTION,
    CONSTRAINT FK_Item_Warehouse
        FOREIGN KEY (WarehouseId) REFERENCES Core.Warehouse(WarehouseId) ON DELETE NO ACTION;
GO

ALTER TABLE Catalogue.ItemPhoto
    ADD CONSTRAINT FK_ItemPhoto_Item
        FOREIGN KEY (ItemId) REFERENCES Catalogue.Item(ItemId) ON DELETE CASCADE; --- Weak Entity 
GO

ALTER TABLE Trading.Auction
    ADD CONSTRAINT FK_Auction_Item
        FOREIGN KEY (ItemId) REFERENCES Catalogue.Item(ItemId) ON DELETE NO ACTION;
GO

ALTER TABLE Trading.Bid
    ADD CONSTRAINT FK_Bid_Auction
        FOREIGN KEY (AuctionId) REFERENCES Trading.Auction(AuctionId) ON DELETE NO ACTION,
    CONSTRAINT FK_Bid_Member
        FOREIGN KEY (MemberId) REFERENCES Core.Member(MemberId) ON DELETE NO ACTION;
GO

ALTER TABLE Engagement.AuctionFollow
    ADD CONSTRAINT FK_AuctionFollow_Member
        FOREIGN KEY (MemberId) REFERENCES Core.Member(MemberId) ON DELETE NO ACTION,
    CONSTRAINT FK_AuctionFollow_Auction
        FOREIGN KEY (AuctionId) REFERENCES Trading.Auction(AuctionId) ON DELETE NO ACTION;
GO


-- 3.2 Members choose an app language, ar or en (NOT NULL, existing rows get 'ar' — One statement)
ALTER TABLE Core.Member
    ADD AppLanguage CHAR(2) NOT NULL
        CONSTRAINT DF_Member_AppLanguage DEFAULT 'ar'
        CONSTRAINT CK_Member_AppLanguage CHECK (AppLanguage IN ('ar', 'en'));
GO

-- 3.3 Items can be "featured" (NOT NULL Yes/No column, default No)
ALTER TABLE Catalogue.Item
    ADD IsFeatured BIT NOT NULL
        CONSTRAINT DF_Item_IsFeatured DEFAULT 0;
GO

-- 3.4 Naming review — Rename IpAddress to DeviceIp and Capacity to MaxItems
EXEC sp_rename 
	'Trading.Bid.IpAddress', 
	'DeviceIp', 
	'COLUMN';
GO
-- Drop dependency temporarily
ALTER TABLE Core.Warehouse
DROP CONSTRAINT CK_Warehouse_Capacity;
GO

-- Rename Capacity to MaxItems
EXEC sp_rename
    'Core.Warehouse.Capacity',
    'MaxItems',
    'COLUMN';
GO

-- Restore the business rule using the new column name
ALTER TABLE Core.Warehouse
ADD CONSTRAINT CK_Warehouse_Capacity
CHECK (MaxItems > 0);
GO


-- 3.5 Expand FullName to 150 characters while preserving NOT NULL
ALTER TABLE Core.Member
    ALTER COLUMN FullName NVARCHAR(150) NOT NULL;
GO


-- 3.6 Change MaxItems to smallest fitting type (SMALLINT) and keep "> 0"
ALTER TABLE Core.Warehouse
    DROP CONSTRAINT CK_Warehouse_Capacity;
GO

ALTER TABLE Core.Warehouse
    ALTER COLUMN MaxItems SMALLINT NOT NULL;
GO

ALTER TABLE Core.Warehouse
	ADD CONSTRAINT CK_Warehouse_MaxItems CHECK(MaxItems>0);
GO


-- 3.7 Max commission is now 25% — Replace commission CHECK
ALTER TABLE Catalogue.Category
    DROP CONSTRAINT CK_Category_CommissionPct;
GO

ALTER TABLE Catalogue.Category
    ADD CONSTRAINT CK_Category_CommissionPct CHECK (CommissionPct BETWEEN 0 AND 25);
GO


-- 3.8 Allow status PendingReview and make it the new default
ALTER TABLE Trading.Auction
    DROP CONSTRAINT CK_Auction_Status,
    CONSTRAINT DF_Auction_Status;
GO

ALTER TABLE Trading.Auction
    ADD CONSTRAINT CK_Auction_Status CHECK (Status IN ('Draft', 'PendingReview', 'Live', 'Ended', 'Cancelled')),
        CONSTRAINT DF_Auction_Status DEFAULT 'PendingReview' FOR Status;
GO

-- 3.9 Optional "Buy Now" price + named CHECK (> StartingPrice)
ALTER TABLE Trading.Auction
ADD BuyNowPrice DECIMAL(12, 2) NULL;
GO

-- WITH CHECK validates existing rows and creates a trusted constraint.
-- Existing BuyNowPrice values are NULL, so they satisfy this condition
ALTER TABLE Trading.Auction WITH CHECK
    ADD CONSTRAINT CK_Auction_BuyNowPrice CHECK(BuyNowPrice IS NULL OR BuyNowPrice > StartingPrice);
GO

-- 3.10 Member's mobile (Phone) must now be unique
ALTER TABLE Core.Member 
	ADD CONSTRAINT UQ_MEMBER_Phone UNIQUE(Phone) ;
GO


-- 3.11 Add VerifiedAt (optional), drop default constraint, then drop IsVerified
ALTER TABLE Core.Member
    ADD VerifiedAt DATETIME2(3) NULL;
GO

ALTER TABLE Core.Member
    DROP CONSTRAINT DF_Member_IsVerivied;
GO

ALTER TABLE Core.Member
    DROP COLUMN IsVerified;
GO


-- 3.12 Create schema Marketing and transfer AuctionFollow into it
CREATE SCHEMA Marketing;
GO

ALTER SCHEMA Marketing 
	TRANSFER Engagement.AuctionFollow;
GO 
