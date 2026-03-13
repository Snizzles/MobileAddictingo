import SpriteKit

// MARK: - Player Bullet

class PlayerBullet: SKNode {
    var damage: CGFloat
    var pierceRemaining: Int
    var homingStrength: CGFloat
    var hasExplosion: Bool
    var explosionRadius: CGFloat
    var freezeChance: CGFloat
    var chainTargets: Int

    private let visual: SKShapeNode
    private var currentVelocity: CGVector      // we own this; physics body reads it
    private var lifetime: TimeInterval = 3.0

    weak var targetEnemy: SKNode?

    init(stats: PlayerStats, direction: CGVector) {
        damage          = stats.damage
        pierceRemaining = stats.pierce
        homingStrength  = stats.homingStrength
        hasExplosion    = stats.explosionLevel > 0
        explosionRadius = stats.explosionRadius
        freezeChance    = stats.freezeChance
        chainTargets    = stats.chainTargets
        currentVelocity = CGVector(dx: direction.dx * stats.bulletSpeed,
                                   dy: direction.dy * stats.bulletSpeed)

        let r = stats.bulletSize
        visual = SKShapeNode(circleOfRadius: r)
        visual.fillColor = UIColor(red: 1.0, green: 0.82, blue: 0.25, alpha: 1)
        visual.strokeColor = UIColor.white.withAlphaComponent(0.7)
        visual.lineWidth = 1
        visual.glowWidth = r * 0.9

        super.init()
        addChild(visual)

        // Trailing dot
        let trail = SKShapeNode(circleOfRadius: r * 0.55)
        trail.fillColor = UIColor(red: 1.0, green: 0.5, blue: 0.1, alpha: 0.5)
        trail.strokeColor = .clear
        trail.position = CGPoint(x: -direction.dx * r * 2.2, y: -direction.dy * r * 2.2)
        addChild(trail)

        // Dynamic body — REQUIRED for contact detection in SpriteKit
        let pb = SKPhysicsBody(circleOfRadius: r)
        pb.categoryBitMask    = PhysicsCategory.playerBullet
        pb.contactTestBitMask = PhysicsCategory.enemy
        pb.collisionBitMask   = PhysicsCategory.none
        pb.isDynamic          = true
        pb.affectedByGravity  = false
        pb.linearDamping      = 0
        pb.angularDamping     = 0
        pb.allowsRotation     = false
        pb.velocity           = currentVelocity   // physics engine drives movement
        physicsBody = pb
        zPosition = 7
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(deltaTime dt: TimeInterval, enemies: [Enemy]) {
        lifetime -= dt
        if lifetime <= 0 { removeFromParent(); return }

        // Homing: steer velocity toward target
        if homingStrength > 0 {
            if targetEnemy == nil || targetEnemy?.parent == nil {
                targetEnemy = closestEnemy(from: enemies)
            }
            if let target = targetEnemy as? Enemy, target.parent != nil {
                let dx = target.position.x - position.x
                let dy = target.position.y - position.y
                let len = hypot(dx, dy)
                if len > 0 {
                    let spd = hypot(currentVelocity.dx, currentVelocity.dy)
                    let desired = CGVector(dx: dx / len * spd, dy: dy / len * spd)
                    currentVelocity.dx += (desired.dx - currentVelocity.dx) * homingStrength * CGFloat(dt) * 6
                    currentVelocity.dy += (desired.dy - currentVelocity.dy) * homingStrength * CGFloat(dt) * 6
                    // Re-normalise speed
                    let newLen = hypot(currentVelocity.dx, currentVelocity.dy)
                    if newLen > 0 {
                        currentVelocity.dx = currentVelocity.dx / newLen * spd
                        currentVelocity.dy = currentVelocity.dy / newLen * spd
                    }
                    physicsBody?.velocity = currentVelocity
                }
            }
        }
        // Non-homing bullets: physics engine maintains velocity automatically
    }

    private func closestEnemy(from enemies: [Enemy]) -> Enemy? {
        enemies.filter { $0.parent != nil }.min {
            hypot($0.position.x - position.x, $0.position.y - position.y) <
            hypot($1.position.x - position.x, $1.position.y - position.y)
        }
    }

    func spawnExplosion(in scene: SKScene, at pos: CGPoint) {
        guard hasExplosion else { return }
        let ring = SKShapeNode(circleOfRadius: 4)
        ring.fillColor = UIColor(red: 1, green: 0.45, blue: 0.05, alpha: 0.8)
        ring.strokeColor = .orange
        ring.lineWidth = 2
        ring.position = pos
        ring.zPosition = 8
        scene.addChild(ring)
        ring.run(SKAction.sequence([
            SKAction.group([SKAction.scale(to: explosionRadius / 4, duration: 0.25),
                            SKAction.fadeOut(withDuration: 0.25)]),
            SKAction.removeFromParent()
        ]))
        for _ in 0..<6 {
            let spark = SKShapeNode(circleOfRadius: 2.5)
            spark.fillColor = UIColor(red: 1, green: 0.6, blue: 0.1, alpha: 1)
            spark.strokeColor = .clear
            spark.position = pos
            scene.addChild(spark)
            let angle = CGFloat.random(in: 0..<CGFloat.pi * 2)
            let d = CGFloat.random(in: 15...50)
            spark.run(SKAction.sequence([
                SKAction.group([SKAction.moveBy(x: cos(angle)*d, y: sin(angle)*d, duration: 0.3),
                                SKAction.fadeOut(withDuration: 0.3)]),
                SKAction.removeFromParent()
            ]))
        }
    }
}

// MARK: - Enemy Bullet

class EnemyBullet: SKNode {
    let damage: CGFloat
    private let visual: SKShapeNode
    private var lifetime: TimeInterval = 4.0

    init(from origin: CGPoint, toward target: CGPoint, damage: CGFloat = 8, speed: CGFloat = 210) {
        self.damage = damage

        let dx = target.x - origin.x
        let dy = target.y - origin.y
        let len = hypot(dx, dy)
        let vel = len > 0
            ? CGVector(dx: dx / len * speed, dy: dy / len * speed)
            : CGVector(dx: speed, dy: 0)

        visual = SKShapeNode(circleOfRadius: 5)
        visual.fillColor = UIColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 1)
        visual.strokeColor = UIColor.white.withAlphaComponent(0.4)
        visual.lineWidth = 1
        visual.glowWidth = 3

        super.init()
        addChild(visual)

        let pb = SKPhysicsBody(circleOfRadius: 5)
        pb.categoryBitMask    = PhysicsCategory.enemyBullet
        pb.contactTestBitMask = PhysicsCategory.player
        pb.collisionBitMask   = PhysicsCategory.none
        pb.isDynamic          = true
        pb.affectedByGravity  = false
        pb.linearDamping      = 0
        pb.angularDamping     = 0
        pb.allowsRotation     = false
        pb.velocity           = vel
        physicsBody = pb
        zPosition = 6
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(deltaTime dt: TimeInterval) {
        lifetime -= dt
        if lifetime <= 0 { removeFromParent() }
        // Physics engine handles position; we only track lifetime
    }
}
