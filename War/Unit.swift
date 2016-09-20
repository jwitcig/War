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
        let node = SKShapeNode(circleOfRadius: 10)
        node.entity = self
        node.name = "unit"
        
        node.fillColor = self.team?.color ?? .black
        node.strokeColor = self.team?.color ?? .black
        return RenderComponent(node: node)
    }()
    
    lazy var moveComponent: MoveComponent = {
        let component = MoveComponent(maxSpeed: 100, maxAcceleration: 1000, radius: 0)
        component.behavior = self.moveBehavior
        return component
    }()
    
    lazy var moveBehavior: MoveBehavior? = {
        return self.newMoveBehavior()
    }()
    
    var teamComponent: TeamComponent? {
        return component(ofType: TeamComponent.self)
    }
    
    var team: Infantry? {
        return teamComponent?.team
    }
    
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
    
    init(team: Infantry, position: CGPoint? = nil) {
        super.init()
        
        addComponent(TeamComponent(team: team, side: team.side))

        addComponent(renderComponent)
        addComponent(moveComponent)
        
        node.position = position ?? team.deployZone.newPoint()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func newMoveBehavior() -> MoveBehavior? {        
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
            CGPoint(x: -size.width/2,
                    y: displacement.y * side),
            CGPoint(x: size.width/2,
                    y: displacement.y * side),
        ].map {
            let converted = scene.convert($0, from: barrier)
            return float2(x: Float(converted.x), y: Float(converted.y))
        }
        
        return MoveBehavior(speed: 100,
                           stayOn: GKPath(points: points, radius: 0, cyclical: false))
    }
    
    func updateDestination() {
        moveBehavior = newMoveBehavior()
        moveComponent.behavior = moveBehavior
    }
    
}
