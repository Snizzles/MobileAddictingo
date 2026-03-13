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
    var bulletSize: CGFloat

    private let visual: SKShapeNode
    private var velocity: CGVector
    private var lifetime: TimeInterval = 3.0

    weak var targetEnemy: SKNode?

    init(stats: PlayerStats, direction: CGVector) {
        damage = stats.damage
        pierceRemaining = stats.pierce
        homingStrength = stats.homingStrength
        hasExplosion = stats.explosionLevel > 0
        explosionRadius = stats.explosionRadius
        freezeChance = stats.freezeChance
        chainTargets = stats.chainTargets
        bulletSize = stats.bulletSize
        velocity = CGVector(dx: direction.dx * stats.bulletSpeed,
                            dy: direction.dy * stats.bulletSpeed)

        visual = SKShapeNode(circleOfRadius: stats.bulletSize)
        visual.fillColor = UIColor(red: 1, green: 0.95, blue: 0.4, alpha: 1)
        visual.strokeColor = UIColor.white.withAlphaComponent(0.8)
        visual.lineWidth = 1
        visual.glowWidth = stats.bulletSize * 0.8

        super.init()
        addChild(visual)

        // Trail
        let trail = SKShapeNode(circleOfRadius: stats.bulletSize * 0.6)
        trail.fillColor = UIColor(red: 1, green: 0.7, blue: 0.2, alpha: 0.5)
        trail.strokeColor = .clear
        trail.position = CGPoint(x: -direction.dx * stats.bulletSize * 2,
                                 y: -direction.dy * stats.bulletSize * 2)
        addChild(trail)

        // Physics
        let pb = SKPhysicsBody(circleOfRadius: stats.bulletSize)
        pb.categoryBitMask = PhysicsCategory.playerBullet
        pb.contactTestBitMask = PhysicsCategory.enemy
        pb.collisionBitMask = PhysicsCategory.none
        pb.isDynamic = false
        physicsBody = pb
        zPosition = 7
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(deltaTime dt: TimeInterval, enemies: [Enemy]) {
        lifetime -= dt
        if lifetime <= 0 {
            removeFromParent()
            return
        }

        // Homing
        if homingStrength > 0 {
            // Find nearest enemy if no target or target removed
            if targetEnemy == nil || targetEnemy?.parent == nil {
                targetEnemy = closestEnemy(from: enemies)
            }
            if let target = targetEnemy as? Enemy, target.parent != nil {
                let dx = target.position.x - position.x
                let dy = target.position.y - position.y
                let len = hypot(dx, dy)
                if len > 0 {
                    let desired = CGVector(dx: dx / len, dy: dy / len)
                    let speed = hypot(velocity.dx, velocity.dy)
                    velocity.dx += (desired.dx * speed - velocity.dx) * homingStrength * CGFloat(dt) * 6
                    velocity.dy += (desired.dy * speed - velocity.dy) * homingStrength * CGFloat(dt) * 6
                    // Re-normalize to maintain speed
                    let newLen = hypot(velocity.dx, velocity.dy)
                    if newLen > 0 {
                        velocity.dx = velocity.dx / newLen * speed
                        velocity.dy = velocity.dy / newLen * speed
                    }
                }
            }
        }

        position.x += velocity.dx * CGFloat(dt)
        position.y += velocity.dy * CGFloat(dt)
    }

    private func closestEnemy(from enemies: [Enemy]) -> Enemy? {
        var best: Enemy?
        var bestDist: CGFloat = .infinity
        for e in enemies {
            guard e.parent != nil else { continue }
            let d = hypot(e.position.x - position.x, e.position.y - position.y)
            if d < bestDist {
                bestDist = d
                best = e
            }
        }
        return best
    }

    func spawnExplosion(in scene: SKScene, at pos: CGPoint) {
        guard hasExplosion else { return }

        let ring = SKShapeNode(circleOfRadius: 4)
        ring.fillColor = UIColor(red: 1, green: 0.5, blue: 0, alpha: 0.7)
        ring.strokeColor = UIColor.orange
        ring.lineWidth = 2
        ring.position = pos
        ring.zPosition = 8
        scene.addChild(ring)

        ring.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: explosionRadius / 4, duration: 0.25),
                SKAction.fadeOut(withDuration: 0.25)
            ]),
            SKAction.removeFromParent()
        ]))

        // Sparks
        for _ in 0..<6 {
            let spark = SKShapeNode(circleOfRadius: 2.5)
            spark.fillColor = .orange
            spark.strokeColor = .clear
            spark.position = pos
            scene.addChild(spark)
            let angle = CGFloat.random(in: 0..<CGFloat.pi * 2)
            let d = CGFloat.random(in: 15...50)
            spark.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: cos(angle)*d, y: sin(angle)*d, duration: 0.3),
                    SKAction.fadeOut(withDuration: 0.3)
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }
}

// MARK: - Enemy Bullet

class EnemyBullet: SKNode {
    let damage: CGFloat
    private let visual: SKShapeNode
    private let velocity: CGVector
    private var lifetime: TimeInterval = 4.0

    init(from origin: CGPoint, toward target: CGPoint, damage: CGFloat = 8, speed: CGFloat = 220) {
        self.damage = damage
        let dx = target.x - origin.x
        let dy = target.y - origin.y
        let len = hypot(dx, dy)
        velocity = len > 0
            ? CGVector(dx: dx / len * speed, dy: dy / len * speed)
            : CGVector(dx: speed, dy: 0)

        visual = SKShapeNode(circleOfRadius: 5)
        visual.fillColor = UIColor(red: 1, green: 0.3, blue: 0.3, alpha: 1)
        visual.strokeColor = UIColor.white.withAlphaComponent(0.5)
        visual.lineWidth = 1
        visual.glowWidth = 3

        super.init()
        addChild(visual)

        let pb = SKPhysicsBody(circleOfRadius: 5)
        pb.categoryBitMask = PhysicsCategory.enemyBullet
        pb.contactTestBitMask = PhysicsCategory.player
        pb.collisionBitMask = PhysicsCategory.none
        pb.isDynamic = false
        physicsBody = pb
        zPosition = 6
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(deltaTime dt: TimeInterval) {
        lifetime -= dt
        if lifetime <= 0 { removeFromParent(); return }
        position.x += velocity.dx * CGFloat(dt)
        position.y += velocity.dy * CGFloat(dt)
    }
}
