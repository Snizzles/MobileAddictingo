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

// MARK: - Player (Humanoid Warrior)

class Player: SKNode {
    var stats = PlayerStats()
    var currentShieldCharges: Int = 0
    var isInvincible = false
    var isMoving: Bool = false

    private var invincibleTimer: TimeInterval = 0
    private let invincibleDuration: TimeInterval = 0.7
    private var walkPhase: CGFloat = 0
    private var regenAccum: TimeInterval = 0

    // Humanoid parts
    private let cloakNode:     SKShapeNode
    private let leftLeg:       SKShapeNode
    private let rightLeg:      SKShapeNode
    private let torso:         SKShapeNode
    private let leftArm:       SKShapeNode
    private let weaponPivot:   SKNode          // rotates toward target
    private let weaponBlade:   SKShapeNode
    private let head:          SKShapeNode
    private let eyeL:          SKShapeNode
    private let eyeR:          SKShapeNode
    private var shieldNode:    SKShapeNode?
    private var orbitalBlades: [OrbitalBlade] = []
    private var orbitalAngle:  CGFloat = 0

    var shootTimer: TimeInterval = 0

    // Palette
    private static let amber   = UIColor(red: 1.00, green: 0.78, blue: 0.14, alpha: 1)
    private static let leather = UIColor(red: 0.44, green: 0.30, blue: 0.12, alpha: 1)
    private static let dark    = UIColor(red: 0.12, green: 0.08, blue: 0.03, alpha: 1)
    private static let steel   = UIColor(red: 0.88, green: 0.94, blue: 1.00, alpha: 1)
    private static let outline = UIColor(red: 1.00, green: 0.88, blue: 0.50, alpha: 0.55)

    override init() {
        // Cloak behind body
        let cp = CGMutablePath()
        cp.move(to: CGPoint(x: 0, y: 5))
        cp.addLine(to: CGPoint(x: -11, y: -19))
        cp.addLine(to: CGPoint(x: 11, y: -19))
        cp.closeSubpath()
        cloakNode = SKShapeNode(path: cp)
        cloakNode.fillColor = Player.dark
        cloakNode.strokeColor = .clear

        // Legs
        leftLeg  = Player.makeLimb(size: CGSize(width: 6, height: 10))
        leftLeg.position  = CGPoint(x: -4, y: -16)
        rightLeg = Player.makeLimb(size: CGSize(width: 6, height: 10))
        rightLeg.position = CGPoint(x:  4, y: -16)

        // Torso
        torso = SKShapeNode(rectOf: CGSize(width: 14, height: 15), cornerRadius: 3)
        torso.fillColor   = Player.leather
        torso.strokeColor = Player.outline
        torso.lineWidth   = 1.5
        torso.position    = CGPoint(x: 0, y: -3)

        // Left arm (shield side)
        leftArm = Player.makeLimb(size: CGSize(width: 5, height: 9))
        leftArm.position  = CGPoint(x: -10, y: -2)
        leftArm.zRotation = -0.25

        // Weapon pivot + blade
        weaponPivot = SKNode()
        weaponPivot.position = CGPoint(x: 0, y: -2)

        weaponBlade = SKShapeNode(rectOf: CGSize(width: 20, height: 4), cornerRadius: 2)
        weaponBlade.fillColor   = Player.steel
        weaponBlade.strokeColor = UIColor(red: 0.55, green: 0.82, blue: 1.0, alpha: 0.9)
        weaponBlade.lineWidth   = 1
        weaponBlade.glowWidth   = 5
        weaponBlade.position    = CGPoint(x: 13, y: 0)  // tip extends right of pivot

        // Head
        head = SKShapeNode(circleOfRadius: 7)
        head.fillColor   = Player.amber
        head.strokeColor = Player.outline
        head.lineWidth   = 1.5
        head.glowWidth   = 4
        head.position    = CGPoint(x: 0, y: 11)

        // Eyes (give life to the hero)
        eyeL = SKShapeNode(circleOfRadius: 1.5)
        eyeL.fillColor   = Player.dark
        eyeL.strokeColor = .clear
        eyeL.position    = CGPoint(x: -2.5, y: 12)

        eyeR = SKShapeNode(circleOfRadius: 1.5)
        eyeR.fillColor   = Player.dark
        eyeR.strokeColor = .clear
        eyeR.position    = CGPoint(x: 2.5, y: 12)

        super.init()

        // Layer order: back → front
        addChild(cloakNode)
        addChild(leftLeg); addChild(rightLeg)
        addChild(torso);   addChild(leftArm)
        weaponPivot.addChild(weaponBlade)
        addChild(weaponPivot)
        addChild(head); addChild(eyeL); addChild(eyeR)

        // Physics
        let pb = SKPhysicsBody(circleOfRadius: 16)
        pb.categoryBitMask    = PhysicsCategory.player
        pb.contactTestBitMask = PhysicsCategory.enemy | PhysicsCategory.enemyBullet
        pb.collisionBitMask   = PhysicsCategory.none
        pb.isDynamic          = true
        pb.affectedByGravity  = false
        pb.linearDamping      = 0
        pb.angularDamping     = 0
        pb.allowsRotation     = false
        physicsBody = pb
        zPosition   = 10
    }

    required init?(coder: NSCoder) { fatalError() }

    private static func makeLimb(size: CGSize) -> SKShapeNode {
        let n = SKShapeNode(rectOf: size, cornerRadius: 2)
        n.fillColor   = leather
        n.strokeColor = outline
        n.lineWidth   = 1
        return n
    }

    // MARK: - Aim weapon toward world position

    func aimWeapon(toward worldPos: CGPoint) {
        let dx = worldPos.x - position.x
        let dy = worldPos.y - position.y
        guard hypot(dx, dy) > 10 else { return }
        weaponPivot.zRotation = atan2(dy, dx)
        // Mirror eyes toward enemy
        let facingRight = dx >= 0
        eyeL.position.x = facingRight ? -2.5 :  2.5
        eyeR.position.x = facingRight ?  2.5 : -2.5
    }

    // MARK: - Update

    func update(deltaTime dt: TimeInterval) {
        // Invincibility flicker
        if isInvincible {
            invincibleTimer -= dt
            if invincibleTimer <= 0 {
                isInvincible = false
                alpha = 1.0
            } else {
                alpha = sin(CGFloat(invincibleTimer) * 28) > 0 ? 1.0 : 0.25
            }
        }

        // Walk cycle
        if isMoving {
            walkPhase += CGFloat(dt) * 14
            leftLeg.position.y  = -16 + sin(walkPhase) * 3.5
            rightLeg.position.y = -16 - sin(walkPhase) * 3.5
            leftLeg.zRotation   =  sin(walkPhase) * 0.18
            rightLeg.zRotation  = -sin(walkPhase) * 0.18
        } else {
            leftLeg.position.y  = -16
            rightLeg.position.y = -16
            leftLeg.zRotation   = 0
            rightLeg.zRotation  = 0
        }

        // Life regen
        if stats.lifeRegen > 0 {
            regenAccum += dt
            if regenAccum >= 1.0 {
                regenAccum -= 1.0
                heal(stats.lifeRegen)
            }
        }

        // Orbital blades — position manually, then zero velocity so dynamic body
        // doesn't accumulate physics-engine drift between frames
        orbitalAngle += CGFloat(dt) * 3.5
        for blade in orbitalBlades {
            let angle = orbitalAngle + blade.angleOffset
            blade.position = CGPoint(x: cos(angle) * blade.orbitRadius,
                                     y: sin(angle) * blade.orbitRadius)
            blade.zRotation = angle + .pi / 2
            blade.physicsBody?.velocity = .zero
            blade.physicsBody?.angularVelocity = 0
        }
    }

    // MARK: - Damage / Heal

    /// Returns true if damage was actually applied (for screen shake etc.)
    @discardableResult
    func takeDamage(_ amount: CGFloat) -> Bool {
        guard !isInvincible else { return false }

        if currentShieldCharges > 0 {
            currentShieldCharges -= 1
            updateShieldVisual()
            flashParts(color: .cyan)
            return false
        }

        let reduced = amount * (1 - stats.armorReduction)
        stats.currentHP = max(0, stats.currentHP - reduced)
        isInvincible    = true
        invincibleTimer = invincibleDuration
        flashParts(color: .red)
        return true
    }

    func heal(_ amount: CGFloat) {
        stats.currentHP = min(stats.maxHP, stats.currentHP + amount)
    }

    private func flashParts(color: UIColor) {
        let flash = SKAction.sequence([
            SKAction.colorize(with: color, colorBlendFactor: 1, duration: 0.05),
            SKAction.colorize(withColorBlendFactor: 0, duration: 0.15)
        ])
        [head, torso, leftArm, weaponBlade].forEach { $0.run(flash) }
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

    // MARK: - Shield visual

    private func updateShieldVisual() {
        shieldNode?.removeFromParent()
        shieldNode = nil
        guard currentShieldCharges > 0 else { return }
        let s = SKShapeNode(circleOfRadius: 26)
        s.fillColor   = UIColor(red: 0.3, green: 0.6, blue: 1, alpha: 0.15)
        s.strokeColor = UIColor(red: 0.4, green: 0.7, blue: 1, alpha: 0.9)
        s.lineWidth   = 2
        s.glowWidth   = 6
        addChild(s)
        shieldNode = s
        s.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.08, duration: 0.6),
            SKAction.scale(to: 1.00, duration: 0.6)
        ])))
    }

    // MARK: - Orbital blades

    private func rebuildOrbitalBlades() {
        orbitalBlades.forEach { $0.removeFromParent() }
        orbitalBlades.removeAll()
        let count = stats.orbitalBladeCount
        for i in 0..<count {
            let blade = OrbitalBlade()
            blade.orbitRadius = 52
            blade.angleOffset = CGFloat(i) * (.pi * 2 / CGFloat(count))
            addChild(blade)
            orbitalBlades.append(blade)
        }
    }
}

// MARK: - Orbital Blade Node

class OrbitalBlade: SKShapeNode {
    var orbitRadius: CGFloat = 52
    var angleOffset: CGFloat = 0
    let damage: CGFloat = 8

    override init() {
        super.init()
        let path = CGMutablePath()
        path.addRect(CGRect(x: -12, y: -3, width: 24, height: 6))
        self.path     = path
        fillColor     = UIColor(red: 0.90, green: 0.95, blue: 1.00, alpha: 1)
        strokeColor   = UIColor(red: 0.55, green: 0.82, blue: 1.00, alpha: 0.7)
        lineWidth     = 1
        glowWidth     = 4

        let body = SKPhysicsBody(rectangleOf: CGSize(width: 24, height: 6))
        body.categoryBitMask    = PhysicsCategory.orbitalBlade
        body.contactTestBitMask = PhysicsCategory.enemy
        body.collisionBitMask   = PhysicsCategory.none
        body.isDynamic          = true
        body.affectedByGravity  = false
        body.linearDamping      = 0
        body.angularDamping     = 0
        body.allowsRotation     = false
        physicsBody = body
        zPosition   = 9
    }

    required init?(coder: NSCoder) { fatalError() }
}
