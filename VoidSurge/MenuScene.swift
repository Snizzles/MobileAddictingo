import SpriteKit

class MenuScene: SKScene {
    private var bestTime: TimeInterval = 0

    override func didMove(to view: SKView) {
        bestTime = UserDefaults.standard.double(forKey: "bestTime")
        setupBackground()
        setupUI()
        spawnAmbientParticles()
    }

    private func setupBackground() {
        backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.06, alpha: 1)

        // Star field
        for _ in 0..<120 {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.5...2))
            star.fillColor = UIColor(white: 1, alpha: CGFloat.random(in: 0.2...0.9))
            star.strokeColor = .clear
            star.position = CGPoint(x: CGFloat.random(in: 0..<size.width),
                                    y: CGFloat.random(in: 0..<size.height))
            star.zPosition = 0
            addChild(star)
            let twinkle = SKAction.sequence([
                SKAction.fadeAlpha(to: CGFloat.random(in: 0.1...0.4), duration: CGFloat.random(in: 0.8...2.5)),
                SKAction.fadeAlpha(to: CGFloat.random(in: 0.6...1.0), duration: CGFloat.random(in: 0.8...2.5))
            ])
            star.run(SKAction.repeatForever(twinkle))
        }
    }

    private func setupUI() {
        let cx = size.width / 2
        let cy = size.height / 2

        // Title glow
        let glowLabel = SKLabelNode(text: "VOID SURGE")
        glowLabel.fontName = "AvenirNext-Heavy"
        glowLabel.fontSize = 52
        glowLabel.fontColor = UIColor.cyan.withAlphaComponent(0.2)
        glowLabel.position = CGPoint(x: cx, y: cy + 140)
        glowLabel.zPosition = 1
        addChild(glowLabel)

        // Title
        let title = SKLabelNode(text: "VOID SURGE")
        title.fontName = "AvenirNext-Heavy"
        title.fontSize = 50
        title.fontColor = .cyan
        title.position = CGPoint(x: cx, y: cy + 140)
        title.zPosition = 2
        addChild(title)

        let titlePulse = SKAction.sequence([
            SKAction.scale(to: 1.03, duration: 1.2),
            SKAction.scale(to: 1.0, duration: 1.2)
        ])
        title.run(SKAction.repeatForever(titlePulse))

        // Subtitle
        let sub = SKLabelNode(text: "Survive the endless void")
        sub.fontName = "AvenirNext-Medium"
        sub.fontSize = 16
        sub.fontColor = UIColor(white: 0.65, alpha: 1)
        sub.position = CGPoint(x: cx, y: cy + 100)
        sub.zPosition = 2
        addChild(sub)

        // Best time
        if bestTime > 0 {
            let mins = Int(bestTime) / 60
            let secs = Int(bestTime) % 60
            let best = SKLabelNode(text: String(format: "Best: %d:%02d", mins, secs))
            best.fontName = "AvenirNext-Bold"
            best.fontSize = 15
            best.fontColor = UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)
            best.position = CGPoint(x: cx, y: cy + 72)
            best.zPosition = 2
            addChild(best)
        }

        // Play button
        makeButton(text: "▶  PLAY", position: CGPoint(x: cx, y: cy - 10),
                   color: .cyan, name: "playBtn")

        // How to play
        let instructions = [
            "Virtual joystick: left side of screen",
            "Auto-attack nearest enemy",
            "Collect XP → Level up → Pick upgrade",
            "Kill the boss every 2 minutes"
        ]
        for (i, line) in instructions.enumerated() {
            let lbl = SKLabelNode(text: line)
            lbl.fontName = "AvenirNext-Regular"
            lbl.fontSize = 13
            lbl.fontColor = UIColor(white: 0.55, alpha: 1)
            lbl.position = CGPoint(x: cx, y: cy - 90 - CGFloat(i) * 22)
            lbl.zPosition = 2
            addChild(lbl)
        }
    }

    private func makeButton(text: String, position: CGPoint, color: UIColor, name: String) {
        let btn = SKShapeNode(rectOf: CGSize(width: 200, height: 52), cornerRadius: 26)
        btn.fillColor = color.withAlphaComponent(0.15)
        btn.strokeColor = color.withAlphaComponent(0.9)
        btn.lineWidth = 2
        btn.glowWidth = 6
        btn.position = position
        btn.zPosition = 3
        btn.name = name
        addChild(btn)

        let lbl = SKLabelNode(text: text)
        lbl.fontName = "AvenirNext-Heavy"
        lbl.fontSize = 22
        lbl.fontColor = color
        lbl.verticalAlignmentMode = .center
        btn.addChild(lbl)

        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.04, duration: 0.7),
            SKAction.scale(to: 1.0, duration: 0.7)
        ])
        btn.run(SKAction.repeatForever(pulse))
    }

    private func spawnAmbientParticles() {
        let spawn = SKAction.run { [weak self] in
            guard let self = self else { return }
            let p = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.5...4))
            p.fillColor = [UIColor.cyan, UIColor.magenta, UIColor.yellow].randomElement()!.withAlphaComponent(0.5)
            p.strokeColor = .clear
            p.position = CGPoint(x: CGFloat.random(in: 0..<self.size.width),
                                 y: -10)
            p.zPosition = 1
            self.addChild(p)
            let rise = SKAction.moveBy(x: CGFloat.random(in: -30...30),
                                       y: self.size.height + 20, duration: CGFloat.random(in: 4...8))
            p.run(SKAction.sequence([SKAction.group([rise, SKAction.fadeOut(withDuration: 4)]), SKAction.removeFromParent()]))
        }
        run(SKAction.repeatForever(SKAction.sequence([spawn, SKAction.wait(forDuration: 0.3)])))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)
        let nodes = nodes(at: loc)
        for node in nodes {
            if node.name == "playBtn" || node.parent?.name == "playBtn" {
                startGame()
                return
            }
        }
    }

    private func startGame() {
        let scene = GameScene(size: size)
        scene.scaleMode = .aspectFill
        let transition = SKTransition.fade(with: UIColor(red: 0.02, green: 0.02, blue: 0.06, alpha: 1), duration: 0.5)
        view?.presentScene(scene, transition: transition)
    }
}
