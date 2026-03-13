import SpriteKit

class HUD: SKNode {
    // HP Bar
    private let hpBarBg: SKShapeNode
    private let hpBarFill: SKShapeNode
    private let hpLabel: SKLabelNode
    private let barWidth: CGFloat = 180
    private let barHeight: CGFloat = 16

    // XP Bar
    private let xpBarBg: SKShapeNode
    private let xpBarFill: SKShapeNode
    private let levelLabel: SKLabelNode
    private let xpBarWidth: CGFloat

    // Info labels
    private let killsLabel: SKLabelNode
    private let timeLabel: SKLabelNode
    private let diffLabel: SKLabelNode

    // Boss HP bar
    private let bossBarContainer: SKNode
    private let bossBarBg: SKShapeNode
    private let bossBarFill: SKShapeNode
    private let bossNameLabel: SKLabelNode
    private let bossBarWidth: CGFloat = 280

    init(size: CGSize) {
        xpBarWidth = size.width - 40

        // HP Bar (top left)
        hpBarBg = SKShapeNode(rectOf: CGSize(width: 180, height: 16), cornerRadius: 8)
        hpBarBg.fillColor = UIColor(white: 0.15, alpha: 0.9)
        hpBarBg.strokeColor = UIColor(white: 0.4, alpha: 0.5)
        hpBarBg.lineWidth = 1

        hpBarFill = SKShapeNode(rectOf: CGSize(width: 180, height: 16), cornerRadius: 8)
        hpBarFill.fillColor = UIColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 1)
        hpBarFill.strokeColor = .clear

        hpLabel = SKLabelNode(text: "100 / 100")
        hpLabel.fontName = "AvenirNext-Bold"
        hpLabel.fontSize = 10
        hpLabel.fontColor = .white
        hpLabel.verticalAlignmentMode = .center

        // XP Bar (bottom)
        xpBarBg = SKShapeNode(rectOf: CGSize(width: xpBarWidth, height: 10), cornerRadius: 5)
        xpBarBg.fillColor = UIColor(white: 0.15, alpha: 0.9)
        xpBarBg.strokeColor = UIColor(white: 0.3, alpha: 0.5)
        xpBarBg.lineWidth = 1

        xpBarFill = SKShapeNode(rectOf: CGSize(width: 1, height: 10), cornerRadius: 5)
        xpBarFill.fillColor = UIColor(red: 0.4, green: 0.9, blue: 1, alpha: 1)
        xpBarFill.strokeColor = .clear

        levelLabel = SKLabelNode(text: "LVL 1")
        levelLabel.fontName = "AvenirNext-Heavy"
        levelLabel.fontSize = 13
        levelLabel.fontColor = UIColor.cyan

        // Info labels
        killsLabel = SKLabelNode(text: "0 KILLS")
        killsLabel.fontName = "AvenirNext-Bold"
        killsLabel.fontSize = 13
        killsLabel.fontColor = UIColor(white: 0.85, alpha: 1)

        timeLabel = SKLabelNode(text: "0:00")
        timeLabel.fontName = "AvenirNext-Bold"
        timeLabel.fontSize = 14
        timeLabel.fontColor = .white

        diffLabel = SKLabelNode(text: "ROOKIE")
        diffLabel.fontName = "AvenirNext-Heavy"
        diffLabel.fontSize = 11
        diffLabel.fontColor = UIColor(red: 0.5, green: 1, blue: 0.5, alpha: 1)

        // Boss HP Bar
        bossBarContainer = SKNode()
        bossBarBg = SKShapeNode(rectOf: CGSize(width: 280, height: 18), cornerRadius: 9)
        bossBarBg.fillColor = UIColor(white: 0.1, alpha: 0.95)
        bossBarBg.strokeColor = UIColor(red: 0.9, green: 0.1, blue: 0.6, alpha: 0.8)
        bossBarBg.lineWidth = 2

        bossBarFill = SKShapeNode(rectOf: CGSize(width: 280, height: 18), cornerRadius: 9)
        bossBarFill.fillColor = UIColor(red: 0.9, green: 0.1, blue: 0.6, alpha: 1)
        bossBarFill.strokeColor = .clear

        bossNameLabel = SKLabelNode(text: "⚠ VOID TITAN")
        bossNameLabel.fontName = "AvenirNext-Heavy"
        bossNameLabel.fontSize = 12
        bossNameLabel.fontColor = .white
        bossNameLabel.verticalAlignmentMode = .center

        super.init()
        zPosition = 50

        // Layout — anchored to top-left for HP, bottom for XP
        let topY = size.height / 2 - 40
        let botY = -size.height / 2 + 25

        // HP
        hpBarBg.position = CGPoint(x: -size.width / 2 + 110, y: topY)
        hpBarFill.position = CGPoint(x: -size.width / 2 + 110, y: topY)
        hpLabel.position = CGPoint(x: -size.width / 2 + 110, y: topY)
        addChild(hpBarBg); addChild(hpBarFill); addChild(hpLabel)

        // XP Bar
        xpBarBg.position = CGPoint(x: 0, y: botY)
        xpBarFill.position = CGPoint(x: -xpBarWidth / 2, y: botY)
        levelLabel.position = CGPoint(x: 0, y: botY + 16)
        addChild(xpBarBg)
        addChild(xpBarFill)
        addChild(levelLabel)

        // Kills (top right)
        killsLabel.position = CGPoint(x: size.width / 2 - 60, y: topY)
        killsLabel.horizontalAlignmentMode = .right
        addChild(killsLabel)

        // Time (top center)
        timeLabel.position = CGPoint(x: 0, y: topY)
        timeLabel.horizontalAlignmentMode = .center
        addChild(timeLabel)

        // Difficulty (below time)
        diffLabel.position = CGPoint(x: 0, y: topY - 18)
        diffLabel.horizontalAlignmentMode = .center
        addChild(diffLabel)

        // Boss bar (center, below time)
        bossBarContainer.position = CGPoint(x: 0, y: topY - 50)
        bossBarContainer.addChild(bossBarBg)
        bossBarContainer.addChild(bossBarFill)
        bossNameLabel.position = CGPoint(x: 0, y: 0)
        bossBarContainer.addChild(bossNameLabel)
        bossBarContainer.isHidden = true
        addChild(bossBarContainer)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(stats: PlayerStats, kills: Int, timeAlive: TimeInterval, xp: Int, xpToNext: Int, level: Int, diffLabel diff: String) {
        // HP Bar
        let hpRatio = stats.maxHP > 0 ? stats.currentHP / stats.maxHP : 0
        let newHPWidth = max(2, barWidth * hpRatio)
        // Path coords are LOCAL to hpBarFill's position — left edge is -barWidth/2
        hpBarFill.path = CGPath(roundedRect: CGRect(x: -barWidth / 2, y: -barHeight / 2,
                                                     width: newHPWidth, height: barHeight),
                                 cornerWidth: 8, cornerHeight: 8, transform: nil)
        let r = hpRatio > 0.5 ? CGFloat((1 - hpRatio) * 2) : 1
        let g = hpRatio > 0.5 ? 1.0 : CGFloat(hpRatio * 2)
        hpBarFill.fillColor = UIColor(red: r, green: g, blue: 0.1, alpha: 1)
        hpLabel.text = "\(Int(stats.currentHP)) / \(Int(stats.maxHP))"

        // Low HP pulse
        if hpRatio < 0.3 {
            if hpBarFill.action(forKey: "pulse") == nil {
                let pulse = SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.5, duration: 0.3),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.3)
                ])
                hpBarFill.run(SKAction.repeatForever(pulse), withKey: "pulse")
            }
        } else {
            hpBarFill.removeAction(forKey: "pulse")
            hpBarFill.alpha = 1
        }

        // XP Bar
        let xpRatio = xpToNext > 0 ? CGFloat(xp) / CGFloat(xpToNext) : 0
        let newXPWidth = max(2, xpBarWidth * xpRatio)
        xpBarFill.path = CGPath(roundedRect: CGRect(x: -xpBarWidth / 2, y: -5, width: newXPWidth, height: 10),
                                 cornerWidth: 5, cornerHeight: 5, transform: nil)
        levelLabel.text = "LVL \(level)"

        // Kills / Time
        killsLabel.text = "\(kills) KILLS"
        let mins = Int(timeAlive) / 60
        let secs = Int(timeAlive) % 60
        timeLabel.text = String(format: "%d:%02d", mins, secs)
        diffLabel.text = diff
        diffLabel.fontColor = difficultyColor(for: diff)
    }

    func showBossBar(name: String) {
        bossNameLabel.text = "⚠ \(name)"
        bossBarContainer.isHidden = false
        bossBarContainer.alpha = 0
        bossBarContainer.run(SKAction.fadeIn(withDuration: 0.3))
    }

    func updateBossHP(ratio: CGFloat) {
        let w = max(2, bossBarWidth * ratio)
        bossBarFill.path = CGPath(roundedRect: CGRect(x: -bossBarWidth / 2, y: -9, width: w, height: 18),
                                   cornerWidth: 9, cornerHeight: 9, transform: nil)
    }

    func hideBossBar() {
        bossBarContainer.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.run { self.bossBarContainer.isHidden = true }
        ]))
    }

    private func difficultyColor(for label: String) -> UIColor {
        switch label {
        case "ROOKIE":    return UIColor(red: 0.4, green: 1, blue: 0.4, alpha: 1)
        case "HUNTER":    return UIColor(red: 0.6, green: 1, blue: 0.2, alpha: 1)
        case "VETERAN":   return UIColor(red: 1, green: 0.8, blue: 0.1, alpha: 1)
        case "ELITE":     return UIColor(red: 1, green: 0.4, blue: 0.1, alpha: 1)
        case "NIGHTMARE": return UIColor(red: 1, green: 0.1, blue: 0.1, alpha: 1)
        default:          return UIColor(red: 0.8, green: 0.2, blue: 1, alpha: 1)
        }
    }
}
