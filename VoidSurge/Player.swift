import SpriteKit

// MARK: - Physics Categories
struct PhysicsCategory {
    static let none:         UInt32 = 0
    static let player:       UInt32 = 0x1 << 0
    static let enemy:        UInt32 = 0x1 << 1
    static let playerBullet: UInt32 = 0x1 << 2
    static let enemyBullet:  UInt32 = 0x1 << 3
    static let xpOrb:        UInt32 = 0x1 << 4
    static let orbitalBlade: UInt32 = 0x1 << 5
}

class Player: SKNode {
    var stats = PlayerStats()
    var currentShieldCharges: Int = 0
    var isInvincible = false
    private var invincibleTimer: TimeInterval = 0
    private let invincibleDuration: TimeInterval = 0.7

    // Visual
    private let body: SKShapeNode
    private let thruster: SKShapeNode
    private var shieldNode: SKShapeNode?
    private var orbitalBlades: [OrbitalBlade] = []
    private var orbitalAngle: CGFloat = 0

    // Auto-shoot
    var shootTimer: TimeInterval = 0

    // Regen
    private var regenAccum: TimeInterval = 0

    override init() {
        // Ship body — triangle pointing up
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 20))
        path.addLine(to: CGPoint(x: -14, y: -14))
        path.addLine(to: CGPoint(x: 14, y: -14))
        path.closeSubpath()

        body = SKShapeNode(path: path)
        body.fillColor = UIColor(red: 1.0, green: 0.78, blue: 0.15, alpha: 1)  // amber hero
        body.strokeColor = UIColor(red: 1.0, green: 0.95, blue: 0.7, alpha: 1)
        body.lineWidth = 1.5
        body.glowWidth = 5

        let thrusterPath = CGMutablePath()
        thrusterPath.move(to: CGPoint(x: -6, y: -14))
        thrusterPath.addLine(to: CGPoint(x: 0, y: -22))
        thrusterPath.addLine(to: CGPoint(x: 6, y: -14))
        thruster = SKShapeNode(path: thrusterPath)
        thruster.fillColor = UIColor.orange
        thruster.strokeColor = .clear
        thruster.alpha = 0.8

        super.init()
        addChild(thruster)
        addChild(body)

        // Thruster flicker
        let flicker = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.4, duration: 0.1),
            SKAction.fadeAlpha(to: 0.9, duration: 0.1)
        ])
        thruster.run(SKAction.repeatForever(flicker))

        // Physics
        let pb = SKPhysicsBody(circleOfRadius: 16)
        pb.categoryBitMask = PhysicsCategory.player
        pb.contactTestBitMask = PhysicsCategory.enemy | PhysicsCategory.enemyBullet
        pb.collisionBitMask = PhysicsCategory.none
        pb.isDynamic         = true
        pb.affectedByGravity = false
        pb.linearDamping     = 0
        pb.angularDamping    = 0
        pb.allowsRotation    = false
        physicsBody = pb

        zPosition = 10
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Update

    func update(deltaTime dt: TimeInterval) {
        // Invincibility cooldown
        if isInvincible {
            invincibleTimer -= dt
            if invincibleTimer <= 0 {
                isInvincible = false
                body.alpha = 1
            } else {
                body.alpha = sin(invincibleTimer * 30).isNaN ? 1 : (sin(CGFloat(invincibleTimer) * 30) > 0 ? 1.0 : 0.3)
            }
        }

        // Life regen
        if stats.lifeRegen > 0 {
            regenAccum += dt
            if regenAccum >= 1.0 {
                regenAccum -= 1.0
                heal(stats.lifeRegen)
            }
        }

        // Orbital blades
        orbitalAngle += CGFloat(dt) * 3.5
        updateOrbitalBlades()
    }

    // MARK: - Damage / Heal

    func takeDamage(_ amount: CGFloat) -> Bool {
        guard !isInvincible else { return false }

        // Shield check
        if currentShieldCharges > 0 {
            currentShieldCharges -= 1
            updateShieldVisual()
            flashHit(color: .cyan)
            return false
        }

        let reduced = amount * (1 - stats.armorReduction)
        stats.currentHP -= reduced
        stats.currentHP = max(0, stats.currentHP)

        isInvincible = true
        invincibleTimer = invincibleDuration
        flashHit(color: .red)
        return true
    }

    func heal(_ amount: CGFloat) {
        stats.currentHP = min(stats.maxHP, stats.currentHP + amount)
    }

    private func flashHit(color: UIColor) {
        let flash = SKAction.sequence([
            SKAction.colorize(with: color, colorBlendFactor: 1, duration: 0.05),
            SKAction.colorize(withColorBlendFactor: 0, duration: 0.15)
        ])
        body.run(flash)
    }

    // MARK: - Upgrades

    func applyUpgrade(_ type: UpgradeType) {
        stats.applyUpgrade(type)

        switch type {
        case .shield:
            currentShieldCharges = stats.shieldCharges
            updateShieldVisual()
        case .orbitalBlades:
            rebuildOrbitalBlades()
        default:
            break
        }
    }

    // MARK: - Shield Visual

    private func updateShieldVisual() {
        shieldNode?.removeFromParent()
        shieldNode = nil
        guard currentShieldCharges > 0 else { return }

        let shield = SKShapeNode(circleOfRadius: 26)
        shield.fillColor = UIColor(red: 0.3, green: 0.6, blue: 1, alpha: 0.15)
        shield.strokeColor = UIColor(red: 0.4, green: 0.7, blue: 1, alpha: 0.9)
        shield.lineWidth = 2
        shield.glowWidth = 6
        addChild(shield)
        shieldNode = shield

        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.08, duration: 0.6),
            SKAction.scale(to: 1.0, duration: 0.6)
        ])
        shield.run(SKAction.repeatForever(pulse))
    }

    // MARK: - Orbital Blades

    private func rebuildOrbitalBlades() {
        orbitalBlades.forEach { $0.removeFromParent() }
        orbitalBlades.removeAll()
        for i in 0..<stats.orbitalBladeCount {
            let blade = OrbitalBlade()
            blade.orbitRadius = 50
            blade.angleOffset = CGFloat(i) * (CGFloat.pi * 2 / CGFloat(stats.orbitalBladeCount))
            addChild(blade)
            orbitalBlades.append(blade)
        }
    }

    private func updateOrbitalBlades() {
        for blade in orbitalBlades {
            let angle = orbitalAngle + blade.angleOffset
            blade.position = CGPoint(x: cos(angle) * blade.orbitRadius,
                                     y: sin(angle) * blade.orbitRadius)
            blade.zRotation = angle + .pi / 2
        }
    }
}

// MARK: - Orbital Blade Node

class OrbitalBlade: SKShapeNode {
    var orbitRadius: CGFloat = 50
    var angleOffset: CGFloat = 0
    let damage: CGFloat = 8

    override init() {
        super.init()
        let path = CGMutablePath()
        path.addRect(CGRect(x: -12, y: -3, width: 24, height: 6))
        self.path = path
        fillColor = .cyan
        strokeColor = UIColor.white.withAlphaComponent(0.6)
        lineWidth = 1
        glowWidth = 3

        let body = SKPhysicsBody(rectangleOf: CGSize(width: 24, height: 6))
        body.categoryBitMask = PhysicsCategory.orbitalBlade
        body.contactTestBitMask = PhysicsCategory.enemy
        body.collisionBitMask = PhysicsCategory.none
        body.isDynamic         = true
        body.affectedByGravity = false
        body.linearDamping     = 0
        body.angularDamping    = 0
        body.allowsRotation    = false
        physicsBody = body
        zPosition = 9
    }

    required init?(coder: NSCoder) { fatalError() }
}
