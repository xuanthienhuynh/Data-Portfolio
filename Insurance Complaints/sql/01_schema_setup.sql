CREATE DATABASE PP_InsuranceComplaints;
GO
USE PP_InsuranceComplaints;
GO
 
CREATE TABLE dbo.Priorities (
    ID          INT PRIMARY KEY,
    Description VARCHAR(50) NOT NULL
);
 
CREATE TABLE dbo.Statuses (
    ID          INT PRIMARY KEY,
    Description VARCHAR(50) NOT NULL
);
 
CREATE TABLE dbo.Sources (
    ID          INT PRIMARY KEY,
    Description VARCHAR(100) NOT NULL
);
 
CREATE TABLE dbo.Types (
    ID          INT PRIMARY KEY,
    Description VARCHAR(100) NOT NULL
);
 
CREATE TABLE dbo.Categories (
    ID          INT PRIMARY KEY,
    Description VARCHAR(255) NOT NULL,  
    Active      BIT NOT NULL DEFAULT 1
);
 
CREATE TABLE dbo.Products (
    ProductID           INT PRIMARY KEY,
    ProductCategory     VARCHAR(50)  NOT NULL,
    ProductSubCategory  VARCHAR(50)  NOT NULL,
    Product              VARCHAR(50)  NOT NULL
);
 
CREATE TABLE dbo.Brokers (
    BrokerID            INT PRIMARY KEY,
    BrokerCode           VARCHAR(50),
    BrokerFullName        VARCHAR(150),
    DistributionNetwork   VARCHAR(50),   -- Bancassurance / Brokers / Direct
    DistributionChannel   VARCHAR(50),   -- XPA / Tele sales / Bank Branches ...
    CommissionScheme       VARCHAR(50)
);
 
CREATE TABLE dbo.StateRegions (
    StateCode   VARCHAR(2) PRIMARY KEY,
    StateName   VARCHAR(50) NOT NULL,
    Region      VARCHAR(50) NOT NULL      -- South / Northeast / Midwest / West
);
 
CREATE TABLE dbo.Regions (
    RegionID        INT PRIMARY KEY,      -- cột 'id' trong file gốc
    Name            VARCHAR(100),
    County          VARCHAR(100),
    StateCode       VARCHAR(2) FOREIGN KEY REFERENCES dbo.StateRegions(StateCode),
    StateName       VARCHAR(50),
    Type            VARCHAR(50),          -- City / Town / Village / Township ...
    Latitude        FLOAT,
    Longitude       FLOAT,
    AreaCode        VARCHAR(10),
    Population      INT,
    Households      INT,
    MedianIncome    INT,
    LandArea        FLOAT,
    WaterArea       FLOAT,
    TimeZone        VARCHAR(50)
);
 
CREATE TABLE dbo.Customers (
    CustomerID       INT PRIMARY KEY,
    LastName          VARCHAR(100),
    FirstName          VARCHAR(100),
    BirthDate          DATE,
    Gender             VARCHAR(10),
    ParticipantType     VARCHAR(20),       -- INDIVIDUAL / COMPANY
    RegionID            INT FOREIGN KEY REFERENCES dbo.Regions(RegionID),
    MaritalStatus       VARCHAR(20)
);
 
 --2 bảng fact 
CREATE TABLE dbo.ComplainsData (
    ID                    INT PRIMARY KEY,
    ComplainDate           DATE NOT NULL,
    CompletionDate          DATE NULL,               -- có thể NULL nếu khiếu nại chưa đóng
    CustomerID              INT FOREIGN KEY REFERENCES dbo.Customers(CustomerID),
    BrokerID                 INT FOREIGN KEY REFERENCES dbo.Brokers(BrokerID),
    ProductID                 INT FOREIGN KEY REFERENCES dbo.Products(ProductID),
    ComplainPriorityID          INT FOREIGN KEY REFERENCES dbo.Priorities(ID),
    ComplainTypeID                INT FOREIGN KEY REFERENCES dbo.Types(ID),
    ComplainSourceID                INT FOREIGN KEY REFERENCES dbo.Sources(ID),
    ComplainCategoryID                INT FOREIGN KEY REFERENCES dbo.Categories(ID),
    ComplainStatusID                    INT FOREIGN KEY REFERENCES dbo.Statuses(ID),
    AdministratorID                       INT,
    ClientSatisfaction VARCHAR(20),  -- SAT / NSA / N/A
    ExpectedReimbursement                    DECIMAL(14,2)
);
 
CREATE TABLE dbo.StatusHistoryData (
    ID                   INT PRIMARY KEY,
    ComplaintID           INT FOREIGN KEY REFERENCES dbo.ComplainsData(ID),
    ComplaintStatusID       INT FOREIGN KEY REFERENCES dbo.Statuses(ID),
    StatusDate                DATE NOT NULL
);
GO


---------- import dữ liệu 
INSERT INTO [dbo].[StatusHistoryData] (
    [ID], 
    [ComplaintID], 
    [ComplaintStatusID], 
    [StatusDate]
)
SELECT 
    TRY_CONVERT(INT, [ID]),
    TRY_CONVERT(INT, [ComplaintID]),
    TRY_CONVERT(INT, [ComplaintStatusID]),
    TRY_CONVERT(DATE, [StatusDate])
FROM [dbo].[Status_History_Cleaned]
WHERE TRY_CONVERT(INT, [ID]) IS NOT NULL;

DROP TABLE [dbo].[Status_History_Cleaned];

----------- 2. kiểm tra dữ liệu đầy đủ sau khi import 
SELECT 'Priorities' t, COUNT(*) c FROM dbo.Priorities
UNION ALL SELECT 'Statuses', COUNT(*) FROM dbo.Statuses
UNION ALL SELECT 'Sources', COUNT(*) FROM dbo.Sources
UNION ALL SELECT 'Types', COUNT(*) FROM dbo.Types
UNION ALL SELECT 'Categories', COUNT(*) FROM dbo.Categories        
UNION ALL SELECT 'Products', COUNT(*) FROM dbo.Products
UNION ALL SELECT 'Brokers', COUNT(*) FROM dbo.Brokers              
UNION ALL SELECT 'StateRegions', COUNT(*) FROM dbo.StateRegions
UNION ALL SELECT 'Regions', COUNT(*) FROM dbo.Regions
UNION ALL SELECT 'Customers', COUNT(*) FROM dbo.Customers          
UNION ALL SELECT 'ComplainsData', COUNT(*) FROM dbo.ComplainsData  
UNION ALL SELECT 'StatusHistoryData', COUNT(*) FROM dbo.StatusHistoryData; 

--------- 3. kiểm tra dữ liệu có mồ côi FK không 
SELECT DISTINCT cd.ComplainCategoryID FROM dbo.ComplainsData cd
LEFT JOIN dbo.Categories c ON cd.ComplainCategoryID = c.ID WHERE c.ID IS NULL;
 
SELECT DISTINCT cd.BrokerID FROM dbo.ComplainsData cd
LEFT JOIN dbo.Brokers b ON cd.BrokerID = b.BrokerID WHERE b.BrokerID IS NULL;
 
SELECT DISTINCT cd.CustomerID FROM dbo.ComplainsData cd
LEFT JOIN dbo.Customers cu ON cd.CustomerID = cu.CustomerID WHERE cu.CustomerID IS NULL;
 
SELECT DISTINCT sh.ComplaintID FROM dbo.StatusHistoryData sh
LEFT JOIN dbo.ComplainsData cd ON sh.ComplaintID = cd.ID WHERE cd.ID IS NULL;
 