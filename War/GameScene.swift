//
//  GameScene.swift
//  War
//
//  Created by Developer on 9/17/16.
//  Copyright © 2016 JwitApps. All rights reserved.
//

import SpriteKit
import GameplayKit

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

class GameScene: SKScene {
    
    var entities = [GKEntity]()
    var graphs = [String : GKGraph]()
    
    private var lastUpdateTime : TimeInterval = 0
    
    private var reinforcementDuration: CGFloat = 5
    
    lazy private var entityManager: EntityManager = {
        let manager = EntityManager(scene: self)
        manager.componentSystems = [
            GKComponentSystem(componentClass: MoveComponent.self),
        ]
        return manager
    }()
    
    private lazy var infantries: [Infantry] = {[
        self.alliedInfantry, self.axisInfantry,
    ]}()
    private lazy var alliedInfantry: Infantry = {
        let xDistribution = GKRandomDistribution(lowestValue: Int(-self.frame.width)/2, highestValue: Int(self.frame.width)/2)
        let yDistribution = GKRandomDistribution(lowestValue: Int(-self.frame.height)/2, highestValue: Int(-self.frame.height)/2)

        return Infantry(player: "allied",
                    deployZone: AreaRange(x: xDistribution, y: yDistribution),
                         color: .blue,
                          side: .bottom)
    }()
    private lazy var axisInfantry: Infantry = {
        let xDistribution = GKRandomDistribution(lowestValue: Int(-self.frame.width)/2, highestValue: Int(self.frame.width)/2)
        let yDistribution = GKRandomDistribution(lowestValue: Int(self.frame.height)/2, highestValue: Int(self.frame.height)/2)
    
        return Infantry(player: "axis",
                    deployZone: AreaRange(x: xDistribution, y: yDistribution),
                         color: .red,
                          side: .top)
    }()

    lazy var drawer: Drawer = {
        let drawer: Drawer = Drawer(rectOf: CGSize(width: self.frame.width, height: 150))
        drawer.addEntity = { self.entityManager.add(entity: $0) }
        drawer.fillColor = .darkGray
        drawer.strokeColor = .darkGray
        drawer.customConstraints = [
            SKConstraint.positionX(SKRange(constantValue: 0)),
            SKConstraint.positionY(SKRange(constantValue: -self.frame.height/2+drawer.frame.height/2)),
        ].map {
            $0.enabled = false
            return $0
        }
        drawer.constraints = drawer.customConstraints
        return drawer
    }()
    
    var touchOnDrawer = false
    
    override func didMove(to view: SKView) {
        self.view?.ignoresSiblingOrder = true
        
        addChild(self.drawer)
        drawer.customConstraints.forEach{$0.enabled = true}
        setup(drawer: drawer)
        
        physicsWorld.gravity = CGVector(dx: 0, dy: 0)
        physicsWorld.speed = 1
        
        let barrier = Barrier(position: CGPoint(x: 200, y: 200))
        entityManager.add(entity: barrier)
        
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { timer in
           self.incrementInfantryCount()
        }
    }
    
    func setup(drawer: Drawer) {
        let barrier = Barrier()
        barrier.node.name = "drawer-barrier"
        drawer.add(item: barrier.node, withEntity: {Barrier()})
    }
    
    func incrementInfantryCount() {
        self.infantries.forEach{$0.addSupplement()}
    
        let alliedUnit = Unit(team: alliedInfantry)
        alliedUnit.addComponent(ShootComponent(fireRate: 1))
        entityManager.add(entity: alliedUnit)
        alliedUnit.updateDestination()
        
        let axisUnit = Unit(team: axisInfantry)
        entityManager.add(entity: axisUnit)
        axisUnit.updateDestination()
    }
    
    func touchDown(atPoint pos : CGPoint) {
        guard !nodes(at: pos).contains(self.drawer) else {
            drawer.touchDown(atPoint: pos)
            self.touchOnDrawer = true
            return
        }
    }
    
    func touchMoved(toPoint pos : CGPoint) {
        guard !self.touchOnDrawer else {
            drawer.touchMoved(toPoint: pos)
            return
        }
    }
    
    func touchUp(atPoint pos : CGPoint) {
        guard !nodes(at: pos).contains(self.drawer) && !self.touchOnDrawer else {
            drawer.touchUp(atPoint: pos)
            self.touchOnDrawer = false
            return
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
        if self.lastUpdateTime == 0 {
            self.lastUpdateTime = currentTime
        }
        let dt = currentTime - self.lastUpdateTime
        
        self.entityManager.update(deltaTime: dt)
        
        self.entities.forEach { $0.update(deltaTime: dt) }
        
        self.lastUpdateTime = currentTime
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

class RenderComponent: GKComponent {
    
    let node: SKNode
    
    init(node: SKNode) {
        self.node = node
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

class TeamComponent: GKComponent {
    
    let team: Infantry
    let side: Side
    
    init(team: Infantry, side: Side) {
        self.team = team
        self.side = side
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

class RadialGravityComponent: GKComponent {
    
    let gravitationalField = SKFieldNode.vortexField()
    
    override init() {
        gravitationalField.strength = 300
        gravitationalField.falloff = 0
        
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class PhysicsComponent: GKComponent {
    
    let physicsBody: SKPhysicsBody
    
    init(physicsBody: SKPhysicsBody) {
        self.physicsBody = physicsBody
        
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class TouchComponent: GKComponent {
    typealias TouchBlock = ((UITouch, UIEvent?)->())
    
    var touchBegan: TouchBlock? = nil
    var touchMoved: TouchBlock? = nil
    var touchEnded: TouchBlock? = nil
    var touchCancelled: TouchBlock? = nil
    
    init(touchBegan: TouchBlock? = nil, touchMoved: TouchBlock? = nil, touchEnded: TouchBlock? = nil, touchCancelled: TouchBlock? = nil) {
        self.touchBegan = touchBegan
        self.touchMoved = touchMoved
        self.touchEnded = touchEnded
        self.touchCancelled = touchCancelled
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class MoveComponent : GKAgent2D, GKAgentDelegate {
    
    init(maxSpeed: Float, maxAcceleration: Float, radius: Float) {
        super.init()
        self.delegate = self
        self.maxSpeed = maxSpeed
        self.maxAcceleration = maxAcceleration
        self.radius = radius
        self.mass = 1
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func agentWillUpdate(_ agent: GKAgent) {
        guard let node = entity?.component(ofType: RenderComponent.self)?.node else { return }
        position = float2(x: Float(node.position.x), y: Float(node.position.y))
    }
    
    func agentDidUpdate(_ agent: GKAgent) {
        guard let node = entity?.component(ofType: RenderComponent.self)?.node else { return }
        node.position = CGPoint(x: CGFloat(position.x), y: CGFloat(position.y))
    }
}

class MoveBehavior: GKBehavior {
    
    init(speed: Float, stayOn path: GKPath? = nil) {
        super.init()
        
//        if speed > 0 {
//            setWeight(0, for: GKGoal(toWander: speed))
//        }
        
        if let path = path {
            setWeight(50, for: GKGoal(toStayOn: path, maxPredictionTime: 1))
        }
    }
}

class ShootComponent: GKComponent {
    
    var fireRate: Int
    
    lazy var gun: SKNode = {
        guard let parent = self.entity?.component(ofType: RenderComponent.self)?.node else {
            fatalError("entities with ShootComponent must have a RenderComponent")
        }
        let node = SKShapeNode(rectOf: CGSize(width: 5, height: 20))
        node.fillColor = .black
        node.strokeColor = .black
        node.position = CGPoint(x: parent.frame.width/2, y: 10)
        return node
    }()
    
    init(fireRate: Int) {
        self.fireRate = fireRate
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didAddToEntity() {
        guard let parent = entity?.component(ofType: RenderComponent.self)?.node else {
            fatalError("entities with ShootComponent must have a RenderComponent")
        }
        parent.addChild(gun)
    }
    
}

extension CGPoint {
    func distance(toPoint: CGPoint) -> CGFloat {
        return sqrt(pow(self.x - toPoint.x, 2) + pow(self.y - toPoint.y, 2))
    }
}
