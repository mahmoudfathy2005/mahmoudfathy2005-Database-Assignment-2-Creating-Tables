# BidNile — Assignment Notes

## 1. The 4 Schemas, Their Tables, and Why
I split the tables into 4 logical schemas based on their role in the system:

* **`Core`** (`City`, `Member`, `Wallet`, `Employee`, `Warehouse`): Contains the main system users, their wallets, locations, and the internal staff/warehouses that other parts of the app depend on.
* **`Catalogue`** (`Category`, `Item`, `ItemPhoto`): Keeps all product-related data (categories, item details, specs, and photos) separate from the live auction process.
* **`Trading`** (`Auction`, `Bid`): Handles the core auction workflow and high-volume bidding operations.
* **`Engagement`** (`AuctionFollow` — moved to **`Marketing`** in Task 3.12): Separates user watchlists/follows from actual bidding so the marketing team can manage user engagement independently.

---

## 2. How I Mapped Each Relationship Type
* **1:1 (`Member` ↔ `Wallet`)**: Put `MemberId` in `Wallet` as both the **Primary Key** and **Foreign Key** referencing `Member(MemberId)`. That way each member gets only one wallet, and no wallet can belong to two members.
* **1:N (`City` → `Member`, `City` → `Warehouse`, `Warehouse` → `Employee`, `Warehouse` → `Item`, `Category` → `Item`, `Member` → `Item` [Seller], `Employee` → `Item` [Inspector], `Item` → `Auction`, `Auction` → `Bid`, `Member` → `Bid`)**: Placed the parent table's PK as an FK column in the child table.
* **M:N (`Member` ↔ `Auction` via `AuctionFollow`)**: Created a junction table (`Marketing.AuctionFollow`) with a composite PK `(MemberId, AuctionId)` and two FKs to `Member` and `Auction`, plus `FollowedAt`.
* **Recursive (`Category` & `Member`)**:
  * `Category.ParentCategoryCode` references `Category.CategoryCode` (nullable for main categories like `Vehicles`).
  * `Member.InvitedByMemberId` references `Member.MemberId` (nullable if the user signed up without an invite).
* **Circular (`Employee` ↔ `Warehouse`)**: `Employee.WarehouseId` references `Warehouse.WarehouseId` (where the employee works), and `Warehouse.ManagerEmployeeId` (`UNIQUE` + `FK`) references `Employee.MemberId` (who manages the warehouse).
* **Weak Entity (`ItemPhoto`)**: Mapped with a composite PK `(ItemId, Position)` where `ItemId` is an FK with `ON DELETE CASCADE`, so photos cannot exist without their item and get deleted automatically if the item is removed.

---

## 3. Why These Data Types?
* **`UNIQUEIDENTIFIER` (GUID) for `MemberId`**: Mobile apps generate member IDs offline before sending requests to the server, so GUID prevents duplicate IDs across different devices without relying on a central counter.
* **`BIGINT` for `BidId`**: Bids will pass 2.1 billion within a few years, which exceeds the `INT` limit (~2.14 billion). `BIGINT` handles much larger numbers safely.
* **`FLOAT` for GPS (`Latitude` / `Longitude`)**: GPS coordinates are approximate values with many decimal places, so `FLOAT` is suitable and lightweight for map locations.
* **`DECIMAL(12, 2)` for Money**: Money needs exact decimal precision (`up to 9,999,999,999.99`) without the rounding issues that happen with `FLOAT`.
* **`DATETIMEOFFSET` for Auctions (`StartTime`, `EndTime`)**: Users bid from different time zones (`+02:00`, `+03:00`, `+04:00`), so `DATETIMEOFFSET` stores both the exact time and the time-zone offset.

---

## 4. Why Can't the Circular Relationship Be Created Inside `CREATE TABLE`?
Because in SQL Server, a Foreign Key can only reference a table that **already exists**. Since `Employee` references `Warehouse` and `Warehouse` also references `Employee`, whichever table is created first would fail if we put the FK inside `CREATE TABLE`. So we create both tables first, then add the FKs later using `ALTER TABLE`.

---

## 5. Table Population Order and Why
Since FKs were already active, parent rows had to be inserted before child rows:

1. `Core.City` (no FKs)
2. `Catalogue.Category` (parent categories first with `NULL`, then subcategories)
3. `Core.Member` (members without referrers first, then invited members)
4. `Core.Wallet` (needs `MemberId`)
5. `Core.Employee` with `WarehouseId = NULL` (breaks the circular loop temporarily)
6. `Core.Warehouse` (needs `CityId` and `ManagerEmployeeId` from `Employee`)
7. Update `Core.Employee.WarehouseId` (links employees to their warehouses now that warehouses exist)
8. `Catalogue.Item` (needs `Member`, `Employee`, `Category`, and `Warehouse`)
9. `Catalogue.ItemPhoto` (needs `ItemId`)
10. `Trading.Auction` (needs `ItemId`)
11. `Trading.Bid` (needs `AuctionId` and `MemberId`)
12. `Marketing.AuctionFollow` (needs `MemberId` and `AuctionId`)

---

## 6. Errors in 3.6 and 3.11 and How I Fixed Them
* **Task 3.6 (`MaxItems` to `SMALLINT`)**:
  * **Error**: Changing `MaxItems` to `SMALLINT` failed because the `CHECK` constraint (`> 0`) was attached to that column.
  * **Fix**: Dropped the `CHECK` constraint first, altered the column to `SMALLINT NOT NULL`, then added the `CHECK (MaxItems > 0)` back.
* **Task 3.11 (Dropping `IsVerified`)**:
  * **Error**: Dropping `IsVerified` failed because its `DEFAULT` constraint (`DF_Member_IsVerified`) was still bound to it.
  * **Fix**: Dropped the default constraint first using `ALTER TABLE Core.Member DROP CONSTRAINT DF_Member_IsVerified`, then dropped the column.

