//
//  Barrier.swift
//  War
//
//  Created by Developer on 9/18/16.
//  Copyright © 2016 JwitApps. All rights reserved.
//

import GameplayKit
import SpriteKit
import UIKit

class Barrier: GKEntity {
    
    lazy var node: SKNode = {
        let node = SKShapeNode(rectOf: CGSize(width: 100, height: 20))
        node.entity = self
        node.name = "barrier"
        node.fillColor = .darkGray
        return node
    }()
  
    lazy var renderComponent: RenderComponent = {
        return RenderComponent(node: self.node)
    }()
    
    lazy var moveComponent: MoveComponent = {
        return MoveComponent(maxSpeed: 0, maxAcceleration: 0, radius: 0)
    }()
    
    override convenience  init() {
        self.init(position: .zero)
    }

    init(position: CGPoint = .zero) {
        super.init()
        
        node.position = position
        
        addComponent(renderComponent)
        addComponent(moveComponent)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
}
