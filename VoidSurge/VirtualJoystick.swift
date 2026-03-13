import SpriteKit

class VirtualJoystick: SKNode {
    private let baseRadius: CGFloat = 65
    private let thumbRadius: CGFloat = 28
    private let base: SKShapeNode
    private let thumb: SKShapeNode
    private let ring: SKShapeNode

    var direction: CGVector = .zero
    var magnitude: CGFloat = 0  // 0..1
    var isActive: Bool = false

    override init() {
        base = SKShapeNode(circleOfRadius: 65)
        base.fillColor = UIColor(white: 1, alpha: 0.08)
        base.strokeColor = UIColor(white: 1, alpha: 0.25)
        base.lineWidth = 2

        ring = SKShapeNode(circleOfRadius: 65)
        ring.fillColor = .clear
        ring.strokeColor = UIColor.cyan.withAlphaComponent(0.15)
        ring.lineWidth = 1

        thumb = SKShapeNode(circleOfRadius: 28)
        thumb.fillColor = UIColor(white: 1, alpha: 0.35)
        thumb.strokeColor = UIColor.cyan.withAlphaComponent(0.7)
        thumb.lineWidth = 2

        super.init()
        addChild(base)
        addChild(ring)
        addChild(thumb)
        isHidden = true
        zPosition = 100
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    func touchBegan(at worldPos: CGPoint) {
        position = worldPos
        thumb.position = .zero
        isHidden = false
        isActive = true
        direction = .zero
        magnitude = 0
    }

    func touchMoved(to worldPos: CGPoint) {
        let dx = worldPos.x - position.x
        let dy = worldPos.y - position.y
        let len = hypot(dx, dy)
        let maxDist = baseRadius - thumbRadius

        if len < maxDist {
            thumb.position = CGPoint(x: dx, y: dy)
            magnitude = len / maxDist
            direction = CGVector(dx: dx / maxDist, dy: dy / maxDist)
        } else {
            let nx = dx / len
            let ny = dy / len
            thumb.position = CGPoint(x: nx * maxDist, y: ny * maxDist)
            magnitude = 1
            direction = CGVector(dx: nx, dy: ny)
        }
    }

    func touchEnded() {
        isHidden = true
        isActive = false
        direction = .zero
        magnitude = 0
        thumb.position = .zero
    }
}
