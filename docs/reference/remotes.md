<!-- 자동 생성 문서: tools/gendocs.luau 가 만듭니다. 직접 고치지 말고 다시 생성하세요. -->

# 네트워크 채널 레퍼런스

서버가 `ReplicatedStorage.RemoteNetwork_Events`에 만듭니다. 사용 위치는 `Net.Reliable("이름")` / `Net.Unreliable("이름")`를 부르는 모든 줄입니다.

## Reliable (RemoteEvent, 32개)

### RequestSpawnLoadout

| 역할 | 위치 |
|---|---|
| 서버 수신 | `src/ServerScriptService/Services/RoundStateMachineService.luau:1095` |

### SwitchPresetInPreRound

| 역할 | 위치 |
|---|---|
| 서버 수신 | `src/ServerScriptService/Services/RoundStateMachineService.luau:1094` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/CombatFeedbackAndHUDController.luau:1002` |

### FireProjectile

| 역할 | 위치 |
|---|---|
| 서버 수신 | `src/ServerScriptService/Services/LagCompensatedCombatService.luau:833` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/WeaponAndProjectileController.luau:272` |

### MeleeSwing

| 역할 | 위치 |
|---|---|
| 서버 수신 | `src/ServerScriptService/Services/LagCompensatedCombatService.luau:834` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/WeaponAndProjectileController.luau:330` |

### UseUtility

| 역할 | 위치 |
|---|---|
| 서버 수신 | `src/ServerScriptService/Services/LagCompensatedCombatService.luau:835` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/WeaponAndProjectileController.luau:359` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/WeaponAndProjectileController.luau:379` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/WeaponAndProjectileController.luau:433` |

### StartHeal

| 역할 | 위치 |
|---|---|
| 서버 수신 | `src/ServerScriptService/Services/LagCompensatedCombatService.luau:836` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/WeaponAndProjectileController.luau:420` |

### CancelHeal

| 역할 | 위치 |
|---|---|
| 서버 수신 | `src/ServerScriptService/Services/LagCompensatedCombatService.luau:837` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/WeaponAndProjectileController.luau:553` |

### ToggleBlock

| 역할 | 위치 |
|---|---|
| 서버 수신 | `src/ServerScriptService/Services/LagCompensatedCombatService.luau:838` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/WeaponAndProjectileController.luau:397` |

### RoundStateChanged

| 역할 | 위치 |
|---|---|
| 서버 → 클라이언트 | `src/ServerScriptService/Services/RoundStateMachineService.luau:225` |
| 서버 → 클라이언트 | `src/ServerScriptService/Services/RoundStateMachineService.luau:748` |
| 클라이언트 수신 | `src/StarterPlayerScripts/ClientMain.client.luau:39` |

### BroadcastPOTGData

| 역할 | 위치 |
|---|---|
| 서버 → 클라이언트 | `src/ServerScriptService/Services/RoundStateMachineService.luau:868` |
| 클라이언트 수신 | `src/StarterPlayerScripts/Controllers/POTGAndVictorySequenceController.luau:727` |

### OpenVictoryChest

| 역할 | 위치 |
|---|---|
| 서버 → 클라이언트 | `src/ServerScriptService/Services/EconomyAndMonetizationService.luau:348` |
| 서버 → 클라이언트 | `src/ServerScriptService/Services/EconomyAndMonetizationService.luau:461` |
| 서버 수신 | `src/ServerScriptService/Services/EconomyAndMonetizationService.luau:477` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/POTGAndVictorySequenceController.luau:497` |
| 클라이언트 수신 | `src/StarterPlayerScripts/Controllers/POTGAndVictorySequenceController.luau:745` |

### UpgradeEquipment

| 역할 | 위치 |
|---|---|
| 서버 → 클라이언트 | `src/ServerScriptService/Services/EconomyAndMonetizationService.luau:471` |
| 서버 수신 | `src/ServerScriptService/Services/EconomyAndMonetizationService.luau:478` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:645` |
| 클라이언트 수신 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:1068` |

### PartyAction

| 역할 | 위치 |
|---|---|
| 서버 → 클라이언트 | `src/ServerScriptService/Services/MatchmakingAndBotService.luau:103` |
| 서버 → 클라이언트 | `src/ServerScriptService/Services/MatchmakingAndBotService.luau:159` |
| 서버 수신 | `src/ServerScriptService/Services/MatchmakingAndBotService.luau:700` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:214` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:1022` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:1028` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:1032` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:1037` |
| 클라이언트 수신 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:1040` |

### QueueAction

| 역할 | 위치 |
|---|---|
| 서버 → 클라이언트 | `src/ServerScriptService/Services/MatchmakingAndBotService.luau:263` |
| 서버 수신 | `src/ServerScriptService/Services/MatchmakingAndBotService.luau:701` |
| 서버 수신 | `src/ServerScriptService/Services/RoundStateMachineService.luau:1096` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:997` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:1001` |
| 클라이언트 수신 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:1003` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/POTGAndVictorySequenceController.luau:718` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/POTGAndVictorySequenceController.luau:722` |

### EquipSlot

| 역할 | 위치 |
|---|---|
| 서버 수신 | `src/ServerScriptService/Services/LagCompensatedCombatService.luau:839` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/WeaponAndProjectileController.luau:524` |

### ProjectileReplicate

| 역할 | 위치 |
|---|---|
| 서버 → 전체 | `src/ServerScriptService/Services/Combat/ProjectileSimulator.luau:165` |
| 서버 → 전체 | `src/ServerScriptService/Services/LagCompensatedCombatService.luau:417` |
| 클라이언트 수신 | `src/StarterPlayerScripts/Controllers/ProjectileRenderer.luau:488` |

### ProjectileResolved

| 역할 | 위치 |
|---|---|
| 서버 → 전체 | `src/ServerScriptService/Services/Combat/ProjectileSimulator.luau:174` |
| 클라이언트 수신 | `src/StarterPlayerScripts/Controllers/ProjectileRenderer.luau:489` |

### CombatEvent

| 역할 | 위치 |
|---|---|
| 서버 → 클라이언트 | `src/ServerScriptService/Services/Combat/DamageModel.luau:84` |
| 클라이언트 수신 | `src/StarterPlayerScripts/Controllers/CombatFeedbackAndHUDController.luau:1032` |

### ApplyImpulse

| 역할 | 위치 |
|---|---|
| 서버 → 클라이언트 | `src/ServerScriptService/Services/Combat/DamageModel.luau:127` |
| 클라이언트 수신 | `src/StarterPlayerScripts/Controllers/MovementController.luau:186` |

### ProfileSync

| 역할 | 위치 |
|---|---|
| 서버 → 클라이언트 | `src/ServerScriptService/Services/PlayerDataService.luau:320` |
| 클라이언트 수신 | `src/StarterPlayerScripts/ClientMain.client.luau:27` |

### SaveLoadout

| 역할 | 위치 |
|---|---|
| 서버 → 클라이언트 | `src/ServerScriptService/Services/PlayerDataService.luau:410` |
| 서버 → 클라이언트 | `src/ServerScriptService/Services/PlayerDataService.luau:418` |
| 서버 수신 | `src/ServerScriptService/Services/PlayerDataService.luau:450` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:627` |
| 클라이언트 수신 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:1061` |

### TribeAction

| 역할 | 위치 |
|---|---|
| 서버 → 클라이언트 | `src/ServerScriptService/Services/TribeService.luau:126` |
| 서버 수신 | `src/ServerScriptService/Services/TribeService.luau:419` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:92` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:93` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:805` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:817` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:821` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:827` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:829` |
| 클라이언트 수신 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:832` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:1096` |

### CustomMatchAction

| 역할 | 위치 |
|---|---|
| 서버 → 전체 | `src/ServerScriptService/Services/MatchmakingAndBotService.luau:438` |
| 서버 수신 | `src/ServerScriptService/Services/MatchmakingAndBotService.luau:702` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:90` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:701` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:729` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:743` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:749` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:753` |
| 클라이언트 수신 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:755` |

### UpdateSettings

| 역할 | 위치 |
|---|---|
| 서버 수신 | `src/ServerScriptService/Services/PlayerDataService.luau:451` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:861` |

### PurchaseRequest

| 역할 | 위치 |
|---|---|
| 서버 수신 | `src/ServerScriptService/Services/EconomyAndMonetizationService.luau:476` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:649` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:984` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:988` |

### Notify

| 역할 | 위치 |
|---|---|
| 서버 → 클라이언트 | `src/ServerScriptService/Services/PlayerDataService.luau:333` |
| 클라이언트 수신 | `src/StarterPlayerScripts/ClientMain.client.luau:45` |

### MatchSummary

| 역할 | 위치 |
|---|---|
| 서버 → 클라이언트 | `src/ServerScriptService/Services/RoundStateMachineService.luau:731` |
| 클라이언트 수신 | `src/StarterPlayerScripts/Controllers/POTGAndVictorySequenceController.luau:732` |

### InventorySync

| 역할 | 위치 |
|---|---|
| 서버 → 클라이언트 | `src/ServerScriptService/Services/LagCompensatedCombatService.luau:102` |
| 서버 → 클라이언트 | `src/ServerScriptService/Services/LagCompensatedCombatService.luau:251` |
| 클라이언트 수신 | `src/StarterPlayerScripts/ClientMain.client.luau:34` |

### UtilityEvent

| 역할 | 위치 |
|---|---|
| 서버 → 클라이언트 | `src/ServerScriptService/Services/Combat/UtilityAndHealing.luau:443` |
| 서버 → 클라이언트 | `src/ServerScriptService/Services/Combat/UtilityAndHealing.luau:445` |
| 클라이언트 수신 | `src/StarterPlayerScripts/Controllers/CombatFeedbackAndHUDController.luau:1033` |

### OpenInterface

| 역할 | 위치 |
|---|---|
| 서버 → 클라이언트 | `src/ServerScriptService/Services/LobbyService.luau:71` |
| 클라이언트 수신 | `src/StarterPlayerScripts/Controllers/LobbyUIController.luau:1051` |

### CatchChakram

| 역할 | 위치 |
|---|---|
| 서버 수신 | `src/ServerScriptService/Services/LagCompensatedCombatService.luau:841` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/WeaponAndProjectileController.luau:557` |

### SlideRequest

| 역할 | 위치 |
|---|---|
| 서버 수신 | `src/ServerScriptService/Services/LagCompensatedCombatService.luau:840` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/MovementController.luau:57` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/MovementController.luau:88` |

## Unreliable (UnreliableRemoteEvent, 2개)

### ReplicateCharacterState

| 역할 | 위치 |
|---|---|
| 서버 수신 | `src/ServerScriptService/Services/LagCompensatedCombatService.luau:842` |
| 서버 → 전체 | `src/ServerScriptService/Services/LagCompensatedCombatService.luau:895` |
| 클라이언트 수신 | `src/StarterPlayerScripts/Controllers/CharacterPoses.luau:295` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/WeaponAndProjectileController.luau:882` |

### ReplicateBowDrawRatio

| 역할 | 위치 |
|---|---|
| 서버 수신 | `src/ServerScriptService/Services/LagCompensatedCombatService.luau:843` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/WeaponAndProjectileController.luau:389` |
| 클라이언트 → 서버 | `src/StarterPlayerScripts/Controllers/WeaponAndProjectileController.luau:843` |

