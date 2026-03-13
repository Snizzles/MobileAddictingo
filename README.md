# VOID SURGE

A highly addictive Vampire Survivors-style auto-battler for iPhone. Fight endless waves of enemies, collect XP, level up with powerful upgrades, and survive as long as possible.

## Gameplay

- **Virtual joystick** (left side of screen) to move
- **Auto-attack** — your ship automatically fires at the nearest enemy
- **Kill enemies** to collect XP orbs
- **Level up** → choose 1 of 3 random upgrades
- **Survive** escalating waves including **boss encounters every 2 minutes**

## Progression System (17 Upgrades)

### Weapon Upgrades
| Upgrade | Effect | Max Level |
|---------|--------|-----------|
| Power Shot | +30% bullet damage | 5 |
| Rapid Fire | +25% attack speed | 5 |
| Multishot | Fire up to 5 bullets at once | 4 |
| Pierce | Bullets pass through enemies | 3 |
| Swift Shot | +20% bullet speed | 3 |
| Big Shot | +40% bullet size | 3 |

### Special Upgrades
| Upgrade | Effect | Max Level |
|---------|--------|-----------|
| Explosive | Bullets explode on impact (AoE) | 3 |
| Homing | Bullets seek enemies | 2 |
| Chain | Lightning chains to nearby enemies | 3 |
| Orbital Blade | Spinning blades orbit you | 3 |
| Cryo | Chance to slow enemies | 3 |

### Passive Upgrades
| Upgrade | Effect | Max Level |
|---------|--------|-----------|
| Vitality | +25% max health | 5 |
| Regeneration | HP regen per second | 3 |
| Shield | Absorb hits without damage | 3 |
| Speed | +15% movement speed | 4 |
| Magnet | Larger XP pickup range | 4 |
| Vampiric | Heal on kills | 3 |
| Armor | Reduce incoming damage | 4 |

## Enemy Types

| Enemy | Description | Unlocks At |
|-------|-------------|------------|
| Grunt | Basic circle — walks toward you | Start |
| Speeder | Diamond — fast, low HP | 20s |
| Tank | Square — slow, very high HP | 60s |
| Shooter | Pentagon — stays back and fires | 90s |
| Splitter | Hexagon — splits into 2 sprinters on death | 150s |
| Sprinter | Tiny circle — spawned by Splitter | — |
| Boss | Octagon — spawns every 2 minutes, 3-way spread | 2:00 |

## Difficulty Curve

| Label | Time |
|-------|------|
| ROOKIE | 0:00 |
| HUNTER | 0:30 |
| VETERAN | 1:30 |
| ELITE | 3:00 |
| NIGHTMARE | 5:00 |
| VOID | 8:00+ |

Spawn rate scales from ~1.8s/enemy to ~0.28s/enemy. Enemy HP also scales with time.

## Tech Stack

- **Swift 5** / **SpriteKit**
- iOS 16+ deployment target
- iPhone portrait mode
- No external assets — all graphics are programmatic `SKShapeNode` + `SKShapeNode`
- Physics collision via `SKPhysicsContactDelegate`

## Requirements

- Xcode 15+
- iOS 16+ device or simulator
- iPhone only (portrait)

## Setup

1. Clone the repo
2. Open `VoidSurge.xcodeproj` in Xcode
3. Set your **Team** in Signing & Capabilities
4. Build and run on device or simulator

## Structure

```
VoidSurge/
├── AppDelegate.swift          # App entry point
├── GameViewController.swift   # SKView host
├── VirtualJoystick.swift      # Floating joystick input
├── UpgradeSystem.swift        # All upgrade definitions + PlayerStats
├── Player.swift               # Player node + orbital blades
├── Enemy.swift                # All enemy types + AI
├── Projectile.swift           # Player bullets + enemy bullets
├── XPOrb.swift                # XP pickup with magnet behavior
├── WaveManager.swift          # Time-based difficulty escalation
├── HUD.swift                  # HP bar, XP bar, boss bar, stats
├── GameScene.swift            # Main game loop + collision handling
├── MenuScene.swift            # Title screen
└── GameOverScene.swift        # Death screen with stats
```
