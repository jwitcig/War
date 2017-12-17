//
//  Bullet.swift
//  War
//
//  Created by Jonah Witcig on 9/19/16.
//  Copyright © 2016 JwitApps. All rights reserved.
//

import GameplayKit
import SpriteKit
import UIKit

class Bullet: GKEntity {
    
    lazy var node: SKNode = {
        let node = SKShapeNode(rectOf: CGSize(width: 3, height: 20))
        node.entity = self
        node.name = "bullet"
        node.position = self.shooterPosition
        node.fillColor = .red
        node.strokeColor = .red
        return node
    }()
    
    let shooter: GKEntity
    let target: GKEntity
    
    var damage = 20
    
    var shooterPosition: CGPoint {
        if let node = shooter.component(ofType: RenderComponent.self)?.node {
            return node.position
        }
        fatalError("shooter must have a RenderComponent")
    }
    var targetPosition: CGPoint {
        if let node = target.component(ofType: RenderComponent.self)?.node {
            return node.position
        }
        fatalError("target must have a RenderComponent")
    }
    
    var distanceToTarget: CGFloat {
        return node.position.distance(toPoint: targetPosition)
    }
    
    lazy var renderComponent: RenderComponent = {
        return RenderComponent(node: self.node)
    }()
    
    lazy var moveComponent: MoveComponent = {
        return MoveComponent(maxSpeed: 0, maxAcceleration: 0, radius: 0)
    }()
    
    init(shooter: GKEntity, target: GKEntity) {
        self.shooter = shooter
        self.target = target

        super.init()
        
        addComponent(renderComponent)
        
        node.physicsBody = SKPhysicsBody(rectangleOf: node.frame.size)
        node.physicsBody!.categoryBitMask = Entity.bullet.rawValue
        node.physicsBody!.collisionBitMask = Entity.none.rawValue
        node.physicsBody!.contactTestBitMask = Entity.unit.rawValue
        addComponent(PhysicsComponent(physicsBody: node.physicsBody!))
        
        startMotion()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("unimplemented method init(coder:)")
    }
    
    func startMotion() {
        let speed: CGFloat = 300
        let bulletVector = CGVector(
            dx: (self.targetPosition.x - node.position.x)/self.distanceToTarget * speed,
            dy: (self.targetPosition.y - node.position.y)/self.distanceToTarget * speed)
        let move = SKAction.move(by: bulletVector, duration: 1)
        let wait = SKAction.wait(forDuration: 0.7)
        let disipate = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()
        
        node.run(move)
        node.run(SKAction.sequence([wait, disipate, remove]))
        node.zRotation = atan2(bulletVector.dy, bulletVector.dx) + CGFloat(M_PI_2)
    }
    
}
