//
//  Unit.swift
//  War
//
//  Created by Developer on 9/18/16.
//  Copyright © 2016 JwitApps. All rights reserved.
//

import GameplayKit
import SpriteKit
import UIKit

class Unit: GKEntity {
    
    var node: SKNode {
        return renderComponent.node
    }
    
    lazy var renderComponent: RenderComponent = {
        var radius: CGFloat = 3
        switch self.type {
        case .normal: radius = 10
        case .large:  radius = 20
        }
        
        let node = SKShapeNode(circleOfRadius: radius)
        node.entity = self
        node.name = "unit"
        
        node.fillColor = self.team?.color ?? .black
        node.strokeColor = self.team?.color ?? .black
        return RenderComponent(node: node)
    }()
    
    lazy var moveComponent: MoveComponent = {
        let component = MoveComponent(maxSpeed: 100, maxAcceleration: 1000, radius: Float(self.node.frame.width))
        component.behavior = self.moveBehavior
        return component
    }()
    
    lazy var moveBehavior: GKBehavior? = {
        return self.newMoveBehavior()
    }()
    
    var healthComponent: HealthComponent {
        return component(ofType: HealthComponent.self)!
    }
    
    var teamComponent: TeamComponent? {
        return component(ofType: TeamComponent.self)
    }
    
    var team: Infantry? {
        return teamComponent?.team
    }
    
    var type: UnitType
    
    private var closestBarrier: Barrier? {
        get {
            let unit = self.node
            guard let scene = unit.scene else { return nil }
            
            var closestBarrier: (SKNode, CGFloat)?
            scene.enumerateChildNodes(withName: "barrier") { barrier, stop in
                let distance = unit.position.distance(toPoint: barrier.position)
                
                guard let closest = closestBarrier else {
                    closestBarrier = (barrier, distance)
                    return
                }
                
                closestBarrier = distance < closest.1 ? (barrier, distance) : closestBarrier
            }
            return closestBarrier?.0.entity as? Barrier
        }
    }
    
    init(team: Infantry, type: UnitType, position: CGPoint? = nil) {
        self.type = type
        
        super.init()
        
        var health = 0
        switch type {
        case .normal: health = 100
        case .large: health = 175
        }

        addComponent(TeamComponent(team: team, side: team.side))
        addComponent(renderComponent)
        addComponent(moveComponent)
        addComponent(HealthComponent(health: health))
        
        node.physicsBody = SKPhysicsBody(circleOfRadius: node.frame.width/2)
        node.physicsBody!.isDynamic = false
        node.physicsBody!.categoryBitMask = Entity.unit.rawValue
        node.physicsBody!.collisionBitMask = Entity.none.rawValue
        node.physicsBody!.contactTestBitMask = Entity.bullet.rawValue
        addComponent(PhysicsComponent(physicsBody: node.physicsBody!))
        
        node.position = position ?? team.deployZone.newPoint()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func newMoveBehavior(destination: CGPoint? = nil) -> MoveToPath? {
        guard let barrier = closestBarrier?.node else { return nil }
        let unit = node
        guard let scene = unit.scene else { return nil }

        let size = CGSize(width: barrier.frame.width*(4/5.0), height: 0)
        
        let displacement: CGPoint = {
            let spacing = CGPoint(x: 0, y: 10)
            let unit = CGPoint(x: 0, y: unit.frame.height/2)
            let barrier = CGPoint(x: 0, y: barrier.frame.height/2)
            return CGPoint(x: spacing.x + unit.x + barrier.x,
                           y: spacing.y + unit.y + barrier.y)
        }()
        
        let side: CGFloat = team?.side == .top ? 1 : -1
        
        let points: [float2] = [
            CGPoint(x: -size.width/2, y: displacement.y * side),
            CGPoint(x: size.width/2, y: displacement.y * side),
        ].map {
            let converted = scene.convert($0, from: barrier)
            return float2(x: Float(converted.x), y: Float(converted.y))
        }
        return MoveToPath(speed: 100,
                           stayOn: GKPath(points: points, radius: 0, cyclical: false))
    }
    
    func updateDestination() {
        moveBehavior = newMoveBehavior()
        moveComponent.behavior = moveBehavior
    }
    
    lazy var stopRandomizer = {
        return GKRandomDistribution(lowestValue: 0, highestValue: 30)
    }()
    
    override func update(deltaTime seconds: TimeInterval) {
        if let destinationBehavior = moveComponent.behavior as? MoveToDestination {
            if node.position.distance(toPoint: destinationBehavior.destination) < 80 {
                if stopRandomizer.nextInt() == 0 {
                    moveComponent.behavior = Stop()
                }
            }
        }
    }
    
}

enum UnitType {
    case normal, large
}
