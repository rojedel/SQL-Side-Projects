--The data I'm using for this project is under a public domain license.
--This is data for the Nashville area housing market
--I'll be doing data validation aswell as data cleaning with SQL using Microsoft's SQL Server Management Studio(SSMS)

------------------------------------------------------------------------------------------

--First I'll open the table to have a first look at the data
SELECT *
FROM dbo.NashvilleHousing

--SaleData column appears to be a datetime format when I't be better to be simply a date type.
SELECT  SaleDate, CONVERT(Date, SaleDate)
FROM dbo.NashvilleHousing

UPDATE NashvilleHousing
SET SaleDate = CONVERT(Date, SaleDate)
--The table doesn't update correctly after this code, so I'll do it in another way.
--I added a new column to the table and did an update to that new column, called it SaleDateConverted

ALTER TABLE NashvilleHousing
ADD SaleDateConverted Date;

UPDATE NashvilleHousing
SET SaleDateConverted = CONVERT(Date, SaleDate)

SELECT  SaleDateConverted, CONVERT(Date, SaleDate)
FROM dbo.NashvilleHousing

-------------------------------------------------------------------------------------------------------------------------------

--Populating the missing PropertyAdress data.
--There is 29 rows with missing PropertyAdress data. I'll use ParcelID data to identify the missing Property Adresses.

SELECT COUNT(*)
FROM dbo.NashvilleHousing
WHERE PropertyAddress is null

SELECT *
FROM dbo.NashvilleHousing
--WHERE PropertyAddress is null
ORDER BY ParcelID

--Using a self join to fill the missing data. 
--ParcelID has been identified as an reference point for where we can find the missing addresses on the table, 
-- which in this case we can find on repeated ParcelID rows.
--This query performs a self join with the ParcelID column being the Primary Key aswell as UniqueID and only shows the rows with the 
-- missing PropertyAdress on the original table. It also shows a new column with the data that it selected to fill the original missing data.
SELECT a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress, ISNULL(a.PropertyAddress, b.PropertyAddress)
FROM dbo.NashvilleHousing a
JOIN dbo.NashvilleHousing b
	ON a.ParcelID = b.ParcelID
	AND a.[UniqueID ] <> b.[UniqueID ]
WHERE a.PropertyAddress is null

--Then it's time to update the table with this identified missing fields.
UPDATE a --"a" is what the called the original table with the alias.
SET PropertyAddress = ISNULL(a.PropertyAddress, b.PropertyAddress)
FROM dbo.NashvilleHousing a
JOIN dbo.NashvilleHousing b
	ON a.ParcelID = b.ParcelID
	AND a.[UniqueID ] <> b.[UniqueID ]
WHERE a.PropertyAddress is null

--Testing to see if the update worked correctly.
SELECT *
FROM dbo.NashvilleHousing
WHERE PropertyAddress is null
--It did.

-----------------------------------------------------------------------------------------------------------------------------------

--Separating PropertyAdress into different address columns. Address, City, State.
--This column has the benefit of having a comma delimiter within the field, which I'll use to separate it.

SELECT PropertyAddress
FROM dbo.NashvilleHousing

SELECT 
	SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress)-1) as Address,
	SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress)+1, LEN(PropertyAddress)) as City
	FROM dbo.NashvilleHousing

-- Now comes modifying the original table and updating it to add these new columns.
ALTER TABLE NashvilleHousing
ADD PropertySplitAddress Nvarchar(255)

UPDATE NashvilleHousing
SET PropertySplitAddress = SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress)-1)

ALTER TABLE NashvilleHousing
ADD PropertySplitCity Nvarchar(255)

UPDATE NashvilleHousing
SET PropertySplitCity = SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress)+1, LEN(PropertyAddress))

--I'll test querying the full table to see if these changes worked correctly.
SELECT *
FROM dbo.NashvilleHousing
--It did work. Now we have the additional split city and address columns.

-----------------------------------------------------------------------------------------------------------------------

--The OwnerAddress column contains several useful pieces of information that would be easier to work with if they were separated,
--which I'll do with the PARSENAME function this time.

SELECT OwnerAddress
FROM dbo.NashvilleHousing

--This query uses the PARSENAME function, which only works to separate strings with the period delimiter. This is why
--I also used the REPLACE function to replace commas with periods. That change was necessary for the function to execute properly.
SELECT PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1) as State,
PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2) as City,
PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3) as Address
FROM dbo.NashvilleHousing

--After figuring out the way to properly split the OwnerAddress column into more useful chunks, I'll update the table.
ALTER TABLE NashvilleHousing
ADD OwnerSplitAddress Nvarchar(255);

UPDATE NashvilleHousing
SET OwnerSplitAddress = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3);

ALTER TABLE NashvilleHousing
ADD OwnerSplitCity Nvarchar(255);

UPDATE NashvilleHousing
SET OwnerSplitCity = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2)

ALTER TABLE NashvilleHousing
ADD OwnerSplitState Nvarchar(255);

UPDATE NashvilleHousing
SET OwnerSplitState = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1)

--Taking a look at the full table to verify results.
SELECT *
FROM dbo.NashvilleHousing

--Doing data validation is appears theres inconsistent data formats in the SoldAsVacant column, I'll standardize it.
--There is a "Yes", "No" format as well as a "Y" and "N".
SELECT DISTINCT(SoldAsVacant), COUNT(SoldAsVacant)
FROM dbo.NashvilleHousing
GROUP BY SoldAsVacant
ORDER BY 2
--Since "Yes" and "No" are the most common in the table, I'll change "Y" and "N" to match the others.
--Utilizing a CASE statement.
SELECT SoldAsVacant, CASE WHEN SoldAsVacant = 'Y'THEN 'Yes'
							WHEN SoldAsVacant = 'N' THEN 'No'
							ELSE SoldAsVacant
							END
FROM dbo.NashvilleHousing

--Updating the table
UPDATE NashvilleHousing
SET SoldAsVacant = CASE WHEN SoldAsVacant = 'Y'THEN 'Yes'
							WHEN SoldAsVacant = 'N' THEN 'No'
							ELSE SoldAsVacant
							END

--------------------------------------------------------------------------------------------------

--Removing the duplicates and unused data using a CTE..
--In this query in order to use the newly created row_num column within the same query, I had to create
-- a CTE to properly count the duplicated rows, which are the rows that have a row_num value above 1.
--In this case the result was 104 duplicated rows, which I chose to drop from the table in the second query.


WITH RowNumCTE AS (
SELECT *, 
	ROW_NUMBER() OVER (
	PARTITION BY ParcelID,
					PropertyAddress,
					SalePrice,
					SaleDate,
					LegalReference
					ORDER BY UniqueID
					) row_num
FROM dbo.NashvilleHousing
)
SELECT COUNT(UniqueID)
FROM RowNumCTE
WHERE row_num > 1

--Dropping the 104 duplicated rows.

WITH RowNumCTE AS (
SELECT *, 
	ROW_NUMBER() OVER (
	PARTITION BY ParcelID,
					PropertyAddress,
					SalePrice,
					SaleDate,
					LegalReference
					ORDER BY UniqueID
					) row_num
FROM dbo.NashvilleHousing
)
DELETE
FROM RowNumCTE
WHERE row_num > 1
--After this query there are no longer any duplicated rows as proved after running the query above this one.

--Now I'm dropping the columns that I dont think are useful.

ALTER TABLE dbo.NashvilleHousing
DROP COLUMN OwnerAddress,
			TaxDistrict,
			PropertyAddress,

ALTER TABLE dbo.NashvilleHousing
DROP COLUMN SaleDate

SELECT *
FROM dbo.NashvilleHousing





