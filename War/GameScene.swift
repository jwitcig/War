//
//  GameScene.swift
//  War
//
//  Created by Developer on 9/17/16.
//  Copyright © 2016 JwitApps. All rights reserved.
//

import GameplayKit
import SpriteKit

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    var graphs = [String : GKGraph]()
    
    private var lastUpdateTime : TimeInterval = 0
    
    private var reinforcementDuration: CGFloat = 5
    
    lazy var entityManager: EntityManager = {
        return EntityManager(scene: self, systems: [
            GKComponentSystem(componentClass: MoveComponent.self),
        ])
    }()
    
    private lazy var infantries: [Infantry] = {[
        self.alliedInfantry, self.axisInfantry,
    ]}()
    private lazy var alliedInfantry: Infantry = {
        let area = AreaRange(x: GKRandomDistribution(lowestValue: Int(-self.frame.width)/2,
                                                    highestValue: Int(self.frame.width)/2),
                             y: GKRandomDistribution(lowestValue: Int(-self.frame.height)/2,
                                                    highestValue: Int(-self.frame.height)/2))
        return Infantry(player: "allied", deployZone: area, color: .blue, side: .bottom)
    }()
    private lazy var axisInfantry: Infantry = {
        let area = AreaRange(x: GKRandomDistribution(lowestValue: Int(-self.frame.width/2),
                                                    highestValue: Int(self.frame.width/2)),
                             y: GKRandomDistribution(lowestValue: Int(self.frame.height/2),
                                                    highestValue: Int(self.frame.height/2)))
        return Infantry(player: "axis", deployZone: area, color: .red, side: .top)
    }()

    lazy var drawer: Drawer = {
        let drawer: Drawer = Drawer(rectOf: CGSize(width: self.frame.width, height: 150))
        drawer.addEntity = { self.entityManager.add(entity: $0) }
        drawer.fillColor = .darkGray
        drawer.strokeColor = .darkGray
        drawer.customConstraints = [
            SKConstraint.positionX(SKRange(constantValue: 0)),
            SKConstraint.positionY(SKRange(constantValue: (drawer.frame.height-self.frame.height)/2)),
        ].map {
            $0.enabled = false
            return $0
        }
        drawer.constraints = drawer.customConstraints
        return drawer
    }()
    
    var touchOnDrawer = false
    
    var selection: UnitSelection?
    
    override func didMove(to view: SKView) {
        self.view?.ignoresSiblingOrder = true
        physicsWorld.contactDelegate = self
        physicsWorld.gravity = CGVector(dx: 0, dy: 0)
        physicsWorld.speed = 1
        self.physicsBody = {
            let buffer: CGFloat = 50
            let body = SKPhysicsBody(edgeLoopFrom: CGRect(x: -self.frame.width/2-buffer,
                                                          y: -self.frame.height/2-buffer,
                                                      width: self.frame.width+buffer*2,
                                                     height: self.frame.height+buffer*2))
            body.isDynamic = false
            body.collisionBitMask = Entity.none.rawValue
            body.contactTestBitMask = Entity.evironmentEdge.rawValue
            return body
        }()
        
        addChild(drawer)
        drawer.customConstraints.forEach{$0.enabled = true}
        setup(drawer: drawer)
        
        let barrier = Barrier(position: CGPoint(x: 200, y: 200))
        entityManager.add(entity: barrier)
        
        (0..<50).forEach{ _ in           self.incrementInfantryCount()}
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { timer in
           self.incrementInfantryCount()
        }
    }
    
    func setup(drawer: Drawer) {
        let barrier = Barrier()
        barrier.node.name = "drawer-barrier"
        drawer.add(item: barrier.node, withEntity: {Barrier()})
    }
    
    var unitTypeDistribution = GKRandomDistribution(lowestValue: 0, highestValue: 3)
    
    func incrementInfantryCount() {
        infantries.forEach{$0.addSupplement()}
        
        var type: UnitType = .normal
        if unitTypeDistribution.nextInt() == 0 {
            type = .large
        }
    
        let alliedUnit = Unit(team: alliedInfantry, type: type)
        alliedUnit.addComponent(ShootComponent(fireRate: 1))
        entityManager.add(entity: alliedUnit)
        alliedUnit.updateDestination()
        
        type = .normal
        if unitTypeDistribution.nextInt() == 0 {
            type = .large
        }
        
        let axisUnit = Unit(team: axisInfantry, type: type)
        axisUnit.addComponent(ShootComponent(fireRate: 1))
        entityManager.add(entity: axisUnit)
        axisUnit.updateDestination()
    }
    
    func touchDown(atPoint position: CGPoint) {
        guard !nodes(at: position).contains(self.drawer) else {
            drawer.touchDown(atPoint: position)
            self.touchOnDrawer = true
            return
        }
    
        guard selection == nil else { return }
        
        let selectionCircle = SizeableCircle(radius: 0, position: position)
        selectionCircle.position = position
        selectionCircle.fillColor = .clear
        selectionCircle.strokeColor = .blue
        addChild(selectionCircle)
        
        selection = UnitSelection(scene: self, position: position, node: selectionCircle)
    }
    
    func touchMoved(toPoint position: CGPoint) {
        guard !self.touchOnDrawer else {
            drawer.touchMoved(toPoint: position)
            return
        }
        
        selection?.finalTouch = position
    }
    
    func touchUp(atPoint position: CGPoint) {
        guard !nodes(at: position).contains(self.drawer) && !self.touchOnDrawer else {
            drawer.touchUp(atPoint: position)
            self.touchOnDrawer = false
            return
        }
        
        guard let selection = selection else { return }
        
        if selection.complete {
            let agents = selection.units.map{$0.moveComponent}
            let moveToDestination = MoveToDestination(speed: 100,
                                                destination: position,
                                             flockingAgents: agents)
            
            agents.forEach{$0.behavior = moveToDestination}
            self.selection = nil
        } else {
            let sequence = SKAction.sequence({
                let selection = SKAction.run {
                    selection.units = selection.selectUnits()
                    selection.complete = true
                }
                let wait = SKAction.wait(forDuration: 0.2)
                let fadeOut = SKAction.fadeOut(withDuration: 0.3)
                let remove = SKAction.removeFromParent()
                return [selection, wait, fadeOut, remove]
            }())
            
            selection.node.run(sequence)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.forEach { self.touchDown(atPoint: $0.location(in: self)) }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.forEach { self.touchMoved(toPoint: $0.location(in: self)) }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.forEach { self.touchUp(atPoint: $0.location(in: self)) }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.forEach { self.touchUp(atPoint: $0.location(in: self)) }
    }
    
    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
        }
        let dt = currentTime - self.lastUpdateTime
        
        entityManager.update(deltaTime: dt)
        
        lastUpdateTime = currentTime
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        let bodies = [contact.bodyA, contact.bodyB]
        
        func entity(withName name: String) -> GKEntity? {
            return bodies.filter {$0.node?.name==name}.first?.node?.entity
        }
        
        func body(ofType entity: Entity) -> SKPhysicsBody? {
            return bodies.filter { $0.categoryBitMask ==  entity.rawValue }.first
        }
        
        let environmentEdge =   body(ofType: .evironmentEdge)
        let unit =              entity(withName: "unit") as? Unit
        let _ =                 entity(withName: "barrier") as? Barrier
        let bullet =            entity(withName: "bullet") as? Bullet
        
        if let unit = unit, let bullet = bullet {
            guard let shooterTeam = (bullet.shooter as? Unit)?.team else { return }
            guard let unitTeam = unit.team else { return }
            
            guard shooterTeam != unitTeam else { return }
            
            let death = unit.healthComponent.doDamage(amount: bullet.damage)
            if death {
                let fade = SKAction.fadeOut(withDuration: 0.5)
                let remove = SKAction.run {
                    self.entityManager.remove(entity: unit)
                }
                unit.node.run(SKAction.sequence([fade, remove]))
            }
            entityManager.remove(entity: bullet)
        }
        
        if let _ = environmentEdge, let bullet = bullet {
            entityManager.remove(entity: bullet)
        }
        
    }
}

class SizeableCircle: SKShapeNode {
    
    var radius: CGFloat {
        didSet {
            self.path = SizeableCircle.path(radius: self.radius)
        }
    }
    
    init(radius: CGFloat, position: CGPoint) {
        self.radius = radius
        
        super.init()
        
        self.path = SizeableCircle.path(radius: self.radius)
        self.position = position
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    class func path(radius: CGFloat) -> CGMutablePath {
        let path = CGMutablePath()
        path.addArc(center: .zero, radius: radius, startAngle: 0, endAngle: CGFloat(2*M_PI), clockwise: true)
        return path
    }
    
}

class UnitSelection {
    
    var scene: GameScene
    
    var units = [Unit]()
    
    var complete = false
    
    var node: SizeableCircle
    
    let originalTouch: CGPoint
    var finalTouch: CGPoint {
        didSet {
            node.radius = finalTouch.distance(toPoint: midpoint)
            node.position = midpoint
        }
    }
    var midpoint: CGPoint {
        return CGPoint(x: (originalTouch.x+finalTouch.x)/2,
                       y: (originalTouch.y+finalTouch.y)/2)
    }
    
    init(scene: GameScene, position: CGPoint, node: SizeableCircle) {
        self.node = node
        self.originalTouch = position
        self.finalTouch = position

        self.scene = scene
    }
    
    func selectUnits() -> [Unit] {
        var inRange = [Unit]()
        scene.enumerateChildNodes(withName: "unit") { node, stop in
            guard let unit = node.entity as? Unit else { return }
            
            if node.position.distance(toPoint: self.midpoint) <= self.node.radius {
                inRange.append(unit)
            }
        }
        return inRange
    }
    
}

class Infantry {
    
    let player: String
    
    let deployZone: AreaRange

    let color: SKColor
    
    let side: Side
    
    var count = 0
    
    var supplementSize = 1
    
    init(player: String, deployZone: AreaRange, color: SKColor, side: Side) {
        self.player = player
        self.deployZone = deployZone
        self.color = color
        self.side = side
    }
    
    func addSupplement() {
        self.count += supplementSize
    }
    
}

func ==(lhs: Infantry, rhs: Infantry) -> Bool {
    return lhs.player == rhs.player
}

func !=(lhs: Infantry, rhs: Infantry) -> Bool {
    return !(lhs == rhs)
}

struct AreaRange {
    let x: GKRandomDistribution
    let y: GKRandomDistribution
    
    init(x: GKRandomDistribution, y: GKRandomDistribution) {
        self.x = x
        self.y = y
    }
    
    func newPoint() -> CGPoint {
        return CGPoint(x: x.nextInt(), y: y.nextInt())
    }
}

enum Side {
    case top, bottom
}

enum Entity: UInt32 {
    case none, unit, barrier, bullet, evironmentEdge
}

extension CGPoint {
    func distance(toPoint: CGPoint) -> CGFloat {
        return sqrt(pow(self.x - toPoint.x, 2) + pow(self.y - toPoint.y, 2))
    }
}
