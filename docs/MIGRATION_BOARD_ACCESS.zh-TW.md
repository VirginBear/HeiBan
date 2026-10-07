# HeiBan 黑板存取與成員契約遷移及安全規格書 (AG-10)

文件版本：`1.0.0`  
生效日期：2026-10-06  
關聯工作：AG-10 (Phase 1 資料安全與文件一致性)  
關聯驗收案例：A28, A30, 契約測試 `[測試 10]`

---

## 1. 背景與安全現況稽核

在本次重構前，原 `firestore.rules` 存在嚴重安全邊界缺失：
1. **未限制黑板存取**：任意登入使用者皆可直接讀取任意 `boardId`，甚至更新其內容與刪除子物件。
2. **Presence 洩漏**：所有登入者可監聽任意黑板的線上成員游標與繪製軌跡。
3. **型別漏失**：白名單漏掉 `paint` 塗鴉筆刷、`curve` 曲線與 `staff` 五線譜，導致合法作品在線上寫入被拒絕。
4. **無十人上限防護**：無法在服務端強制阻止第 11 位使用者同時寫入。

---

## 2. 黑板成員契約與資料模型設計

### 2.1 資料結構 (`BoardMetadata`)

```typescript
export interface BoardMetadata {
  id: string;
  title: string;
  ownerId: string;              // 擁有者 UID (唯一擁有者，具備刪除黑板與指派權限)
  ownerName: string;
  collaboratorIds?: string[];   // 協作者 UID 陣列 (至多 9 位，含 Owner 總共至多 10 人)
  memberRoles?: Record<string, MemberRole>; // 成員角色映射字典
  // ...其餘版面與物件欄位
}

export type MemberRole = 'owner' | 'editor' | 'viewer' | 'revoked';
```

### 2.2 角色權限對照表 (RBAC)

| 角色 (`MemberRole`) | 讀取黑板 | 讀取物件/Presence | 寫入/刪除物件 | 更新 Presence | 編輯黑板標題/設定 | 增刪協作者 | 刪除黑板 |
|---|---|---|---|---|---|---|---|
| **Owner (擁有者)** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Editor (編輯者)** | ✅ | ✅ | ✅ | ✅ | 僅 revision/計數 | ❌ | ❌ |
| **Viewer (檢視者)** | ✅ | ✅ | ❌ | ❌ (僅游標) | ❌ | ❌ | ❌ |
| **Revoked (已撤銷)** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Outsider (非成員)** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

---

## 3. 既有資料遷移方案與相容性保證

### 3.1 既有黑板格式向後相容
* **舊格式 (僅有 `ownerId`)**：
  * 規則自動視 `ownerId == request.auth.uid` 為完整 Owner 權限。
  * 舊檔案即便無 `collaboratorIds` 或 `memberRoles`，擁有者讀寫完全無損。
* **舊格式 (僅有 `collaboratorIds`)**：
  * 若無 `memberRoles`，規則將 `collaboratorIds` 中的所有 UID 預設視為具備編輯權限之 Editor。

### 3.2 遷移腳本邏輯 (可選離線批次遷移)
```typescript
function migrateBoardToMemberContract(legacyBoard: any) {
  const memberRoles: Record<string, string> = {};
  if (legacyBoard.ownerId) {
    memberRoles[legacyBoard.ownerId] = 'owner';
  }
  if (Array.isArray(legacyBoard.collaboratorIds)) {
    for (const uid of legacyBoard.collaboratorIds) {
      if (uid !== legacyBoard.ownerId && Object.keys(memberRoles).length < 10) {
        memberRoles[uid] = 'editor';
      }
    }
  }
  return {
    ...legacyBoard,
    collaboratorIds: Object.keys(memberRoles).filter(id => id !== legacyBoard.ownerId),
    memberRoles,
  };
}
```

---

## 4. 風險評估與防護原則

1. **服務中斷風險**：
   * 若線上存在未記錄在 `collaboratorIds` 卻正在協作的使用者，更新規則後將被阻擋讀寫。
   * **防護措施**：嚴格落實「規則僅提交於本機 repository，未經使用者明確部署指示絕不自動執行 `firebase deploy --only firestore:rules`」。
2. **人數上限阻擋 (10 人限制)**：
   * 依據 A30 規範，第 11 位加入者在服務端規則層面即刻被拒絕（`hasValidMemberCount` 限制 `collaboratorIds.size() <= 9`）。
3. **偽造 OwnerId 防護**：
   * 新建黑板強制驗證 `incoming().ownerId == request.auth.uid`，杜絕任何客戶端偽造建立者身分。

---

## 5. 驗收結果

* 本機 `firestore.rules` 語法與成員驗證邏輯已更新完畢。
* 契約測試 `tests/contract.test.ts` 新增 `[測試 10]`，共 30 項安全斷言全數通過（未登入阻擋、非成員阻擋、Owner 授權、Editor 授權、Viewer 唯讀保護、Revoked 撤銷阻擋、偽造 ownerId 阻擋、10 人上限拒絕第 11 人、paint/curve/staff 白名單）。
