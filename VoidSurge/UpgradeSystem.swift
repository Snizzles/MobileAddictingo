import SpriteKit

// MARK: - Upgrade Types

enum UpgradeType: String, CaseIterable {
    // Weapon
    case damage, fireRate, multishot, pierce, bulletSpeed, bulletSize
    // Special
    case explosion, homing, chainLightning, orbitalBlades, freeze
    // Passive
    case maxHP, lifeRegen, shield, moveSpeed, xpMagnet, lifeSteal, armor
}

struct UpgradeDefinition {
    let type: UpgradeType
    let name: String
    let icon: String
    let maxLevel: Int
    let color: UIColor

    func description(atLevel level: Int) -> String {
        switch type {
        case .damage:       return "+30% bullet damage"
        case .fireRate:     return "+25% attack speed"
        case .multishot:    return "Fire \(level + 1) bullets at once"
        case .pierce:       return "Bullets pierce \(level) enemy(s)"
        case .bulletSpeed:  return "+20% bullet velocity"
        case .bulletSize:   return "+40% bullet size"
        case .explosion:    return "Explode on hit (r=\(20 + 15 * level))"
        case .homing:       return level == 1 ? "Slight bullet homing" : "Strong bullet homing"
        case .chainLightning: return "Chain to \(level + 1) enemies"
        case .orbitalBlades:  return "\(level) blade(s) orbit you"
        case .freeze:       return "\(20 * level)% chance to slow"
        case .maxHP:        return "+25% max health"
        case .lifeRegen:    return "+\(level) HP/sec"
        case .shield:       return "Absorb \(level) hit(s)"
        case .moveSpeed:    return "+15% movement speed"
        case .xpMagnet:     return "+60 XP pickup range"
        case .lifeSteal:    return "Heal \(2 * level) HP per kill"
        case .armor:        return "-10% damage taken"
        }
    }
}

let upgradeDefinitions: [UpgradeType: UpgradeDefinition] = [
    .damage:        UpgradeDefinition(type: .damage,        name: "Power Shot",     icon: "⚡", maxLevel: 5, color: .yellow),
    .fireRate:      UpgradeDefinition(type: .fireRate,      name: "Rapid Fire",     icon: "🔫", maxLevel: 5, color: .orange),
    .multishot:     UpgradeDefinition(type: .multishot,     name: "Multishot",      icon: "✦",  maxLevel: 4, color: .cyan),
    .pierce:        UpgradeDefinition(type: .pierce,        name: "Pierce",         icon: "→",  maxLevel: 3, color: .white),
    .bulletSpeed:   UpgradeDefinition(type: .bulletSpeed,   name: "Swift Shot",     icon: "💨", maxLevel: 3, color: .cyan),
    .bulletSize:    UpgradeDefinition(type: .bulletSize,    name: "Big Shot",       icon: "●",  maxLevel: 3, color: .white),
    .explosion:     UpgradeDefinition(type: .explosion,     name: "Explosive",      icon: "💥", maxLevel: 3, color: .orange),
    .homing:        UpgradeDefinition(type: .homing,        name: "Homing",         icon: "🎯", maxLevel: 2, color: .magenta),
    .chainLightning:UpgradeDefinition(type: .chainLightning,name: "Chain",          icon: "⚡", maxLevel: 3, color: .yellow),
    .orbitalBlades: UpgradeDefinition(type: .orbitalBlades, name: "Orbital Blade",  icon: "🔄", maxLevel: 3, color: .cyan),
    .freeze:        UpgradeDefinition(type: .freeze,        name: "Cryo",           icon: "❄",  maxLevel: 3, color: UIColor(red: 0.5, green: 0.8, blue: 1, alpha: 1)),
    .maxHP:         UpgradeDefinition(type: .maxHP,         name: "Vitality",       icon: "❤",  maxLevel: 5, color: .red),
    .lifeRegen:     UpgradeDefinition(type: .lifeRegen,     name: "Regeneration",   icon: "💚", maxLevel: 3, color: .green),
    .shield:        UpgradeDefinition(type: .shield,        name: "Shield",         icon: "🛡",  maxLevel: 3, color: UIColor(red: 0.3, green: 0.6, blue: 1, alpha: 1)),
    .moveSpeed:     UpgradeDefinition(type: .moveSpeed,     name: "Speed",          icon: "⚡", maxLevel: 4, color: .green),
    .xpMagnet:      UpgradeDefinition(type: .xpMagnet,      name: "Magnet",         icon: "🧲", maxLevel: 4, color: .magenta),
    .lifeSteal:     UpgradeDefinition(type: .lifeSteal,     name: "Vampiric",       icon: "🩸", maxLevel: 3, color: .red),
    .armor:         UpgradeDefinition(type: .armor,         name: "Armor",          icon: "🔰", maxLevel: 4, color: UIColor(red: 0.7, green: 0.7, blue: 0.9, alpha: 1)),
]

// MARK: - Player Stats

struct PlayerStats {
    var maxHP: CGFloat = 100
    var currentHP: CGFloat = 100
    var moveSpeed: CGFloat = 210
    var damage: CGFloat = 10
    var fireRate: CGFloat = 2.0         // shots per second
    var bulletSpeed: CGFloat = 420
    var bulletSize: CGFloat = 6
    var upgradeLevels: [UpgradeType: Int] = [:]

    // Derived
    var multishot: Int { (upgradeLevels[.multishot] ?? 0) + 1 }
    var pierce: Int { upgradeLevels[.pierce] ?? 0 }
    var explosionLevel: Int { upgradeLevels[.explosion] ?? 0 }
    var explosionRadius: CGFloat { CGFloat(20 + 15 * explosionLevel) }
    var homingStrength: CGFloat {
        let l = upgradeLevels[.homing] ?? 0
        return l == 0 ? 0 : (l == 1 ? 0.25 : 0.65)
    }
    var chainTargets: Int { upgradeLevels[.chainLightning] ?? 0 }
    var orbitalBladeCount: Int { upgradeLevels[.orbitalBlades] ?? 0 }
    var freezeChance: CGFloat { CGFloat((upgradeLevels[.freeze] ?? 0) * 20) / 100 }
    var lifeRegen: CGFloat { CGFloat(upgradeLevels[.lifeRegen] ?? 0) }
    var shieldCharges: Int { upgradeLevels[.shield] ?? 0 }
    var xpMagnetRange: CGFloat { 120 + CGFloat((upgradeLevels[.xpMagnet] ?? 0) * 60) }
    var lifeStealPerKill: CGFloat { CGFloat((upgradeLevels[.lifeSteal] ?? 0) * 2) }
    var armorReduction: CGFloat { CGFloat((upgradeLevels[.armor] ?? 0) * 10) / 100 }

    mutating func applyUpgrade(_ type: UpgradeType) {
        let cur = upgradeLevels[type] ?? 0
        upgradeLevels[type] = cur + 1
        switch type {
        case .damage:       damage *= 1.30
        case .fireRate:     fireRate *= 1.25
        case .maxHP:
            let inc = maxHP * 0.25
            maxHP += inc
            currentHP = min(currentHP + inc, maxHP)
        case .moveSpeed:    moveSpeed *= 1.15
        case .bulletSpeed:  bulletSpeed *= 1.20
        case .bulletSize:   bulletSize *= 1.40
        default: break
        }
    }
}

// MARK: - Upgrade Selection Helpers

func randomUpgrades(from stats: PlayerStats, count: Int = 3) -> [UpgradeType] {
    let available = UpgradeType.allCases.filter { type in
        let current = stats.upgradeLevels[type] ?? 0
        let maxLevel = upgradeDefinitions[type]?.maxLevel ?? 1
        return current < maxLevel
    }
    var pool = available.shuffled()
    let picks = min(count, pool.count)
    return Array(pool.prefix(picks))
}

// MARK: - Upgrade Card Node

class UpgradeCard: SKNode {
    private let type: UpgradeType
    private let level: Int
    var onTap: (() -> Void)?

    init(type: UpgradeType, currentLevel: Int, size: CGSize) {
        self.type = type
        self.level = currentLevel + 1
        super.init()

        guard let def = upgradeDefinitions[type] else { return }

        let bg = SKShapeNode(rectOf: size, cornerRadius: 12)
        bg.fillColor = UIColor(white: 0.05, alpha: 0.95)
        bg.strokeColor = def.color.withAlphaComponent(0.8)
        bg.lineWidth = 2
        addChild(bg)

        // Glow
        let glow = SKShapeNode(rectOf: size, cornerRadius: 12)
        glow.fillColor = def.color.withAlphaComponent(0.06)
        glow.strokeColor = .clear
        addChild(glow)

        // Icon
        let icon = SKLabelNode(text: def.icon)
        icon.fontSize = 38
        icon.verticalAlignmentMode = .center
        icon.position = CGPoint(x: 0, y: size.height * 0.25)
        addChild(icon)

        // Level dots
        let maxLevel = def.maxLevel
        let dotSpacing: CGFloat = 14
        let dotStart = -CGFloat(maxLevel - 1) * dotSpacing / 2
        for i in 0..<maxLevel {
            let dot = SKShapeNode(circleOfRadius: 4)
            dot.fillColor = i < level ? def.color : UIColor(white: 0.3, alpha: 1)
            dot.strokeColor = .clear
            dot.position = CGPoint(x: dotStart + CGFloat(i) * dotSpacing, y: size.height * 0.12)
            addChild(dot)
        }

        // Name
        let nameLabel = SKLabelNode(text: def.name)
        nameLabel.fontName = "AvenirNext-Bold"
        nameLabel.fontSize = 16
        nameLabel.fontColor = def.color
        nameLabel.verticalAlignmentMode = .center
        nameLabel.position = CGPoint(x: 0, y: -size.height * 0.05)
        addChild(nameLabel)

        // Description
        let desc = SKLabelNode(text: def.description(atLevel: level))
        desc.fontName = "AvenirNext-Regular"
        desc.fontSize = 12
        desc.fontColor = UIColor(white: 0.85, alpha: 1)
        desc.verticalAlignmentMode = .center
        desc.position = CGPoint(x: 0, y: -size.height * 0.22)
        addChild(desc)

        // Level label
        let lvlLabel = SKLabelNode(text: "LVL \(level)/\(maxLevel)")
        lvlLabel.fontName = "AvenirNext-Medium"
        lvlLabel.fontSize = 10
        lvlLabel.fontColor = UIColor(white: 0.5, alpha: 1)
        lvlLabel.verticalAlignmentMode = .center
        lvlLabel.position = CGPoint(x: 0, y: -size.height * 0.36)
        addChild(lvlLabel)

        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }
}
