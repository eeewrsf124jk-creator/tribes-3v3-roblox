<!-- 자동 생성 문서: tools/gendocs.luau 가 만듭니다. 직접 고치지 말고 다시 생성하세요. -->

# 장비 레퍼런스 (전체 34종)

`src/ReplicatedStorage/Modules/Config/EquipmentDatabase.luau`의 모든 항목과 모든 필드입니다.

## 로드아웃 규칙

| 항목 | 값 |
|---|---|
| 최대 포인트 | 12 |
| 최대 슬롯 (방어구 제외) | 6 |
| 방어구 | 1개 (전용 슬롯) |
| 저장 프리셋 수 | 5 |
| 백스탭 즉사 대미지 | 250 |

## 탄약 묶음

| 종류 | 1묶음 발수 | 묶음당 포인트 | 최대 묶음 | 최대 발수 |
|---|---|---|---|---|
| Arrows | 12 | 1 | 3 | 36 |
| FireArrows | 6 | 2 | 2 | 12 |
| Bullets | 6 | 1 | 2 | 12 |

## 랭크 전용 근접 무기 해금 조건 (Glory RP)

| 아이템 | 필요 Glory |
|---|---|
| Gauntlets | 300 |
| Katana | 1000 |
| Scythe | 1600 |
| TwinHatchets | 600 |

## WEAPONS 요약

| Id | 이름 | SubType | Cost | BaseDmg | HeadMult | AmmoType | MaxStack | UnlockShards | RobuxCost |
|---|---|---|---|---|---|---|---|---|---|
| WoodBow | Wood Bow | BOW | 3 | 40 | 1.75 | Arrows |  | 10 | 399 |
| Crossbow | Crossbow | BOW | 4 | 50 | 1.75 | Arrows |  | 20 | 599 |
| Headhunter | Headhunter | BOW | 5 | 62 | 2 | Arrows |  | 30 | 799 |
| Flintlock | Flintlock | GUN | 3 | 45 | 1.6 | Bullets |  | 10 | 399 |
| Blunderbuss | Blunderbuss | GUN | 4 |  | 1.25 | Bullets |  | 20 | 599 |
| Musket | Musket | GUN | 4 | 58 | 1.7 | Bullets |  | 30 | 799 |
| Sling | Sling | THROWABLE | 1 | 28 | 1.5 | Infinite(12) | 12 |  |  |
| ThrowingKnives | Throwing Knives | THROWABLE | 1 | 30 | 1.8 |  | 5 |  |  |
| Javelins | Javelins | THROWABLE | 2 | 55 | 1.5 |  | 3 |  |  |
| Chakram | Chakram | THROWABLE | 2 | 45 | 1.3 |  |  |  |  |
| Bolas | Bolas | THROWABLE | 2 | 15 | 1 |  | 2 |  |  |
| Harpoon | Harpoon | THROWABLE | 3 | 35 | 1.2 |  |  |  |  |
| DiamondDagger | Diamond Dagger | MELEE | 2 | 25 | 1 |  |  |  |  |
| IronSword | Iron Sword | MELEE | 3 | 34 | 1 |  |  |  |  |
| Hammer | Hammer | MELEE | 3 | 42 | 1.45 |  |  |  |  |
| BattleAxe | Battle Axe | MELEE | 3 | 46 | 1 |  |  |  |  |
| Spear | Spear | MELEE | 3 | 32 | 1 |  |  |  |  |
| Shield | Shield | SHIELD | 3 |  |  |  |  |  |  |
| Katana | Katana | MELEE | 3 | 36 | 1 |  |  |  |  |
| Scythe | Reaper Scythe | MELEE | 4 | 44 | 1 |  |  |  |  |
| Gauntlets | Steel Gauntlets | MELEE | 2 | 18 | 1 |  |  |  |  |
| TwinHatchets | Twin Hatchets | MELEE | 3 | 22 | 1 |  |  |  |  |

## UTILITY 요약

| Id | 이름 | Cost | MaxStack | Cooldown | Duration | Radius | Damage |
|---|---|---|---|---|---|---|---|
| SmokeBomb | Smoke Bomb | 1 | 2 |  | 8 | 16 |  |
| SnapTrap | Snap Trap | 1 | 2 |  |  |  | 35 |
| Palisade | Palisade | 1 | 1 |  | 25 |  |  |
| WarHorn | War Horn | 2 |  | 20 |  |  |  |
| Fireball | Fireball | 3 | 1 |  |  | 10 |  |

## HEALING 요약

| Id | 이름 | Cost | MaxStack | HealAmount | CastTime | Duration | SplashRadius |
|---|---|---|---|---|---|---|---|
| Bandage | Bandage | 1 | 3 | 35 | 2.2 |  |  |
| Apple | Apple | 2 | 2 | 50 | 1.2 |  |  |
| HealingFlask | Healing Flask | 2 | 1 | 60 |  |  | 8 |
| GoldenApple | Golden Apple | 3 | 1 | 100 |  | 3 |  |

## ARMOR 요약

| Id | 이름 | Cost | ArmorHP | RangedDmgReduction | MeleeDmgReduction | SpeedPenalty | KnockbackResist |
|---|---|---|---|---|---|---|---|
| LeatherArmor | Leather Armor | 2 | 25 | 0.15 |  | 0 |  |
| IronArmor | Iron Armor | 4 | 50 | 0.3 |  | 0.06 |  |
| DiamondArmor | Diamond Armor | 6 | 100 | 0.4 | 0.15 | 0.12 | 0.5 |

## 항목별 전체 필드

### Wood Bow (WoodBow)

> Reliable longbow. Hold to draw, release to loose an arrow.

| 필드 | 값 |
|---|---|
| AmmoType | Arrows |
| BaseDmg | 40 |
| Category | WEAPONS |
| Cost | 3 |
| Description | Reliable longbow. Hold to draw, release to loose an arrow. |
| DisplayName | Wood Bow |
| DrawTime | 0.75 |
| GravityScale | 0.35 |
| HeadMult | 1.75 |
| HotbarHint | [LMB hold] Draw   [RMB] Aim   [R] Fire Arrows |
| Id | WoodBow |
| ModelName | WoodBow_Model |
| ProjectileSpeed | 220 |
| RobuxCost | 399 |
| SubType | BOW |
| UnlockShards | 10 |
| ZoomFOVAds | 55 |
| (계산) Lv10 대미지 | 56.9325 |
| (계산) Lv1 헤드샷 | 70 |

### Crossbow (Crossbow)

> Fast, flat bolts. Fires instantly, slow to reload.

| 필드 | 값 |
|---|---|
| AmmoType | Arrows |
| BaseDmg | 50 |
| Category | WEAPONS |
| Cost | 4 |
| Description | Fast, flat bolts. Fires instantly, slow to reload. |
| DisplayName | Crossbow |
| GravityScale | 0.15 |
| HeadMult | 1.75 |
| HotbarHint | [LMB] Fire   [RMB] Aim   Auto-reload 1.8s |
| Id | Crossbow |
| ModelName | Crossbow_Model |
| ProjectileSpeed | 340 |
| ReloadTime | 1.8 |
| RobuxCost | 599 |
| SubType | BOW |
| UnlockShards | 20 |
| ZoomFOVAds | 55 |
| (계산) Lv10 대미지 | 71.1656 |
| (계산) Lv1 헤드샷 | 87.5 |

### Headhunter (Headhunter)

> Heavy compound longbow with a sight pin. Massive headshots, slows you after firing.

| 필드 | 값 |
|---|---|
| AmmoType | Arrows |
| BaseDmg | 62 |
| Category | WEAPONS |
| Cost | 5 |
| Description | Heavy compound longbow with a sight pin. Massive headshots, slows you after firing. |
| DisplayName | Headhunter |
| DrawTime | 1.1 |
| GravityScale | 0.25 |
| HeadMult | 2 |
| HotbarHint | [LMB hold] Draw   [RMB] Zoom   Post-shot slow |
| Id | Headhunter |
| ModelName | Headhunter_Model |
| PostShotSlow | 0.6 |
| ProjectileSpeed | 300 |
| RobuxCost | 799 |
| SubType | BOW |
| UnlockShards | 30 |
| ZoomFOV | 40 |
| ZoomFOVAds | 40 |
| (계산) Lv10 대미지 | 88.2453 |
| (계산) Lv1 헤드샷 | 124 |

### Flintlock (Flintlock)

> Brass-trimmed pistol. One shot, then a 1.6s reload.

| 필드 | 값 |
|---|---|
| AmmoType | Bullets |
| BaseDmg | 45 |
| Category | WEAPONS |
| Cost | 3 |
| Description | Brass-trimmed pistol. One shot, then a 1.6s reload. |
| DisplayName | Flintlock |
| GravityScale | 0.05 |
| HeadMult | 1.6 |
| HotbarHint | [LMB] Fire   [RMB] Aim   Reload 1.6s |
| Id | Flintlock |
| ModelName | Flintlock_Model |
| ProjectileSpeed | 450 |
| ReloadTime | 1.6 |
| RobuxCost | 399 |
| SubType | GUN |
| UnlockShards | 10 |
| ZoomFOVAds | 60 |
| (계산) Lv10 대미지 | 64.049 |
| (계산) Lv1 헤드샷 | 72 |

### Blunderbuss (Blunderbuss)

> Flared scattergun. 8 pellets, brutal up close, falls off past 18 studs.

| 필드 | 값 |
|---|---|
| AmmoType | Bullets |
| Category | WEAPONS |
| Cost | 4 |
| Description | Flared scattergun. 8 pellets, brutal up close, falls off past 18 studs. |
| DisplayName | Blunderbuss |
| FalloffStart | 18 |
| GravityScale | 0.08 |
| HeadMult | 1.25 |
| HotbarHint | [LMB] Fire spread   Reload 2.2s |
| Id | Blunderbuss |
| ModelName | Blunderbuss_Model |
| PelletCount | 8 |
| PelletDmg | 14 |
| ProjectileSpeed | 380 |
| ReloadTime | 2.2 |
| RobuxCost | 599 |
| SpreadAngle | 9 |
| SubType | GUN |
| UnlockShards | 20 |
| ZoomFOVAds | 62 |

### Musket (Musket)

> Long-barrel rifle. Near-hitscan at range, slowest reload.

| 필드 | 값 |
|---|---|
| AmmoType | Bullets |
| BaseDmg | 58 |
| Category | WEAPONS |
| Cost | 4 |
| Description | Long-barrel rifle. Near-hitscan at range, slowest reload. |
| DisplayName | Musket |
| GravityScale | 0.02 |
| HeadMult | 1.7 |
| HotbarHint | [LMB] Fire   [RMB] Aim (FOV 45)   Reload 2.6s |
| Id | Musket |
| ModelName | Musket_Model |
| ProjectileSpeed | 650 |
| ReloadTime | 2.6 |
| RobuxCost | 799 |
| SubType | GUN |
| UnlockShards | 30 |
| ZoomFOVAds | 45 |
| (계산) Lv10 대미지 | 82.5521 |
| (계산) Lv1 헤드샷 | 98.6 |

### Sling (Sling)

> Leather sling. Never runs out of stones.

| 필드 | 값 |
|---|---|
| AmmoType | Infinite(12) |
| BaseDmg | 28 |
| Category | WEAPONS |
| ChargeTime | 0.5 |
| Cost | 1 |
| Description | Leather sling. Never runs out of stones. |
| DisplayName | Sling |
| GravityScale | 0.45 |
| HeadMult | 1.5 |
| HotbarHint | [LMB hold] Spin   Release to sling |
| Id | Sling |
| MaxStack | 12 |
| ModelName | Sling_Model |
| ProjectileSpeed | 180 |
| SubType | THROWABLE |
| (계산) Lv10 대미지 | 39.8527 |
| (계산) Lv1 헤드샷 | 42 |

### Throwing Knives (ThrowingKnives)

> A holster of five silver knives. Quick, accurate, great headshots.

| 필드 | 값 |
|---|---|
| BaseDmg | 30 |
| Category | WEAPONS |
| Cooldown | 0.45 |
| Cost | 1 |
| Description | A holster of five silver knives. Quick, accurate, great headshots. |
| DisplayName | Throwing Knives |
| GravityScale | 0.2 |
| HeadMult | 1.8 |
| HotbarHint | [LMB] Throw knife |
| Id | ThrowingKnives |
| MaxStack | 5 |
| ModelName | ThrowingKnives_Model |
| ProjectileSpeed | 260 |
| SubType | THROWABLE |
| (계산) Lv10 대미지 | 42.6994 |
| (계산) Lv1 헤드샷 | 54 |

### Javelins (Javelins)

> Three iron-tipped javelins. Heavy arc, heavy hit.

| 필드 | 값 |
|---|---|
| BaseDmg | 55 |
| Category | WEAPONS |
| ChargeTime | 0.4 |
| Cooldown | 0.8 |
| Cost | 2 |
| Description | Three iron-tipped javelins. Heavy arc, heavy hit. |
| DisplayName | Javelins |
| GravityScale | 0.5 |
| HeadMult | 1.5 |
| HotbarHint | [LMB hold] Wind up   Release to throw |
| Id | Javelins |
| MaxStack | 3 |
| ModelName | Javelins_Model |
| ProjectileSpeed | 150 |
| SubType | THROWABLE |
| (계산) Lv10 대미지 | 78.2821 |
| (계산) Lv1 헤드샷 | 82.5 |

### Chakram (Chakram)

> Bladed ring that ricochets twice and returns. Catch it to throw again.

| 필드 | 값 |
|---|---|
| BaseDmg | 45 |
| BounceCount | 2 |
| Catchable | true |
| Category | WEAPONS |
| Cost | 2 |
| Description | Bladed ring that ricochets twice and returns. Catch it to throw again. |
| DisplayName | Chakram |
| GravityScale | 0 |
| HeadMult | 1.3 |
| HotbarHint | [LMB] Throw   Bounces x2, returns |
| Id | Chakram |
| ModelName | Chakram_Model |
| ProjectileSpeed | 140 |
| Range | 90 |
| ReturnToSender | true |
| SubType | THROWABLE |
| (계산) Lv10 대미지 | 64.049 |
| (계산) Lv1 헤드샷 | 58.5 |

### Bolas (Bolas)

> Weighted ropes that tangle legs, slowing the target to 25% speed.

| 필드 | 값 |
|---|---|
| BaseDmg | 15 |
| Category | WEAPONS |
| Cooldown | 0.8 |
| Cost | 2 |
| Description | Weighted ropes that tangle legs, slowing the target to 25% speed. |
| DisplayName | Bolas |
| GravityScale | 0.3 |
| HeadMult | 1 |
| HotbarHint | [LMB] Throw   Snares 2.5s |
| Id | Bolas |
| MaxStack | 2 |
| ModelName | Bolas_Model |
| ProjectileSpeed | 160 |
| SnareDuration | 2.5 |
| SnareSpeedMult | 0.25 |
| SubType | THROWABLE |
| (계산) Lv10 대미지 | 21.3497 |
| (계산) Lv1 헤드샷 | 15 |

### Harpoon (Harpoon)

> Barbed harpoon on a rope. Hooks the target and drags them to you.

| 필드 | 값 |
|---|---|
| BaseDmg | 35 |
| Category | WEAPONS |
| Cooldown | 3 |
| Cost | 3 |
| Description | Barbed harpoon on a rope. Hooks the target and drags them to you. |
| DisplayName | Harpoon |
| GravityScale | 0.2 |
| HeadMult | 1.2 |
| HotbarHint | [LMB] Fire harpoon   Pulls target |
| Id | Harpoon |
| ModelName | Harpoon_Model |
| ProjectileSpeed | 200 |
| PullForce | 85 |
| Range | 70 |
| SubType | THROWABLE |
| (계산) Lv10 대미지 | 49.8159 |
| (계산) Lv1 헤드샷 | 42 |

### Diamond Dagger (DiamondDagger)

> Glowing diamond blade. Faster movement; a stab in the back is lethal.

| 필드 | 값 |
|---|---|
| BackstabInstantKill | true |
| BackstabMultiplier | 4 |
| BaseDmg | 25 |
| CanBlock | false |
| Category | WEAPONS |
| Cost | 2 |
| Description | Glowing diamond blade. Faster movement; a stab in the back is lethal. |
| DisplayName | Diamond Dagger |
| HeadMult | 1 |
| HotbarHint | [LMB] Stab   Backstab = instant kill |
| Id | DiamondDagger |
| ModelName | DiamondDagger_Model |
| Range | 6.5 |
| SubType | MELEE |
| SwingRate | 0.35 |
| WalkSpeedBonus | 1.08 |
| (계산) Lv10 대미지 | 35.5828 |
| (계산) Lv1 헤드샷 | 25 |

### Iron Sword (IronSword)

> Straight double-edged sword. Hold RMB to block 80% of frontal melee.

| 필드 | 값 |
|---|---|
| BaseDmg | 34 |
| BlockDamageReduction | 0.8 |
| CanBlock | true |
| Category | WEAPONS |
| Cost | 3 |
| Description | Straight double-edged sword. Hold RMB to block 80% of frontal melee. |
| DisplayName | Iron Sword |
| HeadMult | 1 |
| HotbarHint | [LMB] Slash   [RMB hold] Block |
| Id | IronSword |
| ModelName | IronSword_Model |
| Range | 8.5 |
| SubType | MELEE |
| SwingRate | 0.55 |
| (계산) Lv10 대미지 | 48.3926 |
| (계산) Lv1 헤드샷 | 34 |

### Hammer (Hammer)

> Two-handed hammer. Knocks enemies back and staggers them.

| 필드 | 값 |
|---|---|
| BaseDmg | 42 |
| Category | WEAPONS |
| Cost | 3 |
| Description | Two-handed hammer. Knocks enemies back and staggers them. |
| DisplayName | Hammer |
| HeadMult | 1.45 |
| HotbarHint | [LMB] Smash   Knockback + Stagger |
| Id | Hammer |
| KnockbackImpulse | 65 |
| ModelName | Hammer_Model |
| Range | 9 |
| StaggerDuration | 0.8 |
| SubType | MELEE |
| SwingRate | 0.95 |
| (계산) Lv10 대미지 | 59.7791 |
| (계산) Lv1 헤드샷 | 60.9 |

### Battle Axe (BattleAxe)

> Crescent axe. Hold LMB for an overhead chop that shreds armor.

| 필드 | 값 |
|---|---|
| ArmorShredRatio | 0.5 |
| BaseDmg | 46 |
| Category | WEAPONS |
| ChargeTime | 0.6 |
| Cost | 3 |
| Description | Crescent axe. Hold LMB for an overhead chop that shreds armor. |
| DisplayName | Battle Axe |
| HeadMult | 1 |
| HotbarHint | [LMB] Chop   [LMB hold] Overhead |
| Id | BattleAxe |
| ModelName | BattleAxe_Model |
| OverheadDmg | 58 |
| Range | 8.5 |
| SubType | MELEE |
| SwingRate | 0.85 |
| (계산) Lv10 대미지 | 65.4723 |
| (계산) Lv1 헤드샷 | 46 |

### Spear (Spear)

> Longest melee reach in the game.

| 필드 | 값 |
|---|---|
| BaseDmg | 32 |
| Category | WEAPONS |
| Cost | 3 |
| Description | Longest melee reach in the game. |
| DisplayName | Spear |
| HeadMult | 1 |
| HotbarHint | [LMB] Thrust   12.5 stud reach |
| Id | Spear |
| ModelName | Spear_Model |
| Range | 12.5 |
| SubType | MELEE |
| SwingRate | 0.6 |
| (계산) Lv10 대미지 | 45.546 |
| (계산) Lv1 헤드샷 | 32 |

### Shield (Shield)

> Kite shield. Hold RMB to stop arrows and bullets until it breaks.

| 필드 | 값 |
|---|---|
| BlocksProjectiles | true |
| Category | WEAPONS |
| Cost | 3 |
| Description | Kite shield. Hold RMB to stop arrows and bullets until it breaks. |
| DisplayName | Shield |
| HotbarHint | [RMB hold] Raise shield   120 HP |
| Id | Shield |
| ModelName | Shield_Model |
| ShieldHealth | 120 |
| SubType | SHIELD |

### Katana (Katana)

> Ranked reward. Curved blade with quick draw slashes and a parry block.

| 필드 | 값 |
|---|---|
| BaseDmg | 36 |
| BlockDamageReduction | 0.7 |
| CanBlock | true |
| Category | WEAPONS |
| Cost | 3 |
| Description | Ranked reward. Curved blade with quick draw slashes and a parry block. |
| DisplayName | Katana |
| HeadMult | 1 |
| HotbarHint | [LMB] Slash   [RMB hold] Parry |
| Id | Katana |
| ModelName | Katana_Model |
| Range | 9 |
| RankedOnly | true |
| SubType | MELEE |
| SwingRate | 0.5 |
| (계산) Lv10 대미지 | 51.2392 |
| (계산) Lv1 헤드샷 | 36 |

### Reaper Scythe (Scythe)

> Ranked reward. Wide sweeping arc with long reach.

| 필드 | 값 |
|---|---|
| BaseDmg | 44 |
| Category | WEAPONS |
| Cost | 4 |
| Description | Ranked reward. Wide sweeping arc with long reach. |
| DisplayName | Reaper Scythe |
| HeadMult | 1 |
| HotbarHint | [LMB] Reap   Wide arc |
| Id | Scythe |
| ModelName | Scythe_Model |
| Range | 11 |
| RankedOnly | true |
| SubType | MELEE |
| SwingRate | 0.9 |
| (계산) Lv10 대미지 | 62.6257 |
| (계산) Lv1 헤드샷 | 44 |

### Steel Gauntlets (Gauntlets)

> Ranked reward. Rapid left-right punches with light knockback.

| 필드 | 값 |
|---|---|
| BaseDmg | 18 |
| Category | WEAPONS |
| Cost | 2 |
| Description | Ranked reward. Rapid left-right punches with light knockback. |
| DisplayName | Steel Gauntlets |
| HeadMult | 1 |
| HotbarHint | [LMB] Jab combo |
| Id | Gauntlets |
| KnockbackImpulse | 25 |
| ModelName | Gauntlets_Model |
| Range | 5.5 |
| RankedOnly | true |
| SubType | MELEE |
| SwingRate | 0.25 |
| WalkSpeedBonus | 1.05 |
| (계산) Lv10 대미지 | 25.6196 |
| (계산) Lv1 헤드샷 | 18 |

### Twin Hatchets (TwinHatchets)

> Ranked reward. Paired hand axes that chip armor quickly.

| 필드 | 값 |
|---|---|
| ArmorShredRatio | 0.3 |
| BaseDmg | 22 |
| Category | WEAPONS |
| Cost | 3 |
| Description | Ranked reward. Paired hand axes that chip armor quickly. |
| DisplayName | Twin Hatchets |
| HeadMult | 1 |
| HotbarHint | [LMB] Double chop |
| Id | TwinHatchets |
| ModelName | TwinHatchets_Model |
| Range | 6.5 |
| RankedOnly | true |
| SubType | MELEE |
| SwingRate | 0.32 |
| (계산) Lv10 대미지 | 31.3129 |
| (계산) Lv1 헤드샷 | 22 |

### Smoke Bomb (SmokeBomb)

> Clay bomb that bursts into a 16 stud smoke cloud for 8 seconds.

| 필드 | 값 |
|---|---|
| Category | UTILITY |
| Cost | 1 |
| Description | Clay bomb that bursts into a 16 stud smoke cloud for 8 seconds. |
| DisplayName | Smoke Bomb |
| Duration | 8 |
| GravityScale | 1 |
| HotbarHint | [LMB] Throw smoke |
| Id | SmokeBomb |
| MaxStack | 2 |
| ModelName | SmokeBomb_Model |
| ProjectileSpeed | 90 |
| Radius | 16 |
| SubType | NONE |

### Snap Trap (SnapTrap)

> Steel bear trap. 35 damage and roots the victim for 2.5 seconds.

| 필드 | 값 |
|---|---|
| Category | UTILITY |
| Cost | 1 |
| Damage | 35 |
| Description | Steel bear trap. 35 damage and roots the victim for 2.5 seconds. |
| DisplayName | Snap Trap |
| HotbarHint | [LMB] Place trap (preview) |
| Id | SnapTrap |
| MaxStack | 2 |
| ModelName | SnapTrap_Model |
| RootDuration | 2.5 |
| SubType | NONE |
| TriggerRadius | 3.5 |

### Palisade (Palisade)

> Five sharpened logs burst from the ground: a 180 HP wall for 25 seconds.

| 필드 | 값 |
|---|---|
| Category | UTILITY |
| Cost | 1 |
| Description | Five sharpened logs burst from the ground: a 180 HP wall for 25 seconds. |
| DisplayName | Palisade |
| Duration | 25 |
| HotbarHint | [LMB] Place wall   Faces your view |
| Id | Palisade |
| MaxStack | 1 |
| ModelName | Palisade_Model |
| Size | (8, 6.5, 1.5) |
| SubType | NONE |
| WallHealth | 180 |

### War Horn (WarHorn)

> Reveals all enemies to your team for 5s and speeds allies up by 20%.

| 필드 | 값 |
|---|---|
| Category | UTILITY |
| Cooldown | 20 |
| Cost | 2 |
| Description | Reveals all enemies to your team for 5s and speeds allies up by 20%. |
| DisplayName | War Horn |
| HotbarHint | [LMB] Sound the horn   20s cooldown |
| Id | WarHorn |
| ModelName | WarHorn_Model |
| RevealDuration | 5 |
| SubType | NONE |
| TeamSpeedBoost | 1.2 |

### Fireball (Fireball)

> Hurl a ball of fire: 35 impact damage and a burning patch.

| 필드 | 값 |
|---|---|
| BurnDPS | 8 |
| BurnDuration | 4 |
| Category | UTILITY |
| Cost | 3 |
| Description | Hurl a ball of fire: 35 impact damage and a burning patch. |
| DisplayName | Fireball |
| GravityScale | 0.6 |
| HotbarHint | [LMB] Hurl fireball |
| Id | Fireball |
| ImpactDmg | 35 |
| MaxStack | 1 |
| ModelName | Fireball_Model |
| ProjectileSpeed | 120 |
| Radius | 10 |
| SubType | NONE |

### Bandage (Bandage)

> Wrap up for 35 HP. 2.2s cast, you can walk slowly.

| 필드 | 값 |
|---|---|
| CastTime | 2.2 |
| Category | HEALING |
| Cost | 1 |
| Description | Wrap up for 35 HP. 2.2s cast, you can walk slowly. |
| DisplayName | Bandage |
| HealAmount | 35 |
| HotbarHint | [LMB] Bandage (2.2s)   [Q] Cancel |
| Id | Bandage |
| MaxStack | 3 |
| ModelName | Bandage_Model |
| SubType | NONE |

### Apple (Apple)

> Crunchy. 50 HP in 1.2 seconds.

| 필드 | 값 |
|---|---|
| CastTime | 1.2 |
| Category | HEALING |
| Cost | 2 |
| Description | Crunchy. 50 HP in 1.2 seconds. |
| DisplayName | Apple |
| HealAmount | 50 |
| HotbarHint | [LMB] Eat (1.2s)   [Q] Cancel |
| Id | Apple |
| MaxStack | 2 |
| ModelName | Apple_Model |
| SubType | NONE |

### Healing Flask (HealingFlask)

> Throw to splash 60 HP on every ally within 8 studs.

| 필드 | 값 |
|---|---|
| Category | HEALING |
| Cost | 2 |
| Description | Throw to splash 60 HP on every ally within 8 studs. |
| DisplayName | Healing Flask |
| GravityScale | 1 |
| HealAmount | 60 |
| HotbarHint | [LMB] Throw flask   8 stud splash |
| Id | HealingFlask |
| MaxStack | 1 |
| ModelName | HealingFlask_Model |
| ProjectileSpeed | 80 |
| SplashRadius | 8 |
| SubType | NONE |

### Golden Apple (GoldenApple)

> Instantly eaten. Restores 100 HP over 3 seconds.

| 필드 | 값 |
|---|---|
| Category | HEALING |
| Cost | 3 |
| Description | Instantly eaten. Restores 100 HP over 3 seconds. |
| DisplayName | Golden Apple |
| Duration | 3 |
| HealAmount | 100 |
| HotbarHint | [LMB] Eat   100 HP over 3s |
| Id | GoldenApple |
| MaxStack | 1 |
| ModelName | GoldenApple_Model |
| SubType | NONE |

### Leather Armor (LeatherArmor)

> +25 armor, -15% ranged damage. No speed penalty.

| 필드 | 값 |
|---|---|
| ArmorHP | 25 |
| Category | ARMOR |
| Cost | 2 |
| Description | +25 armor, -15% ranged damage. No speed penalty. |
| DisplayName | Leather Armor |
| HotbarHint |  |
| Id | LeatherArmor |
| ModelName | LeatherArmor_Model |
| RangedDmgReduction | 0.15 |
| SpeedPenalty | 0 |
| SubType | NONE |

### Iron Armor (IronArmor)

> +50 armor, -30% ranged damage, -6% speed.

| 필드 | 값 |
|---|---|
| ArmorHP | 50 |
| Category | ARMOR |
| Cost | 4 |
| Description | +50 armor, -30% ranged damage, -6% speed. |
| DisplayName | Iron Armor |
| HotbarHint |  |
| Id | IronArmor |
| ModelName | IronArmor_Model |
| RangedDmgReduction | 0.3 |
| SpeedPenalty | 0.06 |
| SubType | NONE |

### Diamond Armor (DiamondArmor)

> +100 armor, -40% ranged and -15% melee damage, -12% speed, 50% knockback resist.

| 필드 | 값 |
|---|---|
| ArmorHP | 100 |
| Category | ARMOR |
| Cost | 6 |
| Description | +100 armor, -40% ranged and -15% melee damage, -12% speed, 50% knockback resist. |
| DisplayName | Diamond Armor |
| HotbarHint |  |
| Id | DiamondArmor |
| KnockbackResist | 0.5 |
| MeleeDmgReduction | 0.15 |
| ModelName | DiamondArmor_Model |
| RangedDmgReduction | 0.4 |
| SpeedPenalty | 0.12 |
| SubType | NONE |

## 기본 프리셋 5종

| # | 이름 | 슬롯 | 방어구 | 탄약 (묶음) | 포인트 |
|---|---|---|---|---|---|
| 1 | Skirmisher | ThrowingKnives, IronSword, Bandage, SmokeBomb | LeatherArmor | 화살 0 / 총알 0 / 불화살 0 | 8 |
| 2 | Slinger | Sling, Spear, Apple, SnapTrap | LeatherArmor | 화살 0 / 총알 0 / 불화살 0 | 9 |
| 3 | Bruiser | Hammer, Shield, Bandage, Palisade | IronArmor | 화살 0 / 총알 0 / 불화살 0 | 12 |
| 4 | Assassin | DiamondDagger, Bolas, SmokeBomb, Apple, Bandage | LeatherArmor | 화살 0 / 총알 0 / 불화살 0 | 10 |
| 5 | Support | Chakram, IronSword, HealingFlask, WarHorn, Bandage | LeatherArmor | 화살 0 / 총알 0 / 불화살 0 | 12 |
