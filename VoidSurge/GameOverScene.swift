import SpriteKit

class GameOverScene: SKScene {
    let timeAlive: TimeInterval
    let kills: Int
    let level: Int
    let upgrades: [UpgradeType]

    init(size: CGSize, timeAlive: TimeInterval, kills: Int, level: Int, upgrades: [UpgradeType]) {
        self.timeAlive = timeAlive
        self.kills = kills
        self.level = level
        self.upgrades = upgrades
        super.init(size: size)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        // Save best time
        let best = UserDefaults.standard.double(forKey: "bestTime")
        if timeAlive > best {
            UserDefaults.standard.set(timeAlive, forKey: "bestTime")
        }

        backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.06, alpha: 1)

        let cx = size.width / 2
        let cy = size.height / 2

        // YOU DIED
        let died = SKLabelNode(text: "YOU DIED")
        died.fontName = "AvenirNext-Heavy"
        died.fontSize = 54
        died.fontColor = UIColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 1)
        died.position = CGPoint(x: cx, y: cy + 130)
        died.zPosition = 2
        addChild(died)

        // Dramatic enter
        died.setScale(2)
        died.alpha = 0
        died.run(SKAction.group([
            SKAction.scale(to: 1, duration: 0.4),
            SKAction.fadeIn(withDuration: 0.4)
        ]))

        let mins = Int(timeAlive) / 60
        let secs = Int(timeAlive) % 60

        let isNewBest = timeAlive > best && best > 0

        // Stats
        let stats: [(String, String)] = [
            ("TIME SURVIVED", String(format: "%d:%02d%@", mins, secs, isNewBest ? " ★ NEW BEST" : "")),
            ("ENEMIES KILLED", "\(kills)"),
            ("LEVEL REACHED", "\(level)"),
        ]

        for (i, (key, value)) in stats.enumerated() {
            let yPos = cy + 55 - CGFloat(i) * 50

            let keyLbl = SKLabelNode(text: key)
            keyLbl.fontName = "AvenirNext-Medium"
            keyLbl.fontSize = 13
            keyLbl.fontColor = UIColor(white: 0.5, alpha: 1)
            keyLbl.position = CGPoint(x: cx, y: yPos + 14)
            keyLbl.zPosition = 2
            addChild(keyLbl)

            let valLbl = SKLabelNode(text: value)
            valLbl.fontName = "AvenirNext-Heavy"
            valLbl.fontSize = 24
            valLbl.fontColor = i == 0 && isNewBest
                ? UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1) : .white
            valLbl.position = CGPoint(x: cx, y: yPos - 8)
            valLbl.zPosition = 2
            addChild(valLbl)

            // Separator line
            let line = SKShapeNode(rectOf: CGSize(width: 250, height: 1))
            line.fillColor = UIColor(white: 0.2, alpha: 1)
            line.strokeColor = .clear
            line.position = CGPoint(x: cx, y: yPos - 28)
            line.zPosition = 2
            addChild(line)
        }

        // Upgrades collected
        if !upgrades.isEmpty {
            let upgLabel = SKLabelNode(text: "UPGRADES COLLECTED")
            upgLabel.fontName = "AvenirNext-Medium"
            upgLabel.fontSize = 12
            upgLabel.fontColor = UIColor(white: 0.4, alpha: 1)
            upgLabel.position = CGPoint(x: cx, y: cy - 100)
            upgLabel.zPosition = 2
            addChild(upgLabel)

            let icons = upgrades.compactMap { upgradeDefinitions[$0]?.icon }.joined(separator: " ")
            let iconLbl = SKLabelNode(text: icons)
            iconLbl.fontSize = 22
            iconLbl.position = CGPoint(x: cx, y: cy - 125)
            iconLbl.zPosition = 2
            addChild(iconLbl)
        }

        // Play Again button
        makeButton(text: "▶  PLAY AGAIN", position: CGPoint(x: cx, y: cy - 195), name: "playAgain")
        makeButton(text: "MENU", position: CGPoint(x: cx, y: cy - 255), name: "menu", color: UIColor(white: 0.6, alpha: 1))
    }

    private func makeButton(text: String, position: CGPoint, name: String, color: UIColor = .cyan) {
        let btn = SKShapeNode(rectOf: CGSize(width: 220, height: 50), cornerRadius: 25)
        btn.fillColor = color.withAlphaComponent(0.12)
        btn.strokeColor = color.withAlphaComponent(0.8)
        btn.lineWidth = 2
        btn.position = position
        btn.zPosition = 3
        btn.name = name
        addChild(btn)

        let lbl = SKLabelNode(text: text)
        lbl.fontName = "AvenirNext-Heavy"
        lbl.fontSize = 20
        lbl.fontColor = color
        lbl.verticalAlignmentMode = .center
        btn.addChild(lbl)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)
        for node in nodes(at: loc) {
            let name = node.name ?? node.parent?.name
            if name == "playAgain" {
                let scene = GameScene(size: size)
                scene.scaleMode = .aspectFill
                view?.presentScene(scene, transition: SKTransition.fade(with: .black, duration: 0.4))
                return
            }
            if name == "menu" {
                let scene = MenuScene(size: size)
                scene.scaleMode = .aspectFill
                view?.presentScene(scene, transition: SKTransition.fade(with: .black, duration: 0.4))
                return
            }
        }
    }
}
