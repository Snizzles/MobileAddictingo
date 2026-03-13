import SpriteKit

class XPOrb: SKNode {
    let xpValue: Int
    var isCollected = false
    private let visual: SKShapeNode
    private var floatPhase: CGFloat

    init(xpValue: Int) {
        self.xpValue = xpValue
        self.floatPhase = CGFloat.random(in: 0..<CGFloat.pi * 2)

        // Diamond shape
        let size: CGFloat = xpValue >= 8 ? 8 : (xpValue >= 5 ? 6 : 4.5)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: size))
        path.addLine(to: CGPoint(x: size * 0.6, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -size))
        path.addLine(to: CGPoint(x: -size * 0.6, y: 0))
        path.closeSubpath()

        let color: UIColor = xpValue >= 8 ? .yellow : (xpValue >= 5 ? UIColor(red: 0.4, green: 1, blue: 0.6, alpha: 1) : UIColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 1))
        visual = SKShapeNode(path: path)
        visual.fillColor = color
        visual.strokeColor = UIColor.white.withAlphaComponent(0.6)
        visual.lineWidth = 1
        visual.glowWidth = xpValue >= 8 ? 4 : 2

        super.init()
        addChild(visual)
        zPosition = 2

        // Bounce-in spawn
        visual.setScale(0)
        visual.run(SKAction.sequence([
            SKAction.scale(to: 1.3, duration: 0.1),
            SKAction.scale(to: 1.0, duration: 0.08)
        ]))
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(deltaTime dt: TimeInterval, playerPosition: CGPoint, magnetRange: CGFloat) {
        guard !isCollected else { return }

        let dist = hypot(position.x - playerPosition.x, position.y - playerPosition.y)

        // Float animation
        floatPhase += CGFloat(dt) * 3
        visual.position.y = sin(floatPhase) * 2.5

        if dist < magnetRange {
            // Pull toward player
            let speed: CGFloat = dist < 60 ? 600 : 280 + (1 - dist / magnetRange) * 320
            let dx = playerPosition.x - position.x
            let dy = playerPosition.y - position.y
            let len = hypot(dx, dy)
            if len > 0 {
                position.x += (dx / len) * speed * CGFloat(dt)
                position.y += (dy / len) * speed * CGFloat(dt)
            }
        }
    }

    func collect() {
        guard !isCollected else { return }
        isCollected = true
        let burst = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.8, duration: 0.1),
                SKAction.fadeOut(withDuration: 0.1)
            ]),
            SKAction.removeFromParent()
        ])
        run(burst)
    }
}
