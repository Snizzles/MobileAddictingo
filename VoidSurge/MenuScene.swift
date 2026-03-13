import SpriteKit

class MenuScene: SKScene {
    private var bestTime: TimeInterval = 0

    override func didMove(to view: SKView) {
        bestTime = UserDefaults.standard.double(forKey: "bestTime")
        setupBackground()
        setupUI()
        spawnEmbers()
    }

    private func setupBackground() {
        backgroundColor = UIColor(red: 0.06, green: 0.04, blue: 0.03, alpha: 1)

        // Dungeon bricks
        let bW: CGFloat = 52, bH: CGFloat = 28
        var row = 0
        var yy: CGFloat = 0
        while yy < size.height + bH {
            var xx: CGFloat = row % 2 == 0 ? 0 : -bW / 2
            while xx < size.width + bW {
                let brick = SKShapeNode(rectOf: CGSize(width: bW - 2, height: bH - 2), cornerRadius: 1)
                brick.fillColor = UIColor(
                    red: CGFloat.random(in: 0.09...0.13),
                    green: CGFloat.random(in: 0.07...0.10),
                    blue: CGFloat.random(in: 0.05...0.08), alpha: 1)
                brick.strokeColor = UIColor(white: 0, alpha: 0.5)
                brick.lineWidth = 1
                brick.position = CGPoint(x: xx + bW/2, y: yy + bH/2)
                brick.zPosition = 0
                addChild(brick)
                xx += bW
            }
            yy += bH; row += 1
        }

        // Torch glows at top corners
        for x in [CGFloat(0), size.width] {
            let glow = SKShapeNode(circleOfRadius: 80)
            glow.fillColor = UIColor(red: 1.0, green: 0.45, blue: 0.05, alpha: 0.12)
            glow.strokeColor = .clear
            glow.position = CGPoint(x: x, y: size.height)
            glow.zPosition = 1
            addChild(glow)
            let flicker = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.06, duration: 0.4),
                SKAction.fadeAlpha(to: 0.15, duration: 0.4)
            ])
            glow.run(SKAction.repeatForever(flicker))
        }
    }

    private func setupUI() {
        let cx = size.width / 2
        let cy = size.height / 2

        // Glow behind title
        let glowLabel = SKLabelNode(text: "VOID SURGE")
        glowLabel.fontName = "AvenirNext-Heavy"
        glowLabel.fontSize = 52
        glowLabel.fontColor = UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.25)
        glowLabel.position = CGPoint(x: cx, y: cy + 140)
        glowLabel.zPosition = 1
        addChild(glowLabel)

        let title = SKLabelNode(text: "VOID SURGE")
        title.fontName = "AvenirNext-Heavy"
        title.fontSize = 50
        title.fontColor = UIColor(red: 1.0, green: 0.78, blue: 0.15, alpha: 1)
        title.position = CGPoint(x: cx, y: cy + 140)
        title.zPosition = 2
        addChild(title)
        title.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.03, duration: 1.2),
            SKAction.scale(to: 1.0, duration: 1.2)
        ])))

        let sub = SKLabelNode(text: "Survive the endless dungeon")
        sub.fontName = "AvenirNext-Medium"
        sub.fontSize = 16
        sub.fontColor = UIColor(red: 0.7, green: 0.6, blue: 0.45, alpha: 1)
        sub.position = CGPoint(x: cx, y: cy + 100)
        sub.zPosition = 2
        addChild(sub)

        if bestTime > 0 {
            let mins = Int(bestTime) / 60
            let secs = Int(bestTime) % 60
            let best = SKLabelNode(text: String(format: "Best: %d:%02d", mins, secs))
            best.fontName = "AvenirNext-Bold"
            best.fontSize = 15
            best.fontColor = UIColor(red: 1.0, green: 0.82, blue: 0.25, alpha: 1)
            best.position = CGPoint(x: cx, y: cy + 72)
            best.zPosition = 2
            addChild(best)
        }

        makeButton(text: "▶  ENTER DUNGEON", position: CGPoint(x: cx, y: cy - 10), name: "playBtn")

        let instructions = [
            "Joystick (left) to move your hero",
            "Auto-attacks the nearest enemy",
            "Kill enemies → XP → Level up → Upgrade",
            "Defeat the Demon Lord every 2 minutes"
        ]
        for (i, line) in instructions.enumerated() {
            let lbl = SKLabelNode(text: line)
            lbl.fontName = "AvenirNext-Regular"
            lbl.fontSize = 13
            lbl.fontColor = UIColor(red: 0.6, green: 0.52, blue: 0.38, alpha: 1)
            lbl.position = CGPoint(x: cx, y: cy - 90 - CGFloat(i) * 22)
            lbl.zPosition = 2
            addChild(lbl)
        }
    }

    private func makeButton(text: String, position: CGPoint, name: String) {
        let color = UIColor(red: 1.0, green: 0.72, blue: 0.1, alpha: 1)
        let btn = SKShapeNode(rectOf: CGSize(width: 240, height: 54), cornerRadius: 8)
        btn.fillColor = UIColor(red: 0.18, green: 0.12, blue: 0.06, alpha: 0.95)
        btn.strokeColor = color.withAlphaComponent(0.9)
        btn.lineWidth = 2
        btn.glowWidth = 6
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

        btn.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.04, duration: 0.7),
            SKAction.scale(to: 1.0, duration: 0.7)
        ])))
    }

    private func spawnEmbers() {
        let spawn = SKAction.run { [weak self] in
            guard let self = self else { return }
            let ember = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...3))
            let colors: [UIColor] = [
                UIColor(red: 1.0, green: 0.55, blue: 0.1, alpha: 0.8),
                UIColor(red: 1.0, green: 0.3, blue: 0.05, alpha: 0.7),
                UIColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 0.6)
            ]
            ember.fillColor = colors.randomElement()!
            ember.strokeColor = .clear
            ember.position = CGPoint(x: CGFloat.random(in: 0..<self.size.width), y: 0)
            ember.zPosition = 2
            self.addChild(ember)
            let rise = SKAction.moveBy(x: CGFloat.random(in: -20...20),
                                       y: self.size.height + 20,
                                       duration: CGFloat.random(in: 5...10))
            ember.run(SKAction.sequence([
                SKAction.group([rise, SKAction.fadeOut(withDuration: 5)]),
                SKAction.removeFromParent()
            ]))
        }
        run(SKAction.repeatForever(SKAction.sequence([spawn, SKAction.wait(forDuration: 0.25)])))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)
        for node in nodes(at: loc) {
            if node.name == "playBtn" || node.parent?.name == "playBtn" {
                let scene = GameScene(size: size)
                scene.scaleMode = .aspectFill
                view?.presentScene(scene, transition: SKTransition.fade(
                    with: UIColor(red: 0.06, green: 0.04, blue: 0.03, alpha: 1), duration: 0.5))
                return
            }
        }
    }
}
