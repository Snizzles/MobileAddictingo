import SpriteKit

// MARK: - Enemy Type

enum EnemyType {
    case grunt      // Basic, walks toward player
    case speeder    // Fast, low HP
    case tank       // Slow, high HP
    case shooter    // Keeps distance, fires projectiles
    case splitter   // Splits on death
    case sprinter   // Spawned by splitter — tiny, fast
    case boss       // Wave boss

    var baseHP: CGFloat {
        switch self {
        case .grunt:    return 30
        case .speeder:  return 14
        case .tank:     return 120
        case .shooter:  return 40
        case .splitter: return 55
        case .sprinter: return 8
        case .boss:     return 800
        }
    }
    var baseSpeed: CGFloat {
        switch self {
        case .grunt:    return 90
        case .speeder:  return 200
        case .tank:     return 55
        case .shooter:  return 60
        case .splitter: return 80
        case .sprinter: return 220
        case .boss:     return 70
        }
    }
    var xpValue: Int {
        switch self {
        case .grunt:    return 3
        case .speeder:  return 2
        case .tank:     return 10
        case .shooter:  return 5
        case .splitter: return 7
        case .sprinter: return 1
        case .boss:     return 60
        }
    }
    var contactDamage: CGFloat {
        switch self {
        case .grunt:    return 12
        case .speeder:  return 8
        case .tank:     return 20
        case .shooter:  return 10
        case .splitter: return 14
        case .sprinter: return 6
        case .boss:     return 25
        }
    }
    var bodyRadius: CGFloat {
        switch self {
        case .grunt:    return 16
        case .speeder:  return 10
        case .tank:     return 26
        case .shooter:  return 14
        case .splitter: return 20
        case .sprinter: return 8
        case .boss:     return 52
        }
    }
    var fillColor: UIColor {
        switch self {
        case .grunt:    return UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1)
        case .speeder:  return UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1)
        case .tank:     return UIColor(red: 0.5, green: 0.1, blue: 0.1, alpha: 1)
        case .shooter:  return UIColor(red: 0.7, green: 0.2, blue: 0.9, alpha: 1)
        case .splitter: return UIColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1)
        case .sprinter: return UIColor(red: 1.0, green: 0.7, blue: 0.1, alpha: 1)
        case .boss:     return UIColor(red: 0.9, green: 0.1, blue: 0.6, alpha: 1)
        }
    }
    var isBoss: Bool { self == .boss }
}

// MARK: - Enemy Node

class Enemy: SKNode {
    let type: EnemyType
    var hp: CGFloat
    var maxHP: CGFloat
    let moveSpeed: CGFloat
    var isFrozen = false
    private var frozenTimer: TimeInterval = 0

    // Shooter state
    private var shootTimer: TimeInterval = 0
    private let shootInterval: TimeInterval = 2.5
    private let shootRange: CGFloat = 320

    var onDeath: ((Enemy) -> Void)?
    var onShoot: ((CGPoint, CGPoint) -> Void)?  // from, toward

    private let body: SKShapeNode
    private let hpBarBg: SKShapeNode
    private let hpBarFill: SKShapeNode
    private let hpBarWidth: CGFloat

    init(type: EnemyType, hpMultiplier: CGFloat = 1) {
        self.type = type
        self.maxHP = type.baseHP * hpMultiplier
        self.hp = self.maxHP
        self.moveSpeed = type.baseSpeed

        // Visual
        let r = type.bodyRadius
        hpBarWidth = r * 2.2

        body = Enemy.makeBody(type: type, radius: r)

        // HP bar (only show for tanks, bosses, splitters)
        hpBarBg = SKShapeNode(rectOf: CGSize(width: r * 2.2, height: 4), cornerRadius: 2)
        hpBarBg.fillColor = UIColor(white: 0.2, alpha: 0.9)
        hpBarBg.strokeColor = .clear
        hpBarBg.position = CGPoint(x: 0, y: r + 7)

        hpBarFill = SKShapeNode(rectOf: CGSize(width: r * 2.2, height: 4), cornerRadius: 2)
        hpBarFill.fillColor = UIColor(red: 0.3, green: 1, blue: 0.3, alpha: 1)
        hpBarFill.strokeColor = .clear
        hpBarFill.position = CGPoint(x: 0, y: r + 7)

        super.init()
        addChild(body)

        if type == .tank || type == .boss || type == .splitter {
            addChild(hpBarBg)
            addChild(hpBarFill)
        }

        // Physics
        let pb = SKPhysicsBody(circleOfRadius: r * 0.85)
        pb.categoryBitMask = PhysicsCategory.enemy
        pb.contactTestBitMask = PhysicsCategory.playerBullet | PhysicsCategory.player | PhysicsCategory.orbitalBlade
        pb.collisionBitMask = PhysicsCategory.none
        pb.isDynamic = false
        physicsBody = pb
        zPosition = 5

        // Boss: add pulsing ring
        if type == .boss {
            let ring = SKShapeNode(circleOfRadius: r + 8)
            ring.fillColor = .clear
            ring.strokeColor = type.fillColor.withAlphaComponent(0.5)
            ring.lineWidth = 3
            ring.glowWidth = 5
            addChild(ring)
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.1, duration: 0.5),
                SKAction.scale(to: 1.0, duration: 0.5)
            ])
            ring.run(SKAction.repeatForever(pulse))
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    private static func makeBody(type: EnemyType, radius: CGFloat) -> SKShapeNode {
        let node: SKShapeNode
        switch type {
        case .grunt:
            // Circle
            node = SKShapeNode(circleOfRadius: radius)
        case .speeder:
            // Diamond
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: radius))
            path.addLine(to: CGPoint(x: radius * 0.7, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -radius))
            path.addLine(to: CGPoint(x: -radius * 0.7, y: 0))
            path.closeSubpath()
            node = SKShapeNode(path: path)
        case .tank:
            // Rounded square
            node = SKShapeNode(rectOf: CGSize(width: radius * 1.8, height: radius * 1.8), cornerRadius: 6)
        case .shooter:
            // Pentagon
            let path = CGMutablePath()
            for i in 0..<5 {
                let angle = CGFloat(i) * .pi * 2 / 5 - .pi / 2
                let pt = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
                i == 0 ? path.move(to: pt) : path.addLine(to: pt)
            }
            path.closeSubpath()
            node = SKShapeNode(path: path)
        case .splitter:
            // Hexagon
            let path = CGMutablePath()
            for i in 0..<6 {
                let angle = CGFloat(i) * .pi / 3
                let pt = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
                i == 0 ? path.move(to: pt) : path.addLine(to: pt)
            }
            path.closeSubpath()
            node = SKShapeNode(path: path)
        case .sprinter:
            node = SKShapeNode(circleOfRadius: radius)
        case .boss:
            let path = CGMutablePath()
            for i in 0..<8 {
                let angle = CGFloat(i) * .pi / 4
                let pt = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
                i == 0 ? path.move(to: pt) : path.addLine(to: pt)
            }
            path.closeSubpath()
            node = SKShapeNode(path: path)
        }

        node.fillColor = type.fillColor
        node.strokeColor = UIColor.white.withAlphaComponent(0.4)
        node.lineWidth = 1.5
        if type == .boss { node.glowWidth = 8 }
        return node
    }

    // MARK: - Update

    func update(deltaTime dt: TimeInterval, playerPosition: CGPoint) {
        // Thaw
        if isFrozen {
            frozenTimer -= dt
            if frozenTimer <= 0 {
                isFrozen = false
                body.alpha = 1
            }
        }

        let effectiveSpeed = isFrozen ? moveSpeed * 0.25 : moveSpeed
        let dx = playerPosition.x - position.x
        let dy = playerPosition.y - position.y
        let dist = hypot(dx, dy)

        // Movement
        switch type {
        case .shooter:
            if dist > shootRange * 0.75 {
                move(dx: dx, dy: dy, dist: dist, speed: effectiveSpeed, dt: dt)
            } else if dist < shootRange * 0.5 {
                // Back away
                move(dx: -dx, dy: -dy, dist: dist, speed: effectiveSpeed * 0.6, dt: dt)
            }
            // Shoot timer
            shootTimer -= dt
            if shootTimer <= 0 && dist < shootRange {
                shootTimer = shootInterval
                onShoot?(position, playerPosition)
            }
        case .boss:
            // Boss has wider zigzag
            let t = CACurrentMediaTime()
            let sideOffset = sin(t * 1.5) * 80
            let perp = dist > 0 ? CGPoint(x: -dy / dist * sideOffset, y: dx / dist * sideOffset) : .zero
            let targetX = playerPosition.x + perp.x
            let targetY = playerPosition.y + perp.y
            let tdx = targetX - position.x
            let tdy = targetY - position.y
            let tdist = hypot(tdx, tdy)
            move(dx: tdx, dy: tdy, dist: tdist, speed: effectiveSpeed, dt: dt)

            // Boss shoots every 1.5s
            shootTimer -= dt
            if shootTimer <= 0 {
                shootTimer = 1.5
                onShoot?(position, playerPosition)
            }
        default:
            if dist > 0 {
                move(dx: dx, dy: dy, dist: dist, speed: effectiveSpeed, dt: dt)
            }
        }

        // Slow rotation for visual interest
        body.zRotation += CGFloat(dt) * (type == .tank ? 0.5 : (type == .shooter ? -1.2 : 1.5))
    }

    private func move(dx: CGFloat, dy: CGFloat, dist: CGFloat, speed: CGFloat, dt: TimeInterval) {
        guard dist > 1 else { return }
        position.x += (dx / dist) * speed * CGFloat(dt)
        position.y += (dy / dist) * speed * CGFloat(dt)
    }

    // MARK: - Damage

    func takeDamage(_ amount: CGFloat) -> Bool {
        hp -= amount
        hp = max(0, hp)
        updateHPBar()
        flashHit()
        return hp <= 0
    }

    func freeze(duration: TimeInterval = 2.0) {
        isFrozen = true
        frozenTimer = duration
        body.alpha = 0.6
        // Blue tint
        let tint = SKAction.colorize(with: UIColor(red: 0.5, green: 0.8, blue: 1, alpha: 1), colorBlendFactor: 0.7, duration: 0.1)
        body.run(tint)
    }

    private func updateHPBar() {
        guard maxHP > 0 else { return }
        let ratio = hp / maxHP
        let newWidth = max(1, hpBarWidth * ratio)
        hpBarFill.path = CGPath(roundedRect: CGRect(x: -hpBarWidth / 2, y: -2, width: newWidth, height: 4), cornerWidth: 2, cornerHeight: 2, transform: nil)

        let color = ratio > 0.5
            ? UIColor(red: CGFloat(1 - ratio) * 2, green: 1, blue: 0, alpha: 1)
            : UIColor(red: 1, green: CGFloat(ratio) * 2, blue: 0, alpha: 1)
        hpBarFill.fillColor = color
    }

    private func flashHit() {
        let flash = SKAction.sequence([
            SKAction.colorize(with: .white, colorBlendFactor: 0.9, duration: 0.04),
            SKAction.colorize(withColorBlendFactor: 0, duration: 0.12)
        ])
        body.run(flash)
    }

    // MARK: - Death Explosion

    func spawnDeathParticles(in scene: SKScene) {
        let count = type == .boss ? 30 : (type == .tank ? 16 : 8)
        for _ in 0..<count {
            let spark = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.5...4))
            spark.fillColor = type.fillColor
            spark.strokeColor = .clear
            spark.position = scene.convert(position, from: parent ?? scene)
            scene.addChild(spark)

            let angle = CGFloat.random(in: 0..<CGFloat.pi * 2)
            let dist = CGFloat.random(in: 20...80)
            let move = SKAction.moveBy(x: cos(angle) * dist, y: sin(angle) * dist, duration: 0.4)
            let fade = SKAction.fadeOut(withDuration: 0.4)
            spark.run(SKAction.sequence([SKAction.group([move, fade]), SKAction.removeFromParent()]))
        }
    }
}
