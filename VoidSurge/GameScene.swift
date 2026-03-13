import SpriteKit
import UIKit

// MARK: - Game State

enum GameState {
    case playing, levelingUp, dead
}

// MARK: - Game Stats

struct GameStats {
    var kills: Int = 0
    var timeAlive: TimeInterval = 0
    var level: Int = 1
    var xp: Int = 0
    var xpToNext: Int = 10
    var collectedUpgrades: [UpgradeType] = []

    mutating func addXP(_ amount: Int) -> Bool {
        xp += amount
        if xp >= xpToNext {
            xp -= xpToNext
            level += 1
            xpToNext = xpForNextLevel(level)
            return true
        }
        return false
    }

    private func xpForNextLevel(_ level: Int) -> Int {
        return Int(Double(10) * pow(1.32, Double(level - 1)))
    }
}

// MARK: - GameScene

class GameScene: SKScene, SKPhysicsContactDelegate {

    // Nodes
    private let player = Player()
    private var enemies: [Enemy] = []
    private var playerBullets: [PlayerBullet] = []
    private var enemyBullets: [EnemyBullet] = []
    private var xpOrbs: [XPOrb] = []
    private var activeBoss: Enemy?

    // Systems
    private let joystick = VirtualJoystick()
    private var hud: HUD!
    private let waveManager = WaveManager()

    // State
    private var gameState: GameState = .playing
    private var gameStats = GameStats()
    private var lastUpdateTime: TimeInterval = 0

    // Camera for shake
    private let cam = SKCameraNode()

    // Upgrade overlay
    private var upgradeOverlay: SKNode?
    private var pendingUpgrades: [UpgradeType] = []

    // Background stars
    private var bgStars: [SKShapeNode] = []

    // Joystick touch tracking
    private var joystickTouch: UITouch?

    // Enemy contact cooldown (per enemy)
    private var enemyContactCooldowns: [ObjectIdentifier: TimeInterval] = [:]
    private let contactCooldownDuration: TimeInterval = 0.8

    // Boss contact
    private var bossContactCooldown: TimeInterval = 0

    // MARK: - Setup

    override func didMove(to view: SKView) {
        setupPhysics()
        setupBackground()
        setupCamera()
        setupPlayer()
        setupHUD()
        setupJoystick()
        setupWaveManager()
    }

    private func setupPhysics() {
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        backgroundColor = UIColor(red: 0.08, green: 0.06, blue: 0.05, alpha: 1)
    }

    private func setupBackground() {
        // Dungeon stone floor — dark brown base
        backgroundColor = UIColor(red: 0.08, green: 0.06, blue: 0.05, alpha: 1)

        // Stone brick grid
        let brickW: CGFloat = 52
        let brickH: CGFloat = 28
        var row = 0
        var yy: CGFloat = 0
        while yy < size.height + brickH {
            var xx: CGFloat = row % 2 == 0 ? 0 : -brickW / 2
            while xx < size.width + brickW {
                let brick = SKShapeNode(rectOf: CGSize(width: brickW - 2, height: brickH - 2), cornerRadius: 1)
                brick.fillColor = UIColor(
                    red: CGFloat.random(in: 0.10...0.14),
                    green: CGFloat.random(in: 0.08...0.11),
                    blue: CGFloat.random(in: 0.06...0.09),
                    alpha: 1)
                brick.strokeColor = UIColor(white: 0, alpha: 0.4)
                brick.lineWidth = 1
                brick.position = CGPoint(x: xx + brickW / 2, y: yy + brickH / 2)
                brick.zPosition = 0
                addChild(brick)
                xx += brickW
            }
            yy += brickH
            row += 1
        }

        // Scattered dust particles
        let dustSpawn = SKAction.run { [weak self] in
            guard let self = self else { return }
            let mote = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.8...2.2))
            mote.fillColor = UIColor(red: 0.7, green: 0.55, blue: 0.3, alpha: CGFloat.random(in: 0.2...0.5))
            mote.strokeColor = .clear
            mote.position = CGPoint(x: CGFloat.random(in: 0..<self.size.width),
                                    y: CGFloat.random(in: 0..<self.size.height))
            mote.zPosition = 1
            self.addChild(mote)
            mote.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: CGFloat.random(in: -15...15), y: CGFloat.random(in: 5...25), duration: 3),
                    SKAction.sequence([SKAction.fadeIn(withDuration: 0.5), SKAction.fadeOut(withDuration: 2.5)])
                ]),
                SKAction.removeFromParent()
            ]))
        }
        run(SKAction.repeatForever(SKAction.sequence([dustSpawn, SKAction.wait(forDuration: 0.18)])))

        // Torch flicker spots at corners/edges
        let torchPositions: [CGPoint] = [
            CGPoint(x: 0, y: 0), CGPoint(x: size.width, y: 0),
            CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height),
            CGPoint(x: size.width / 2, y: 0), CGPoint(x: size.width / 2, y: size.height)
        ]
        for pos in torchPositions {
            let glow = SKShapeNode(circleOfRadius: 45)
            glow.fillColor = UIColor(red: 1.0, green: 0.45, blue: 0.05, alpha: 0.06)
            glow.strokeColor = .clear
            glow.position = pos
            glow.zPosition = 1
            addChild(glow)
            let flicker = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.03, duration: CGFloat.random(in: 0.3...0.7)),
                SKAction.fadeAlpha(to: 0.09, duration: CGFloat.random(in: 0.3...0.7))
            ])
            glow.run(SKAction.repeatForever(flicker))
        }
    }

    private func setupCamera() {
        cam.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(cam)
        self.camera = cam
    }

    private func setupPlayer() {
        player.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(player)
    }

    private func setupHUD() {
        // HUD is a child of camera so it stays fixed on screen
        hud = HUD(size: size)
        cam.addChild(hud)
    }

    private func setupJoystick() {
        // Joystick is also camera-space
        cam.addChild(joystick)
    }

    private func setupWaveManager() {
        waveManager.onSpawnEnemy = { [weak self] instruction in
            self?.spawnEnemy(type: instruction.type, hpMult: instruction.hpMultiplier)
        }
        waveManager.onBossWave = { [weak self] in
            self?.spawnBoss()
        }
    }

    // MARK: - Main Update

    override func update(_ currentTime: TimeInterval) {
        guard gameState == .playing else { return }

        let dt: TimeInterval
        if lastUpdateTime == 0 {
            dt = 0
        } else {
            dt = min(currentTime - lastUpdateTime, 0.1)
        }
        lastUpdateTime = currentTime
        gameStats.timeAlive += dt

        updatePlayer(dt: dt)
        updateEnemies(dt: dt)
        updateBullets(dt: dt)
        updateXPOrbs(dt: dt)
        updateContactCooldowns(dt: dt)
        waveManager.update(deltaTime: dt)
        updateHUD()
    }

    // MARK: - Player

    private func updatePlayer(dt: TimeInterval) {
        // Move
        if joystick.isActive {
            let spd = player.stats.moveSpeed * joystick.magnitude
            let newX = player.position.x + joystick.direction.dx * spd * CGFloat(dt)
            let newY = player.position.y + joystick.direction.dy * spd * CGFloat(dt)
            let margin: CGFloat = 25
            player.position.x = newX.clamped(to: margin...(size.width - margin))
            player.position.y = newY.clamped(to: margin...(size.height - margin))
        }
        // Zero out physics drift from manual repositioning
        player.physicsBody?.velocity = .zero

        player.isMoving = joystick.isActive
        player.update(deltaTime: dt)

        // Aim weapon at nearest enemy
        if let target = nearestEnemy(to: player.position) {
            player.aimWeapon(toward: target.position)
        }

        // Auto-shoot
        player.shootTimer -= dt
        if player.shootTimer <= 0 {
            player.shootTimer = 1.0 / player.stats.fireRate
            firePlayerBullets()
        }
    }

    private func firePlayerBullets() {
        guard let target = nearestEnemy(to: player.position) else { return }
        SoundManager.shared.play(.shoot)

        let dx = target.position.x - player.position.x
        let dy = target.position.y - player.position.y
        let len = hypot(dx, dy)
        guard len > 0 else { return }

        let baseDir = CGVector(dx: dx / len, dy: dy / len)
        let count = player.stats.multishot

        for i in 0..<count {
            let spread: CGFloat
            if count == 1 { spread = 0 }
            else {
                let totalSpread = min(CGFloat(count - 1) * 0.18, 0.6)
                spread = -totalSpread / 2 + totalSpread * CGFloat(i) / CGFloat(count - 1)
            }

            let cos_s = cos(spread)
            let sin_s = sin(spread)
            let rotDir = CGVector(
                dx: baseDir.dx * cos_s - baseDir.dy * sin_s,
                dy: baseDir.dx * sin_s + baseDir.dy * cos_s
            )

            let bullet = PlayerBullet(stats: player.stats, direction: rotDir)
            bullet.position = player.position
            if player.stats.homingStrength > 0 { bullet.targetEnemy = target }
            addChild(bullet)
            playerBullets.append(bullet)
        }
    }

    private func nearestEnemy(to pos: CGPoint) -> Enemy? {
        var best: Enemy?
        var bestDist: CGFloat = .infinity
        for e in enemies {
            guard e.parent != nil else { continue }
            let d = hypot(e.position.x - pos.x, e.position.y - pos.y)
            if d < bestDist { bestDist = d; best = e }
        }
        return best
    }

    // MARK: - Enemies

    private func spawnEnemy(type: EnemyType, hpMult: CGFloat) {
        let e = Enemy(type: type, hpMultiplier: hpMult)
        e.position = randomEdgePosition()
        e.onDeath = { [weak self] dying in self?.handleEnemyDeath(dying) }
        e.onShoot = { [weak self] from, toward in self?.spawnEnemyBullet(from: from, toward: toward) }
        addChild(e)
        enemies.append(e)
    }

    private func spawnBoss() {
        let boss = Enemy(type: .boss, hpMultiplier: 1 + CGFloat(waveManager.bossCount) * 0.4)
        boss.position = randomEdgePosition()
        boss.onDeath = { [weak self] dying in
            self?.activeBoss = nil
            self?.hud.hideBossBar()
            self?.handleEnemyDeath(dying)
            self?.shakeCamera(intensity: 15, duration: 0.5)
        }
        boss.onShoot = { [weak self] from, toward in
            // Boss fires spread
            for i in -1...1 {
                let spread = CGFloat(i) * 0.3
                let dx = toward.x - from.x
                let dy = toward.y - from.y
                let len = hypot(dx, dy)
                if len > 0 {
                    let dir = CGVector(dx: dx/len, dy: dy/len)
                    let rotated = CGVector(
                        dx: dir.dx * cos(spread) - dir.dy * sin(spread),
                        dy: dir.dx * sin(spread) + dir.dy * cos(spread)
                    )
                    let adjusted = CGPoint(
                        x: from.x + rotated.dx * 5,
                        y: from.y + rotated.dy * 5
                    )
                    self?.spawnEnemyBullet(from: adjusted, toward: CGPoint(x: from.x + rotated.dx * 300, y: from.y + rotated.dy * 300), damage: 15)
                }
            }
        }
        addChild(boss)
        enemies.append(boss)
        activeBoss = boss
        hud.showBossBar(name: "DEMON LORD LVL \(waveManager.bossCount + 1)")

        // Boss entry flash
        let flash = SKSpriteNode(color: UIColor(red: 0.9, green: 0.1, blue: 0.6, alpha: 0.3), size: size)
        flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        flash.zPosition = 20
        addChild(flash)
        flash.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.5), SKAction.removeFromParent()]))

        SoundManager.shared.play(.bossSpawn)
        shakeCamera(intensity: 8, duration: 0.3)
    }

    private func updateEnemies(dt: TimeInterval) {
        for e in enemies {
            guard e.parent != nil else { continue }
            e.update(deltaTime: dt, playerPosition: player.position)

            // Remove if way off screen
            let margin: CGFloat = 200
            if e.position.x < -margin || e.position.x > size.width + margin ||
               e.position.y < -margin || e.position.y > size.height + margin {
                e.removeFromParent()
            }
        }
        // Update boss bar
        if let boss = activeBoss, boss.parent != nil {
            hud.updateBossHP(ratio: boss.hp / boss.maxHP)
        }
        enemies.removeAll { $0.parent == nil }
    }

    private func handleEnemyDeath(_ e: Enemy) {
        gameStats.kills += 1

        // Life steal
        if player.stats.lifeStealPerKill > 0 {
            player.heal(player.stats.lifeStealPerKill)
        }

        // XP drop
        let xpValue = e.type.xpValue
        let orbCount = e.type == .boss ? 8 : (e.type == .tank ? 3 : 1)
        for i in 0..<orbCount {
            let orb = XPOrb(xpValue: i == 0 ? xpValue : max(1, xpValue / orbCount))
            orb.position = e.position + CGPoint(x: CGFloat.random(in: -20...20),
                                                y: CGFloat.random(in: -20...20))
            addChild(orb)
            xpOrbs.append(orb)
        }

        // Splitter spawns sprinters
        if e.type == .splitter {
            for _ in 0..<2 {
                let sprinter = Enemy(type: .sprinter, hpMultiplier: waveManager.hpMultiplier)
                sprinter.position = e.position + CGPoint(x: CGFloat.random(in: -25...25),
                                                          y: CGFloat.random(in: -25...25))
                sprinter.onDeath = { [weak self] dying in self?.handleEnemyDeath(dying) }
                addChild(sprinter)
                enemies.append(sprinter)
            }
        }

        // Death particles
        e.spawnDeathParticles(in: self)

        // Damage number
        spawnDamageNumber(text: "+\(xpValue)XP", at: e.position, color: UIColor(red: 0.3, green: 1, blue: 0.5, alpha: 1))
    }

    // MARK: - Bullets

    private func updateBullets(dt: TimeInterval) {
        let screenRect = CGRect(x: -50, y: -50, width: size.width + 100, height: size.height + 100)

        // Player bullets
        for b in playerBullets {
            guard b.parent != nil else { continue }
            b.update(deltaTime: dt, enemies: enemies)
            if !screenRect.contains(b.position) {
                b.removeFromParent()
            }
        }
        playerBullets.removeAll { $0.parent == nil }

        // Enemy bullets
        for b in enemyBullets {
            guard b.parent != nil else { continue }
            b.update(deltaTime: dt)
            if !screenRect.contains(b.position) {
                b.removeFromParent()
            }
        }
        enemyBullets.removeAll { $0.parent == nil }
    }

    private func spawnEnemyBullet(from: CGPoint, toward: CGPoint, damage: CGFloat = 8) {
        let b = EnemyBullet(from: from, toward: toward, damage: damage)
        b.position = from
        addChild(b)
        enemyBullets.append(b)
    }

    // MARK: - XP Orbs

    private func updateXPOrbs(dt: TimeInterval) {
        let collectRadius: CGFloat = 22
        for orb in xpOrbs {
            guard !orb.isCollected && orb.parent != nil else { continue }
            orb.update(deltaTime: dt, playerPosition: player.position,
                       magnetRange: player.stats.xpMagnetRange)

            let dist = hypot(orb.position.x - player.position.x, orb.position.y - player.position.y)
            if dist < collectRadius {
                orb.collect()
                SoundManager.shared.play(.xpCollect)
                let leveledUp = gameStats.addXP(orb.xpValue)
                if leveledUp { triggerLevelUp() }
            }
        }
        xpOrbs.removeAll { $0.isCollected || $0.parent == nil }
    }

    // MARK: - Contacts

    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA
        let b = contact.bodyB

        // Player bullet hit enemy
        if (a.categoryBitMask == PhysicsCategory.playerBullet && b.categoryBitMask == PhysicsCategory.enemy) ||
           (a.categoryBitMask == PhysicsCategory.enemy && b.categoryBitMask == PhysicsCategory.playerBullet) {
            let bulletNode = a.categoryBitMask == PhysicsCategory.playerBullet ? a.node : b.node
            let enemyNode  = a.categoryBitMask == PhysicsCategory.enemy ? a.node : b.node
            if let bullet = bulletNode as? PlayerBullet, let enemy = enemyNode as? Enemy {
                handleBulletHitEnemy(bullet: bullet, enemy: enemy)
            }
        }

        // Enemy touches player
        if (a.categoryBitMask == PhysicsCategory.enemy && b.categoryBitMask == PhysicsCategory.player) ||
           (a.categoryBitMask == PhysicsCategory.player && b.categoryBitMask == PhysicsCategory.enemy) {
            let enemyNode = a.categoryBitMask == PhysicsCategory.enemy ? a.node : b.node
            if let enemy = enemyNode as? Enemy {
                handleEnemyTouchPlayer(enemy: enemy)
            }
        }

        // Enemy bullet hits player
        if (a.categoryBitMask == PhysicsCategory.enemyBullet && b.categoryBitMask == PhysicsCategory.player) ||
           (a.categoryBitMask == PhysicsCategory.player && b.categoryBitMask == PhysicsCategory.enemyBullet) {
            let bulletNode = a.categoryBitMask == PhysicsCategory.enemyBullet ? a.node : b.node
            if let bullet = bulletNode as? EnemyBullet {
                handleEnemyBulletHitPlayer(bullet: bullet)
            }
        }

        // Orbital blade hits enemy
        if (a.categoryBitMask == PhysicsCategory.orbitalBlade && b.categoryBitMask == PhysicsCategory.enemy) ||
           (a.categoryBitMask == PhysicsCategory.enemy && b.categoryBitMask == PhysicsCategory.orbitalBlade) {
            let bladeNode = a.categoryBitMask == PhysicsCategory.orbitalBlade ? a.node : b.node
            let enemyNode = a.categoryBitMask == PhysicsCategory.enemy ? a.node : b.node
            if let blade = bladeNode as? OrbitalBlade, let enemy = enemyNode as? Enemy {
                handleOrbitalBladeHitEnemy(blade: blade, enemy: enemy)
            }
        }
    }

    private func handleBulletHitEnemy(bullet: PlayerBullet, enemy: Enemy) {
        guard bullet.parent != nil, enemy.parent != nil else { return }

        let killed = enemy.takeDamage(bullet.damage)
        SoundManager.shared.play(killed ? .enemyDie : .enemyHit)

        // Freeze
        if player.stats.freezeChance > 0 && CGFloat.random(in: 0...1) < player.stats.freezeChance {
            enemy.freeze()
        }

        // Damage number
        spawnDamageNumber(text: "\(Int(bullet.damage))", at: enemy.position,
                          color: UIColor(red: 1, green: 0.9, blue: 0.3, alpha: 1))

        // Explosion check
        if bullet.hasExplosion {
            bullet.spawnExplosion(in: self, at: enemy.position)
            // AoE damage to nearby enemies
            for other in enemies where other !== enemy && other.parent != nil {
                let dist = hypot(other.position.x - enemy.position.x,
                                 other.position.y - enemy.position.y)
                if dist < bullet.explosionRadius {
                    let aoeDmg = bullet.damage * 0.6
                    let otherKilled = other.takeDamage(aoeDmg)
                    if otherKilled { killEnemy(other) }
                }
            }
        }

        // Chain lightning
        if bullet.chainTargets > 0 {
            chainLightning(from: enemy.position, damage: bullet.damage * 0.5,
                           targets: bullet.chainTargets, excluding: enemy)
        }

        if killed { killEnemy(enemy) }

        // Pierce
        if bullet.pierceRemaining > 0 {
            bullet.pierceRemaining -= 1
        } else {
            bullet.removeFromParent()
        }
    }

    private func handleEnemyTouchPlayer(enemy: Enemy) {
        let id = ObjectIdentifier(enemy)
        guard enemyContactCooldowns[id] == nil else { return }
        enemyContactCooldowns[id] = contactCooldownDuration

        let damaged = player.takeDamage(enemy.type.contactDamage)
        if damaged {
            SoundManager.shared.play(.playerHit)
            shakeCamera(intensity: 5, duration: 0.2)
            if player.stats.currentHP <= 0 { triggerGameOver() }
        }
    }

    private func handleEnemyBulletHitPlayer(bullet: EnemyBullet) {
        guard bullet.parent != nil else { return }
        bullet.removeFromParent()
        let damaged = player.takeDamage(bullet.damage)
        if damaged {
            SoundManager.shared.play(.playerHit)
            shakeCamera(intensity: 4, duration: 0.15)
            if player.stats.currentHP <= 0 { triggerGameOver() }
        }
    }

    private func handleOrbitalBladeHitEnemy(blade: OrbitalBlade, enemy: Enemy) {
        let id = ObjectIdentifier(enemy)
        guard enemyContactCooldowns[id] == nil else { return }
        enemyContactCooldowns[id] = 0.3
        let killed = enemy.takeDamage(blade.damage)
        if killed { killEnemy(enemy) }
    }

    private func killEnemy(_ enemy: Enemy) {
        guard enemy.parent != nil else { return }
        enemy.removeFromParent()
        handleEnemyDeath(enemy)
    }

    private func chainLightning(from pos: CGPoint, damage: CGFloat, targets: Int, excluding: Enemy) {
        var remaining = targets
        var checked: Set<ObjectIdentifier> = [ObjectIdentifier(excluding)]
        var currentPos = pos

        while remaining > 0 {
            var best: Enemy?
            var bestDist: CGFloat = 250
            for e in enemies where e.parent != nil && !checked.contains(ObjectIdentifier(e)) {
                let d = hypot(e.position.x - currentPos.x, e.position.y - currentPos.y)
                if d < bestDist { bestDist = d; best = e }
            }
            guard let target = best else { break }
            checked.insert(ObjectIdentifier(target))

            // Draw lightning arc
            drawLightningArc(from: currentPos, to: target.position)

            let killed = target.takeDamage(damage)
            if killed { killEnemy(target) }
            currentPos = target.position
            remaining -= 1
        }
    }

    private func drawLightningArc(from: CGPoint, to: CGPoint) {
        let path = CGMutablePath()
        path.move(to: from)
        let mid = CGPoint(x: (from.x + to.x) / 2 + CGFloat.random(in: -20...20),
                          y: (from.y + to.y) / 2 + CGFloat.random(in: -20...20))
        path.addQuadCurve(to: to, control: mid)

        let arc = SKShapeNode(path: path)
        arc.strokeColor = UIColor(red: 0.8, green: 0.9, blue: 1, alpha: 0.9)
        arc.lineWidth = 2
        arc.glowWidth = 4
        arc.zPosition = 8
        addChild(arc)
        arc.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.2), SKAction.removeFromParent()]))
    }

    // MARK: - Contact Cooldowns

    private func updateContactCooldowns(dt: TimeInterval) {
        var toRemove: [ObjectIdentifier] = []
        for (id, remaining) in enemyContactCooldowns {
            let newVal = remaining - dt
            if newVal <= 0 { toRemove.append(id) }
            else { enemyContactCooldowns[id] = newVal }
        }
        for id in toRemove { enemyContactCooldowns.removeValue(forKey: id) }
    }

    // MARK: - Level Up

    private func triggerLevelUp() {
        gameState = .levelingUp
        SoundManager.shared.play(.levelUp)

        let types = randomUpgrades(from: player.stats, count: 3)
        guard !types.isEmpty else { gameState = .playing; return }

        showUpgradeOverlay(types)
    }

    private func showUpgradeOverlay(_ types: [UpgradeType]) {
        let overlay = SKNode()
        overlay.zPosition = 200
        cam.addChild(overlay)
        upgradeOverlay = overlay

        // Dim background
        let dim = SKShapeNode(rectOf: size)
        dim.fillColor = UIColor(white: 0, alpha: 0.75)
        dim.strokeColor = .clear
        dim.zPosition = 0
        overlay.addChild(dim)

        // "LEVEL UP!" label
        let lvlLabel = SKLabelNode(text: "LEVEL \(gameStats.level)!")
        lvlLabel.fontName = "AvenirNext-Heavy"
        lvlLabel.fontSize = 38
        lvlLabel.fontColor = .cyan
        lvlLabel.verticalAlignmentMode = .center
        lvlLabel.position = CGPoint(x: 0, y: size.height * 0.28)
        lvlLabel.zPosition = 1
        overlay.addChild(lvlLabel)

        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.06, duration: 0.5),
            SKAction.scale(to: 1.0, duration: 0.5)
        ])
        lvlLabel.run(SKAction.repeatForever(pulse))

        let subLabel = SKLabelNode(text: "CHOOSE AN UPGRADE")
        subLabel.fontName = "AvenirNext-Medium"
        subLabel.fontSize = 14
        subLabel.fontColor = UIColor(white: 0.6, alpha: 1)
        subLabel.verticalAlignmentMode = .center
        subLabel.position = CGPoint(x: 0, y: size.height * 0.2)
        subLabel.zPosition = 1
        overlay.addChild(subLabel)

        // Cards
        let cardSize = CGSize(width: min(140, size.width * 0.38), height: 210)
        let spacing: CGFloat = cardSize.width + 14
        let totalWidth = spacing * CGFloat(types.count - 1)

        for (i, type) in types.enumerated() {
            let currentLevel = player.stats.upgradeLevels[type] ?? 0
            let card = UpgradeCard(type: type, currentLevel: currentLevel, size: cardSize)
            card.position = CGPoint(x: -totalWidth / 2 + CGFloat(i) * spacing, y: 0)
            card.zPosition = 2
            card.name = "card_\(type.rawValue)"
            overlay.addChild(card)

            // Slide in from bottom
            card.position.y -= 300
            card.alpha = 0
            card.run(SKAction.group([
                SKAction.moveBy(x: 0, y: 300, duration: 0.35),
                SKAction.fadeIn(withDuration: 0.35)
            ]))
        }
    }

    private func selectUpgrade(_ type: UpgradeType) {
        player.applyUpgrade(type)
        gameStats.collectedUpgrades.append(type)

        // Flash confirm
        upgradeOverlay?.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.15),
            SKAction.run { [weak self] in
                self?.upgradeOverlay?.removeFromParent()
                self?.upgradeOverlay = nil
                self?.gameState = .playing
            }
        ]))
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let loc = touch.location(in: self)
            let camLoc = touch.location(in: cam)

            // Handle upgrade overlay taps
            if gameState == .levelingUp {
                handleUpgradeTap(at: camLoc)
                return
            }

            // Joystick on left half
            if loc.x < size.width / 2 && joystickTouch == nil {
                joystickTouch = touch
                // Convert to camera space for joystick positioning
                joystick.touchBegan(at: camLoc)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if touch === joystickTouch {
                let camLoc = touch.location(in: cam)
                joystick.touchMoved(to: camLoc)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if touch === joystickTouch {
                joystick.touchEnded()
                joystickTouch = nil
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func handleUpgradeTap(at pos: CGPoint) {
        guard let overlay = upgradeOverlay else { return }
        let tapped = overlay.nodes(at: pos)
        for node in tapped {
            let name = node.name ?? node.parent?.name ?? ""
            if name.hasPrefix("card_") {
                let typeRaw = String(name.dropFirst(5))
                if let type = UpgradeType(rawValue: typeRaw) {
                    selectUpgrade(type)
                    return
                }
            }
        }
    }

    // MARK: - HUD

    private func updateHUD() {
        hud.update(stats: player.stats,
                   kills: gameStats.kills,
                   timeAlive: gameStats.timeAlive,
                   xp: gameStats.xp,
                   xpToNext: gameStats.xpToNext,
                   level: gameStats.level,
                   diffLabel: waveManager.difficultyLabel)
    }

    // MARK: - Screen Shake

    private func shakeCamera(intensity: CGFloat, duration: TimeInterval) {
        cam.removeAction(forKey: "shake")
        let steps = 8
        var actions: [SKAction] = []
        for _ in 0..<steps {
            let dx = CGFloat.random(in: -intensity...intensity)
            let dy = CGFloat.random(in: -intensity...intensity)
            actions.append(SKAction.moveBy(x: dx, y: dy, duration: duration / Double(steps)))
        }
        actions.append(SKAction.move(to: CGPoint(x: size.width / 2, y: size.height / 2), duration: 0.05))
        cam.run(SKAction.sequence(actions), withKey: "shake")
    }

    // MARK: - Damage Numbers

    private func spawnDamageNumber(text: String, at pos: CGPoint, color: UIColor) {
        let lbl = SKLabelNode(text: text)
        lbl.fontName = "AvenirNext-Heavy"
        lbl.fontSize = 14
        lbl.fontColor = color
        lbl.position = pos + CGPoint(x: CGFloat.random(in: -15...15), y: 0)
        lbl.zPosition = 15
        addChild(lbl)
        lbl.run(SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: 40, duration: 0.6),
                SKAction.sequence([
                    SKAction.wait(forDuration: 0.3),
                    SKAction.fadeOut(withDuration: 0.3)
                ])
            ]),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Spawn Helpers

    private func randomEdgePosition() -> CGPoint {
        let margin: CGFloat = 30
        let side = Int.random(in: 0..<4)
        switch side {
        case 0: return CGPoint(x: CGFloat.random(in: 0..<size.width), y: -margin)
        case 1: return CGPoint(x: CGFloat.random(in: 0..<size.width), y: size.height + margin)
        case 2: return CGPoint(x: -margin, y: CGFloat.random(in: 0..<size.height))
        default: return CGPoint(x: size.width + margin, y: CGFloat.random(in: 0..<size.height))
        }
    }

    // MARK: - Game Over

    private func triggerGameOver() {
        guard gameState != .dead else { return }
        gameState = .dead

        // Death explosion
        for _ in 0..<20 {
            let spark = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...6))
            spark.fillColor = .cyan
            spark.strokeColor = .clear
            spark.position = player.position
            spark.zPosition = 20
            addChild(spark)
            let angle = CGFloat.random(in: 0..<CGFloat.pi * 2)
            let dist = CGFloat.random(in: 30...120)
            spark.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: cos(angle)*dist, y: sin(angle)*dist, duration: 0.5),
                    SKAction.fadeOut(withDuration: 0.5)
                ]),
                SKAction.removeFromParent()
            ]))
        }
        player.removeFromParent()
        shakeCamera(intensity: 20, duration: 0.6)

        run(SKAction.wait(forDuration: 1.5)) { [weak self] in
            guard let self = self else { return }
            let scene = GameOverScene(
                size: self.size,
                timeAlive: self.gameStats.timeAlive,
                kills: self.gameStats.kills,
                level: self.gameStats.level,
                upgrades: self.gameStats.collectedUpgrades
            )
            scene.scaleMode = .aspectFill
            self.view?.presentScene(scene, transition: SKTransition.fade(with: .black, duration: 0.6))
        }
    }
}

// MARK: - CGFloat Clamping

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - CGPoint Arithmetic

extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
}
