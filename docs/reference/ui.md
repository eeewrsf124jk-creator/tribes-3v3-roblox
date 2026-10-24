<!-- 자동 생성 문서: tools/gendocs.luau 가 만듭니다. 직접 고치지 말고 다시 생성하세요. -->

# ScreenGui 전체 구조

Step 4 빌더가 만드는 11개 화면의 모든 요소입니다. 이름은 클라이언트 컨트롤러가 찾는 계약이라 바꾸면 컨트롤러도 같이 바꿔야 합니다. 글자가 있는 요소는 기본 문구를 함께 적었습니다.

| ScreenGui | 요소 수 |
|---|---|
| LobbyHUD | 148 |
| LoadoutBuilder | 335 |
| CustomMatches | 100 |
| TribeHall | 89 |
| Settings | 73 |
| VSScreen | 89 |
| CombatHUD | 294 |
| DeathAndSpectate | 35 |
| POTGViewfinder | 54 |
| VictoryDropUI | 196 |
| ScoreboardSummaryUI | 156 |

## LobbyHUD

꾸밈 요소 포함 구성: Frame 12, TextBox 1, TextButton 12, TextLabel 14, UIAspectRatioConstraint 5, UICorner 22, UIGradient 19, UIListLayout 3, UIPadding 13, UIStroke 20, UITextSizeConstraint 27

<details><summary>요소 트리 펼치기</summary>

- ProfileCard `Frame`
  - NameLabel `TextLabel` — "Player"
  - LevelLabel `TextLabel` — "LV 1"
  - XPBar `Frame`
    - Fill `Frame`
  - StreakLabel `TextLabel` — "🔥 0"
  - GloryLabel `TextLabel` — "0 RP"
  - TribeLabel `TextLabel` — "[—]"
- CurrencyCard `Frame`
  - ShardsLabel `TextLabel` — "💎 0 SHARDS"
- SideButtons `Frame`
  - LoadoutButton `TextButton` — "[B] LOADOUT"
  - CustomButton `TextButton` — "CUSTOM MATCH"
  - TribeButton `TextButton` — "TRIBE HALL"
  - SettingsButton `TextButton` — "SETTINGS"
  - GoldenDropButton `TextButton` — "GOLDEN DROP 9R$"
  - RestoreStreakButton `TextButton` — "RESTORE STREAK"
- PlayPanel `Frame`
  - PlayButton `TextButton` — "PLAY 3v3"
  - CancelButton `TextButton` — "CANCEL"
  - QueueStatus `TextLabel` — "Ready to fight"
  - BotFillLabel `TextLabel`
- PartyPanel `Frame`
  - Title `TextLabel` — "PARTY"
  - MemberList `Frame`
    - MemberTemplate `Frame`
      - Name `TextLabel` — "Member"
      - Role `TextLabel` — "LEADER"
  - InviteBox `TextBox`
  - InviteButton `TextButton` — "INVITE"
  - LeaveButton `TextButton` — "LEAVE"
- PartyInvite `Frame`
  - InviteText `TextLabel` — "X invited you to a party"
  - AcceptButton `TextButton` — "ACCEPT"
  - DeclineButton `TextButton` — "DECLINE"
- Toasts `Frame`
  - ToastTemplate `Frame`
    - Message `TextLabel`
- InteractHint `TextLabel`

</details>

## LoadoutBuilder

꾸밈 요소 포함 구성: Frame 24, ScrollingFrame 1, TextButton 29, TextLabel 42, UIAspectRatioConstraint 15, UICorner 48, UIGradient 32, UIGridLayout 1, UIListLayout 4, UIPadding 30, UIStroke 39, UITextSizeConstraint 70

<details><summary>요소 트리 펼치기</summary>

- Dim `Frame`
- Modal `Frame`
  - Title `TextLabel` — "LOADOUT BUILDER"
  - CloseButton `TextButton` — "✕"
  - PresetTabs `Frame`
    - Preset1 `TextButton` — "1"
    - Preset2 `TextButton` — "2"
    - Preset3 `TextButton` — "3"
    - Preset4 `TextButton` — "4"
    - Preset5 `TextButton` — "5"
  - Categories `Frame`
    - Cat_WEAPONS `TextButton` — "WEAPONS"
    - Cat_UTILITY `TextButton` — "UTILITY"
    - Cat_HEALING `TextButton` — "HEALING"
    - Cat_ARMOR `TextButton` — "ARMOR"
    - Cat_AMMO `TextButton` — "AMMO"
  - ItemGridFrame `Frame`
    - ItemGrid `ScrollingFrame`
      - ItemCardTemplate `TextButton`
        - Glyph `TextLabel` — "⚔"
        - NameLabel `TextLabel` — "Item"
        - CostLabel `TextLabel` — "3 PT"
        - LevelLabel `TextLabel` — "LV1"
        - LockOverlay `Frame`
          - LockText `TextLabel` — "🔒"
  - LoadoutPanel `Frame`
    - PresetName `TextLabel` — "PRESET 1"
    - Slots `Frame`
      - Slot1 `Frame`
        - Key `TextLabel` — "1"
        - ItemName `TextLabel` — "— empty —"
        - Cost `TextLabel`
        - RemoveButton `TextButton` — "✕"
      - Slot2 `Frame`
        - Key `TextLabel` — "2"
        - ItemName `TextLabel` — "— empty —"
        - Cost `TextLabel`
        - RemoveButton `TextButton` — "✕"
      - Slot3 `Frame`
        - Key `TextLabel` — "3"
        - ItemName `TextLabel` — "— empty —"
        - Cost `TextLabel`
        - RemoveButton `TextButton` — "✕"
      - Slot4 `Frame`
        - Key `TextLabel` — "4"
        - ItemName `TextLabel` — "— empty —"
        - Cost `TextLabel`
        - RemoveButton `TextButton` — "✕"
      - Slot5 `Frame`
        - Key `TextLabel` — "5"
        - ItemName `TextLabel` — "— empty —"
        - Cost `TextLabel`
        - RemoveButton `TextButton` — "✕"
      - Slot6 `Frame`
        - Key `TextLabel` — "6"
        - ItemName `TextLabel` — "— empty —"
        - Cost `TextLabel`
        - RemoveButton `TextButton` — "✕"
    - ArmorSlot `Frame`
      - Key `TextLabel` — "🛡"
      - ItemName `TextLabel` — "No armor"
      - Cost `TextLabel`
      - RemoveButton `TextButton` — "✕"
    - AmmoRows `Frame`
      - Arrows `Frame`
        - Label `TextLabel` — "ARROWS ×12 · 1 PT"
        - Minus `TextButton` — "−"
        - Count `TextLabel` — "0"
        - Plus `TextButton` — "+"
      - Bullets `Frame`
        - Label `TextLabel` — "BULLETS ×6 · 1 PT"
        - Minus `TextButton` — "−"
        - Count `TextLabel` — "0"
        - Plus `TextButton` — "+"
      - FireArrows `Frame`
        - Label `TextLabel` — "FIRE ARROWS ×6 · 2 PT"
        - Minus `TextButton` — "−"
        - Count `TextLabel` — "0"
        - Plus `TextButton` — "+"
    - PointsLabel `TextLabel` — "0 / 12 PT"
    - SlotsLabel `TextLabel` — "0 / 6 SLOTS"
    - PointsBar `Frame`
      - Fill `Frame`
    - ErrorLabel `TextLabel`
    - SaveButton `TextButton` — "SAVE & EQUIP"
  - DetailPanel `Frame`
    - DetailName `TextLabel` — "Select an item"
    - DetailLevel `TextLabel`
    - DetailDesc `TextLabel`
    - DetailStats `TextLabel`
    - ShardBar `Frame`
      - Fill `Frame`
    - ShardLabel `TextLabel`
    - AddButton `TextButton` — "ADD TO LOADOUT"
    - UpgradeButton `TextButton` — "UPGRADE"
    - UnlockRobuxButton `TextButton` — "UNLOCK R$"

</details>

## CustomMatches

꾸밈 요소 포함 구성: Frame 8, ScrollingFrame 1, TextButton 10, TextLabel 7, UIAspectRatioConstraint 2, UICorner 16, UIGradient 11, UIListLayout 4, UIPadding 13, UIStroke 11, UITextSizeConstraint 17

<details><summary>요소 트리 펼치기</summary>

- Dim `Frame`
- Modal `Frame`
  - Title `TextLabel` — "CUSTOM MATCHES"
  - CloseButton `TextButton` — "✕"
  - ModeButtons `Frame`
    - Create1v1 `TextButton` — "CREATE 1v1"
    - Create2v2 `TextButton` — "CREATE 2v2"
    - Create3v3 `TextButton` — "CREATE 3v3"
  - FillBotsToggle `TextButton` — "BOT FILL: OFF"
  - RoomListFrame `Frame`
    - RoomList `ScrollingFrame`
      - RoomTemplate `Frame`
        - RoomName `TextLabel` — "Room"
        - ModeLabel `TextLabel` — "3v3"
        - CountLabel `TextLabel` — "0/6"
        - JoinButton `TextButton` — "JOIN"
  - RoomDetail `Frame`
    - RoomTitle `TextLabel` — "Not in a room"
    - AlphaList `Frame`
      - Header `TextLabel` — "ALPHA"
    - JoinAlpha `TextButton` — "JOIN ALPHA"
    - BravoList `Frame`
      - Header `TextLabel` — "BRAVO"
    - JoinBravo `TextButton` — "JOIN BRAVO"
    - StartButton `TextButton` — "START MATCH"
    - LeaveRoomButton `TextButton` — "LEAVE ROOM"

</details>

## TribeHall

꾸밈 요소 포함 구성: Frame 6, ScrollingFrame 2, TextBox 3, TextButton 5, TextLabel 11, UIAspectRatioConstraint 2, UICorner 13, UIGradient 6, UIListLayout 2, UIPadding 11, UIStroke 9, UITextSizeConstraint 19

<details><summary>요소 트리 펼치기</summary>

- Dim `Frame`
- Modal `Frame`
  - Title `TextLabel` — "TRIBE HALL"
  - CloseButton `TextButton` — "✕"
  - CreateSection `Frame`
    - Header `TextLabel` — "FOUND A TRIBE"
    - NameBox `TextBox`
    - TagBox `TextBox`
    - CreateButton `TextButton` — "CREATE · 299 R$"
    - CreateStatus `TextLabel`
  - MyTribe `Frame`
    - MyTribeName `TextLabel` — "No tribe"
    - MyTribeGlory `TextLabel`
    - Members `ScrollingFrame`
      - MemberTemplate `TextLabel` — "Member"
    - LeaveButton `TextButton` — "LEAVE TRIBE"
  - BrowseSection `Frame`
    - Header `TextLabel` — "JOIN A TRIBE"
    - SearchBox `TextBox`
    - SearchButton `TextButton` — "SEARCH"
    - TribeList `ScrollingFrame`
      - TribeTemplate `Frame`
        - TagLabel `TextLabel` — "[TAG]"
        - NameLabel `TextLabel` — "Tribe"
        - MembersLabel `TextLabel` — "0/20"
        - GloryLabel `TextLabel` — "0 RP"
        - JoinButton `TextButton` — "JOIN"

</details>

## Settings

꾸밈 요소 포함 구성: Frame 12, TextButton 6, TextLabel 8, UIAspectRatioConstraint 4, UICorner 16, UIGradient 5, UIListLayout 1, UIPadding 4, UIStroke 5, UITextSizeConstraint 12

<details><summary>요소 트리 펼치기</summary>

- Dim `Frame`
- Modal `Frame`
  - Title `TextLabel` — "SETTINGS"
  - CloseButton `TextButton` — "✕"
  - Rows `Frame`
    - CameraSensitivity `Frame`
      - Label `TextLabel` — "CAMERA SENSITIVITY"
      - Track `Frame`
        - Fill `Frame`
        - Knob `TextButton`
      - Value `TextLabel` — "0"
    - FieldOfView `Frame`
      - Label `TextLabel` — "FIELD OF VIEW (70~120)"
      - Track `Frame`
        - Fill `Frame`
        - Knob `TextButton`
      - Value `TextLabel` — "0"
    - ViewBobbing `Frame`
      - Label `TextLabel` — "VIEW BOBBING"
      - Toggle `TextButton` — "OFF"
    - PreventFullBotMatches `Frame`
      - Label `TextLabel` — "PREVENT FULL BOT MATCHES"
      - Toggle `TextButton` — "OFF"
    - FirstPersonDefault `Frame`
      - Label `TextLabel` — "START IN FIRST PERSON"
      - Toggle `TextButton` — "OFF"

</details>

## VSScreen

꾸밈 요소 포함 구성: Frame 9, TextLabel 23, UIAspectRatioConstraint 6, UICorner 6, UIGradient 7, UIListLayout 2, UIStroke 13, UITextSizeConstraint 23

<details><summary>요소 트리 펼치기</summary>

- Background `Frame`
  - AlphaColumn `Frame`
    - TeamLabel `TextLabel` — "ALPHA"
    - Card1 `Frame`
      - Name `TextLabel` — "Waiting..."
      - Level `TextLabel`
      - Tag `TextLabel`
    - Card2 `Frame`
      - Name `TextLabel` — "Waiting..."
      - Level `TextLabel`
      - Tag `TextLabel`
    - Card3 `Frame`
      - Name `TextLabel` — "Waiting..."
      - Level `TextLabel`
      - Tag `TextLabel`
  - BravoColumn `Frame`
    - TeamLabel `TextLabel` — "BRAVO"
    - Card1 `Frame`
      - Name `TextLabel` — "Waiting..."
      - Level `TextLabel`
      - Tag `TextLabel`
    - Card2 `Frame`
      - Name `TextLabel` — "Waiting..."
      - Level `TextLabel`
      - Tag `TextLabel`
    - Card3 `Frame`
      - Name `TextLabel` — "Waiting..."
      - Level `TextLabel`
      - Tag `TextLabel`
  - VSLabel `TextLabel` — "VS"
  - MapLabel `TextLabel` — "MAP"
  - ModeLabel `TextLabel` — "3v3 · BEST OF 5"

</details>

## CombatHUD

꾸밈 요소 포함 구성: Frame 59, TextButton 5, TextLabel 52, UIAspectRatioConstraint 20, UICorner 42, UIGradient 14, UIListLayout 8, UIPadding 5, UIStroke 32, UITextSizeConstraint 57

<details><summary>요소 트리 펼치기</summary>

- TopBar `Frame`
  - AlphaScore `Frame`
    - AlphaPips `Frame`
      - Pip1 `Frame`
      - Pip2 `Frame`
      - Pip3 `Frame`
    - Score `TextLabel` — "0"
  - BravoScore `Frame`
    - BravoPips `Frame`
      - Pip1 `Frame`
      - Pip2 `Frame`
      - Pip3 `Frame`
    - Score `TextLabel` — "0"
  - RoundTimer `TextLabel` — "1:00"
  - RoundLabel `TextLabel` — "ROUND 1"
- AlphaAlive `Frame`
  - IconTemplate `Frame`
    - Initial `TextLabel` — "?"
- BravoAlive `Frame`
  - IconTemplate `Frame`
    - Initial `TextLabel` — "?"
- RingWarning `TextLabel`
- Vitals `Frame`
  - HealthBar `Frame`
    - Fill `Frame`
    - HealthText `TextLabel` — "100"
  - ArmorBar `Frame`
    - Fill `Frame`
    - ArmorText `TextLabel` — "0"
  - StatusRow `Frame`
    - StatusTemplate `Frame`
      - Label `TextLabel` — "STATUS"
- Hotbar `Frame`
  - Slot1 `Frame`
    - Cooldown `Frame`
    - Key `TextLabel` — "1"
    - Glyph `TextLabel`
    - ItemName `TextLabel`
    - Count `TextLabel`
    - Level `TextLabel`
  - Slot2 `Frame`
    - Cooldown `Frame`
    - Key `TextLabel` — "2"
    - Glyph `TextLabel`
    - ItemName `TextLabel`
    - Count `TextLabel`
    - Level `TextLabel`
  - Slot3 `Frame`
    - Cooldown `Frame`
    - Key `TextLabel` — "3"
    - Glyph `TextLabel`
    - ItemName `TextLabel`
    - Count `TextLabel`
    - Level `TextLabel`
  - Slot4 `Frame`
    - Cooldown `Frame`
    - Key `TextLabel` — "4"
    - Glyph `TextLabel`
    - ItemName `TextLabel`
    - Count `TextLabel`
    - Level `TextLabel`
  - Slot5 `Frame`
    - Cooldown `Frame`
    - Key `TextLabel` — "5"
    - Glyph `TextLabel`
    - ItemName `TextLabel`
    - Count `TextLabel`
    - Level `TextLabel`
  - Slot6 `Frame`
    - Cooldown `Frame`
    - Key `TextLabel` — "6"
    - Glyph `TextLabel`
    - ItemName `TextLabel`
    - Count `TextLabel`
    - Level `TextLabel`
- ControlHints `Frame`
  - AmmoLabel `TextLabel`
  - HintText `TextLabel`
  - ViewModeLabel `TextLabel` — "[first person V]  [shoulder X]  [slide C]"
- Crosshair `Frame`
  - Dot `Frame`
  - Top `Frame`
  - Bottom `Frame`
  - Left `Frame`
  - Right `Frame`
  - DrawRing `Frame`
  - Hitmarker `Frame`
    - Seg1 `Frame`
    - Seg2 `Frame`
    - Seg3 `Frame`
    - Seg4 `Frame`
- KillFeed `Frame`
  - FeedTemplate `Frame`
    - Text `TextLabel` — "A ⚔ B"
- Banner `Frame`
  - BannerText `TextLabel`
  - BannerSub `TextLabel`
- CountdownText `TextLabel`
- PresetSwitcher `Frame`
  - Title `TextLabel` — "[B] SWITCH PRESET"
  - List `Frame`
    - Preset1 `TextButton` — "1. Preset"
    - Preset2 `TextButton` — "2. Preset"
    - Preset3 `TextButton` — "3. Preset"
    - Preset4 `TextButton` — "4. Preset"
    - Preset5 `TextButton` — "5. Preset"
- KillBanner `Frame`
  - Skull `TextLabel` — "☠"
  - KillText `TextLabel` — "ELIMINATED"
- CastBar `Frame`
  - Bar `Frame`
    - Fill `Frame`
  - Label `TextLabel`
- DamageNumbers `Frame`
  - DamageTemplate `TextLabel` — "0"
- ScopeVignette `Frame`

</details>

## DeathAndSpectate

꾸밈 요소 포함 구성: Frame 2, TextButton 2, TextLabel 6, UIAspectRatioConstraint 2, UICorner 4, UIGradient 4, UIPadding 2, UIStroke 5, UITextSizeConstraint 8

<details><summary>요소 트리 펼치기</summary>

- EliminatedCard `Frame`
  - Header `TextLabel` — "ELIMINATED BY"
  - KillerName `TextLabel`
  - WeaponLabel `TextLabel`
  - KillerHP `TextLabel`
- SpectateBar `Frame`
  - Label `TextLabel` — "SPECTATING"
  - TargetName `TextLabel`
  - PrevButton `TextButton` — "◀"
  - NextButton `TextButton` — "▶"

</details>

## POTGViewfinder

꾸밈 요소 포함 구성: Frame 22, TextButton 1, TextLabel 8, UIAspectRatioConstraint 5, UICorner 4, UIGradient 2, UIPadding 1, UIStroke 2, UITextSizeConstraint 9

<details><summary>요소 트리 펼치기</summary>

- LetterTop `Frame`
- LetterBottom `Frame`
- Overlay `Frame`
  - BracketTL `Frame`
    - Horizontal `Frame`
    - Vertical `Frame`
  - BracketTR `Frame`
    - Horizontal `Frame`
    - Vertical `Frame`
  - BracketBL `Frame`
    - Horizontal `Frame`
    - Vertical `Frame`
  - BracketBR `Frame`
    - Horizontal `Frame`
    - Vertical `Frame`
  - Rec `Frame`
    - RecDot `Frame`
    - RecLabel `TextLabel` — "REC"
  - Timecode `TextLabel` — "00:00:00"
  - TitleTag `TextLabel` — "PLAY OF THE GAME"
  - Caption `Frame`
    - PlayerName `TextLabel`
    - PlayTags `TextLabel`
  - ReplayProgress `Frame`
    - Fill `Frame`
- SkipButton `TextButton` — "SKIP >>"
- Splash `Frame`
  - Stripe `Frame`
  - SplashTitle `TextLabel` — "PLAY OF THE GAME"
  - SplashName `TextLabel`
  - SplashTags `TextLabel`

</details>

## VictoryDropUI

꾸밈 요소 포함 구성: Camera 1, Frame 26, Model 2, Part 52, TextButton 2, TextLabel 27, UIAspectRatioConstraint 5, UICorner 25, UIGradient 14, UIListLayout 1, UIPadding 1, UIStroke 10, UITextSizeConstraint 28, ViewportFrame 1, WorldModel 1

<details><summary>요소 트리 펼치기</summary>

- Dim `Frame`
- Header `TextLabel` — "VICTORY"
- SubHeader `TextLabel` — "Tap the chest to open"
- ChestViewport `ViewportFrame`
  - WorldModel `WorldModel`
    - Chest `Model`
      - Base `Part`
      - Band `Part`
      - CornerPost `Part`
      - CornerPost `Part`
      - Band `Part`
      - CornerPost `Part`
      - CornerPost `Part`
      - Plinth `Part`
      - Glow `Part`
      - Lid `Model`
        - Hinge `Part`
        - Slab `Part`
        - Vault_1 `Part`
        - Vault_2 `Part`
        - Vault_3 `Part`
        - Vault_4 `Part`
        - Vault_5 `Part`
        - Vault_6 `Part`
        - Vault_7 `Part`
        - Vault_8 `Part`
        - Vault_9 `Part`
        - LidBand_1 `Part`
        - LidBand_2 `Part`
        - LidBand_3 `Part`
        - LidBand_4 `Part`
        - LidBand_5 `Part`
        - LidBand_6 `Part`
        - LidBand_7 `Part`
        - LidBand_8 `Part`
        - LidBand_9 `Part`
        - EndCap `Part`
        - EndCap `Part`
        - EndCap `Part`
        - EndCap `Part`
        - EndCap `Part`
        - EndCap `Part`
        - LidBand_1 `Part`
        - LidBand_2 `Part`
        - LidBand_3 `Part`
        - LidBand_4 `Part`
        - LidBand_5 `Part`
        - LidBand_6 `Part`
        - LidBand_7 `Part`
        - LidBand_8 `Part`
        - LidBand_9 `Part`
        - EndCap `Part`
        - EndCap `Part`
        - EndCap `Part`
        - EndCap `Part`
        - EndCap `Part`
        - EndCap `Part`
        - Lock `Part`
        - Keyhole `Part`
  - ViewportCamera `Camera`
  - OpenChestButton `TextButton`
- Cards `Frame`
  - Card1 `Frame`
    - Back `Frame`
      - Mark `TextLabel` — "?"
    - Front `Frame`
      - Glyph `TextLabel`
      - ItemName `TextLabel`
      - Shards `TextLabel` — "+0"
      - ShardBar `Frame`
        - Fill `Frame`
      - ShardProgress `TextLabel` — "0 / 10"
      - UpgradeReady `Frame`
        - Label `TextLabel` — "UPGRADE READY"
  - Card2 `Frame`
    - Back `Frame`
      - Mark `TextLabel` — "?"
    - Front `Frame`
      - Glyph `TextLabel`
      - ItemName `TextLabel`
      - Shards `TextLabel` — "+0"
      - ShardBar `Frame`
        - Fill `Frame`
      - ShardProgress `TextLabel` — "0 / 10"
      - UpgradeReady `Frame`
        - Label `TextLabel` — "UPGRADE READY"
  - Card3 `Frame`
    - Back `Frame`
      - Mark `TextLabel` — "?"
    - Front `Frame`
      - Glyph `TextLabel`
      - ItemName `TextLabel`
      - Shards `TextLabel` — "+0"
      - ShardBar `Frame`
        - Fill `Frame`
      - ShardProgress `TextLabel` — "0 / 10"
      - UpgradeReady `Frame`
        - Label `TextLabel` — "UPGRADE READY"
  - Card4 `Frame`
    - Back `Frame`
      - Mark `TextLabel` — "?"
    - Front `Frame`
      - Glyph `TextLabel`
      - ItemName `TextLabel`
      - Shards `TextLabel` — "+0"
      - ShardBar `Frame`
        - Fill `Frame`
      - ShardProgress `TextLabel` — "0 / 10"
      - UpgradeReady `Frame`
        - Label `TextLabel` — "UPGRADE READY"
- TotalShards `TextLabel` — "TOTAL +0 SHARDS"
- ContinueButton `TextButton` — "CONTINUE"

</details>

## ScoreboardSummaryUI

꾸밈 요소 포함 구성: Frame 16, TextButton 2, TextLabel 52, UIAspectRatioConstraint 1, UICorner 14, UIGradient 6, UIListLayout 2, UIPadding 2, UIStroke 7, UITextSizeConstraint 54

<details><summary>요소 트리 펼치기</summary>

- Dim `Frame`
- Modal `Frame`
  - ResultLabel `TextLabel` — "VICTORY"
  - FinalScore `TextLabel` — "3 - 0"
  - Tables `Frame`
    - Header `Frame`
      - Name `TextLabel` — "NAME"
      - K `TextLabel` — "K"
      - D `TextLabel` — "D"
      - A `TextLabel` — "A"
      - DMG `TextLabel` — "DMG"
      - Glory `TextLabel` — "GLORY"
    - AlphaLabel `TextLabel` — "ALPHA"
    - AlphaRow1 `Frame`
      - Name `TextLabel`
      - K `TextLabel` — "0"
      - D `TextLabel` — "0"
      - A `TextLabel` — "0"
      - DMG `TextLabel` — "0"
      - Glory `TextLabel` — "0"
    - AlphaRow2 `Frame`
      - Name `TextLabel`
      - K `TextLabel` — "0"
      - D `TextLabel` — "0"
      - A `TextLabel` — "0"
      - DMG `TextLabel` — "0"
      - Glory `TextLabel` — "0"
    - AlphaRow3 `Frame`
      - Name `TextLabel`
      - K `TextLabel` — "0"
      - D `TextLabel` — "0"
      - A `TextLabel` — "0"
      - DMG `TextLabel` — "0"
      - Glory `TextLabel` — "0"
    - BravoLabel `TextLabel` — "BRAVO"
    - BravoRow1 `Frame`
      - Name `TextLabel`
      - K `TextLabel` — "0"
      - D `TextLabel` — "0"
      - A `TextLabel` — "0"
      - DMG `TextLabel` — "0"
      - Glory `TextLabel` — "0"
    - BravoRow2 `Frame`
      - Name `TextLabel`
      - K `TextLabel` — "0"
      - D `TextLabel` — "0"
      - A `TextLabel` — "0"
      - DMG `TextLabel` — "0"
      - Glory `TextLabel` — "0"
    - BravoRow3 `Frame`
      - Name `TextLabel`
      - K `TextLabel` — "0"
      - D `TextLabel` — "0"
      - A `TextLabel` — "0"
      - DMG `TextLabel` — "0"
      - Glory `TextLabel` — "0"
  - MVPCard `Frame`
    - MVPTag `TextLabel` — "★ MVP ★"
    - MVPName `TextLabel`
    - MVPStats `TextLabel`
    - MVPWeapon `TextLabel`
  - XPBreakdown `Frame`
    - Lines `Frame`
      - LineTemplate `TextLabel`
    - XPBar `Frame`
      - Fill `Frame`
    - XPLabel `TextLabel` — "LV 1  0 / 250 XP"
  - Buttons `Frame`
    - PlayAgainButton `TextButton` — "PLAY AGAIN (25s)"
    - LobbyButton `TextButton` — "LOBBY"

</details>
