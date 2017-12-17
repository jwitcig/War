//
//  Components.swift
//  War
//
//  Created by Jonah Witcig on 9/19/16.
//  Copyright © 2016 JwitApps. All rights reserved.
//

import GameplayKit
import SpriteKit

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
        
        node.zRotation = speed > 0 ? atan2(CGFloat(velocity.y), CGFloat(velocity.x)) - CGFloat(M_PI_2) : 0
    }
}

class MoveToPath: GKBehavior {
    init(speed: Float, stayOn path: GKPath) {
        super.init()
        
        setWeight(50, for: GKGoal(toStayOn: path, maxPredictionTime: 1))
    }
}

class MoveToDestination: GKBehavior {
    
    let destination: CGPoint
    
    let destinationGoal: GKGoal
    let alignGoal: GKGoal
    let cohereGoal: GKGoal
    let avoidGoal: GKGoal
    
    init(speed: Float, destination: CGPoint, flockingAgents: [GKAgent]) {
    
        self.destination = destination
        
        let agent = GKAgent2D()
        agent.position = vector2(Float(destination.x), Float(destination.y))
        
        self.destinationGoal = GKGoal(toSeekAgent: agent)
        self.alignGoal = GKGoal(toAlignWith: flockingAgents, maxDistance: 200, maxAngle: .pi/4)
        self.cohereGoal = GKGoal(toCohereWith: flockingAgents, maxDistance: 200, maxAngle: .pi/4)
        self.avoidGoal = GKGoal(toSeparateFrom: flockingAgents, maxDistance: 20, maxAngle: .pi)
        super.init()
        
        setWeight(10, for: destinationGoal)
        setWeight(50, for: alignGoal)
        setWeight(50, for: cohereGoal)
        setWeight(800, for: avoidGoal)
    }
}

class Stop: GKBehavior {
    override init() {
        super.init()
        
        setWeight(100, for: GKGoal(toReachTargetSpeed: 0))
    }
}

class ShootComponent: GKComponent {
    
    lazy var renderComponent: RenderComponent = {
        if let component = self.entity?.component(ofType: RenderComponent.self) {
            return component
        }
        fatalError("Entity with ShootingComponent must have a node in the scene")
    }()
    
    lazy var teamComponent: TeamComponent = {
        if let component = self.entity?.component(ofType: TeamComponent.self) {
            return component
        }
        fatalError("Entity must be on a team")
    }()
    
    var fireRate: Int
    
    lazy var firingTimer: Timer = {
        return Timer.scheduledTimer(withTimeInterval: 1.0/Double(self.fireRate), repeats: true) { timer in
            if let target = self.enemyInRange() {
                self.fire(target: target)
            }
        }
    }()
    
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
        renderComponent.node.addChild(gun)
        
        startFiring()
    }
    
    func fire(target: GKEntity) {
        let node = renderComponent.node
        
        guard let scene = node.scene as? GameScene else { return }

        guard let shooter = entity else { return }
        
        guard target.component(ofType: RenderComponent.self)?.node.scene != nil else { return }
        
        let bullet = Bullet(shooter: shooter, target: target)
        scene.entityManager.add(entity: bullet)
    }
    
    func startFiring() {
        firingTimer.fire()
    }
    
    func enemyInRange() -> Unit? {
        let node = renderComponent.node
        guard let scene = node.scene else { return nil }
       
        var enemyInRange: Unit?
        scene.enumerateChildNodes(withName: "unit") { enemy, stop in
            guard node.position.distance(toPoint: enemy.position) < 100 else { return }
            
            guard let enemyUnit = enemy.entity as? Unit else { return }
            
            guard let enemyTeam = enemyUnit.team else { return }
            
            if enemyTeam != self.teamComponent.team {
                enemyInRange = enemyUnit
            }
        }
        return enemyInRange
    }
    
}

class HealthComponent: GKComponent {
    
    lazy var renderComponent: RenderComponent = {
        if let component = self.entity?.component(ofType: RenderComponent.self) {
            return component
        }
        fatalError("Entity with ShootingComponent must have a node in the scene")
    }()
    
    var health: Int
    
    init(health: Int) {
        self.health = 100
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func doDamage(amount: Int) -> Bool {
        health -= amount
        return health <= 0
    }
    
}
