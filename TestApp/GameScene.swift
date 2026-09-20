import SpriteKit
import AVFoundation

// MARK: - Категории физики

struct PhysicsCategory {
    static let tank: UInt32   = 1 << 0
    static let bullet: UInt32 = 1 << 1
    static let wall: UInt32   = 1 << 2
}

// MARK: - Сцена

final class GameScene: SKScene {

    var onGameOver: ((Int) -> Void)?

    private var p1: Tank!
    private var p2: Tank!
    private var leftStick: Joystick!
    private var rightStick: Joystick!
    private var p1Vec = CGVector.zero
    private var p2Vec = CGVector.zero
    private var gameFinished = false

    // MARK: Жизненный цикл

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(white: 0.07, alpha: 1)
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        setupGrid()
        setupWalls()
        setupTanks()
        setupControls()
        SoundService.shared.prepare()
    }

    // MARK: Построение

    private func setupGrid() {
        let path = CGMutablePath()
        let step: CGFloat = 40
        var x: CGFloat = 0
        while x < size.width { path.move(to: .init(x: x, y: 0)); path.addLine(to: .init(x: x, y: size.height)); x += step }
        var y: CGFloat = 0
        while y < size.height { path.move(to: .init(x: 0, y: y)); path.addLine(to: .init(x: size.width, y: y)); y += step }
        let grid = SKShapeNode(path: path)
        grid.strokeColor = SKColor(white: 0.16, alpha: 1)
        grid.lineWidth = 0.5
        grid.zPosition = -10
        addChild(grid)
    }

    private func setupWalls() {
        let t: CGFloat = 10
        wall(CGRect(x: 0, y: 0, width: size.width, height: t))
        wall(CGRect(x: 0, y: size.height - t, width: size.width, height: t))
        wall(CGRect(x: 0, y: 0, width: t, height: size.height))
        wall(CGRect(x: size.width - t, y: 0, width: t, height: size.height))
        // Препятствия в центре
        wall(CGRect(x: size.width/2 - 60, y: size.height/2 - 8, width: 120, height: 16))
        wall(CGRect(x: size.width/2 - 8, y: size.height/2 - 90, width: 16, height: 70))
        wall(CGRect(x: size.width/2 - 8, y: size.height/2 + 20, width: 16, height: 70))
    }

    private func wall(_ rect: CGRect) {
        let n = SKShapeNode(rect: rect)
        n.fillColor = SKColor(white: 0.4, alpha: 1)
        n.strokeColor = .white
        n.lineWidth = 1
        n.position = .init(x: rect.midX, y: rect.midY)
        let pb = SKPhysicsBody(rectangleOf: rect.size)
        pb.isDynamic = false
        pb.categoryBitMask = PhysicsCategory.wall
        pb.collisionBitMask = PhysicsCategory.tank | PhysicsCategory.bullet
        pb.restitution = 1.0
        pb.friction = 0
        n.physicsBody = pb
        addChild(n)
    }

    private func setupTanks() {
        p1 = Tank(id: 1, hp: 3, color: .green, position: .init(x: 100, y: size.height/2))
        p2 = Tank(id: 2, hp: 3, color: .blue,  position: .init(x: size.width - 100, y: size.height/2))
        addChild(p1); addChild(p2)
    }

    private func setupControls() {
        let r: CGFloat = 70
        leftStick  = Joystick(radius: r, color: .green)
        rightStick = Joystick(radius: r, color: .blue)
        leftStick.position  = .init(x: 110, y: 110)
        rightStick.position = .init(x: size.width - 110, y: 110)
        leftStick.zPosition  = 100
        rightStick.zPosition = 100
        leftStick.onChange  = { [weak self] v in self?.p1Vec = v }
        rightStick.onChange = { [weak self] v in self?.p2Vec = v }
        addChild(leftStick); addChild(rightStick)

        // Кнопки стрельбы
        let b1 = FireButton(radius: 32, color: .green) { [weak self] in self?.fire(from: self!.p1) }
        let b2 = FireButton(radius: 32, color: .blue)  { [weak self] in self?.fire(from: self!.p2) }
        b1.position = .init(x: 250, y: 70)
        b2.position = .init(x: size.width - 250, y: 70)
        b1.zPosition = 100; b2.zPosition = 100
        addChild(b1); addChild(b2)
    }

    // MARK: Игровой цикл

    override func update(_ currentTime: TimeInterval) {
        guard !gameFinished else { return }
        let dt: TimeInterval = 1.0 / 60.0
        p1.move(by: p1Vec, dt: dt)
        p2.move(by: p2Vec, dt: dt)
    }

    // MARK: Стрельба

    private func fire(from tank: Tank) {
        guard !gameFinished else { return }
        let b = Bullet(ownerID: tank.playerID)
        b.position = tank.barrelTip()
        addChild(b)
        let speed: CGFloat = 600
        b.physicsBody?.velocity = .init(dx: cos(tank.zRotation) * speed,
                                        dy: sin(tank.zRotation) * speed)
        SoundService.shared.shoot()
    }

    // MARK: Урон

    private func hit(bullet: Bullet, tank: Tank) {
        guard bullet.ownerID != tank.playerID else { return }
        bullet.removeFromParent()
        SoundService.shared.hit()
        if tank.takeDamage() {
            tank.removeFromParent()
            SoundService.shared.explode()
            gameFinished = true
            let winner = tank.playerID == 1 ? 2 : 1
            onGameOver?(winner)
        }
    }

    // MARK: Касания (multi-touch)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let loc = t.location(in: self)
            if leftStick.contains(loc, in: self) {
                leftStick.began(t, in: self)
            } else if rightStick.contains(loc, in: self) {
                rightStick.began(t, in: self)
            } else {
                for n in children {
                    if let b = n as? FireButton, b.contains(loc, in: self) { b.press() }
                }
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            leftStick.moved(t, in: self)
            rightStick.moved(t, in: self)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            leftStick.ended(t, in: self)
            rightStick.ended(t, in: self)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
}

// MARK: - Физика

extension GameScene: SKPhysicsContactDelegate {
    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA.node, b = contact.bodyB.node
        if let bullet = a as? Bullet, let tank = b as? Tank { hit(bullet: bullet, tank: tank) }
        if let bullet = b as? Bullet, let tank = a as? Tank { hit(bullet: bullet, tank: tank) }
        if let bullet = a as? Bullet, b is SKShapeNode { bullet.bounce() }
        if let bullet = b as? Bullet, a is SKShapeNode { bullet.bounce() }
    }
}

// MARK: - Танк

final class Tank: SKNode {
    let playerID: Int
    var hp: Int

    init(id: Int, hp: Int, color: SKColor, position: CGPoint) {
        self.playerID = id; self.hp = hp
        super.init(); self.position = position

        let body = SKShapeNode(rect: CGRect(x: -25, y: -20, width: 50, height: 40), cornerRadius: 6)
        body.fillColor = color; body.strokeColor = .white; body.lineWidth = 1.5
        addChild(body)

        let turret = SKShapeNode(circleOfRadius: 14)
        turret.fillColor = color.withAlphaComponent(0.9)
        turret.strokeColor = .white; turret.lineWidth = 1.5
        addChild(turret)

        let p = CGMutablePath()
        p.move(to: .zero); p.addLine(to: .init(x: 30, y: 0))
        let barrel = SKShapeNode(path: p)
        barrel.strokeColor = .white; barrel.lineWidth = 5; barrel.lineCap = .round
        addChild(barrel)

        let pb = SKPhysicsBody(rectangleOf: .init(width: 50, height: 40))
        pb.categoryBitMask = PhysicsCategory.tank
        pb.contactTestBitMask = PhysicsCategory.bullet
        pb.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.tank
        pb.allowsRotation = false
        pb.restitution = 0
        physicsBody = pb
    }

    required init?(coder: NSCoder) { fatalError() }

    func move(by v: CGVector, dt: TimeInterval) {
        guard v.dx != 0 || v.dy != 0 else { return }
        let angle = atan2(v.dy, v.dx)
        zRotation = angle
        let speed: CGFloat = 140
        position.x += cos(angle) * speed * CGFloat(dt)
        position.y += sin(angle) * speed * CGFloat(dt)
    }

    func barrelTip() -> CGPoint {
        let len: CGFloat = 34
        return .init(x: position.x + cos(zRotation) * len,
                     y: position.y + sin(zRotation) * len)
    }

    func takeDamage() -> Bool { hp -= 1; return hp <= 0 }
}

// MARK: - Пуля

final class Bullet: SKNode {
    let ownerID: Int
    private var bounces = 0

    init(ownerID: Int) {
        self.ownerID = ownerID
        super.init()
        let s = SKShapeNode(circleOfRadius: 5)
        s.fillColor = .yellow; s.strokeColor = .orange
        s.lineWidth = 1; s.glowWidth = 3
        addChild(s)

        let pb = SKPhysicsBody(circleOfRadius: 5)
        pb.categoryBitMask = PhysicsCategory.bullet
        pb.contactTestBitMask = PhysicsCategory.tank | PhysicsCategory.wall
        pb.collisionBitMask = PhysicsCategory.wall
        pb.restitution = 1.0; pb.friction = 0; pb.linearDamping = 0
        pb.affectedByGravity = false
        pb.usesPreciseCollisionDetection = true
        physicsBody = pb

        run(.sequence([.wait(duration: 5), .removeFromParent()]))
    }

    required init?(coder: NSCoder) { fatalError() }

    func bounce() { bounces += 1; if bounces > 2 { removeFromParent() } }
}

// MARK: - Джойстик

final class Joystick: SKNode {
    let radius: CGFloat
    private let stick: SKShapeNode
    private var active: UITouch?
    var onChange: ((CGVector) -> Void)?

    init(radius: CGFloat, color: SKColor) {
        self.radius = radius
        self.stick = SKShapeNode(circleOfRadius: radius * 0.5)
        super.init()

        let base = SKShapeNode(circleOfRadius: radius)
        base.fillColor = color.withAlphaComponent(0.15)
        base.strokeColor = color.withAlphaComponent(0.6)
        base.lineWidth = 3
        addChild(base)

        stick.fillColor = color.withAlphaComponent(0.6)
        stick.strokeColor = color; stick.lineWidth = 2
        addChild(stick)
    }

    required init?(coder: NSCoder) { fatalError() }

    func began(_ t: UITouch, in scene: SKScene) { active = t; update(t, in: scene) }
    func moved(_ t: UITouch, in scene: SKScene) { guard t == active else { return }; update(t, in: scene) }
    func ended(_ t: UITouch, in scene: SKScene) {
        guard t == active else { return }
        active = nil; stick.position = .zero; onChange?(.zero)
    }

    private func update(_ t: UITouch, in scene: SKScene) {
        let local = t.location(in: self)
        let dist = hypot(local.x, local.y)
        let clamped: CGPoint = dist > radius
            ? .init(x: local.x * radius / dist, y: local.y * radius / dist)
            : local
        stick.position = clamped
        onChange?(.init(dx: clamped.x / radius, dy: clamped.y / radius))
    }

    func contains(_ p: CGPoint, in scene: SKScene) -> Bool {
        let local = scene.convert(p, to: self)
        return hypot(local.x, local.y) <= radius * 1.3
    }
}

// MARK: - Кнопка стрельбы

final class FireButton: SKNode {
    private let action: () -> Void

    init(radius: CGFloat, color: SKColor, action: @escaping () -> Void) {
        self.action = action
        super.init()
        let base = SKShapeNode(circleOfRadius: radius)
        base.fillColor = color.withAlphaComponent(0.4)
        base.strokeColor = color; base.lineWidth = 3
        addChild(base)

        let label = SKLabelNode(text: "ОГОНЬ")
        label.fontSize = 11; label.fontColor = .white
        label.verticalAlignmentMode = .center
        addChild(label)
    }

    required init?(coder: NSCoder) { fatalError() }

    func contains(_ p: CGPoint, in scene: SKScene) -> Bool {
        let local = scene.convert(p, to: self)
        return hypot(local.x, local.y) <= 32
    }

    func press() { action() }
}

// MARK: - Звук (программный, без файлов)

final class SoundService {
    static let shared = SoundService()
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

    private init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try? engine.start()
    }

    func prepare() { if !player.isPlaying { player.play() } }

    func tone(_ freq: Double, _ dur: Double) {
        let frames = AVAudioFrameCount(44100 * dur)
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return }
        buf.frameLength = frames
        let data = buf.floatChannelData![0]
        for i in 0..<Int(frames) {
            let t = Double(i) / 44100.0
            let env = max(0, 1.0 - t / dur)
            data[i] = Float(sin(2 * .pi * freq * t) * env * 0.3)
        }
        player.scheduleBuffer(buf, at: nil, options: .interrupts)
    }

    func shoot()   { tone(880, 0.08) }
    func hit()     { tone(220, 0.12) }
    func explode() { tone(110, 0.40) }
}